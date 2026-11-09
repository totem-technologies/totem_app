import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_app/widgets/update_alert.dart';
import 'package:totem_core/shared/widgets/update_available_dialog.dart';
import 'package:upgrader/upgrader.dart';

class _FakeUpgrader extends Upgrader {
  _FakeUpgrader({this.isBlocked = false, this.shouldDisplay = false});

  final bool isBlocked;
  final bool shouldDisplay;
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
  bool shouldDisplayUpgrade() => shouldDisplay;

  @override
  String body(UpgraderMessages messages) => 'A new version is available.';

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
  group('hasMajorOrMinorVersionUpdate', () {
    test('prompts when the major or minor version changes', () {
      check(hasMajorOrMinorVersionUpdate('0.0.1', '0.1.0')).isTrue();
      check(hasMajorOrMinorVersionUpdate('0.1.10', '0.2.0')).isTrue();
      check(hasMajorOrMinorVersionUpdate('1.4.2', '1.5.0')).isTrue();
    });

    test('does not prompt for patch-only changes', () {
      check(hasMajorOrMinorVersionUpdate('0.1.10', '0.1.11')).isFalse();
      check(hasMajorOrMinorVersionUpdate('1.4.2', '2.4.0')).isTrue();
    });

    test('does not prompt when either version is unavailable or invalid', () {
      check(hasMajorOrMinorVersionUpdate(null, '0.1.0')).isFalse();
      check(hasMajorOrMinorVersionUpdate('0.1.0', 'invalid')).isFalse();
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
            messages: TotemUpgraderMessages(),
          );
      await tester.pumpAndSettle();
    }

    Finder button<T extends Widget>(String text) =>
        find.widgetWithText(T, text);

    testWidgets('does not reinitialize the upgrader on rebuild', (
      tester,
    ) async {
      final upgrader = _FakeUpgrader();
      await tester.pumpWidget(
        _Host(upgrader: upgrader, navigatorKey: navigatorKey),
      );
      await tester.pumpAndSettle();

      check(upgrader.initializeCount).equals(1);

      tester.state<_HostState>(find.byType(_Host)).replacePage('home');
      await tester.pumpAndSettle();

      check(upgrader.initializeCount).equals(1);
    });

    testWidgets('shows through checkVersion on the inner Navigator', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Host(
          upgrader: _FakeUpgrader(shouldDisplay: true),
          navigatorKey: navigatorKey,
        ),
      );
      tester
          .state<UpgradeAlertState>(find.byType(TotemUpgradeAlert))
          .checkVersion(
            context: tester.element(find.byType(TotemUpgradeAlert)),
          );
      await tester.pumpAndSettle();

      final dialog = find.byType(UpdateAvailableDialog);
      check(tester.widgetList(dialog)).length.equals(1);
      final navigator = find
          .ancestor(of: dialog, matching: find.byType(Navigator))
          .first;
      check(
        identical(tester.state(navigator), navigatorKey.currentState),
      ).isTrue();
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
        tester.widgetList(button<ElevatedButton>('Update')),
      ).length.equals(1);
      check(
        tester.widgetList(button<OutlinedButton>('Later')),
      ).length.equals(1);
      check(tester.widgetList(find.text('IGNORE'))).isEmpty();
      check(tester.widgetList(find.text('Update available'))).length.equals(1);
      check(
        tester
            .widgetList(
              find.text(
                'A newer version of Totem is available. Update to get the latest '
                'fixes and improvements.',
              ),
            )
            .length,
      ).equals(1);
      check(
        tester.widgetList(find.text('Would you like to update now?')),
      ).length.equals(1);
    });

    testWidgets('Update sends to the store and closes when not blocked', (
      tester,
    ) async {
      final upgrader = _FakeUpgrader();
      await pumpAndShow(tester, upgrader);

      await tester.tap(button<ElevatedButton>('Update'));
      await tester.pumpAndSettle();

      check(upgrader.sentToStore).equals(1);
      check(tester.widgetList(find.byType(UpdateAvailableDialog))).isEmpty();
    });

    testWidgets('blocked update hides Later and stays open', (tester) async {
      final upgrader = _FakeUpgrader(isBlocked: true);
      await pumpAndShow(tester, upgrader);

      check(tester.widgetList(button<OutlinedButton>('Later'))).isEmpty();

      await tester.tap(button<ElevatedButton>('Update'));
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

      await tester.tap(button<OutlinedButton>('Later'));
      await tester.pumpAndSettle();
      tester.state<_HostState>(find.byType(_Host)).replacePage('home');
      await tester.pumpAndSettle();

      check(tester.widgetList(find.byType(UpdateAvailableDialog))).isEmpty();
    });
  });
}
