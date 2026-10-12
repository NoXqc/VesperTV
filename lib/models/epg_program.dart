/// A single XMLTV `<programme>` entry: one show airing on one channel
/// between [start] and [stop].
class EpgProgram {
  EpgProgram({
    required this.channelId,
    required this.title,
    required this.start,
    required this.stop,
    this.description,
  });

  final String channelId;
  final String title;
  final String? description;
  final DateTime start;
  final DateTime stop;

  bool isNowPlaying(DateTime now) => !now.isBefore(start) && now.isBefore(stop);
}
