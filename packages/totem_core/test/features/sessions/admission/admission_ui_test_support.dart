import 'package:flutter/foundation.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/admission/session_admission_service.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';

class AdmissionUiSession extends Mock implements SessionController {
  AdmissionUiSession(this.admission);
  @override
  final AdmissionUiService admission;
}

Participant admissionParticipant(
  String identity, {
  String? name,
  String state = 'waiting',
  String status = 'requested',
}) => Participant(
  identity: identity,
  user: PublicUserSchema(
    name: Omittable(name ?? identity),
    profileAvatarType: ProfileAvatarTypeEnum.td,
    dateCreated: DateTime.utc(2024),
  ),
  admissionState: ParticipantAdmissionState.fromJson(state),
  admissionVersion: 1,
  requestId: Omittable('request-$identity'),
  attemptId: Omittable('attempt-$identity'),
  attemptVersion: const Omittable(1),
  status: ParticipantStatus.fromJson(status),
  connectionState: ParticipantConnectionState.disconnected,
  eligible: true,
  returning: false,
  sessionStarted: false,
  lateArrival: false,
  permissionStatus: ParticipantPermissionStatus.pending,
  permissionRevision: 0,
);

AdmissionSnapshot admissionSnapshot({
  List<Participant> waiting = const [],
  List<Participant> participants = const [],
  List<Participant> attempts = const [],
  bool approvalRequired = true,
}) => AdmissionSnapshot(
  sessionSlug: 'test-session',
  keeper: 'keeper-1',
  roomVersion: 1,
  roomState: const RoomState(
    sessionSlug: 'test-session',
    version: 1,
    status: RoomStatus.active,
    turnState: TurnState.idle,
    statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
    talkingOrder: [],
    keeper: 'keeper-1',
    roundNumber: 1,
  ),
  roomStatus: RoomStatus.active,
  approvalRequired: approvalRequired,
  settingsRevision: 1,
  version: 1,
  observedAt: DateTime.utc(2026),
  admittedCount: 0,
  activatedCount: 0,
  pendingCount: waiting.length,
  participants: participants,
  waiting: waiting,
  requests: attempts,
  historyTruncated: false,
);

class AdmissionUiService extends ChangeNotifier
    implements SessionAdmissionService {
  AdmissionUiService(this.snapshot);

  @override
  AdmissionSnapshot? snapshot;
  @override
  bool mounted = true;
  @override
  bool busy = false;
  @override
  bool hasUnresolvedCommand = false;
  @override
  String? error;
  final decisions = <(Participant, bool, bool)>[];
  final allowed = <Participant>[];
  final settingCommands = <bool>[];
  int admitAllCalls = 0;
  int syncCalls = 0;
  int unresolvedRetryCalls = 0;
  Future<void> Function(Participant)? onAllow;
  Future<void> Function(bool)? onSetting;

  @override
  List<Participant> get requests => snapshot?.waiting ?? [];
  @override
  List<Participant> get attempts => snapshot?.requests ?? [];
  @override
  List<Participant> get declined =>
      snapshot?.participants
          .where(
            (p) =>
                p.admissionState ==
                ParticipantAdmissionState.permanentlyDeclined,
          )
          .toList() ??
      [];
  @override
  bool get approvalRequired => snapshot?.approvalRequired ?? true;

  void update(AdmissionSnapshot? value, {String? failure}) {
    snapshot = value;
    error = failure;
    notifyListeners();
  }

  @override
  void sync() {
    syncCalls++;
  }

  @override
  Future<bool> retryUnresolved() async {
    unresolvedRetryCalls++;
    return true;
  }

  @override
  Future<void> decide(
    Participant participant,
    bool approve, {
    bool permanently = false,
  }) async {
    decisions.add((participant, approve, permanently));
  }

  @override
  Future<bool> admitAll() async {
    admitAllCalls++;
    return true;
  }

  @override
  Future<void> allow(Participant participant) async {
    allowed.add(participant);
    await onAllow?.call(participant);
  }

  @override
  Future<void> setApprovalRequired(bool value) async {
    settingCommands.add(value);
    await onSetting?.call(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
