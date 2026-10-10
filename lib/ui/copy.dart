import '../bridge/models.dart';
import '../config/network.dart';
import '../core/address.dart';
import '../core/unlock.dart';

/// All text of the app. The screens take their words from here.
abstract final class Copy {
  /// The minutes of a whole wait for coins to unlock, from the Monero constants.
  static int get _unlockMinutes => (blockTarget * spendableAge).inMinutes;

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
  static const String backToMainnet = 'Back to mainnet';

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

  // The notice after the start moved a file that it could not read aside, K-09 of the security review of 0.2.0.
  static const String recoveryTitle = 'Kranox moved a damaged file aside';
  static String recoverySettings(String file) =>
      'It could not read its settings, so it started with the defaults. Check your network and node in Settings. '
      'The old file stays as $file.';
  static String recoverySwaps(String file) =>
      'It could not read every saved swap. The swaps that it could read stay, and the old file stays as $file.';
  static const String recoveryWalletsSafe = 'Your wallets and their keys live in other files, which did not change.';
  static const String recoveryDismiss = 'Got it';

  // Unlock.
  static const String unlockTitle = 'Welcome back';
  static const String unlockLead = 'Enter your password to open the wallet.';
  static const String unlockAction = 'Unlock';
  static String version(String name, {required bool beta}) => beta ? 'Version $name beta' : 'Version $name';

  // Navigation.
  static const String navHome = 'Home';
  static const String navSend = 'Send';
  static const String navReceive = 'Receive';
  static const String navActivity = 'Activity';
  static const String navPrivacy = 'Privacy';
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
  static const String allUnlocked = 'All of it is ready to spend.';
  static const String unlocked = 'Unlocked';
  static const String locked = 'Locked';
  static const String unlockedNote = 'Ready to send now.';
  // The card of a locked balance. On 5 Oct 2026 the owner asked for a better look of the locked and the unlocked
  // balance: the progress of the confirmations and the time left, in place of a bare "waits for 10 confirmations".
  static const String unlocking = 'Unlocking';
  static String lockedReadyIn(String amount, Duration wait) => '$amount XMR ${readyIn(wait)}';
  static String lockedNote(String amount) => '$amount XMR waits for $spendableAge confirmations.';
  static const String unlockReason = 'New coins and change unlock after $spendableAge confirmations.';
  static const String receiveAddress = 'Receive address';
  static String subaddress(int index) => 'Subaddress #$index';
  static const String recentActivity = 'Recent activity';
  static const String allActivity = 'All activity';
  static const String noActivity = 'No transactions yet. Receive XMR to see them here.';
  static const String activityAfterSync = 'The list fills in when the wallet has caught up with the chain.';
  static const String activityUpdating = 'Syncing. New payments show when the wallet has caught up.';
  static const String balanceUpdating = 'Updating while the wallet catches up with the chain.';
  static const String nodeOnline = 'Node online';
  static const String nodeOffline = 'Node offline';
  static const String nodeWrongVersion = 'Node too old';

  // Send.
  static const String sendTitle = 'Send XMR';
  static const String sendLead = 'Payments in Monero are final. Check the address before you send.';
  static const String recipient = 'Address';
  static String recipientHint(MoneroNetwork network) => 'A Monero address on ${network.label}';
  static const String paste = 'Paste';
  static String addressValid(AddressKind kind, MoneroNetwork network) => switch (kind) {
    AddressKind.standard => '${network.label} address',
    AddressKind.subaddress => '${network.label} subaddress',
    AddressKind.integrated => '${network.label} integrated address',
  };
  static const String amountHint = '0.00';
  static const String youSend = 'You send';
  static const String amount = 'Amount';
  static String available(String amount) => 'Unlocked: $amount XMR';
  static const String availableUpdating = 'Unlocked: updating while the wallet catches up.';
  static const String review = 'Review payment';
  static const String preparing = 'Building the payment…';
  static const String reviewTitle = 'Check the payment';
  static const String reviewLead = 'Once sent, a payment cannot be undone.';
  static const String to = 'To';
  static const String fee = 'Network fee';
  static const String total = 'Total';
  static const String sendNow = 'Send now';
  static const String sendPassword = 'Your password, to send';

