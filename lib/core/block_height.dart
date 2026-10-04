final class BlockHeightException implements Exception {
  const BlockHeightException();

  @override
  String toString() => 'BlockHeightException';
}

/// Reads the restore height of a wallet: the block from which the app scans the chain. An empty field means the
/// first block, which makes the scan slower but misses nothing.
int parseRestoreHeight(String text) {
  final value = text.trim().replaceAll(',', '');
  if (value.isEmpty) {
    return 0;
  }
  if (!RegExp(r'^\d{1,10}$').hasMatch(value)) {
    throw const BlockHeightException();
  }
  return int.parse(value);
}
