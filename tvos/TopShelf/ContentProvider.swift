import TVServices

/// VesperTV's Top Shelf: the rows above the Apple TV home screen while VesperTV sits in its
/// top row (dev-notes/apple-tv-parity-plan.md point 5). The app keeps them as JSON in the
/// App Group's defaults (`VesperTopShelf` in tvos/Runner/AppDelegate.swift, sent by
/// lib/services/launcher_channels.dart `topShelf`):
///
///     {"rows": [{"title": "Continue Watching",
///                "items": [{"id", "title", "image"?, "shape", "progress"?, "link"}]}]}
///
/// Nothing stored (or the App Group missing from the build) = nil: tvOS shows the app's
/// static Top Shelf image instead.
final class ContentProvider: TVTopShelfContentProvider {
  static let appGroup = "group.app.vespertv.player"
  static let contentKey = "vesper_top_shelf"

  override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
    guard
      let data = UserDefaults(suiteName: Self.appGroup)?.data(forKey: Self.contentKey),
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let rows = root["rows"] as? [[String: Any]]
    else {
      completionHandler(nil)
      return
    }
    var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []
    for row in rows {
      let items = (row["items"] as? [[String: Any]] ?? []).compactMap(Self.item)
      if items.isEmpty { continue }
      let section = TVTopShelfItemCollection(items: items)
      section.title = row["title"] as? String
      sections.append(section)
    }
    completionHandler(sections.isEmpty ? nil : TVTopShelfSectionedContent(sections: sections))
  }

  private static func item(_ map: [String: Any]) -> TVTopShelfSectionedItem? {
    guard
      let id = map["id"] as? String,
      let link = (map["link"] as? String).flatMap(URL.init(string:))
    else { return nil }
    let item = TVTopShelfSectionedItem(identifier: id)
    item.title = map["title"] as? String
    switch map["shape"] as? String {
    case "poster": item.imageShape = .poster
    case "square": item.imageShape = .square
    default: item.imageShape = .hdtv
    }
    if let image = (map["image"] as? String).flatMap(URL.init(string:)) {
      item.setImageURL(image, for: .screenScale1x)
      item.setImageURL(image, for: .screenScale2x)
    }
    if let progress = (map["progress"] as? NSNumber)?.doubleValue, progress > 0 {
      item.playbackProgress = min(progress, 1)
    }
    let action = TVTopShelfAction(url: link)
    item.displayAction = action
    item.playAction = action
    return item
  }
}
