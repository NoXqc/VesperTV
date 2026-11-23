# Adds the TopShelf extension target (tvos/TopShelf) to tvos/Runner.xcodeproj
# and embeds it in the app (dev-notes/apple-tv-parity-plan.md point 5).
#
# Run by .github/workflows/tvos-build.yml before every build: there is no Mac
# here to add a target in Xcode, and hand-editing project.pbxproj is fragile.
# Idempotent: a project that already has the target is left alone.
#
#   ruby tools/tvos/add_topshelf_target.rb [path/to/Runner.xcodeproj]
#
# Needs the xcodeproj gem (it comes with CocoaPods).
require 'xcodeproj'

project_path = ARGV[0] || File.expand_path('../../tvos/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

if project.targets.any? { |t| t.name == 'TopShelf' }
  puts 'TopShelf: already in the project'
  exit 0
end

app = project.targets.find { |t| t.name == 'Runner' } or abort('error: no Runner target')

ext = project.new_target(:tv_extension, 'TopShelf', :tvos, '15.0')

group = project.main_group.find_subpath('TopShelf', true)
group.set_source_tree('<group>')
group.set_path('TopShelf')
source = group.new_reference('ContentProvider.swift')
group.new_reference('Info.plist')
group.new_reference('TopShelf.entitlements')
xcconfig = group.new_reference('TopShelf.xcconfig')
ext.add_file_references([source])

ext.build_configurations.each do |config|
  config.base_configuration_reference = xcconfig
  s = config.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'app.vespertv.player.TopShelf'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = 'TopShelf/Info.plist'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['CODE_SIGN_ENTITLEMENTS'] = 'TopShelf/TopShelf.entitlements'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['SDKROOT'] = 'appletvos'
  s['SUPPORTED_PLATFORMS'] = 'appletvos appletvsimulator'
  s['TARGETED_DEVICE_FAMILY'] = '3'
  s['TVOS_DEPLOYMENT_TARGET'] = '15.0'
  s['SWIFT_VERSION'] = '5.0'
  s['SKIP_INSTALL'] = 'YES'
  s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS'] = [
    '$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'
  ]
  s['ENABLE_BITCODE'] = 'NO'
end

# The extension builds before the app and goes into its PlugIns folder.
app.add_dependency(ext)
embed = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
embed.name = 'Embed Foundation Extensions'
embed.symbol_dst_subfolder_spec = :plug_ins
embed.dst_path = ''
file = embed.add_file_reference(ext.product_reference, true)
file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
# Right after Resources, before the Flutter script phases: an embed phase
# after a script that writes into the app bundle makes Xcode report a
# build cycle.
resources_at = app.build_phases.index { |p| p.is_a?(Xcodeproj::Project::Object::PBXResourcesBuildPhase) }
app.build_phases.insert(resources_at ? resources_at + 1 : app.build_phases.length, embed)

project.save
puts "TopShelf: target added and embedded in Runner (#{project_path})"
