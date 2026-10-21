import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_keeper_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';

class MockSessionKeeperController extends Mock
    implements SessionKeeperController {}

class MockSessionMessagingController extends Mock
    implements SessionMessagingController {}

class MockSessionRoomState extends Mock implements SessionRoomState {}

class MockParticipant extends Mock implements Participant {}
