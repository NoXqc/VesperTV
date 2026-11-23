# iCloud backups + backup folder (iPhone, iPad, Apple TV)

Owner, 2026-11-22: "can we get iOS users to save on their cloud, similar to SMB or external
storage, so they can upload / restore from there", after BallerMC (Discord, Apple TV) asked for an
iCloud restore on a clean install. Owner chose: iPhone folder + Apple TV iCloud.

## What the viewer gets

Settings > Backup & devices > Backup & restore:

| Row | Where | What |
|---|---|---|
| Backup folder | iPhone, iPad | Pick a folder once in Files (iCloud Drive, OneDrive, Google Drive, an SMB server added to Files). Back up now, automatic backups, the Backups list and Restore all use it. "On this device" goes back to Files > On My iPhone > VesperTV. |
| Also save to iCloud | iPhone, iPad, Apple TV | Each backup (manual or automatic) also replaces this device's copy in iCloud. Turning it on makes one at once. Off by default, never synced. |
| Restore from iCloud | iPhone, iPad, Apple TV | Every Apple device's newest backup in this Apple ID's iCloud; OK = Restore / Delete. |
| Restore from a file | iPhone, iPad (not Apple TV: no Files app) | unchanged |

First launch > From another device also has **Restore from iCloud** on Apple devices (the Apple TV
restores what the iPhone saved; a purged Apple TV restores its own).

The undo point a restore makes (`create(auto: true, cloud: false)`) never goes to iCloud: it would
replace the device's good copy with the setup being thrown away.

## How it works

- **Backup folder** (`lib/services/backup_folder.dart`, Swift `VesperBackupFolder` in
  `ios/Runner/AppDelegate.swift`, channel `vespertv/backup_folder`): `UIDocumentPickerViewController`
  for `.folder`, kept as a `.minimalBookmark` in UserDefaults (not a Flutter pref, so it never goes
  into a backup or sync). Writes / reads / deletes go through `NSFileCoordinator`; a coordinated read
  downloads an iCloud file that is only a `.name.icloud` placeholder. Entry ids are `folder:<name>`
  so a listed backup is read from the folder even after the setting changes. No entitlement needed.
- **iCloud** (`lib/services/icloud_backups.dart`, Swift `VesperICloud` in both runners' AppDelegate,
  channel `vespertv/icloud`): CloudKit private database of `iCloud.app.vespertv.player`, zone
  `Backups` (made at the first save), record type `Backup`, record name
  `device-<identifierForVendor>`, fields `file` (Asset: the backup JSON), `device` (String,
  `UIDevice.name`), `app` (String, version+build), `size` (Int64). Listing is a zone-changes fetch
  with `desiredKeys` device/app/size (no files downloaded, no query index needed). No sign-in inside
  VesperTV: it is the device's Apple ID, and only it can read its private database.
- **Crash guard:** `CKContainer` stops the app when the build lacks the iCloud entitlement.
  `VesperICloud.entitled` looks for `com.apple.developer.icloud-services` in the app's own
  executable (the code signature) first; without it every call answers `NOT_SET_UP` and the app
  says "iCloud backups aren't available in this build yet."

## Owner steps before the first signed build (TestFlight)

The entitlements (`ios/Runner/Runner.entitlements`, `tvos/Runner/Runner.entitlements`,
`CODE_SIGN_ENTITLEMENTS` in both projects) are on this branch. **Signed iOS archives fail until
step 1 is done**, because automatic signing must find iCloud on the App ID.

1. developer.apple.com > Certificates, IDs & Profiles:
   - Identifiers > (filter "iCloud Containers") > **+** > iCloud Containers >
     identifier `iCloud.app.vespertv.player`, description "VesperTV backups".
   - Identifiers > App IDs > `app.vespertv.player` > tick **iCloud** > **Include CloudKit support**
     > Configure > tick `iCloud.app.vespertv.player` > Save (confirm the profile warning).
2. icloud.developer.apple.com > CloudKit Database > container `iCloud.app.vespertv.player` >
   **Development** environment > Schema > Record Types > **+** `Backup` with fields:
   `file` Asset, `device` String, `app` String, `size` Int(64). Save.
   (TestFlight and App Store builds use the **Production** environment, where the app can't create
   record types itself, and the owner has no Mac for a development build that would create it.)
3. Same page: **Deploy Schema Changes...** to Production.
4. Run the iOS / Apple TV TestFlight workflows as usual. The API key's automatic signing makes new
   profiles with iCloud.

## Not verified yet

- Nothing here is compiled on this PC (Swift): the first `ios-build` / `tvos-build` run checks it.
- **Apple TV export:** `tvos-build.yml` archives unsigned (`CODE_SIGNING_ALLOWED=NO`) and the export
  signs it, which most likely leaves the entitlements out (the Apple TV build would run without
  iCloud: the guard above says "not available in this build", no crash). Fixed on
  `claude/appletv-parity` (2026-11-23, "Phase 0" in its dev-notes/apple-tv-parity-plan.md): the
  archive is signed ad hoc with the entitlements files and the run fails if the exported app lacks
  a key. **Merge that branch before an Apple TV TestFlight with iCloud.**
- `tvos/Runner/Runner.entitlements` is the same file on both branches (iCloud + the Top Shelf App
  Group), so a signed Apple TV build also needs the App Group portal steps (plan, "Owner steps for
  C"). The iPhone file (`ios/Runner/Runner.entitlements`) is iCloud only.
- Real iCloud / Files provider behaviour (placeholders, OneDrive, SMB in Files) is untested.
