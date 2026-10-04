import 'network.dart';

/// The settings of this build of the app. Each value that can change has its one definition here.
abstract final class AppConfig {
  /// The first build runs on stagenet, by decision of the owner on 4 Oct 2026. Mainnet follows when send and
  /// receive have proven safe.
  static const MoneroNetwork network = MoneroNetwork.stagenet;

  /// The node that a new wallet uses until the user chooses another one. The user can point the app at any node.
  /// CHECKED 4 Oct 2026: of five public stagenet nodes that answered, this one let a new wallet catch up fastest,
  /// at 8,800 to 32,000 blocks a second against 2,800 to 11,200 for the others.
  static const Map<MoneroNetwork, String> defaultNodes = {MoneroNetwork.stagenet: 'node3.monerodevs.org:38089'};

  /// The app keeps one wallet in this version. wallet2 writes the file `main` and the key file `main.keys`.
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

  /// wallet2 derives the key of the wallet file with this many rounds of its key function. 1 is the default of
  /// wallet2, which opens and creates wallets with it.
  static const int kdfRounds = 1;

  /// The node that the app uses for the network of this build.
  static String get defaultNode {
    final node = defaultNodes[network];
    if (node == null) {
      throw StateError('AppConfig names no default node for ${network.label}.');
    }
    return node;
  }
}
