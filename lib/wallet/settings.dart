import '../config/app_config.dart';
import '../config/network.dart';

/// The choices of the user that the app keeps between runs: the network, a node for each network where the user
/// chose one, and the subaddress that the receive page shows on each network. A network without a choice uses its
/// default node.
final class AppSettings {
  const AppSettings({this.network = AppConfig.defaultNetwork, this.nodes = const {}, this.receiveIndexes = const {}});

  final MoneroNetwork network;
  final Map<MoneroNetwork, String> nodes;

  /// The index of the subaddress that the receive page shows. The bridge makes subaddresses of its own for the
  /// exchanger, so the newest subaddress of a wallet is not always one that the user may hand out.
  final Map<MoneroNetwork, int> receiveIndexes;

  String nodeOf(MoneroNetwork network) => nodes[network] ?? AppConfig.defaultNode(network);

  int? receiveIndexOf(MoneroNetwork network) => receiveIndexes[network];

  AppSettings withNetwork(MoneroNetwork network) =>
      AppSettings(network: network, nodes: nodes, receiveIndexes: receiveIndexes);

  AppSettings withNode(MoneroNetwork network, String node) =>
      AppSettings(network: this.network, nodes: {...nodes, network: node}, receiveIndexes: receiveIndexes);

  AppSettings withReceiveIndex(MoneroNetwork network, int index) =>
      AppSettings(network: this.network, nodes: nodes, receiveIndexes: {...receiveIndexes, network: index});

  Map<String, Object?> toJson() => {
    _networkKey: network.name,
    _nodesKey: {for (final entry in nodes.entries) entry.key.name: entry.value},
    _receiveIndexesKey: {for (final entry in receiveIndexes.entries) entry.key.name: entry.value},
  };

  /// Reads the settings from their JSON. Throws a [FormatException] for a value of the wrong form.
  ///
  /// Up to 5 Oct 2026 the app ran on stagenet only and kept one node under the key `node`. A file of that time keeps
  /// its node as the node of stagenet.
  factory AppSettings.fromJson(Object? data) {
    if (data is! Map<String, Object?>) {
      throw const FormatException('The settings hold no object.');
    }
    final nodes = <MoneroNetwork, String>{};
    final legacyNode = data[_legacyNodeKey];
    if (legacyNode is String) {
      nodes[MoneroNetwork.stagenet] = legacyNode;
    }
    final savedNodes = data[_nodesKey];
    if (savedNodes is Map<String, Object?>) {
      for (final entry in savedNodes.entries) {
        final node = entry.value;
        if (node is! String) {
          throw FormatException('The settings hold a node that is no text.', entry.key);
        }
        nodes[_networkNamed(entry.key)] = node;
      }
    } else if (savedNodes != null) {
      throw const FormatException('The settings hold nodes that are no object.');
    }
    final receiveIndexes = <MoneroNetwork, int>{};
    final savedIndexes = data[_receiveIndexesKey];
    if (savedIndexes is Map<String, Object?>) {
      for (final entry in savedIndexes.entries) {
        final index = entry.value;
        if (index is! int || index < 1) {
          throw FormatException('The settings hold a receive index that is no whole number above zero.', entry.key);
        }
        receiveIndexes[_networkNamed(entry.key)] = index;
      }
    } else if (savedIndexes != null) {
      throw const FormatException('The settings hold receive indexes that are no object.');
    }
    final network = data[_networkKey];
    return AppSettings(
      network: network is String ? _networkNamed(network) : AppConfig.defaultNetwork,
      nodes: nodes,
      receiveIndexes: receiveIndexes,
    );
  }

  static MoneroNetwork _networkNamed(String name) => MoneroNetwork.values.firstWhere(
    (network) => network.name == name,
    orElse: () => throw FormatException('The settings name an unknown network.', name),
  );

  static const String _networkKey = 'network';
  static const String _nodesKey = 'nodes';
  static const String _legacyNodeKey = 'node';
  static const String _receiveIndexesKey = 'receiveIndexes';
}
