import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/core/seed.dart';

final _words = List.generate(seedWordCount, (index) => 'word${String.fromCharCode(97 + index)}');

void main() {
  test('reads 25 words in lowercase without extra spaces', () {
    final typed = '  ${_words.take(5).join('  ').toUpperCase()}\n${_words.skip(5).join(' ')} ';
    expect(parseSeed(typed), _words);
  });

  test('rejects a seed with a wrong number of words', () {
    expect(
      () => parseSeed(_words.take(24).join(' ')),
      throwsA(
        isA<SeedFormatException>()
            .having((error) => error.problem, 'problem', SeedProblem.wrongWordCount)
            .having((error) => error.wordCount, 'wordCount', 24),
      ),
    );
    expect(() => parseSeed(''), throwsA(isA<SeedFormatException>()));
  });

  test('rejects words with characters other than letters', () {
    final words = [..._words]..[3] = 'word1';
    expect(
      () => parseSeed(words.join(' ')),
      throwsA(isA<SeedFormatException>().having((error) => error.problem, 'problem', SeedProblem.invalidCharacters)),
    );
  });
}
