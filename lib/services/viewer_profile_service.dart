import 'package:flutter/material.dart';

import '../models/viewer_profile.dart';
import '../widgets/pin_pad.dart';
import 'playback_service.dart';
import 'playlist_manager.dart';
import 'storage_service.dart';
import 'home_wallpaper.dart';
import 'dart:typed_data';
import 'dart:io';
import '../models/profile_copy.dart';
import 'profile_photos.dart';
import 'parental_pin.dart';

/// Whether a locked profile in use goes back behind its PIN after VesperTV
/// was left for [away] ([relockMinutes] 0 = every time it is left).
bool profileRelockDue(Duration away, int relockMinutes) =>
    relockMinutes <= 0 || away >= Duration(minutes: relockMinutes);

/// Owns viewer-profile CRUD and the switch sequence — see `ViewerProfile`'s
/// doc comment for the feature. Depends on `PlaylistManager`/
/// `PlaybackService` to apply a switch's effects on catalog/playback state;
/// neither of those depends back on this class (see `PlaylistManager`'s own
/// doc comment on why).
class ViewerProfileService extends ChangeNotifier {
  ViewerProfileService(
      this._storage, this._playlistManager, this._playbackService,
      {VoidCallback? onViewerChanged})
      : _onViewerChanged = onViewerChanged {
    _profiles = _storage.getViewerProfiles();
    _activeId = _storage.getActiveViewerId();
    // Catches an impossible-but-cheap-to-guard-against state: an active id
    // that doesn't match any stored profile (a prefs key half-written by a
    // killed process, say). Falling back to Main is the same safe default
    // `_activeViewerIsRestricted` in `PlaylistManager` uses.
    if (!_profiles.any((p) => p.id == _activeId)) {
      _activeId = ViewerProfile.mainId;
    }
  }

  /// main.dart reloads viewer-scoped appearance before the switch is announced.
  final VoidCallback? _onViewerChanged;
  final StorageService _storage;
  final PlaylistManager _playlistManager;
  final PlaybackService _playbackService;

  late List<ViewerProfile> _profiles;
  late String _activeId;

  List<ViewerProfile> get profiles => List.unmodifiable(_profiles);

  ViewerProfile get active => _profiles.firstWhere((p) => p.id == _activeId,
      orElse: ViewerProfile.main);

  bool get isActiveRestricted => active.isRestricted;

  /// The active profile is locked and VesperTV went back to Who's watching
  /// ([lockActive]): picking it again asks the PIN like any locked profile.
  bool _lockedOut = false;
  bool get lockedOut => _lockedOut;

  /// Puts a locked active profile behind its PIN again (a fresh start, or
  /// back after [relockAfter] away). False when it isn't locked.
  bool lockActive() {
    if (!active.isLocked || active.isRestricted) return false;
    _lockedOut = true;
    return true;
  }

  /// Whether opening [target] from the profile in use needs the PIN.
  bool needsPinFor(ViewerProfile target) {
    if (target.id == _activeId) {
      return _lockedOut && target.isLocked;
    }
    return active.isRestricted || (target.isLocked && !target.isRestricted);
  }

  /// Turns [id]'s lock on or off. Both ask the household PIN (one is set up
  /// first when none exists): a kid must not lock or unlock a profile.
  /// False when the PIN wasn't given.
  Future<bool> setLocked(BuildContext context, String id, bool locked) async {
    final pin = ParentalPin(_storage);
    // No PIN yet: locking sets one up; unlocking has nothing to protect.
    final ok = pin.isSet
        ? await promptForPin(context)
        : (!locked || await setupPinFlow(context));
    if (!ok) return false;
    _profiles = _profiles
        .map((p) => p.id == id ? p.copyWith(isLocked: locked) : p)
        .toList();
    await _persist();
    notifyListeners();
    return true;
  }

  ProfilePhotos get photos => _storage.profilePhotos;
  Future<File> photoFile(String id) => photos.file(id);
  Future<void> setPhoto(String id, Uint8List bytes) async {
    final profile = _profiles.firstWhere((p) => p.id == id);
    final target = await photos.file(id);
    await FileImage(target).evict();
    await photos.save(id, bytes);
    await FileImage(target).evict();
    if (!_profiles.any((p) => p.id == id)) {
      await photos.remove(id);
      return;
    }
    _profiles = _profiles
        .map((p) =>
            p.id == id ? p.copyWith(photoVersion: profile.photoVersion + 1) : p)
        .toList();
    await _persist();
    notifyListeners();
  }

  Future<void> removePhoto(String id) async {
    await FileImage(await photos.file(id)).evict();
    await photos.remove(id);
    _profiles = _profiles
        .map((p) => p.id == id ? p.copyWith(photoVersion: 0) : p)
        .toList();
    await _persist();
    notifyListeners();
  }

