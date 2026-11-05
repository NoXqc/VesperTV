# dmgbuild settings for the VesperTV macOS installer.
# Used by tools/macos_dmg/build.sh:
#   dmgbuild -s settings.py -D app=<VesperTV.app> -D assets=<dir> "VesperTV 1.0" out.dmg
# Window size and icon positions must match make_background.py.
import os

app = defines["app"]  # noqa: F821 (injected by dmgbuild)
assets = defines["assets"]  # noqa: F821
appname = os.path.basename(app)

format = "UDZO"
compression_level = 9
filesystem = "HFS+"

files = [app]
symlinks = {"Applications": "/Applications"}
icon = os.path.join(app, "Contents", "Resources", "AppIcon.icns")  # volume icon
hide_extensions = [appname]

background = os.path.join(assets, "background.png")  # + background@2x.png
window_rect = ((200, 160), (660, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 112
text_size = 13
label_pos = "bottom"
arrange_by = None
icon_locations = {
    appname: (170, 228),
    "Applications": (490, 228),
}
