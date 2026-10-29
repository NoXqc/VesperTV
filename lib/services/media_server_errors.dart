/// Authentication was rejected by the media server.
class MediaServerLoginException implements Exception {
  @override
  String toString() => 'MediaServerLoginException';
}

/// The connected account has no movie or TV library.
class MediaServerNoLibraryException implements Exception {
  @override
  String toString() => 'MediaServerNoLibraryException';
}
