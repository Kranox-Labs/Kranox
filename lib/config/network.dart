/// The Monero networks that the app knows. wallet2 numbers them, and each network has its own address prefixes.
///
/// The prefixes come from `cryptonote_config.h` of Monero: the first byte of an address names its network and
/// its kind.
enum MoneroNetwork {
  mainnet(label: 'Mainnet', walletType: 0, standardPrefix: 18, integratedPrefix: 19, subaddressPrefix: 42),
  stagenet(label: 'Stagenet', walletType: 2, standardPrefix: 24, integratedPrefix: 25, subaddressPrefix: 36);

  const MoneroNetwork({
    required this.label,
    required this.walletType,
    required this.standardPrefix,
    required this.integratedPrefix,
    required this.subaddressPrefix,
  });

  final String label;

  /// The number of the network type in wallet2.
  final int walletType;

  final int standardPrefix;
  final int integratedPrefix;
  final int subaddressPrefix;
}
