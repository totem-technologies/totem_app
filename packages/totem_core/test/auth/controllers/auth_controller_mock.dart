import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/models/auth_state.dart';

class FakeAuthController extends AuthController {
  FakeAuthController(this.fakeState);

  final AuthState fakeState;

  @override
  AuthState build() => fakeState;
}
