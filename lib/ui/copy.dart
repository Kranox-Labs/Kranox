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

  // Unlock.
  static const String unlockTitle = 'Welcome back';
  static const String unlockLead = 'Enter your password to open the wallet.';
  static const String unlockAction = 'Unlock';
  static String version(String name) => 'Version $name';

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
