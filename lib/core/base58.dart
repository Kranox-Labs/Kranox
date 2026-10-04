import 'dart:typed_data';

/// The base58 of Monero. Unlike the base58 of Bitcoin, it works in blocks: each block of 8 bytes becomes 11
/// characters, and a shorter last block becomes fewer characters.
abstract final class MoneroBase58 {
  static const String alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  static const int fullBlockBytes = 8;
  static const int fullBlockChars = 11;

  /// The number of characters of a block of 0 to 8 bytes.
  static const List<int> blockChars = [0, 2, 3, 5, 6, 7, 9, 10, 11];

  static final BigInt _base = BigInt.from(alphabet.length);
  static final BigInt _byteMask = BigInt.from(0xFF);

  /// Turns the text into bytes. Throws a [FormatException] for a character outside the alphabet, for a last
  /// block of a length that no block has, and for a block whose value does not fit its bytes.
  static Uint8List decode(String text) {
    final fullBlocks = text.length ~/ fullBlockChars;
    final lastChars = text.length % fullBlockChars;
    final lastBytes = blockChars.indexOf(lastChars);
    if (lastBytes < 0) {
      throw FormatException('No block of base58 has $lastChars characters.', text);
    }
    final bytes = BytesBuilder(copy: false);
    for (var block = 0; block < fullBlocks; block++) {
      final start = block * fullBlockChars;
      bytes.add(_decodeBlock(text.substring(start, start + fullBlockChars), fullBlockBytes));
    }
    if (lastChars > 0) {
      bytes.add(_decodeBlock(text.substring(fullBlocks * fullBlockChars), lastBytes));
    }
    return bytes.toBytes();
  }

  static Uint8List _decodeBlock(String block, int size) {
    var value = BigInt.zero;
    for (final character in block.split('')) {
      final digit = alphabet.indexOf(character);
      if (digit < 0) {
        throw FormatException('"$character" is no character of base58.', block);
      }
      value = value * _base + BigInt.from(digit);
    }
    if (value >= BigInt.one << (8 * size)) {
      throw FormatException('The block does not fit into $size bytes.', block);
    }
    final bytes = Uint8List(size);
    for (var index = size - 1; index >= 0; index--) {
      bytes[index] = (value & _byteMask).toInt();
      value = value >> 8;
    }
    return bytes;
  }
}
