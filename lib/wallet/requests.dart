/// The requests that the app sends to the wallet engine in its own isolate. Each request carries only plain
/// values, so that it can cross from one isolate to the other.
sealed class WalletRequest {
  const WalletRequest();
}

/// Makes a new wallet and gives the words of its seed.
final class CreateWallet extends WalletRequest {
  const CreateWallet({required this.path, required this.password, required this.networkType});

  final String path;
  final String password;
  final int networkType;
}

/// Makes the wallet of a seed. The wallet scans the chain from the restore height.
final class RestoreWallet extends WalletRequest {
  const RestoreWallet({
    required this.path,
    required this.password,
    required this.seed,
    required this.restoreHeight,
    required this.networkType,
  });

  final String path;
  final String password;
  final String seed;
  final int restoreHeight;
  final int networkType;
}

/// Opens the wallet file with its password.
final class OpenWallet extends WalletRequest {
  const OpenWallet({required this.path, required this.password, required this.networkType});

  final String path;
  final String password;
  final int networkType;
}

/// Connects the open wallet to a node and starts the scan of the chain.
final class ConnectNode extends WalletRequest {
  const ConnectNode({required this.address, this.proxy});

  final String address;

  /// The SOCKS proxy to the node, or null to reach the node straight.
  final String? proxy;
}

final class ReadStatus extends WalletRequest {
  const ReadStatus();
}

final class ReadHistory extends WalletRequest {
  const ReadHistory();
}

/// Gives the newest subaddress. With [createNew], the wallet makes a new subaddress first.
final class ReadReceiveAddress extends WalletRequest {
  const ReadReceiveAddress({required this.createNew});

  final bool createNew;
}

/// Gives the subaddress with [index], which the wallet made before.
final class ReadSubaddress extends WalletRequest {
  const ReadSubaddress({required this.index});

  final int index;
}

/// Builds a payment without sending it, so that the user sees its fee. The answer names the payment with an id.
final class PrepareSend extends WalletRequest {
  const PrepareSend({required this.address, required this.amountUnits});

  final String address;
  final int amountUnits;
}

/// Sends the payment that [PrepareSend] built with [id]. The engine sends it only with the [password] of the wallet,
/// when it still holds that payment, to [address] and of [amountUnits] as the review showed, and, with [deadline],
/// only before that time.
final class ConfirmSend extends WalletRequest {
  const ConfirmSend({
    required this.id,
    required this.address,
    required this.amountUnits,
    required this.password,
    this.deadline,
  });

  final int id;
  final String address;
  final int amountUnits;
  final String password;

  /// The time, in milliseconds since the epoch in UTC, after which the payment must not leave.
  final int? deadline;
}

/// Drops the payment that [PrepareSend] built with [id]. Another payment that the wallet built later stays.
final class CancelSend extends WalletRequest {
  const CancelSend({required this.id});

  final int id;
}

/// Gives the words of the seed after it checks the password against the key file.
final class ReadSeed extends WalletRequest {
  const ReadSeed({required this.password});

  final String password;
}

/// Writes the state of the wallet to its file.
final class StoreWallet extends WalletRequest {
  const StoreWallet();
}

/// Writes the wallet to its file and closes it.
final class CloseWallet extends WalletRequest {
  const CloseWallet();
}
