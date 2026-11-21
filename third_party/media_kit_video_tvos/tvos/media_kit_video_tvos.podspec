#
# Apple TV video output for package:media_kit: media_kit_video 1.3.1's iOS
# plugin code (Classes/, unchanged) plus libmpv as Frameworks/Mpv.xcframework,
# which tools/tvos/build_mpv_framework.sh builds from MPVKit (LGPL) on the
# tvOS workflow. See ../README.md.
#
Pod::Spec.new do |s|
  s.name             = 'media_kit_video_tvos'
  s.version          = '0.0.1'
  s.summary          = 'Apple TV video output for package:media_kit.'
  s.description      = 'media_kit_video iOS plugin code built for tvOS, with libmpv from MPVKit.'
  s.homepage         = 'https://github.com/NoXqc/VesperTV'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'VesperTV' => 'noreply@vespertv.app' }
  s.source           = { :path => '.' }
  s.platform         = :tvos, '15.0'
  s.swift_version    = '5.0'
  s.source_files     = 'Classes/**/*.swift', 'Headers/**/*.h'
  s.public_header_files = 'Headers/**/*.h'
  s.vendored_frameworks = 'Frameworks/Mpv.xcframework'
  s.frameworks       = 'OpenGLES', 'CoreVideo', 'UIKit'

  # Like the fluttertv.dev ports: no dependency on the Flutter pod (it has no
  # tvOS support); Flutter.framework comes from the host app's Flutter folder.
  s.xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '"${PODS_ROOT}/../Flutter"',
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE'               => 'YES',
    'GCC_WARN_INHIBIT_ALL_WARNINGS' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' => '"$(inherited)" GL_SILENCE_DEPRECATION COREVIDEO_SILENCE_GL_DEPRECATION',
    # The vendored framework is only linked into the app by CocoaPods; this
    # pod's own Swift calls mpv_* too (as media_kit_video's iOS podspec).
    'OTHER_LDFLAGS'                => '"$(inherited)" -framework Mpv',
  }
end