  // The privacy check on the review of a payment.
  static const String privacyTitle = 'Privacy check';
  static const String privacyClear = 'All clear';
  static String privacyWarnings(int count) => count == 1 ? '1 warning' : '$count warnings';
  static const String privacyAmountLabel = 'Amount';
  static const String privacyTimingLabel = 'Timing';
  static const String privacyAddressLabel = 'Address';
  static const String privacyAmountClear = 'It matches nothing that came in lately.';
  static String privacyAmountMatchesXmr(String amount, String ago) =>
      'It is close to the $amount XMR that came in $ago. Anyone who sees both payments can match them.';
  static String privacyAmountMatchesChain(String paid, String sent, String asset, String ago) =>
      'They get about $paid $asset, close to the $sent $asset that you sent in from Robinhood Chain $ago. Anyone who '
      'watches the chain can match the two.';
  static String privacyUse(String amount) => 'Use $amount XMR';
  static String privacyTimingClear(int hours) => 'You hold enough XMR that came in more than $hours hours ago.';
  static String privacyTimingFresh(String ago, String moment) =>
      'This payment may use XMR that came in $ago. A short gap makes the two easy to match. Waiting until $moment '
      'helps.';
  static String privacyTimingFromChain(String ago, String moment) =>
      'This payment may use XMR that came from Robinhood Chain $ago. A short gap makes the two easy to match. Waiting '
      'until $moment helps.';
  static const String privacyAddressClear = 'It is not an address of yours from a receive.';
  static String privacyAddressOwn(String day) =>
      'You gave it as the refund address of a receive on $day. Paying it from XMR links both sides.';
  static const String privacyNote = 'The check runs on this Mac. You can still send.';

  // The menu Privacy: the whole wallet, from its history on this Mac. Each check has a tile with one line, and the
  // longer text shows when the user opens the tile.
  static const String privacyPageTitle = 'Privacy';
  static const String privacyPageLead = 'How private your wallet is, worked out on this Mac from your own history.';
  static const String privacyMoneroTab = 'Monero';
  static const String privacyChainTab = 'Robinhood Chain';
  static String privacyRingCount(int clear, int total) => '$clear/$total';
  static const String privacyRingLabel = 'Clear';
  static String privacyToImprove(int count) => count == 1 ? '1 thing to improve' : '$count things to improve';
  static const String privacyAllClearLead = 'Your wallet gives nothing away that this page can find.';
  static const String privacyNothingLeft = 'Nothing left to improve';
  static const String privacyFromHistory = 'From your history';
  static String privacyNotesLead(int count) => count == 1
      ? '1 note on your history. Click it to see what it found.'
      : '$count notes on your history. Click one to see what it found.';
  static const String privacyToImproveLead = 'Click a check to see what it found and what you can do.';
  static const String privacyPageNote = 'Everything on this page comes from this Mac. Nothing leaves it.';
  static const String privacyNodeOwnLine = 'Your own node';
  static const String privacyNodePublicLine = 'A public node sees your IP address';
  static const String privacySubaddressClearLine = 'One payment each at most';
  static String privacySubaddressLine(int index, int payments) => 'Subaddress #$index took $payments payments';
  static String privacySubaddressManyLine(int count) => '$count subaddresses took several payments';
  static String privacySubaddressPastLine(int index, int payments) =>
      'Subaddress #$index took $payments payments before';
  static String privacySubaddressPastManyLine(int count) => '$count subaddresses took several payments before';
  static const String privacySwapsClearLine = 'No swaps sit close';
  static String privacySwapsLine(int count) => count == 1 ? '1 pair can be matched' : '$count pairs can be matched';
  static const String privacyRefundClearLine = 'None paid from XMR';
  static String privacyRefundLine(int count) =>
      count == 1 ? '1 address links both sides' : '$count addresses link both sides';
  static String privacyNewCoinsClearLine(int hours) => 'All older than $hours hours';
  static String privacyNewCoinsLine(String amount, int hours) => '$amount XMR from the last $hours hours';
  static String privacyLockLine(int minutes) => 'Locks after $minutes minutes';
  static const String privacyNodeTitle = 'Node';
  static String privacyNodeOwn(String node) =>
      'Your wallet uses the node at $node in your own network, so no outside node sees what it asks.';
  static String privacyNodePublic(String node) =>
      'Your wallet syncs and sends through $node. That node sees your IP address and when you send, and the '
      'connection is not encrypted, so your network can watch it too. A node of your own, or a proxy such as Tor in '
      'Settings, keeps this to you.';
  static String privacyNodeProxy(String node, String proxy) =>
      'Your wallet reaches $node through the proxy at $proxy, so the node sees the proxy and not your IP address.';
  static const String privacyNodeProxyLine = 'Through a proxy';
  static const String privacyChangeNode = 'Change node';
  static const String privacySubaddressTitle = 'Subaddresses';
  static const String privacySubaddressClear = 'Each subaddress took one payment at most.';
  static String privacySubaddressOne(int index, int payments) =>
      'Subaddress #$index took $payments payments. Payers who compare notes can tell that they paid the same person. '
      'Give each payer a new subaddress.';
  static String privacySubaddressMany(int count, int index, int payments) =>
      '$count subaddresses took more than one payment, #$index the most with $payments. Payers who compare notes can '
      'tell that they paid the same person. Give each payer a new subaddress.';
  static String privacySubaddressPast(int index, int payments) =>
      'Subaddress #$index took $payments payments before. Payers who compare notes can tell that they paid the same '
      'person. Your receive page gives out a new subaddress now, so give that one to the next payer.';
  static String privacySubaddressPastMany(int count, int index, int payments) =>
      '$count subaddresses took more than one payment before, #$index the most with $payments. Payers who compare '
      'notes can tell that they paid the same person. Your receive page gives out a new subaddress now, so give that '
      'one to the next payer.';
  static const String privacyNewSubaddress = 'New subaddress';
  static const String privacySwapsTitle = 'Swaps with Robinhood Chain';
  static const String privacySwapsClear = 'None of your swaps sit close in time or amount.';
  static String privacySwapsPair(String sent, String paid, String receivedOn, String paidOn, String how) =>
      'Your receive of $sent on $receivedOn and your payment of $paid on $paidOn sit close in $how. Anyone who '
      'watches the chain can match them.';
  static String privacySwapsMore(int count) => count == 1 ? '1 more pair does too.' : '$count more pairs do too.';
  static const String privacySwapsTip = 'Next time, leave a day between them and change the amount.';
  static const String privacyCloseInTime = 'time';
  static const String privacyCloseInAmount = 'amount';
  static const String privacyCloseInBoth = 'time and amount';
  static const String privacyRefundTitle = 'Refund addresses';
  static const String privacyRefundClear = 'You never paid a refund address of yours from XMR.';
  static String privacyRefundLinked(String address, String paidOn, String receivedOn) =>
      'You paid $address from XMR on $paidOn, and you gave it as the refund address of a receive on $receivedOn. That '
      'links both sides.';
  static String privacyRefundMore(int count) =>
      count == 1 ? '1 more address does too.' : '$count more addresses do too.';
  static const String privacyNewCoinsTitle = 'New XMR';
  static String privacyNewCoinsClear(int hours) => 'All your XMR came in more than $hours hours ago.';
  static String privacyNewCoins(String amount, int hours, String moment) =>
      '$amount XMR came in within the last $hours hours. Spending it soon after makes the two easy to match. All of '
      'it is older from $moment.';
  static const String privacyLockTitle = 'Lock and password';

