import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/permissions/adapters/media_permission_adapter.dart';
import 'package:totem_core/features/permissions/media_permission_controller.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/permissions/ui/priming_sheet.dart';

import '../../setup.dart';
import 'fake_media_permission_adapter.dart';

void main() {
  setUpAll(setupAppConfig);

  Future<FakeMediaPermissionAdapter> pumpSheet(
    WidgetTester tester, {
    MediaPermission microphone = MediaPermission.unknown,
    MediaPermission? requestResult,
    PlatformInfo platform = const IosApp(),
  }) async {
    final adapter = FakeMediaPermissionAdapter(
      camera: MediaPermission.unknown,
      microphone: microphone,
      requestResults: {MediaKind.microphone: ?requestResult},
    );
    final container = ProviderContainer(
      overrides: [
        platformInfoProvider.overrideWithValue(platform),
        mediaPermissionAdapterProvider.overrideWithValue(adapter),
      ],
    );
    addTearDown(container.dispose);
    await container.read(mediaPermissionControllerProvider.notifier).refresh();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: MediaPrimingSheet())),
      ),
    );
    return adapter;
  }

  testWidgets("X2: the sheet's main action asks for the microphone", (
    tester,
  ) async {
    final adapter = await pumpSheet(
      tester,
      requestResult: MediaPermission.granted,
    );
    check(find.text('Not now').evaluate()).length.equals(1);

    await tester.tap(find.text('Allow microphone'));
    await tester.pumpAndSettle();

    check(adapter.requested).deepEquals([MediaKind.microphone]);
    check(find.text('Continue').evaluate()).length.equals(1);
    check(find.text('Not now').evaluate()).isEmpty();
  });

  testWidgets('A2: once the OS stops asking, the main action opens Settings', (
    tester,
  ) async {
    final adapter = await pumpSheet(
      tester,
      microphone: MediaPermission.denied,
      requestResult: MediaPermission.blocked,
      platform: const AndroidApp(),
    );

    await tester.tap(find.text('Allow microphone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    check(adapter.settingsOpened).equals(1);
    check(find.text('Not now').evaluate()).length.equals(1);
  });
}
