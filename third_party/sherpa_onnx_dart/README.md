Copy of the Dart part of [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) 2.0.1 (`flutter/sherpa_onnx/lib/src`,
Apache-2.0, LICENSE here) used by VesperTV's automatic live subtitles. Changed: `lib/sherpa_onnx.dart` exports only
the streaming recognizer and loads the native library from a given folder; `pubspec.yaml` drops the platform
packages (their native libraries are downloaded on demand instead, pinned to the 2.0.1 archives on pub.dev).
To update: copy the new `lib/src` (minus `web/` and `init_stub.dart`) and bump the pinned archives in
`lib/services/auto_subtitles.dart`.
