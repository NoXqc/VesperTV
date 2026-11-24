/// Words in a group (category) name that mark adult content. A Kids profile
/// never shows such a group, even when its allowlist has it (Show All, then
/// only the TV tab's adult group hidden: Discord, LOG-GT8TZG, 2026-11-24),
/// and What's New never headlines one (`CatalogDatabase`'s recently-added
/// queries). Plain substrings, any case: "ADULTOS", "|AR| +18", "XXX VOD".
const adultGroupWords = ['XXX', 'ADULT', 'PORN', '18+', '+18'];

/// Whether [name] says adult content (see [adultGroupWords]).
bool isAdultGroupName(String name) {
  final upper = name.toUpperCase();
  for (final word in adultGroupWords) {
    if (upper.contains(word)) return true;
  }
  return false;
}