  // The scan of an address on Robinhood Chain in the menu Privacy. Before a scan, each tile says what its check reads.
  static const String privacyChainTitle = 'Scan an address of yours';
  static const String privacyChainLead = 'See what the public history of an address on Robinhood Chain gives away.';
  static const String privacyChainNote =
      'Kranox asks the explorer through its relay, so the explorer never sees your IP address, and the relay keeps no '
      'record.';
  static const String privacyChainField = 'Your address on Robinhood Chain';
  static const String privacyChainScan = 'Scan';
  static const String privacyChainScanning = 'Scanning…';
  static String privacyChainResult(String address) => 'What $address shows';
  static const String privacyChainClearLead = 'Its public history ties it to nothing of yours that Kranox knows.';
  static const String privacyCleanStart = 'To start clean, pay a new address of yours from XMR with Kranox.';
  static const String privacyPayNewAddress = 'Pay a new address';
  static const String privacyFundingPending = 'Who sent it its first coins';
  static const String privacyOwnPending = 'Direct transfers with your other addresses';
  static const String privacyLookAlikePending = 'Senders that mimic an address it paid';
  static const String privacyKranoxPending = 'Its part in your swaps in Kranox';
  static const String privacyExposurePending = 'Its counts, first day, tokens, and busiest hours';
  static const String privacyFundingNoneLine = 'No first funding found';
  static const String privacyFundingOwnLine = 'Funded by an address of yours';
  static String privacyFundingNamedLine(String name) => 'Funded by $name';
  static const String privacyFundingPlainLine = 'Funded by an address without a name';
  static const String privacyOwnClearLine = 'No direct link to your addresses';
  static String privacyOwnLine(int count) =>
      count == 1 ? 'Linked to 1 address of yours' : 'Linked to $count addresses of yours';
  static const String privacyLookAlikeClearLine = 'No look-alike senders';
  static String privacyLookAlikeLine(int count) => count == 1 ? '1 look-alike sender' : '$count look-alike senders';
  static const String privacyKranoxClearLine = 'In none of your swaps';
  static String privacyKranoxLine(int count) => count == 1 ? 'In 1 of your swaps' : 'In $count of your swaps';
  static const String privacyExposureEmptyLine = 'No public history yet';
  static const String privacyExposureLine = 'Anyone can look this up';
  static String privacyExposureHoldsLine(String tokens) => 'Holds $tokens';
  static const String privacyStatTransactions = 'Transactions';
  static const String privacyStatTokenTransfers = 'Token transfers';
  static const String privacyStatFirstSeen = 'First seen';
  static const String privacyStatHours = 'Busiest hours';
  // The source of the scan may count only what it read, so a count above 0 is a floor.
  static String privacyStatCount(int count) => count == 0 ? '0' : '$count+';
  static String privacyStatHourRange(String from, String to) => '$from–$to UTC';
  static const String privacyFundingTitle = 'First funding';
  static const String privacyFundingNone = 'Kranox found no transfer that first funded this address.';
  static String privacyFundingOwn(String sender, String day) =>
      'Your address $sender funded it first on $day, so the two are linked in public.';
  static String privacyFundingNamed(String name, String day) =>
      '$name funded it first on $day. If $name knows who you are, it can tie you to this address.';
  static String privacyFundingPlain(String sender, String day) =>
      '$sender funded it first on $day, and that address has no public name.';
  static const String privacyOwnTitle = 'Your other addresses';
  static const String privacyOwnClear = 'It never dealt directly with another address of yours that Kranox knows.';
  static String privacyOwnLinked(String other, String day) =>
      'It dealt directly with $other, another address of yours, on $day, so the two are linked in public.';
  static String privacyMoreAddresses(int count) =>
      count == 1 ? '1 more address does too.' : '$count more addresses do too.';
  static const String privacyLookAlikeTitle = 'Look-alike addresses';
  static const String privacyLookAlikeClear = 'No address that looks like one it paid sent it anything.';
  static String privacyLookAlike(String sender, String resembles, String day) =>
      '$sender looks like $resembles, which this address paid, and sent it a transfer on $day. The trick aims to make '
      'you copy the wrong address later, so copy an address from its owner and never from a history.';
  static const String privacyKranoxTitle = 'Swaps with Kranox';
  static const String privacyKranoxClear = 'It takes part in none of your swaps in Kranox.';
  static String privacyKranoxFunded(String amount, String day) => 'It sent $amount into your receive on $day.';
  static String privacyKranoxPaid(String amount, String day) => 'It got your payment of $amount from XMR on $day.';
  static String privacyKranoxRefund(String day) => 'You gave it as the refund address of your receive on $day.';
  static String privacyMoreSwaps(int count) => count == 1 ? '1 more swap does too.' : '$count more swaps do too.';
  static const String privacyKranoxNote =
      'On the chain this shows a transfer with an exchanger, and only the records of ChangeNOW tie it to your XMR.';
  static const String privacyExposureTitle = 'What everyone sees';
  static const String privacyExposureEmpty = 'It has no public history yet.';
  // The source of the scan may count only what it read, so the counts are a floor.
  static String privacyExposure(int transactions, int transfers) =>
      'At least $transactions transactions and $transfers token transfers.';
  static String privacyExposureSince(String day) => 'Active since $day.';
  static String privacyExposureTokens(String tokens) => 'It holds $tokens.';
  static String privacyExposureHours(String from, String to) =>
      'Most of its activity falls between $from:00 and $to:00 UTC, which hints at your time zone.';
  static String privacyLock(int minutes) =>
      'The wallet locks after $minutes minutes without use, and each send asks for your password.';

