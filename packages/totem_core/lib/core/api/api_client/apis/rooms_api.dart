// GENERATED CODE - DO NOT MODIFY BY HAND

import 'dart:async';
import 'dart:convert';

import 'package:degenerate_runtime/degenerate_runtime.dart';

import '../models/admission_command_response.dart';
import '../models/admission_me_snapshot.dart';
import '../models/admission_request_input.dart';
import '../models/admission_snapshot.dart';
import '../models/attempt_receipt_input.dart';
import '../models/batch_command_input.dart';
import '../models/decline_input.dart';
import '../models/error_schema.dart';
import '../models/event_request.dart';
import '../models/join_response.dart';
import '../models/join_room_request.dart';
import '../models/keeper_decision_input.dart';
import '../models/membership_command_input.dart';
import '../models/remove_participant_payload.dart';
import '../models/remove_reason.dart';
import '../models/room_error_response.dart';
import '../models/room_state.dart';
import '../models/settings_command_input.dart';

/// RoomsApi operations.
///
/// All operations return [ApiResult] - use pattern matching to handle
/// success, error, and exception cases.
final class RoomsApi with ApiExecutor {
  const RoomsApi(this.apiConfig);

  @override
  final ApiConfig apiConfig;

  /// Submit a state transition event
  ///
  /// All state mutations go through this endpoint. The server validates the transition, persists it, and broadcasts the new state to LiveKit.
  ///
  /// `POST /api/mobile/protected/rooms/{session_slug}/event`
  Future<ApiResult<RoomState, RoomErrorResponse>> totemRoomsApiPostEvent({
    required String sessionSlug,
    required EventRequest body,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};
    headers['Content-Type'] = 'application/json';

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/event',
      headers: headers,
      body: jsonEncode(body.toJson()),
      options: options,
    );

