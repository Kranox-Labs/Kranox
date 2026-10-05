/// The Monero networks that the app knows. wallet2 numbers them, and each network has its own address prefixes.
///
/// The prefixes and the ports come from `cryptonote_config.h` of Monero: the first byte of an address names its
/// network and its kind, and a node of each network answers on its own RPC port by default.
enum MoneroNetwork {
  mainnet(
    label: 'Mainnet',
    walletType: 0,
    standardPrefix: 18,
    integratedPrefix: 19,
    subaddressPrefix: 42,
    rpcPort: 18081,
  ),
  stagenet(
    label: 'Stagenet',
    walletType: 2,
    standardPrefix: 24,
    integratedPrefix: 25,
    subaddressPrefix: 36,
    rpcPort: 38081,
  ),
  testnet(
    label: 'Testnet',
    walletType: 1,
    standardPrefix: 53,
    integratedPrefix: 54,
    subaddressPrefix: 63,
    rpcPort: 28081,
  );

  const MoneroNetwork({
    required this.label,
    required this.walletType,
    required this.standardPrefix,
    required this.integratedPrefix,
    required this.subaddressPrefix,
    required this.rpcPort,
  });

  final String label;

  /// The number of the network type in wallet2.
  final int walletType;

  final int standardPrefix;
  final int integratedPrefix;
  final int subaddressPrefix;

  /// The port on which a node of this network answers by default.
  final int rpcPort;

  /// Whether the coins of this network have no value: a network for tests.
  bool get isTest => this != mainnet;
}
