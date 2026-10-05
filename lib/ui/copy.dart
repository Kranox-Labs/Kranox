import '../config/network.dart';

/// All text of the app. The screens take their words from here.
abstract final class Copy {
  static const String appName = 'Kranox';
  static const String walletName = 'Main wallet';
  static const String currency = 'XMR';

  // Welcome.
  // The title calls back the drawing of the treasury behind the card. On 4 Oct 2026 the owner turned down the
  // title "Fight in the shade." for this screen.
  static const String welcomeTitle = 'Your treasury, guarded.';
  static const String welcomeLead =
      'A private Monero wallet. Only you hold the keys, and they never leave this device.';

  /// The note on the network of the wallet. With [lineBreak], its two sentences stand on two lines, for a narrow
  /// card.
  static String networkNote(MoneroNetwork network, {bool lineBreak = false}) => network.isTest
      ? 'This wallet runs on ${network.label}, a test network of Monero.${lineBreak ? '\n' : ' '}Its coins have no value.'
      : 'This wallet runs on the Monero mainnet.${lineBreak ? '\n' : ' '}Its coins are real XMR.';
  static const String createWallet = 'Create a new wallet';
  static const String restoreWallet = 'Restore from your seed';
  static const String back = 'Back';

  // Create.
  static const String createTitle = 'Create your wallet';
  static const String createLead =
      'Choose a password. It locks the wallet on this device. Kranox cannot recover it for you.';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm the password';
  static const String createAction = 'Create wallet';
  static const String creating = 'Creating…';
  static const String seedTitle = 'Write down your seed';
  static const String seedLead =
      'These 25 words restore your wallet on any device. Write them on paper in this '
      'order and keep them offline. Anyone with these words can spend your XMR.';
  static const String seedConfirm = 'I wrote down all 25 words.';
  static const String enterWallet = 'Open my wallet';
  static const String opening = 'Opening…';

  // Restore.
  static const String restoreTitle = 'Restore a wallet';
  static const String restoreLead = 'Enter the 25 words of your seed and choose a password for this device.';
  static const String seed = 'Seed';
  static const String seedHint = 'The 25 words, separated by spaces';
  static const String restoreHeight = 'Restore height';
  static const String restoreHeightHint = 'Optional: the block height when the wallet was created';
  static const String restoreHeightNote = 'Leave it empty to scan from the first block. That takes longer.';
  static const String restoreAction = 'Restore wallet';
  static const String restoring = 'Restoring…';

  // Unlock.
  static const String unlockTitle = 'Welcome back';
  static const String unlockLead = 'Enter your password to open the wallet.';
  static const String unlockAction = 'Unlock';

  // Navigation.
  static const String navHome = 'Home';
  static const String navSend = 'Send';
  static const String navReceive = 'Receive';
  static const String navActivity = 'Activity';
  static const String navSettings = 'Settings';
  static const String navLock = 'Lock';
  static const String synced = 'Synced';
  static const String syncing = 'Syncing';
  static const String connecting = 'Connecting';

  // Home.
  static String greeting(DateTime now) => switch (now.hour) {
    < 12 => 'Good morning',
    < 18 => 'Good afternoon',
    _ => 'Good evening',
  };
  static const String homeLead = 'Your keys stay on this device.';
  static const String balance = 'Balance';
  static String lockedNote(String amount) => '$amount XMR waits for 10 confirmations.';
  static const String allUnlocked = 'All of it is ready to spend.';
  static const String unlocked = 'Unlocked';
  static const String unlockedNote = 'Ready to send now.';
  static const String receiveAddress = 'Receive address';
  static String subaddress(int index) => 'Subaddress #$index';
  static const String recentActivity = 'Recent activity';
  static const String allActivity = 'All activity';
  static const String noActivity = 'No transactions yet. Receive XMR to see them here.';
  static const String activityAfterSync = 'The list fills in when the wallet has caught up with the chain.';
  static const String nodeOnline = 'Node online';
  static const String nodeOffline = 'Node offline';
  static const String nodeWrongVersion = 'Node too old';

