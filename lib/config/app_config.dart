import 'network.dart';

/// The settings of this build of the app. Each value that can change has its one definition here.
abstract final class AppConfig {
  /// The network of the app until the user chooses another one. The owner chose mainnet on 5 Oct 2026, with a choice
  /// of stagenet and testnet in the app. Each network keeps its own wallet and its own node.
  static const MoneroNetwork defaultNetwork = MoneroNetwork.mainnet;

  /// The node of each network until the user chooses another one. The user can point the app at any node.
  static String defaultNode(MoneroNetwork network) => switch (network) {
    // CHECKED 5 Oct 2026: a new mainnet wallet caught up in 9 seconds on this node and in 11 on
    // nodes.hashvault.pro:18081; node and node2.monerodevs.org:18089 took 70 to 76 seconds, and node3.monerodevs.org
    // and monero.stackwallet.com had not caught up after 4 minutes.
    MoneroNetwork.mainnet => 'xmr-node.cakewallet.com:18081',
    // CHECKED 5 Oct 2026: a new stagenet wallet caught up in 183 seconds on this node; on node, node2, and
    // node3.monerodevs.org:38089 it had not caught up after 4 minutes. On 4 Oct 2026 node3 had been the fastest.
    MoneroNetwork.stagenet => 'stagenet.xmr-tw.org:38081',
    // CHECKED 5 Oct 2026: a new testnet wallet caught up in 74 seconds on this node; on node, node2, and
    // node3.monerodevs.org:28089 it had not caught up after 4 minutes. All four run the hard fork version 16.
    MoneroNetwork.testnet => 'testnet.xmr-tw.org:28081',
  };

  /// The app keeps one wallet for each network. wallet2 writes the file `main` and the key file `main.keys` in the
  /// folder of the network.
  static const String walletFileName = 'main';
  static const String walletsFolderName = 'wallets';
  static const String settingsFileName = 'settings.json';

  /// A password has at least this many characters. The password encrypts the key file of the wallet.
  static const int minPasswordLength = 8;

  /// The app reads the state of the open wallet this often.
  static const Duration statusInterval = Duration(seconds: 2);

  /// wallet2 asks the node for new blocks this often while the wallet is open.
  static const Duration autoRefreshInterval = Duration(seconds: 20);

  /// The home screen shows this many of the latest transactions.
  static const int recentActivityCount = 5;

  /// Monero signs each input with a ring of 16 members: the real output and 15 decoys. wallet2 of the branch
  /// release-v0.18 fixes the ring at that size.
  static const int decoyCount = 15;

  /// The priority of a payment. 0 lets wallet2 choose its default priority, which sets the fee.
  static const int sendPriority = 0;

  /// The app uses the first account of the wallet.
  static const int accountIndex = 0;

  /// The seed of a new wallet has words of this language.
  static const String seedLanguage = 'English';

  /// The relay of Kranox for the bridge. It holds the API key of the exchanger, so that the key never sits in the
  /// app; apps/relay holds its code. From 5 Oct 2026 it runs on the server of the site, apart from the site, at its
  /// own name. A build for development can point at a relay on the machine:
  /// fvm flutter run -d macos --dart-define=BRIDGE_RELAY=http://127.0.0.1:8787
  static const String bridgeRelay = String.fromEnvironment('BRIDGE_RELAY', defaultValue: 'https://relay.kranox.cash');

  /// A call to the relay that takes longer than this fails.
  static const Duration bridgeRequestTimeout = Duration(seconds: 30);

  /// The bridge form asks for a quote this long after the last change of the amount.
  static const Duration bridgeQuoteDelay = Duration(milliseconds: 600);

  /// The app asks for the state of an open swap this often.
  static const Duration bridgeStatusInterval = Duration(seconds: 15);

  /// An amount in the bridge form has at most this many decimals.
  static const int bridgeAmountDecimals = 8;

  /// Pay sends its XMR only while the fixed rate holds at least this much longer, so that the deposit reaches the
  /// exchanger in time. CHECKED 5 Oct 2026: ChangeNOW holds a fixed rate for 10 minutes after it makes a payment.
  static const Duration payRateMargin = Duration(minutes: 1);

  /// The amount of a payment that the exchanger makes may differ from the amount of the form by this much, which is
  /// the rounding of a number, not a change of the amount.
  static const double payAmountTolerance = 1e-9;

  /// The file of the support folder that keeps the swaps of the bridge.
  static const String bridgeFileName = 'bridge.json';

  /// wallet2 derives the key of the wallet file with this many rounds of its key function. 1 is the default of
  /// wallet2, which opens and creates wallets with it.
  static const int kdfRounds = 1;
}
