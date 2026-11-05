import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_app/widgets/update_alert.dart';
import 'package:totem_core/shared/widgets/update_available_dialog.dart';
import 'package:upgrader/upgrader.dart';

class _FakeUpgrader extends Upgrader {
  _FakeUpgrader({this.isBlocked = false});

  final bool isBlocked;
  var initializeCount = 0;
  var sentToStore = 0;

  @override
  Future<bool> initialize() async {
    initializeCount++;
    return true;
  }

  @override
  bool blocked() => isBlocked;

  @override
  Future<void> sendUserToAppStore() async => sentToStore++;

  @override
  Future<bool> saveLastAlerted() async => true;
}

/// Hosts [TotemUpgradeAlert] above a pages-based Navigator, like
/// MaterialApp.router's builder does with GoRouter.
class _Host extends StatefulWidget {
  const _Host({required this.upgrader, required this.navigatorKey});

  final Upgrader upgrader;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  var page = 'splash';

  void replacePage(String next) => setState(() => page = next);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      // No home: like MaterialApp.router, the only Navigator is the one
      // below the builder, so the dialog is anchored to its pages.
      builder: (context, _) => TotemUpgradeAlert(
        upgrader: widget.upgrader,
        navigatorKey: widget.navigatorKey,
        child: Navigator(
          key: widget.navigatorKey,
          pages: [
            MaterialPage<void>(
              key: ValueKey(page),
              child: Scaffold(body: Text(page)),
            ),
          ],
          onDidRemovePage: (_) {},
        ),
      ),
    );
  }
}

void main() {
  group('hasMinorVersionUpdate', () {
    test('prompts when the second version component changes', () {
      check(hasMinorVersionUpdate('0.0.1', '0.1.0')).isTrue();
      check(hasMinorVersionUpdate('0.1.10', '0.2.0')).isTrue();
      check(hasMinorVersionUpdate('1.4.2', '1.5.0')).isTrue();
    });

    test('does not prompt for patch or first-component-only changes', () {
      check(hasMinorVersionUpdate('0.1.10', '0.1.11')).isFalse();
      check(hasMinorVersionUpdate('1.4.2', '2.4.0')).isFalse();
    });

    test('does not prompt when either version is unavailable or invalid', () {
      check(hasMinorVersionUpdate(null, '0.1.0')).isFalse();
      check(hasMinorVersionUpdate('0.1.0', 'invalid')).isFalse();
    });
  });

  group('TotemUpgradeAlert', () {
    late GlobalKey<NavigatorState> navigatorKey;

    setUp(() => navigatorKey = GlobalKey<NavigatorState>());

    Future<void> pumpAndShow(WidgetTester tester, Upgrader upgrader) async {
      await tester.pumpWidget(
        _Host(upgrader: upgrader, navigatorKey: navigatorKey),
      );
      tester
          .state<UpgradeAlertState>(find.byType(TotemUpgradeAlert))
          .showTheDialog(
            context: navigatorKey.currentContext!,
            title: 'Update available',
            message: 'A newer version is available.',
            releaseNotes: null,
            barrierDismissible: false,
            messages: UpgraderMessages(code: 'en'),
          );
      await tester.pumpAndSettle();
    }

    Finder button<T extends Widget>(String text) =>
        find.widgetWithText(T, text);

    test('keeps the same upgrader across rebuilds', () {
      final widget = TotemUpgradeAlert(child: const SizedBox());
      final rebuilt = TotemUpgradeAlert(child: const SizedBox());
      check(identical(widget.upgrader, rebuilt.upgrader)).isTrue();
    });

    testWidgets('shows Update and Later but not Ignore when not blocked', (
      tester,
    ) async {
      final upgrader = _FakeUpgrader();
      await pumpAndShow(tester, upgrader);

      check(
        tester.widgetList(find.byType(UpdateAvailableDialog)),
      ).length.equals(1);
      check(
        tester.widgetList(button<ElevatedButton>('UPDATE NOW')),
      ).length.equals(1);
      check(
        tester.widgetList(button<OutlinedButton>('LATER')),
      ).length.equals(1);
      check(tester.widgetList(find.text('IGNORE'))).isEmpty();
      check(
        tester.widgetList(find.text('Would you like to update it now?')),
      ).length.equals(1);
    });

    testWidgets('Update sends to the store and closes when not blocked', (
      tester,
    ) async {
      final upgrader = _FakeUpgrader();
      await pumpAndShow(tester, upgrader);

      await tester.tap(button<ElevatedButton>('UPDATE NOW'));
      await tester.pumpAndSettle();

      check(upgrader.sentToStore).equals(1);
      check(tester.widgetList(find.byType(UpdateAvailableDialog))).isEmpty();
    });

    testWidgets('blocked update hides Later and stays open', (tester) async {
      final upgrader = _FakeUpgrader(isBlocked: true);
      await pumpAndShow(tester, upgrader);

      check(tester.widgetList(button<OutlinedButton>('LATER'))).isEmpty();

      await tester.tap(button<ElevatedButton>('UPDATE NOW'));
      await tester.pumpAndSettle();

      check(upgrader.sentToStore).equals(1);
      check(
        tester.widgetList(find.byType(UpdateAvailableDialog)),
      ).length.equals(1);
    });

    testWidgets('reshows the dialog when the page under it is replaced', (
      tester,
    ) async {
      await pumpAndShow(tester, _FakeUpgrader());

      tester.state<_HostState>(find.byType(_Host)).replacePage('home');
      await tester.pumpAndSettle();

      check(tester.widgetList(find.text('home'))).length.equals(1);
      check(
        tester.widgetList(find.byType(UpdateAvailableDialog)),
      ).length.equals(1);
    });

    testWidgets('does not reshow after the user closes it', (tester) async {
      await pumpAndShow(tester, _FakeUpgrader());

      await tester.tap(button<OutlinedButton>('LATER'));
      await tester.pumpAndSettle();
      tester.state<_HostState>(find.byType(_Host)).replacePage('home');
      await tester.pumpAndSettle();

      check(tester.widgetList(find.byType(UpdateAvailableDialog))).isEmpty();
    });
  });
}
