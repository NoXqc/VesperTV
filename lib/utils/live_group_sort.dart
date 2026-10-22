/// Display-only sorting. Stored group and channel orders are never changed.
enum LiveGroupSort { provider, aToZ, zToA }

extension LiveGroupOrdering on LiveGroupSort {
  List<T> sorted<T>(Iterable<T> items, String Function(T) title) {
    final indexed = items.indexed.toList();
    if (this != LiveGroupSort.provider) {
      indexed.sort((a, b) {
        final order =
            title(a.$2).toLowerCase().compareTo(title(b.$2).toLowerCase());
        return order == 0
            ? a.$1.compareTo(b.$1)
            : (this == LiveGroupSort.zToA ? -order : order);
      });
    }
    return indexed.map((e) => e.$2).toList();
  }
}
