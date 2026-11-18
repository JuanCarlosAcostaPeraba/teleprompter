# Teleprompter

Teleprompter nativo para macOS 14 o posterior. Guarda el guion en este Mac y sigue lo que lees con el reconocimiento de voz local de Apple. Puedes elegir español de España o inglés de Estados Unidos.

## Abrir la aplicación

Descarga `Teleprompter-macOS.zip` en [Releases](https://github.com/JuanCarlosAcostaPeraba/teleprompter/releases/latest), descomprímelo y abre **Teleprompter.app**. La descarga es para Apple Silicon e Intel y usa firma ad hoc.

Para compilar desde el código, ejecuta `./scripts/build-app.sh` con Swift 6 o posterior y abre `dist/Teleprompter.app`.

1. Pega el guion y elige su idioma. Escribe las indicaciones de escena entre corchetes.
2. Pulsa **Abrir lector** y coloca el panel flotante cerca de la cámara.
3. Pulsa **Escuchar** y concede los permisos de micrófono y reconocimiento cuando macOS los solicite. Puedes seguir en modo manual si el reconocimiento local para ese idioma no está disponible.
4. Pulsa una palabra, usa las flechas o vuelve al inicio para ajustar la posición. En **Vista** puedes cambiar el tamaño del texto y la opacidad.

## Compartir o grabar

Selecciona la ventana de la presentación o de la aplicación que vas a mostrar. Teleprompter permanece en su propio panel. También puedes activar **Solicitar exclusión de captura en macOS**. Esa opción usa una API heredada de AppKit y su efecto depende de cómo capture la otra aplicación. Comprueba la previsualización antes de compartir o grabar la pantalla completa.

## Desarrollo

`swift test` comprueba el seguimiento de texto con transcripciones simuladas. `./scripts/build-app.sh` genera la aplicación en `dist/`.

## Dock, barra de menús y accesos rápidos

Desde el icono de la barra de menús puedes abrir el lector, leer texto copiado, editar el guion y cambiar el idioma, tamaño de letra, opacidad y exclusión de captura. Los ajustes de Dock y barra de menús son independientes. Ocultar sus iconos no cambia la exclusión del lector al compartir pantalla.

- **Spotlight:** busca **Teleprompter** y ábrelo para recuperar los ajustes, aunque hayas ocultado ambos iconos. Para que Spotlight lo encuentre fácilmente, coloca la app en **Aplicaciones**.
- **Raycast:** añade [scripts/raycast](scripts/raycast) como carpeta de Script Commands y busca **Ajustes de Teleprompter**. También puedes crear un Quicklink con `teleprompter://settings`.
