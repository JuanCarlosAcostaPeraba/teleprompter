# Teleprompter

Teleprompter nativo para macOS 14 o posterior. Guarda el guion en este Mac y sigue lo que lees con el reconocimiento de voz local de Apple. Puedes elegir entre los idiomas y las variantes que macOS ofrece para el reconocimiento de voz.

## Abrir la aplicación

Descarga `Teleprompter-macOS.zip` en [Releases](https://github.com/JuanCarlosAcostaPeraba/teleprompter/releases/latest), descomprímelo y abre **Teleprompter.app**. La descarga es para Apple Silicon e Intel y usa firma ad hoc.

Para compilar desde el código, ejecuta `./scripts/build-app.sh` con Swift 6 o posterior y abre `dist/Teleprompter.app`.

1. Pega el guion y elige su idioma. Si necesitas preparar un idioma, abre **Configurar idiomas en Dictado…** y revisa **Teclado → Dictado → Idiomas**. La disponibilidad local depende del idioma y del Mac. Escribe las indicaciones de escena entre corchetes.
2. Pulsa **Abrir lector** y coloca el panel flotante cerca de la cámara.
3. El lector empieza a escuchar al abrirse. Concede los permisos de micrófono y reconocimiento cuando macOS los solicite. Verás el nombre de la entrada junto al medidor. Puedes desactivar **Escuchar al abrir el lector** en Ajustes. Puedes seguir en modo manual si el reconocimiento local para ese idioma no está disponible.
4. Pulsa una palabra, usa las flechas o vuelve al inicio para ajustar la posición. En **Vista** puedes cambiar el tamaño del texto y la opacidad.

## Compartir o grabar

Selecciona la ventana de la presentación o de la aplicación que vas a mostrar. Teleprompter permanece en su propio panel. También puedes activar **Solicitar exclusión de captura en macOS**. Esa opción usa una API heredada de AppKit y su efecto depende de cómo capture la otra aplicación. Comprueba la previsualización antes de compartir o grabar la pantalla completa.

## Desarrollo

`swift test` comprueba el seguimiento de texto con transcripciones simuladas. `./scripts/build-app.sh` genera la aplicación en `dist/`.

## Dock, barra de menús y accesos rápidos

Desde el icono de la barra de menús puedes abrir el lector, leer texto copiado, editar el guion y cambiar el idioma, tamaño de letra, opacidad, desenfoque, color de resalto y exclusión de captura. La barra del micrófono mide la señal local mientras el lector escucha. Con Teleprompter activo también puedes abrir **Controles rápidos** con **⌘⇧K**. El texto del portapapeles se carga en el lector sin reemplazar el guion guardado. Los ajustes de Dock y barra de menús son independientes. Ocultar sus iconos no cambia la exclusión del lector al compartir pantalla.

- **Spotlight:** busca **Teleprompter** y ábrelo para recuperar los ajustes, aunque hayas ocultado ambos iconos. Para que Spotlight lo encuentre fácilmente, coloca la app en **Aplicaciones**.
- **Raycast:** añade [scripts/raycast](scripts/raycast) como carpeta de Script Commands y busca **Ajustes de Teleprompter**. También puedes crear un Quicklink con `teleprompter://settings`.

## Arranque y permisos

Al arrancar, Teleprompter se queda en el Dock, en la barra de menús o en ambos, según tus ajustes. Si ocultas ambos iconos, muestra Ajustes al arrancar. Al abrir el lector se cierran las ventanas de edición y configuración. Ajustes muestra una vista previa bajo la cámara que refleja el tamaño, el resalto, la opacidad y el desenfoque sin activar el micrófono.

macOS puede volver a pedir acceso al micrófono y al reconocimiento al actualizar una compilación con firma ad hoc. Para compilaciones locales con una identidad de firma válida, usa `TELEPROMPTER_SIGN_IDENTITY` con el nombre o el hash de la identidad y conserva la misma en las siguientes compilaciones.
