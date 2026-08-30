# Local Dictation

[English (canonical)](README.md) · [Español](README.es.md) · [Русский](README.ru.md)

Dictado local para macOS, configurado y verificado para ruso. Mantén pulsada una tecla global, habla y la transcripción sin editar de Whisper se insertará directamente en el campo de texto enfocado: sin nube, sin posprocesamiento y sin pulsar Enter.

El audio y la transcripción permanecen en tu Mac: la aplicación ejecuta WhisperKit localmente. El decodificador está configurado con `language = ru`. Otros idiomas no han superado el gate de aceptación del proyecto y no forman parte de los claims de `v0.1.0`. Los pesos del modelo y los archivos del tokenizer no están incluidos; debes instalarlos por separado sin conexión.

Una compilación local necesita permisos de Micrófono y Accesibilidad antes de dictar. Concédelos desde la aplicación de la barra de menús antes de evaluar la inserción.

Esta alpha experimental basada únicamente en código fuente está dirigida a macOS 14 o posterior. La compilación automatizada actual se verifica en macOS 15; la compatibilidad de ejecución con macOS 14 aún no se ha probado por separado. No incluye telemetría, servicio de actualizaciones ni una descarga `.app`. Consulta la documentación de [privacidad](docs/PRIVACY.md), [compilación](docs/BUILD.md) y [limitaciones conocidas](docs/LIMITATIONS.md) antes de usarla.

Si alguna traducción difiere, la versión inglesa es la canónica.

## Qué hace

- Aplicación para la barra de menús escrita en Swift y AppKit.
- Hold-to-talk con una tecla global configurable.
- Una inferencia local de WhisperKit (`language = ru`).
- Inserción byte por byte de la transcripción sin editar: sin modelo de corrección, diccionario, historial ni comandos de voz.
- Inserción mediante Accessibility con una alternativa protegida de Command+V; nunca se sintetiza Enter/Return.
- El audio temporal de la aplicación se elimina antes de continuar con la transcripción.

El modo manos libres mediante doble pulsación existe en el código fuente, pero es experimental y no forma parte del release claim.

## No incluido

- Archivos del modelo o del tokenizer; consulta [MODEL_SETUP.md](docs/MODEL_SETUP.md) para instalarlos sin conexión.
- Una aplicación `.app` firmada o notarizada.
- Transcripción en la nube, análisis, telemetría ni servicio de actualizaciones.
- Compatibilidad garantizada con Bluetooth, WhatsApp o cualquier aplicación de destino.
- Compatibilidad verificada con inglés, español o detección automática del idioma.

## Estado

`v0.1.0` es una alpha basada únicamente en código fuente bajo la [licencia MIT](LICENSE). Las revisiones del modelo y del tokenizer están fijadas a commits exactos con inventarios de integridad completos, pero este proyecto no incluye ni licencia los archivos externos.

## Verificación rápida

```bash
./scripts/privacy-scan.sh
./scripts/check-dependencies.sh
./scripts/check-toolchain.sh
./scripts/run-core-tests-offline.sh
./scripts/run-tests.sh
```

La aplicación nunca descarga un modelo durante la ejecución. Consulta [MODEL_SETUP.md](docs/MODEL_SETUP.md) para conocer el límite de instalación sin conexión.

## Licencia

El código fuente está disponible bajo la [licencia MIT](LICENSE). Las dependencias externas y los recursos del modelo están sujetos a sus propias condiciones; consulta [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
