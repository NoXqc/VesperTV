// Native platform initialization (dart:io available).
import 'dart:io';
import 'dart:ffi';

import 'sherpa_onnx_bindings.dart';

DynamicLibrary loadDylib(String? path) {
  if (Platform.isMacOS) {
    if (path == null) {
      return DynamicLibrary.process();
    } else {
      return DynamicLibrary.open(
        '$path/sherpa_onnx_macos/sherpa-onnx.xcframework/macos-arm64_x86_64/libsherpa-onnx-c-api.dylib',
      );
    }
  }

  if (Platform.isIOS) {
    return DynamicLibrary.process();
  }

  if (Platform.isAndroid || Platform.isLinux) {
    if (path == null) {
      return DynamicLibrary.open('libsherpa-onnx-c-api.so');
    } else {
      // VesperTV: downloaded libraries live outside the app's library
      // folder, so the linker can't find libonnxruntime.so (a dependency of
      // the C API) by name: load it first by its full path.
      if (File('$path/libonnxruntime.so').existsSync()) {
        DynamicLibrary.open('$path/libonnxruntime.so');
      }
      return DynamicLibrary.open('$path/libsherpa-onnx-c-api.so');
    }
  }

  if (Platform.isWindows) {
    if (path == null) {
      return DynamicLibrary.open('sherpa-onnx-c-api.dll');
    } else {
      return DynamicLibrary.open('$path\\sherpa-onnx-c-api.dll');
    }
  }

  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}

void initNativeBindings(String? path) {
  final dylib = loadDylib(path);
  SherpaOnnxBindings.init(dylib);
}
