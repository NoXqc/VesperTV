# Startup profile selector (cdx, 2026-10-28)

Branch: `codex/startup-profile-selector`, based on published +492 (`eaed570`).
Claude's uncommitted +493 Sports Menu/provider-error changes remain in the owner's
checkout. This feature does not include or modify those changes.

Settings > General > Startup > **Launch with profiles selector** is off by default.
It is shared by every viewer on this device, retained by backups, and excluded
from device transfers so the receiving device keeps its own startup choice.
It applies on the next cold launch, even with only the Main profile.

The existing splash/catalog budgets are unchanged. Before creating application
routes, `main.dart` waits on a selection completer. `StartupProfileScreen` uses a
separate MaterialApp/Navigator for the picker and any existing PIN flow; startup
navigation, resume hints/overlays and automatic playback are not mounted behind it.
After a successful switch and a 420ms selection animation, the gate creates the
real application and awaits its first frame before releasing post-splash startup.
Selecting the active viewer also continues. Cancelling PIN or a failed switch
keeps the picker open. Back cannot silently choose the previous viewer.

All viewer changes go through `ViewerProfileService.switchTo`: leaving a
restricted viewer still needs the PIN. History, favourites, restrictions, theme
and Sports Mode are applied before the selected viewer's startup routes/resume.
There is no alternate bypass or new active-viewer storage format.

The bounded blurred panel uses static background gradients, existing profile
photos/initials and scrollable wrapping cards. Initial focus is the last viewer;
arrow movement uses actual columns and reveals offscreen rows immediately.
The selected card grows while other cards fade, then the app opens. Reduced
motion removes the picker entrance/selection delay. English, French, Spanish,
Italian and Greek strings are included. Profile creation/editing stays in its
existing places.

Validation: startup setting persistence/transfer/backup; settings UI; actual
viewer switching/theme/Sports Mode; PIN cancellation and successful unlock;
repeat activation/failure/retry; reduced motion; 12-profile remote sweeps at TV,
portrait-phone and short landscape sizes with large text on Android/Windows.
TV/phone widget renders visually inspected (local build/ PNGs).
Full analyzer/test results and commit are in the root HANDOFF.md.
Not built/installed or checked on a physical box/phone/Windows app.
