/// A seed of Monero has this many words: 24 words of the key and one word of the checksum.
const int seedWordCount = 25;

/// What is wrong with a typed seed.
enum SeedProblem { wrongWordCount, invalidCharacters }

final class SeedFormatException implements Exception {
  const SeedFormatException(this.problem, {this.wordCount = 0});

  final SeedProblem problem;
  final int wordCount;

  @override
  String toString() => 'SeedFormatException: ${problem.name} ($wordCount words)';
}

/// Splits a typed seed into its words, in lowercase and without extra spaces. wallet2 checks the words and their
/// checksum when it restores the wallet; this check catches a wrong count and stray characters first.
List<String> parseSeed(String text) {
  final words = text.trim().toLowerCase().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  if (words.length != seedWordCount) {
    throw SeedFormatException(SeedProblem.wrongWordCount, wordCount: words.length);
  }
  if (words.any((word) => !RegExp(r'^[a-z]+$').hasMatch(word))) {
    throw SeedFormatException(SeedProblem.invalidCharacters, wordCount: words.length);
  }
  return words;
}
