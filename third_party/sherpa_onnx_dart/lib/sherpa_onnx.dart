// Copyright (c)  2024  Xiaomi Corporation (sherpa-onnx, Apache-2.0).
// VesperTV: native-only entry point of the sherpa-onnx 2.0.1 Dart bindings
// (no web, no bundled libraries). See ../pubspec.yaml.
import 'src/init_native.dart' as init;

export 'src/feature_config.dart';
export 'src/homophone_replacer_config.dart';
export 'src/online_recognizer_config.dart';
export 'src/online_recognizer.dart';
export 'src/online_stream.dart';
export 'src/version.dart';

/// Loads the native library from the folder [path] (Android:
/// `libsherpa-onnx-c-api.so`, with `libonnxruntime.so` opened first). Call it
/// once in every isolate that uses the recognizer.
void initBindings(String path) => init.initNativeBindings(path);
