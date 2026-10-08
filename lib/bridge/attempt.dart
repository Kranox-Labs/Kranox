import 'dart:math';

import '../wallet/models.dart';

/// A creation of an exchange whose answer has not come back yet: the form that it came from, the subaddress of this
/// wallet that it named, and the key that the relay knows it by. A second try of the same form reuses the subaddress
/// and the key, so that the relay answers the exchange of the first try, if it made one, instead of a second exchange
/// (K-14 of the security review of 0.2.0).
final class CreationAttempt {
  const CreationAttempt({required this.form, required this.address, required this.key});

  final String form;
  final ReceiveAddress address;
  final String key;
}

/// The attempt for [form]: [last] when it came from the same form, otherwise a new one with a new subaddress from
/// [newAddress] and a new key from [random].
Future<CreationAttempt> attemptFor(
  String form,
  CreationAttempt? last,
  Future<ReceiveAddress> Function() newAddress,
  Random random,
) async {
  if (last != null && last.form == form) return last;
  return CreationAttempt(form: form, address: await newAddress(), key: _newKey(random));
}

/// 32 hex digits from [random].
String _newKey(Random random) =>
    [for (var i = 0; i < 16; i++) random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