  // How long ago something happened, and a moment to come.
  static const String justNow = 'just now';
  static String minutesAgo(int count) => count == 1 ? 'a minute ago' : '$count minutes ago';
  static String hoursAgo(int count) => count == 1 ? 'an hour ago' : '$count hours ago';
  static String daysAgo(int count) => count == 1 ? 'a day ago' : '$count days ago';
  static String todayAt(String time) => 'today at $time';
  static String tomorrowAt(String time) => 'tomorrow at $time';
  static String dayAt(String day, String time) => '$day at $time';
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
  static const String copy = 'Copy';
  static const String copied = 'Copied';
  static const String newAddress = 'New address';
  // The two ways to receive. On 5 Oct 2026 the owner asked for receive from Robinhood Chain inside the receive page,
  // not as a page "Bridge" of its own.
  static const String receiveMoneroTab = 'Monero';
  static const String receiveChainTab = 'From Robinhood Chain';
  static const String receiveChainLead =
      'Turn ETH or USDG on Robinhood Chain into XMR for this wallet. ChangeNOW handles the exchange.';

  // Activity.
  static const String activityTitle = 'Activity';
  static const String activityLead = 'Every transaction of this wallet, the newest first.';
  static const String received = 'Received';
  static const String sent = 'Sent';
  static const String pending = 'Pending';
  static const String failed = 'Failed';
  static String confirmationCount(int count) => '$count/$spendableAge';
  static String confirmationsOf(int count) => '${confirmationCount(count)} confirmations';
  static String readyIn(Duration wait) => 'ready in about ${wait.inMinutes} min';
  static String feeOf(String amount) => 'Fee $amount XMR';
  static const String copyId = 'Copy ID';

