/// Search without a search server: every video and channel stores a
/// `keywords` list with the beginnings ("prefixes") of its words, so
/// Firestore can find "bunny" when you type "bun":
///
///   "Big Buck Bunny" -> [b, bi, big, bu, buc, buck, bun, bunn, bunny]
///
/// A search asks Firestore for ONE word (`array-contains`) and checks the
/// other words in the app.
library;

/// Longest prefix stored per word (longer words still match: a query word
/// is cut to this length too).
const int maxPrefixLength = 15;

/// Most keywords per document (keeps documents small; the rules allow 200).
const int maxKeywords = 200;

/// The words of [text], lower case, without punctuation:
/// "Sci-Fi: Tears of Steel!" -> [sci, fi, tears, of, steel].
List<String> searchWords(String text) => text
    .toLowerCase()
    .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
    .where((word) => word.isNotEmpty)
    .toList();

/// All prefixes of all words in [texts], in order, without repeats, at most
/// [maxKeywords].
List<String> buildKeywords(Iterable<String> texts) {
  final keywords = <String>{};
  for (final text in texts) {
    for (final word in searchWords(text)) {
      final end = word.length < maxPrefixLength ? word.length : maxPrefixLength;
      for (var length = 1; length <= end; length++) {
        keywords.add(word.substring(0, length));
        if (keywords.length >= maxKeywords) return keywords.toList();
      }
    }
  }
  return keywords.toList();
}

/// Keywords of a video: its title, channel name and category.
List<String> videoKeywords({
  required String title,
  required String channelName,
  required String category,
}) => buildKeywords([title, channelName, category]);

/// Keywords of a channel: its name and @handle.
List<String> channelKeywords({required String name, required String handle}) =>
    buildKeywords([name, handle]);

/// The query's words, each cut to [maxPrefixLength].
List<String> queryWords(String query) => [
  for (final word in searchWords(query))
    word.length > maxPrefixLength ? word.substring(0, maxPrefixLength) : word,
];

/// The word to ask Firestore for: the longest one (it matches the fewest
/// documents). null if the query has no words.
String? searchTerm(String query) {
  final words = queryWords(query);
  if (words.isEmpty) return null;
  return words.reduce((a, b) => b.length > a.length ? b : a);
}

/// Every word of [query] is the beginning of a word in [texts].
bool matchesQuery(Iterable<String> texts, String query) {
  final keywords = buildKeywords(texts).toSet();
  return queryWords(query).every(keywords.contains);
}

/// How well [title] matches [query], for "Relevance": the whole query in
/// the title counts most, then the title starting with it, then each
/// whole word that matches exactly.
int relevanceScore(String title, String query) {
  final t = title.toLowerCase();
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return 0;
  var score = 0;
  if (t.contains(q)) score += 10;
  if (t.startsWith(q)) score += 5;
  final titleWords = searchWords(title).toSet();
  for (final word in searchWords(query)) {
    if (titleWords.contains(word)) score += 2;
  }
  return score;
}
