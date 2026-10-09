import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/config/app_config.dart';
import 'package:kranox_wallet/ui/copy.dart';
import 'package:kranox_wallet/ui/format.dart';

void main() {
  test('takes a new password of 12 characters or more, repeated the same (O-004)', () {
    expect(AppConfig.minPasswordLength, 12);
    expect(passwordProblem('eleven-char', 'eleven-char'), Copy.passwordTooShort(12));
    expect(passwordProblem('twelve-chars', 'twelve-chars'), isNull);
    expect(passwordProblem('twelve-chars', 'twelve-charz'), Copy.passwordMismatch);
  });
}