  // Receive from Robinhood Chain, through ChangeNOW. On 5 Oct 2026 the owner asked for it in the app: a coin on
  // Robinhood Chain in, XMR out. Pay, from XMR to Robinhood Chain, follows on the send page.
  static const String exchanger = 'ChangeNOW';
  static const String bridgeMainnetOnly =
      'Receiving from Robinhood Chain works on the Monero mainnet only. Switch the network in Settings to use it.';
  // The form of a swap, as on pay. On 6 Oct 2026 the owner asked for the receive page in the form of the send page.
  static const String bridgeYouSend = 'You send';
  static const String bridgeYouGet = 'You get about';
  static String bridgeMinimum(String amount, BridgeAsset asset) => 'Minimum: $amount ${asset.label}';
  static String bridgeBelowMinimum(String amount, BridgeAsset asset) => 'Below the minimum of $amount ${asset.label}.';
  static String bridgeSpeed(String minutes) => 'Usually $minutes minutes.';
  static const String bridgeRefundField = 'Refund address (optional)';
  static const String bridgeRefundHint = 'Your Robinhood Chain address, 0x…';
  static const String bridgeRefundNote =
      'ChangeNOW sends your coins back here if the swap fails. Without it, a failed swap waits for its support.';
  static const String bridgeRefundInvalid = 'Enter a Robinhood Chain address: 0x and 40 hex digits.';
  static const String bridgeCreate = 'Get a deposit address';
  static const String bridgeCreating = 'Asking ChangeNOW…';
  static const String bridgeSeenBy =
      'ChangeNOW sees the amount, the time, the deposit, and the subaddress of this swap. It never sees your keys.';
  static String bridgeSwapTitle(String amount, BridgeAsset asset) => '$amount ${asset.label} into XMR';

  /// When a swap started and last changed, and, while it runs, when the app last checked it with the exchanger.
  static String bridgeSwapTimes(String started, String? updated, {String? checked}) => [
    'Started $started',
    if (updated != null) 'last change $updated',
    if (checked != null) 'checked $checked',
  ].join(' · ');
  // The owner asked on 6 Oct 2026 what a card of a swap should say so that a user does not worry while it runs.
  static const String bridgeCanClose =
      'You can close Kranox: ChangeNOW carries on, and this card catches up when you open the app again.';
  static String bridgeDepositLead(String amount, BridgeAsset asset) =>
      'Send exactly $amount ${asset.label} on Robinhood Chain to this address.';
  // The code of a deposit holds a payment link that names the chain, the coin, and the amount; a wallet that cannot
  // read such a link scans the address alone.
  static String bridgeLinkNote(BridgeAsset asset) =>
      'The code also names Robinhood Chain, ${asset.label}, and the amount.';
  static const String bridgeAddressOnly = 'Address only';
  static const String bridgePaymentLink = 'Payment link';
  static String bridgeOnlyAsset(BridgeAsset asset) =>
      'Send only ${asset.label} on Robinhood Chain. Another coin or another chain does not arrive.';
  static const String bridgeSwapId = 'Swap ID';
  static const String bridgeRefresh = 'Check now';
  static const String bridgeAnother = 'Start another swap';
  static const String bridgeSwapsTitle = 'Swaps';
  static String bridgeSwapLine(String amount, BridgeAsset asset) => '$amount ${asset.label} into XMR';
  static String bridgeOut(String xmr) => '$xmr XMR';

  /// The state of a swap in a list, in the words of its card.
  static String swapStage(SwapDirection direction, SwapStage stage) => switch ((direction, stage)) {
    (SwapDirection.pay, SwapStage.waiting) => payStepWaiting,
    (SwapDirection.pay, SwapStage.confirming) => payStepConfirming,
    (SwapDirection.pay, SwapStage.sending) => 'Sending to the recipient',
    (SwapDirection.pay, SwapStage.finished) => payStepDone,
    (_, SwapStage.waiting) => 'Waiting for your deposit',
    (_, SwapStage.confirming) => 'Confirming the deposit',
    (_, SwapStage.exchanging) => 'Exchanging',
    (_, SwapStage.sending) => 'Sending XMR',
    (_, SwapStage.finished) => 'Done',
    (_, SwapStage.failed) => 'Failed',
    (_, SwapStage.refunded) => 'Refunded',
    (_, SwapStage.verifying) => 'Held for a check',
  };