    return await execute(
      request,
      onSuccess: (response) {
        final json = jsonDecode(response.body);
        return RoomState.fromJson(json as Map<String, dynamic>);
      },
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 500:
            final json = jsonDecode(response.body);
            return RoomErrorResponse.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Get current room state
  ///
  /// Returns the current state snapshot. Used by clients on reconnect or as a fallback poll when LiveKit data messages may have been missed.
  ///
  /// `GET /api/mobile/protected/rooms/{session_slug}/state`
  Future<ApiResult<RoomState, RoomErrorResponse>> totemRoomsApiGetState({
    required String sessionSlug,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};

    final request = ApiRequest(
      method: 'GET',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/state',
      headers: headers,
      options: options,
    );

    return await execute(
      request,
      onSuccess: (response) {
        final json = jsonDecode(response.body);
        return RoomState.fromJson(json as Map<String, dynamic>);
      },
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 500:
            final json = jsonDecode(response.body);
            return RoomErrorResponse.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Reconcile room state
  ///
  /// Keeper-only command that reconciles room state with connected LiveKit participants and broadcasts the resulting state.
  ///
  /// `POST /api/mobile/protected/rooms/{session_slug}/state/reconcile`
  Future<ApiResult<RoomState, RoomErrorResponse>> totemRoomsApiReconcileRoom({
    required String sessionSlug,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/state/reconcile',
      headers: headers,
      options: options,
    );

    return await execute(
      request,
      onSuccess: (response) {
        final json = jsonDecode(response.body);
        return RoomState.fromJson(json as Map<String, dynamic>);
      },
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 500:
            final json = jsonDecode(response.body);
            return RoomErrorResponse.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Join a session room
  ///
  /// Returns a LiveKit access token. Creates the Room if needed.
  ///
  /// `POST /api/mobile/protected/rooms/{session_slug}/join`
  Future<ApiResult<JoinResponse, RoomErrorResponse>> totemRoomsApiJoinRoom({
    required String sessionSlug,
    JoinRoomRequest? body,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};
    headers['Content-Type'] = 'application/json';

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/join',
      headers: headers,
      body: jsonEncode(body?.toJson()),
      options: options,
    );

    return await execute(
      request,
      onSuccess: (response) {
        final json = jsonDecode(response.body);
        return JoinResponse.fromJson(json as Map<String, dynamic>);
      },
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 500:
            final json = jsonDecode(response.body);
            return RoomErrorResponse.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Mute a participant
  ///
  /// Keeper mutes a specific participant's audio.
  ///
  /// `POST /api/mobile/protected/rooms/{session_slug}/mute/{participant_identity}`
  Future<ApiResult<void, RoomErrorResponse>> totemRoomsApiMute({
    required String sessionSlug,
    required String participantIdentity,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/mute/${Uri.encodeComponent(participantIdentity)}',
      headers: headers,
      options: options,
    );

    return await execute(
      request,
      onSuccess: (_) {},
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 500:
            final json = jsonDecode(response.body);
            return RoomErrorResponse.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Disable a participant's camera
  ///
  /// Keeper disables a specific participant's camera.
  ///
  /// `POST /api/mobile/protected/rooms/{session_slug}/disable-camera/{participant_identity}`
  Future<ApiResult<void, RoomErrorResponse>> totemRoomsApiDisableCamera({
    required String sessionSlug,
    required String participantIdentity,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/disable-camera/${Uri.encodeComponent(participantIdentity)}',
      headers: headers,
      options: options,
    );

    return await execute(
      request,
      onSuccess: (_) {},
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 500:
            final json = jsonDecode(response.body);
            return RoomErrorResponse.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Mute all participants
  ///
  /// Keeper mutes everyone except themselves.
  ///
  /// `POST /api/mobile/protected/rooms/{session_slug}/mute-all`
  Future<ApiResult<void, RoomErrorResponse>> totemRoomsApiMuteAll({
    required String sessionSlug,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/mute-all',
      headers: headers,
      options: options,
    );

    return await execute(
      request,
      onSuccess: (_) {},
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 500:
            final json = jsonDecode(response.body);
            return RoomErrorResponse.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Remove a participant
  ///
  /// Emits a remove event to a specific participant
  ///
  /// `POST /api/mobile/protected/rooms/{session_slug}/remove/{participant_identity}`
  Future<ApiResult<RemoveParticipantPayload, RoomErrorResponse>>
  totemRoomsApiRemove({
    required String sessionSlug,
    required String participantIdentity,
    RemoveReason? reason,
    RequestOptions? options,
  }) async {
    final queryParameters = <String, String>{
      ...apiConfig.defaultQueryParameters,
    };
    final queryParametersList = <ApiQueryParameter>[];
    if (reason != null) {
      queryParameters['reason'] = reason.toJson();
    }

    final headers = <String, String>{...apiConfig.defaultHeaders};

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/remove/${Uri.encodeComponent(participantIdentity)}',
      headers: headers,
      queryParameters: queryParameters,
      queryParametersList: queryParametersList,
      options: options,
    );

    return await execute(
      request,
      onSuccess: (response) {
        final json = jsonDecode(response.body);
        return RemoveParticipantPayload.fromJson(json as Map<String, dynamic>);
      },
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 500:
            final json = jsonDecode(response.body);
            return RoomErrorResponse.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Request Admission
  ///
  /// `POST /api/mobile/protected/rooms/{session_slug}/admission/request`
  Future<ApiResult<AdmissionMeSnapshot, ErrorSchema>>
  totemRoomsAdmissionApiRequestAdmission({
    required String sessionSlug,
    required AdmissionRequestInput body,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};
    headers['Content-Type'] = 'application/json';

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/admission/request',
      headers: headers,
      body: jsonEncode(body.toJson()),
      options: options,
    );

    return await execute(
      request,
      onSuccess: (response) {
        final json = jsonDecode(response.body);
        return AdmissionMeSnapshot.fromJson(json as Map<String, dynamic>);
      },
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 503 || 504:
            final json = jsonDecode(response.body);
            return ErrorSchema.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Get Admission
  ///
  /// `GET /api/mobile/protected/rooms/{session_slug}/admission`
  Future<ApiResult<AdmissionSnapshot, ErrorSchema>>
  totemRoomsAdmissionApiGetAdmission({
    required String sessionSlug,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};

    final request = ApiRequest(
      method: 'GET',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/admission',
      headers: headers,
      options: options,
    );

    return await execute(
      request,
      onSuccess: (response) {
        final json = jsonDecode(response.body);
        return AdmissionSnapshot.fromJson(json as Map<String, dynamic>);
      },
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 503 || 504:
            final json = jsonDecode(response.body);
            return ErrorSchema.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Get My Admission
  ///
  /// `GET /api/mobile/protected/rooms/{session_slug}/admission/me`
  Future<ApiResult<AdmissionMeSnapshot, ErrorSchema>>
  totemRoomsAdmissionApiGetMyAdmission({
    required String sessionSlug,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};

    final request = ApiRequest(
      method: 'GET',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/admission/me',
      headers: headers,
      options: options,
    );

    return await execute(
      request,
      onSuccess: (response) {
        final json = jsonDecode(response.body);
        return AdmissionMeSnapshot.fromJson(json as Map<String, dynamic>);
      },
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 503 || 504:
            final json = jsonDecode(response.body);
            return ErrorSchema.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Admit All
  ///
  /// `POST /api/mobile/protected/rooms/{session_slug}/admission/admit-all`
  Future<ApiResult<AdmissionCommandResponse, ErrorSchema>>
  totemRoomsAdmissionApiAdmitAll({
    required String sessionSlug,
    required BatchCommandInput body,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};
    headers['Content-Type'] = 'application/json';

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/admission/admit-all',
      headers: headers,
      body: jsonEncode(body.toJson()),
      options: options,
    );

    return await execute(
      request,
      onSuccess: (response) {
        final json = jsonDecode(response.body);
        return AdmissionCommandResponse.fromJson(json as Map<String, dynamic>);
      },
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 503 || 504:
            final json = jsonDecode(response.body);
            return ErrorSchema.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Activate Admission
  ///
  /// `POST /api/mobile/protected/rooms/{session_slug}/admission/activated`
  Future<ApiResult<AdmissionMeSnapshot, ErrorSchema>>
  totemRoomsAdmissionApiActivateAdmission({
    required String sessionSlug,
    required AttemptReceiptInput body,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};
    headers['Content-Type'] = 'application/json';

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/admission/activated',
      headers: headers,
      body: jsonEncode(body.toJson()),
      options: options,
    );

    return await execute(
      request,
      onSuccess: (response) {
        final json = jsonDecode(response.body);
        return AdmissionMeSnapshot.fromJson(json as Map<String, dynamic>);
      },
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 503 || 504:
            final json = jsonDecode(response.body);
            return ErrorSchema.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Cancel Admission
  ///
  /// `POST /api/mobile/protected/rooms/{session_slug}/admission/cancel`
  Future<ApiResult<AdmissionMeSnapshot, ErrorSchema>>
  totemRoomsAdmissionApiCancelAdmission({
    required String sessionSlug,
    required AttemptReceiptInput body,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};
    headers['Content-Type'] = 'application/json';

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/admission/cancel',
      headers: headers,
      body: jsonEncode(body.toJson()),
      options: options,
    );

    return await execute(
      request,
      onSuccess: (response) {
        final json = jsonDecode(response.body);
        return AdmissionMeSnapshot.fromJson(json as Map<String, dynamic>);
      },
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 503 || 504:
            final json = jsonDecode(response.body);
            return ErrorSchema.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Update Settings
  ///
  /// `PATCH /api/mobile/protected/rooms/{session_slug}/admission/settings`
  Future<ApiResult<AdmissionCommandResponse, ErrorSchema>>
  totemRoomsAdmissionApiUpdateSettings({
    required String sessionSlug,
    required SettingsCommandInput body,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};
    headers['Content-Type'] = 'application/json';

    final request = ApiRequest(
      method: 'PATCH',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/admission/settings',
      headers: headers,
      body: jsonEncode(body.toJson()),
      options: options,
    );

    return await execute(
      request,
      onSuccess: (response) {
        final json = jsonDecode(response.body);
        return AdmissionCommandResponse.fromJson(json as Map<String, dynamic>);
      },
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 503 || 504:
            final json = jsonDecode(response.body);
            return ErrorSchema.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Approve
  ///
  /// `POST /api/mobile/protected/rooms/{session_slug}/admission/{identity}/approve`
  Future<ApiResult<AdmissionCommandResponse, ErrorSchema>>
  totemRoomsAdmissionApiApprove({
    required String sessionSlug,
    required String identity,
    required KeeperDecisionInput body,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};
    headers['Content-Type'] = 'application/json';

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/admission/${Uri.encodeComponent(identity)}/approve',
      headers: headers,
      body: jsonEncode(body.toJson()),
      options: options,
    );

    return await execute(
      request,
      onSuccess: (response) {
        final json = jsonDecode(response.body);
        return AdmissionCommandResponse.fromJson(json as Map<String, dynamic>);
      },
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 503 || 504:
            final json = jsonDecode(response.body);
            return ErrorSchema.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Decline
  ///
  /// `POST /api/mobile/protected/rooms/{session_slug}/admission/{identity}/decline`
  Future<ApiResult<AdmissionCommandResponse, ErrorSchema>>
  totemRoomsAdmissionApiDecline({
    required String sessionSlug,
    required String identity,
    required DeclineInput body,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};
    headers['Content-Type'] = 'application/json';

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/admission/${Uri.encodeComponent(identity)}/decline',
      headers: headers,
      body: jsonEncode(body.toJson()),
      options: options,
    );

    return await execute(
      request,
      onSuccess: (response) {
        final json = jsonDecode(response.body);
        return AdmissionCommandResponse.fromJson(json as Map<String, dynamic>);
      },
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 503 || 504:
            final json = jsonDecode(response.body);
            return ErrorSchema.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Allow
  ///
  /// `POST /api/mobile/protected/rooms/{session_slug}/admission/{identity}/allow`
  Future<ApiResult<AdmissionCommandResponse, ErrorSchema>>
  totemRoomsAdmissionApiAllow({
    required String sessionSlug,
    required String identity,
    required MembershipCommandInput body,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};
    headers['Content-Type'] = 'application/json';

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/admission/${Uri.encodeComponent(identity)}/allow',
      headers: headers,
      body: jsonEncode(body.toJson()),
      options: options,
    );

    return await execute(
      request,
      onSuccess: (response) {
        final json = jsonDecode(response.body);
        return AdmissionCommandResponse.fromJson(json as Map<String, dynamic>);
      },
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 503 || 504:
            final json = jsonDecode(response.body);
            return ErrorSchema.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }

  /// Revoke
  ///
  /// `POST /api/mobile/protected/rooms/{session_slug}/admission/{identity}/revoke`
  Future<ApiResult<AdmissionCommandResponse, ErrorSchema>>
  totemRoomsAdmissionApiRevoke({
    required String sessionSlug,
    required String identity,
    required MembershipCommandInput body,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};
    headers['Content-Type'] = 'application/json';

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/rooms/${Uri.encodeComponent(sessionSlug)}/admission/${Uri.encodeComponent(identity)}/revoke',
      headers: headers,
      body: jsonEncode(body.toJson()),
      options: options,
    );

    return await execute(
      request,
      onSuccess: (response) {
        final json = jsonDecode(response.body);
        return AdmissionCommandResponse.fromJson(json as Map<String, dynamic>);
      },
      onError: (response) {
        switch (response.statusCode) {
          case 400 || 403 || 404 || 409 || 503 || 504:
            final json = jsonDecode(response.body);
            return ErrorSchema.fromJson(json as Map<String, dynamic>);
          default:
            return null;
        }
      },
    );
  }
}
