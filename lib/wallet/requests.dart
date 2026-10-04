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
  const ConnectNode({required this.address});

  final String address;
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

/// Builds a payment without sending it, so that the user sees its fee.
final class PrepareSend extends WalletRequest {
  const PrepareSend({required this.address, required this.amountUnits});

  final String address;
  final int amountUnits;
}

/// Sends the payment that [PrepareSend] built.
final class ConfirmSend extends WalletRequest {
  const ConfirmSend();
}

/// Drops the payment that [PrepareSend] built.
final class CancelSend extends WalletRequest {
  const CancelSend();
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
