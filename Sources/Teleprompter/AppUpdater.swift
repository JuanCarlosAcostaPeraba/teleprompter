import AppKit
import CoreServices
import CryptoKit
import SwiftUI

@MainActor
final class AppUpdater: ObservableObject {
    @Published private(set) var status: String?
    @Published private(set) var busy = false
    @Published private(set) var available: Release?

    private static let repository = "JuanCarlosAcostaPeraba/teleprompter"
    private static let assetNames = ["Teleprompter.dmg", "Teleprompter-macOS.dmg"]
    private static let latestRelease = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    private static let releasesPage = URL(string: "https://github.com/\(repository)/releases/latest")!

    func check() {
        check(automatically: false)
    }

    func checkInBackground() {
        check(automatically: true)
    }

    private func check(automatically: Bool) {
        guard !busy else { return }
        busy = true
        if !automatically { status = "Buscando actualizaciones…" }
        Task {
            defer { busy = false }
            do {
                var request = URLRequest(url: Self.latestRelease, timeoutInterval: 20)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("Teleprompter", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                try Self.validate(response)
                let release = try JSONDecoder().decode(Release.self, from: data)
                let installed = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                guard let latest = Version(release.tag), let current = Version(installed) else {
                    throw UpdateError.invalidRelease
                }
                if latest > current {
                    let newlyAvailable = available?.tag != release.tag
                    available = release
                    if newlyAvailable || !automatically {
                        status = "Teleprompter \(latest) está disponible."
                    }
                } else {
                    if available != nil || !automatically {
                        status = "Teleprompter \(current) está al día."
                    }
                    available = nil
                }
            } catch {
                if !automatically {
                    status = "No se pudo comprobar la versión: \(error.localizedDescription)"
                }
            }
        }
    }

    func download() {
        guard !busy, let release = available else { return }
        guard let asset = Self.assetNames.lazy.compactMap({ name in
            release.assets.first { $0.name == name }
        }).first,
              let version = Version(release.tag),
              let expected = asset.sha256,
              let url = URL(string: asset.downloadURL),
              url.scheme == "https", url.host == "github.com",
              url.path == "/\(Self.repository)/releases/download/\(release.tag)/\(asset.name)" else {
            status = "La versión no incluye un DMG verificable. Consulta GitHub."
            NSWorkspace.shared.open(Self.releasesPage)
            return
        }
        busy = true
        status = "Descargando Teleprompter \(version)…"
        Task {
            defer { busy = false }
            do {
                let file = try await Self.downloadDiskImage(url: url, digest: expected, version: version)
                guard NSWorkspace.shared.open(file) else { throw UpdateError.couldNotOpen }
                status = "DMG abierto. Cierra Teleprompter y reemplázalo en Aplicaciones."
            } catch {
                status = "No se pudo preparar el DMG: \(error.localizedDescription)"
            }
        }
    }

    private nonisolated static func downloadDiskImage(url: URL, digest: String, version: Version) async throws -> URL {
        let (temporary, response) = try await URLSession.shared.download(from: url)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try validate(response)
        let actual = SHA256.hash(data: try Data(contentsOf: temporary, options: .mappedIfSafe))
            .map { String(format: "%02x", $0) }.joined()
        guard actual == digest else { throw UpdateError.checksumMismatch }

        // Keep Gatekeeper in the loop just as a browser download would.
        try (temporary as NSURL).setResourceValue([
            kLSQuarantineTypeKey as String: kLSQuarantineTypeWebDownload,
            kLSQuarantineAgentNameKey as String: "Teleprompter",
            kLSQuarantineDataURLKey as String: url
        ], forKey: .quarantinePropertiesKey)

        let manager = FileManager.default
        let downloads = try manager.url(for: .downloadsDirectory, in: .userDomainMask,
                                        appropriateFor: nil, create: true)
        let stem = "Teleprompter-\(version)"
        let destination = downloads.appendingPathComponent(stem + ".dmg")
        let file = manager.fileExists(atPath: destination.path)
            ? downloads.appendingPathComponent(stem + "-" + UUID().uuidString.prefix(8) + ".dmg")
            : destination
        try manager.moveItem(at: temporary, to: file)
        return file
    }

    private nonisolated static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              http.url?.scheme == "https" else { throw UpdateError.network }
    }

    struct Release: Decodable {
        let tag: String
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tag = "tag_name"
            case assets
        }
    }

    struct Asset: Decodable {
        let name: String
        let downloadURL: String
        let digest: String?

        enum CodingKeys: String, CodingKey {
            case name, digest
            case downloadURL = "browser_download_url"
        }

        var sha256: String? {
            guard let digest, digest.hasPrefix("sha256:") else { return nil }
            let hash = String(digest.dropFirst(7)).lowercased()
            guard hash.count == 64, hash.allSatisfy({ "0123456789abcdef".contains($0) }) else { return nil }
            return hash
        }
    }

    struct Version: Comparable, CustomStringConvertible {
        let parts: [Int]

        init?(_ text: String) {
            let version = text.hasPrefix("v") ? String(text.dropFirst()) : text
            let components = version.split(separator: ".", omittingEmptySubsequences: false)
            let numbers = components.compactMap { Int($0) }
            guard components.count == 3, numbers.count == 3,
                  numbers.allSatisfy({ $0 >= 0 }), numbers.map(String.init).joined(separator: ".") == version else {
                return nil
            }
            parts = numbers
        }

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.parts.lexicographicallyPrecedes(rhs.parts) }
        var description: String { parts.map(String.init).joined(separator: ".") }
    }

    enum UpdateError: LocalizedError {
        case invalidRelease, network, checksumMismatch, couldNotOpen

        var errorDescription: String? {
            switch self {
            case .invalidRelease: "La versión publicada no se pudo interpretar."
            case .network: "GitHub no devolvió una respuesta válida."
            case .checksumMismatch: "La huella SHA-256 del archivo no coincide."
            case .couldNotOpen: "macOS no pudo abrir la imagen de disco."
            }
        }
    }
}

struct UpdateControls<Trailing: View>: View {
    @ObservedObject var updater: AppUpdater
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Button("Buscar actualizaciones", systemImage: "arrow.clockwise", action: updater.check)
                    .disabled(updater.busy)
                if updater.busy { ProgressView().controlSize(.small) }
                Spacer(minLength: 0)
                trailing()
            }
            if let status = updater.status {
                Text(status).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if updater.available != nil {
                Button("Descargar y abrir DMG", systemImage: "arrow.down.to.line", action: updater.download)
                    .disabled(updater.busy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension UpdateControls where Trailing == EmptyView {
    init(updater: AppUpdater) {
        self.init(updater: updater) { EmptyView() }
    }
}