  // The steps of a swap, each with its facts. The support of ChangeNOW answers at this address: CHECKED 5 Oct 2026,
  // sources changenow.io/press and its API documentation.
  static const String exchangerSupport = 'support@changenow.io';
  static const String bridgeStepWaiting = 'Waiting for your deposit';
  static const String bridgeStepDeposited = 'Deposit received';
  static String bridgeStepReceived(String amount, BridgeAsset asset) => '$amount ${asset.label} received.';
  static const String bridgeStepConfirming = 'Confirming the deposit on Robinhood Chain';
  static const String bridgeStepConfirmingNote = 'ChangeNOW waits until Robinhood Chain confirms your deposit.';
  static String bridgeStepExchanging(BridgeAsset asset) => 'Exchanging ${asset.label} for XMR';
  static String bridgeStepRate(String xmr) => 'About $xmr XMR at the current rate.';
  static String bridgeStepExchanged(String xmr) => 'Exchanged for $xmr XMR.';
  static String bridgeStepSending(int subaddress) => 'Sending XMR to subaddress #$subaddress';
  static String bridgeStepSendingNote(String xmr) => 'ChangeNOW sends $xmr XMR to this wallet.';
  static const String bridgeStepDone = 'XMR arrived';
  static String bridgeStepDoneNote(String xmr) =>
      '$xmr XMR is in this wallet. You can spend it after $spendableAge confirmations, about $_unlockMinutes minutes.';
  static const String bridgeStepHeld = 'Held for a check';
  static const String bridgeHeld =
      'ChangeNOW stopped this swap to check it. Write to $exchangerSupport with the swap ID; Kranox cannot release '
      'it. After the check the swap goes on, or ChangeNOW refunds it.';
  static const String bridgeStepFailed = 'The swap failed';
  static String bridgeFailedNoDeposit(BridgeAsset asset) =>
      'ChangeNOW saw no deposit, so nothing left your wallet. If you sent ${asset.label} after all, write to '
      '$exchangerSupport with the swap ID.';
  static String bridgeFailedRefunding(String amount, BridgeAsset asset, String refundAddress) =>
      'Your $amount ${asset.label} goes back to $refundAddress. This card shows the refund as soon as ChangeNOW '
      'sends it. If it does not come, write to $exchangerSupport with the swap ID.';
  static String bridgeFailedNoRefundAddress(String amount, BridgeAsset asset) =>
      'Your $amount ${asset.label} is with ChangeNOW. Write to $exchangerSupport with the swap ID to get it back.';
  static const String bridgeStepRefunded = 'Refunded';
  static String bridgeRefundedTo(String amount, BridgeAsset asset, String refundAddress) =>
      'ChangeNOW sent $amount ${asset.label} back to $refundAddress on Robinhood Chain.';
  static String bridgeRefundedNoAddress(String amount, BridgeAsset asset) =>
      'ChangeNOW sent $amount ${asset.label} back to the address that you gave its support.';
  static const String bridgeDepositHash = 'Deposit';
  static const String bridgePayoutHash = 'XMR transaction';
  static const String bridgeRefundHash = 'Refund';
  static const String bridgeClose = 'Close';
  static const String bridgeRelayDown = 'The bridge service does not answer. Try again in a moment.';
  static String bridgeRefused(String detail) => 'ChangeNOW refused: $detail';
  static String bridgeFailed(String detail) => 'The bridge failed: $detail';

  // Pay, from XMR to an address on Robinhood Chain, through ChangeNOW at a fixed rate. On 5 Oct 2026 the owner chose
  // it as the next main feature, as a choice on the send page beside Monero. On 6 Oct 2026 the owner asked for the
  // form of a swap: the XMR to pay above, the coin that the recipient gets below, and the recipient last.
  static const String sendMoneroTab = 'Monero';
  static const String sendChainTab = 'To Robinhood Chain';
  static const String payLead = 'Pay any address on Robinhood Chain from your XMR. ChangeNOW handles the exchange.';
  static const String payMainnetOnly =
      'Paying to Robinhood Chain works on the Monero mainnet only. Switch the network in Settings to use it.';
  static const String payRecipient = 'Recipient on Robinhood Chain';
  static const String payRecipientHint = 'An address on Robinhood Chain, 0x…';
  static const String payRecipientValid = 'Robinhood Chain address';
  static const String payRecipientNoChecksum =
      'Robinhood Chain address in lowercase, without a checksum. Check it character by character.';
  static const String payRecipientWrongForm = 'Enter a Robinhood Chain address: 0x and 40 hex digits.';
  static const String payRecipientBadChecksum = 'This address has a typo: its checksum does not match.';
  static const String payTheyReceive = 'They receive';
  static const String payTheyReceiveAbout = 'They receive about';