  // Send.
  static const String sendTitle = 'Send XMR';
  static const String sendLead = 'Payments in Monero are final. Check the address before you send.';
  static const String recipient = 'Address';
  static String recipientHint(MoneroNetwork network) => 'A Monero address on ${network.label}';
  static const String amount = 'Amount';
  static String available(String amount) => 'Unlocked: $amount XMR';
  static const String review = 'Review payment';
  static const String preparing = 'Building the payment…';
  static const String reviewTitle = 'Check the payment';
  static const String reviewLead = 'Once sent, a payment cannot be undone.';
  static const String to = 'To';
  static const String fee = 'Network fee';
  static const String total = 'Total';
  static const String sendNow = 'Send now';
  static const String sending = 'Sending…';
  static const String cancel = 'Cancel';
  static const String sentTitle = 'Payment sent';
  static const String sentLead = 'The node accepted the payment. A block confirms it in about two minutes.';
  static const String transactionId = 'Transaction ID';
  static const String done = 'Done';

  // Receive.
  static const String receiveTitle = 'Receive XMR';
  static const String receiveLead =
      'Share this subaddress. Give each payer a new one, so that no two payments meet on the same address.';
  static const String copyAddress = 'Copy address';
  static const String copied = 'Copied';
  static const String newAddress = 'New address';

  // Activity.
  static const String activityTitle = 'Activity';
  static const String activityLead = 'Every transaction of this wallet, the newest first.';
  static const String received = 'Received';
  static const String sent = 'Sent';
  static const String pending = 'Pending';
  static const String failed = 'Failed';
  static String confirmations(int count) => count == 1 ? '1 confirmation' : '$count confirmations';
  static String feeOf(String amount) => 'Fee $amount XMR';
  static const String copyId = 'Copy ID';

  // Settings.
  static const String settingsTitle = 'Settings';
  static const String settingsLead = 'Your node, your network, your seed, and the lock of this wallet.';
  static const String nodeTitle = 'Node';
  static const String nodeLead = 'The node that your wallet talks to. Run your own node for the most privacy.';
  static const String nodeField = 'Node address';
  static const String nodeHint = 'host:port';
  static const String saveNode = 'Save node';
  static const String nodeSaved = 'The wallet uses the new node.';
  static const String networkTitle = 'Network';
  static const String networkLead =
      'Each network keeps its own wallet and its own node. A switch locks this wallet and opens the wallet of the '
      'other network.';
  static const String seedSettingsLead = 'Show the 25 words of your seed. Kranox asks for your password first.';
  static const String showSeed = 'Show seed';
  static const String hideSeed = 'Hide seed';
  static const String walletFileTitle = 'Wallet file';
  static const String lockLead = 'Close the wallet. Your password opens it again.';
  static const String lockNow = 'Lock now';

  // Errors of the forms.
  static String passwordTooShort(int count) => 'Use at least $count characters.';
  static const String passwordMismatch = 'The passwords do not match.';
  static String seedWordCount(int count) => 'A seed has 25 words. This one has $count.';
  static const String seedCharacters = 'A seed has letters only.';
  static const String restoreHeightInvalid = 'Enter the restore height as a whole number.';
  static String nodeInvalid(MoneroNetwork network) =>
      'Enter the node as host:port, such as node.example.org:${network.rpcPort}.';
  static const String addressEmpty = 'Enter an address.';
  static const String addressLength = 'This address has the wrong length.';
  static const String addressNotBase58 = 'This address has characters that no Monero address has.';
  static const String addressChecksum = 'This address has a typo: its checksum does not match.';
  static String addressOtherNetwork(MoneroNetwork found, MoneroNetwork wallet) =>
      'This is a ${found.label} address. This wallet runs on ${wallet.label}.';
  static const String addressUnknown = 'This is not a Monero address.';
  static const String amountEmpty = 'Enter an amount.';
  static const String amountNotANumber = 'Enter the amount as a number, with a point for decimals.';
  static const String amountTooManyDecimals = 'XMR has at most 12 decimals.';
  static const String amountTooLarge = 'This amount is too large.';
  static const String amountZero = 'Enter an amount above zero.';
  static const String amountAboveUnlocked = 'This is more than your unlocked balance.';

  // Failures of the wallet.
  static const String wrongPassword = 'This password does not open the wallet.';
  static const String walletMissing = 'The wallet file is missing.';
  static const String notEnoughUnlocked = 'Your unlocked balance does not cover this payment and its fee.';
  static const String nodeUnreachable = 'The node does not answer. Check its address in Settings.';
  static String walletReported(String detail) => 'The wallet reported: $detail';

  // Dates.
  static const List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static String today(String time) => 'Today, $time';
}
