# App Store exception to the GPL (added 2026-11-14)

VesperTV is GPL-3.0. Apple's App Store terms add usage rules (one Apple account, a limited
number of devices) that the GPL doesn't allow on top of it; VLC was pulled from the App Store
in 2011 over exactly this. The usual fix is an extra permission from the copyright holders,
under GPL-3.0 section 7.

**Who agreed:** every author whose code is in the iOS app. From `git log`: NoXQc (the owner)
and **gmtherien** (macOS desktop work: `desktop_platform.dart` and the macOS paths, which the
iOS build compiles in). gmtherien consented in a Discord DM on 2026-11-14 at 14:04 ("Je
consent!"); the owner keeps the screenshot privately, outside the repo
(`Documents/VesperTV-legal/` on the owner's PC).

**Where:** `APP_STORE_EXCEPTION.md` at the repo root. The GPL's own text may not be changed,
so it is not inside `LICENSE`. The README's licence section points to it and says
contributions come under the GPL together with the exception; any new outside contributor's
code is covered by that line, but ask them to confirm on their first pull request.

Not legal advice: this is the usual shape of such an exception.

## Third-party code in the iOS app

The exception covers our own code only. The libraries keep their own licences; check that
none forbids App Store distribution before submitting (`flutter pub deps` + each licence).
The one to look at closely is libmpv as shipped by `media_kit_libs_ios_video` (mpv is LGPL
when built without GPL parts; confirm which build media_kit ships).