  /// An amount at a floating rate, which can still move.
  static String about(String amount) => '≈ $amount';
  static String payFees(String xmrFee, String coinFee, BridgeAsset asset) =>
      'ChangeNOW fees, included: $xmrFee XMR + $coinFee ${asset.label}';
  // The choice of the rate. On 6 Oct 2026 the owner asked to let the user choose, with the trade of each one in view.
  static const String payRateTitle = 'Rate';
  static const String payRateFixed = 'Fixed rate';
  static const String payRateFixedNote = 'Exact amount';
  static const String payRateFloating = 'Floating rate';
  static const String payRateFloatingNote = 'Can move a little';
  static String payRateMinimum(String xmr) => 'Min $xmr XMR';
  static String paySwitchToFloating(String xmr) => 'Switch to a floating rate to pay from $xmr XMR';
  static const String payRateFixedReview = 'Fixed: they get exactly this amount';
  static const String payRateFloatingReview =
      'Floating: the amount follows the market until ChangeNOW exchanges the XMR';
  static const String payOnMonero = 'On Monero';
  static const String payOnChain = 'On Robinhood Chain';
  static const String payEnterRecipient = 'Enter recipient address';
  static const String payQuoting = 'Asking ChangeNOW for a fixed rate…';
  // The owner asked on 6 Oct 2026 for the minimum payment in plain view, before the user types.
  static String payMinimum(String xmr) => 'Minimum payment: $xmr XMR';
  static String payBelowMinimum(String xmr) => 'Below the minimum payment of $xmr XMR.';
  static String payAboveMaximum(String xmr) => 'Above the maximum payment of $xmr XMR.';
  static const String payPreparing = 'Asking ChangeNOW…';
  static const String payTo = 'To, on Robinhood Chain';
  // The check of the recipient on the review of pay, from 8 Oct 2026: the scan of the menu Privacy, for an address that
  // may be one of the user's own.
  static const String payCheckRecipient = 'Check this address';
  static const String payCheckingRecipient = 'Checking…';
  static const String payCheckRecipientLead = 'Is it yours? See what it already shows on Robinhood Chain.';
  static const String payRecipientFresh = 'No public history yet';
  static const String payRecipientFreshNote = 'A clean start, if this address is yours.';
  static String payRecipientFundedNamed(String name, String day) => 'First funded by $name on $day';
  static String payRecipientFundedOwn(String address, String day) =>
      'First funded by $address, an address of yours, on $day';
  static String payRecipientFundedPlain(String day) => 'First funded on $day by an address without a name';
  static String payRecipientOwn(String address) => 'Dealt directly with $address, another address of yours';
  static String payRecipientOwnMany(int count) => 'Dealt directly with $count other addresses of yours';
  // The source of the scan may count only what it read, so the count is a floor.
  static String payRecipientHistory(int transactions, String? since) =>
      since == null ? 'At least $transactions transactions' : 'At least $transactions transactions since $since';
  static const String payRecipientApart =
      'If this address is yours, paying a new one keeps this payment apart from you.';
  static const String payYouSend = 'You pay';
  static const String payRateHolds = 'Rate holds until';
  static const String payRefundLabel = 'Refund';
  static String payRefund(int index) => 'Back to subaddress #$index if the swap fails';
  static const String paySeenBy =
      'The recipient sees a transfer from an address of ChangeNOW, not from your wallet. ChangeNOW sees the amount, '
      'the time, and the recipient, never your keys.';
  static const String payNow = 'Pay now';
  static const String paying = 'Paying…';
  static const String payRateExpired =
      'The fixed rate ran out before the payment left. Review it again for a new rate.';
  static String paySwapTitle(String amount, BridgeAsset asset, String recipient) =>
      '$amount ${asset.label} to $recipient';
  static const String payStepWaiting = 'XMR on its way to ChangeNOW';
  static const String payStepDeposited = 'XMR sent to ChangeNOW';
  static String payStepSentNote(String xmr) => '$xmr XMR left this wallet.';
  static const String payStepConfirming = 'Confirming the XMR';
  static const String payStepConfirmingNote = 'ChangeNOW waits until Monero confirms your payment.';
  // The wait of a payment in view. CHECKED 6 Oct 2026, the two first payments on mainnet: 27 and 16 minutes from the
  // XMR that left the wallet to the coin at the recipient, with gaps of 15 and 9 minutes without a block of Monero.
  static const String payUsualTime = 'Usually 15 to 30 minutes after the XMR leaves.';
  static String get payStepFirstBlock =>
      'Waiting for the first block. Monero adds one about every ${blockTarget.inMinutes} minutes; sometimes one takes '
      '10 minutes or more.';
  static String payStepConfirmations(int confirmations, int target, Duration left) =>
      '$confirmations of about $target confirmations · about ${left.inMinutes} min left';
  static const String payStepConfirmed = 'Confirmed on Monero. ChangeNOW takes the XMR in at any moment.';
  static String payRefundNote(int index) => 'If the swap fails, ChangeNOW sends the XMR back to subaddress #$index.';
  static String payStepExchanging(BridgeAsset asset) => 'Exchanging XMR for ${asset.label}';
  static String payStepSendingOut(BridgeAsset asset, String recipient) => 'Sending ${asset.label} to $recipient';
  static const String payStepDone = 'Paid';
  static String payStepDoneNote(String amount, BridgeAsset asset, String recipient) =>
      '$amount ${asset.label} arrived at $recipient on Robinhood Chain.';
  static String payFailed(int index) =>
      'ChangeNOW sends your XMR back to subaddress #$index of this wallet. If it does not come, write to '
      '$exchangerSupport with the swap ID.';
  static String payRefunded(String xmr, int index) => 'ChangeNOW sent $xmr XMR back to subaddress #$index.';
  static const String payMoneroHash = 'Monero transaction';
  static const String payChainHash = 'Robinhood Chain transaction';
  static String payOut(String xmr) => '-$xmr XMR';
  static const String payAnother = 'Make another payment';
  static const String paymentsTitle = 'Payments';

