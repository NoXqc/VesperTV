import 'dart:async';

/// A remote can send a key and a platform Back for one press. Keep the
/// playback route protected while its modal is open and through dismissal.
class PlaybackModalBackGuard {
  PlaybackModalBackGuard({required this.onChanged});
  final void Function() onChanged;
  bool isOpen = false;
  Timer? _dismissal;
  bool _disposed = false;

  bool get blocksBack => isOpen || (_dismissal?.isActive ?? false);

  void opened() {
    if (_disposed) return;
    _dismissal?.cancel();
    isOpen = true;
    onChanged();
  }

  void closed() {
    if (_disposed) return;
    isOpen = false;
    _dismissal?.cancel();
    _dismissal = Timer(const Duration(milliseconds: 700), () {
      _dismissal = null;
      onChanged();
    });
    onChanged();
  }

  void dispose() {
    _disposed = true;
    _dismissal?.cancel();
  }
}
