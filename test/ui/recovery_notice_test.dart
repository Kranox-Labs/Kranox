import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/ui/copy.dart';
import 'package:kranox_wallet/ui/theme/kranox_theme.dart';
import 'package:kranox_wallet/ui/theme/palette.dart';
import 'package:kranox_wallet/ui/widgets/recovery_notice.dart';

void main() {
  Future<void> show(WidgetTester tester, {String? settingsFile, String? swapsFile, VoidCallback? onDismiss}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KranoxTheme.build(Palette.of(activeLook)),
        home: Scaffold(
          body: RecoveryNotice(settingsFile: settingsFile, swapsFile: swapsFile, onDismiss: onDismiss ?? () {}),
        ),
      ),
    );
  }

  testWidgets('names each file that the start moved aside, by its name alone, and closes on the button', (
    tester,
  ) async {
    var closed = 0;
    await show(
      tester,
      settingsFile: '/Users/someone/Library/Containers/app/settings.json.unreadable-1791400000000',
      swapsFile: '/Users/someone/Library/Containers/app/bridge.json.unreadable-1791400000001',
      onDismiss: () => closed++,
    );
    expect(find.text(Copy.recoveryTitle), findsOneWidget);
    expect(find.text(Copy.recoverySettings('settings.json.unreadable-1791400000000')), findsOneWidget);
    expect(find.text(Copy.recoverySwaps('bridge.json.unreadable-1791400000001')), findsOneWidget);
    expect(find.text(Copy.recoveryWalletsSafe), findsOneWidget);

    await tester.tap(find.text(Copy.recoveryDismiss));
    expect(closed, 1);
  });

  testWidgets('says nothing of the settings when only the file of the swaps moved aside', (tester) async {
    await show(tester, swapsFile: '/tmp/bridge.json.unreadable-2');
    expect(find.text(Copy.recoverySwaps('bridge.json.unreadable-2')), findsOneWidget);
    expect(find.textContaining('could not read its settings'), findsNothing);
  });
}
