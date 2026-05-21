import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/main.dart' as app;
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/shared/router.dart';

import '../../totem_core/test/auth/controllers/auth_controller_mock.dart';
import '../../totem_core/test/setup.dart';

void main() {
  setUpAll(() async {
    setupDotenv();
    await setupFirebase();
    TotemRouter.instance = AppTotemRouter();
  });

  testWidgets('App builds smoke test', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(AuthState.unauthenticated()),
          ),
        ],
        child: app.TotemApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(app.TotemApp), findsOneWidget);
  });
}