  // Settings.
  static const String settingsTitle = 'Settings';
  static const String settingsLead = 'Your node, the relay, your network, your seed, and the lock of this wallet.';
  static const String nodeTitle = 'Node';
  static const String nodeLead = 'The node that your wallet talks to. Run your own node for the most privacy.';
  static const String nodeField = 'Node address';
  static const String nodeHint = 'host:port';
  static const String saveNode = 'Save node';
  static const String nodeSaved = 'The wallet uses the new node.';
  static const String proxyField = 'Proxy, such as Tor (optional)';
  static const String proxyHint = '127.0.0.1:9050';
  static const String proxyNote =
      'With Tor on this Mac, 127.0.0.1:9050 carries the traffic to the node and to the relay through Tor. Leave it '
      'empty to reach both straight.';
  static const String proxyInvalid = 'Enter the proxy as host:port, such as 127.0.0.1:9050.';
  static const String relayTitle = 'Relay';
  static const String relayLead =
      'The service of Kranox that talks to ChangeNOW when you receive from Robinhood Chain. It never sees your keys '
      'and keeps no record of a swap.';
  static const String relayOnline = 'Relay online';
  static const String relayOffline = 'Relay offline';
  static const String relayChecking = 'Checking';
  static const String relayCheck = 'Check';
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
  static const String amountLeavesNoFee =
      'Keep a little of your unlocked balance for the network fee: send less than all of it.';
  static String lockedPart(String amount) =>
      'Locked: $amount XMR. New coins and change unlock after $spendableAge confirmations, about $_unlockMinutes '
      'minutes.';
  static String lockedPartReadyIn(String amount, Duration wait) => 'Locked: $amount XMR, ${readyIn(wait)}.';

  // Failures of the wallet.
  static const String wrongPassword = 'This password does not open the wallet.';
  static const String walletMissing = 'The wallet file is missing.';
  static const String notEnoughUnlocked = 'Your unlocked balance does not cover this payment and its fee.';
  static const String nodeUnreachable = 'The node does not answer. Check its address in Settings.';
  static String walletReported(String detail) => 'The wallet reported: $detail';
  static const String walletClosed = 'The wallet locked before this step. Unlock it and try again.';
  static const String paymentChanged = 'This payment changed before it left. Nothing was sent; review it again.';
  static const String deadlinePassed = 'The time for this payment passed. Nothing was sent; review it again.';
  static String feeTooHigh(String fee, String most) =>
      'The node asks for a network fee of $fee XMR, above the most that Kranox pays, $most XMR. Nothing was sent. '
      'Choose another node in Settings, or try again later.';
  // A failure that the app does not name. A payment may have left before it, so the user looks first.
  static const String unexpectedFailure = 'Something went wrong. Check Activity before you try again.';

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