  Future<void> setColour(String id, int index) async {
    _profiles = _profiles
        .map((p) => p.id == id ? p.copyWith(colorIndex: index) : p)
        .toList();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() => _storage.setViewerProfiles(_profiles);

  /// Creates a new profile — does not switch to it or prompt for a PIN;
  /// the caller (`ProfilesScreen`'s Add Profile flow) runs [setupPinFlow]
  /// first when [isRestricted] is true (a restricted profile must never
  /// exist without a PIN already set to get out of it), then calls
  /// [switchTo] itself afterward with its own `BuildContext`/`mounted`
  /// handling, rather than this method holding a context across its own
  /// `await` gaps on the caller's behalf.
  Future<ViewerProfile> createProfile(
      {required String name,
      required int colorIndex,
      required bool isRestricted,
      Set<ProfileCopy> copyFromMain = const {},
      Uint8List? photo}) async {
    final profile = ViewerProfile(
      id: 'vp${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      colorIndex: colorIndex,
      isRestricted: isRestricted,
      createdAt: DateTime.now(),
    );
    await _storage.copyMainToViewer(profile.id, copyFromMain,
        restricted: isRestricted);
    if (photo != null) await photos.save(profile.id, photo);
    final created = profile.copyWith(photoVersion: photo == null ? 0 : 1);
    _profiles = [..._profiles, created];
    await _persist();
    notifyListeners();
    return created;
  }

  Future<void> renameProfile(String id, String name) async {
    _profiles =
        _profiles.map((p) => p.id == id ? p.copyWith(name: name) : p).toList();
    await _persist();
    notifyListeners();
  }

  /// Refuses Main and the currently-active profile outright — switch away
  /// first. Removes every one of this profile's own storage keys
  /// ([StorageService.deleteViewerData]) and its recently-played cache
  /// file, in addition to the profile entry itself.
  Future<bool> deleteProfile(String id) async {
    if (id == ViewerProfile.mainId || id == _activeId) return false;
    _profiles = _profiles.where((p) => p.id != id).toList();
    await _persist();
    await _storage.deleteViewerData(id);
    await _storage.deleteCacheFile('recently_played_vp_$id');
    await photos.remove(id);
    try {
      await HomeWallpaper.instance.remove(id);
    } catch (_) {}
    notifyListeners();
    return true;
  }

  /// The actual profile switch. Order matters throughout:
  /// 1. A restricted *current* profile needs the PIN before leaving, no
  ///    matter what the target is — a kid picking "Main" from the switcher
  ///    is exactly the case this whole feature exists to gate.
  /// 2. Playback stops (and saves its final position) *before* the active
  ///    viewer id changes — `PlaybackService.stop`'s teardown awaits that
  ///    write, so switching immediately after a stopped video can't land
  ///    the position under the wrong viewer.
  /// 3. The new id is persisted, then [PlaylistManager.applyActiveViewer]
  ///    and [PlaybackService.reloadForViewer] re-derive everything else
  ///    (favorites, hidden groups, recently-played) from storage — no
  ///    network access, so a switch is fast regardless of catalog size.
  /// 4. `notifyListeners()` here is what a `Consumer<ViewerProfileService>`
  ///    further up the tree (see `main.dart`) actually reacts to — without
  ///    it, nothing would ever know to remount the home screen for the
  ///    newly-active viewer, no matter what key it's built with.
  ///
  /// Returns false if a required PIN check failed/was cancelled, or if
  /// [targetId] isn't an id this service actually has — the switch never
  /// happened in either case. [unlocked]: the caller already had the PIN
  /// entered for this request (Vesper AI asks it with a timeout).
  Future<bool> switchTo(BuildContext context, String targetId,
      {bool unlocked = false}) async {
    final target = _profiles.where((p) => p.id == targetId).firstOrNull;
    if (target == null) return false;
    if (targetId == _activeId && !_lockedOut) return true;
    // Leaving a kids profile, or opening a locked one: the PIN.
    if (needsPinFor(target) && !unlocked) {
      final unlocked = await promptForPin(context);
      if (!unlocked) return false;
    }
    if (targetId == _activeId) {
      // Back into the locked profile in use: nothing else changes.
      _lockedOut = false;
      notifyListeners();
      return true;
    }
    _lockedOut = false;
    await _playbackService.stop();
    _activeId = targetId;
    await _storage.setActiveViewerId(targetId);
    _playlistManager.applyActiveViewer();
    await _playbackService.reloadForViewer();
    _onViewerChanged?.call();
    notifyListeners();
    return true;
  }

  /// The single choke point every path into Settings goes through — see
  /// `SettingsMenuScreen`/`HomeScreen`'s own call sites. A restricted
  /// active profile needs the PIN before Settings opens at all, not
  /// screen-by-screen inside it: almost everything in Settings can undo a
  /// restriction one way or another (Group Management, Hidden Channels,
  /// Playlist Manager, EPG Clear Cache, this very Profiles screen), and
  /// gating only some of them would leave the rest as an unintended
  /// bypass — confirmed as a real gap during this feature's own review for
  /// two *other*, non-Settings controls (the live-channel long-press
  /// "Unhide" option and the phone sidebar's group-visibility toggle),
  /// which are gated the same way at their own call sites instead, since
  /// neither one goes through Settings to begin with.
  Future<bool> requireUnlock(BuildContext context) async {
    if (!isActiveRestricted) return true;
    return promptForPin(context);
  }
}
