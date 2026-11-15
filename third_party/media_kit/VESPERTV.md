# media_kit 1.2.6, patched for Apple TV

A copy of media_kit **1.2.6** (pub.dev, Dart only: `lib/`, `assets/`) used
through `dependency_overrides` in the app's pubspec.yaml. One change:
`lib/src/player/native/core/native_library.dart` has a `'tvos'` entry
(`Mpv.framework/Mpv`) beside `'ios'`, in the library names and the error
messages. media_kit picks libmpv by `Platform.operatingSystem`, which is
`'tvos'` on Apple TV (flutter-tvos), and media_kit_video looks libmpv up
again without a path (`queryDecoders`), so passing `libmpv:` to
`MediaKit.ensureInitialized` alone isn't enough. Dart's
`Platform.environment` is empty on Apple platforms, so
`LIBMPV_LIBRARY_PATH` can't be used either.

Every other platform runs the same code as upstream. If media_kit is bumped,
re-copy it here and re-apply the entry. dev-notes/apple-tv.md.
