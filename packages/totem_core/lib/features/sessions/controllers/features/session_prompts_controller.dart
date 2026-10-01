import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/api_service.dart';

part 'session_prompts_controller.g.dart';

enum SessionPromptsFailure { conflict, validation, network, unexpected }

class SessionPromptsState {
  const SessionPromptsState({
    this.snapshot,
    this.loading = false,
    this.mutating = false,
    this.failure,
    this.message,
  });

  final SessionPromptsSchema? snapshot;
  final bool loading;
  final bool mutating;
  final SessionPromptsFailure? failure;
  final String? message;

  List<SessionPromptSchema> get prompts => snapshot?.prompts ?? const [];
  int? get revision => snapshot?.revision;

  SessionPromptsState copyWith({
    SessionPromptsSchema? snapshot,
    bool? loading,
    bool? mutating,
    SessionPromptsFailure? Function()? failure,
    String? Function()? message,
  }) {
    return SessionPromptsState(
      snapshot: snapshot ?? this.snapshot,
      loading: loading ?? this.loading,
      mutating: mutating ?? this.mutating,
      failure: failure != null ? failure() : this.failure,
      message: message != null ? message() : this.message,
    );
  }
}

/// The sole client-side owner of a session's prepared-prompt collection.
///
/// It is deliberately kept alive: an HTTP mutation belongs to the session, not
/// to the transient modal that started it.
@Riverpod(keepAlive: true)
class SessionPromptsController extends _$SessionPromptsController {
  var _generation = 0;

  @override
  SessionPromptsState build(String sessionSlug) {
    unawaited(Future<void>.microtask(refresh));
    return const SessionPromptsState(loading: true);
  }

  Future<void> refresh() async {
    final generation = _generation;
    state = state.copyWith(
      loading: state.snapshot == null,
      failure: () => null,
      message: () => null,
    );
    try {
      final response = await ref
          .read(apiServiceProvider)
          .spaces
          .totemSpacesMobileApiGetSessionPrompts(eventSlug: sessionSlug);
      final snapshot = response.dataOrThrow;
      if (generation != _generation) return;
      state = SessionPromptsState(snapshot: snapshot);
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        loading: false,
        failure: () => _failureFor(error),
        message: () => _messageFor(error),
      );
    }
  }

  Future<void> addPrompt(String text) => _mutate(
    (prompts) => [
      ..._updates(prompts),
      SessionPromptUpdateSchema(prompt: text),
    ],
  );

  Future<void> editPrompt(int id, String text) => _mutate(
    (prompts) => [
      for (final prompt in prompts)
        SessionPromptUpdateSchema(
          id: Omittable(prompt.id),
          prompt: prompt.id == id ? text : prompt.prompt,
        ),
    ],
  );

  Future<void> deletePrompt(int id) => _mutate(
    (prompts) => [
      for (final prompt in prompts)
        if (prompt.id != id)
          SessionPromptUpdateSchema(
            id: Omittable(prompt.id),
            prompt: prompt.prompt,
          ),
    ],
  );

  /// Moves [id] to [newIndex] using current state when the operation begins.
  Future<void> reorderPrompt(int id, int newIndex) => _mutate((prompts) {
    final reordered = [...prompts];
    final oldIndex = reordered.indexWhere((prompt) => prompt.id == id);
    if (oldIndex < 0 || newIndex < 0 || newIndex >= reordered.length) {
      return _updates(reordered);
    }
    final prompt = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, prompt);
    return _updates(reordered);
  });

  List<SessionPromptUpdateSchema> _updates(List<SessionPromptSchema> prompts) =>
      [
        for (final prompt in prompts)
          SessionPromptUpdateSchema(
            id: Omittable(prompt.id),
            prompt: prompt.prompt,
          ),
      ];

  Future<void> _mutate(
    List<SessionPromptUpdateSchema> Function(List<SessionPromptSchema>)
    operation,
  ) async {
    if (state.mutating || state.snapshot == null) return;

    final snapshot = state.snapshot!;
    final generation = ++_generation;
    final body = SessionPromptsUpdateSchema(
      expectedRevision: snapshot.revision,
      prompts: operation(snapshot.prompts),
    );
    state = state.copyWith(
      mutating: true,
      failure: () => null,
      message: () => null,
    );

    try {
      final response = await ref
          .read(apiServiceProvider)
          .spaces
          .totemSpacesMobileApiUpdateSessionPrompts(
            eventSlug: sessionSlug,
            body: body,
          );
      final confirmed = response.dataOrThrow;
      if (generation != _generation) return;
      state = SessionPromptsState(snapshot: confirmed);
    } on ApiError<dynamic, dynamic> catch (error) {
      if (generation != _generation) return;
      final current = error.error;
      if (current is SessionPromptsStaleRevisionSchema) {
        state = SessionPromptsState(
          snapshot: SessionPromptsSchema(
            revision: current.revision,
            prompts: current.prompts,
          ),
          failure: SessionPromptsFailure.conflict,
          message: current.messageOrDefault,
        );
      } else {
        await _recoverAfterFailure(generation, SessionPromptsFailure.conflict);
      }
    } catch (error) {
      if (generation != _generation) return;
      await _recoverAfterFailure(generation, _failureFor(error));
    }
  }

  Future<void> _recoverAfterFailure(
    int generation,
    SessionPromptsFailure failure,
  ) async {
    try {
      final response = await ref
          .read(apiServiceProvider)
          .spaces
          .totemSpacesMobileApiGetSessionPrompts(eventSlug: sessionSlug);
      if (generation != _generation) return;
      state = SessionPromptsState(
        snapshot: response.dataOrThrow,
        failure: failure,
        message: _messageForFailure(failure),
      );
    } catch (_) {
      if (generation != _generation) return;
      // Keep only the confirmed snapshot. No optimistic draft is retained.
      state = SessionPromptsState(
        snapshot: state.snapshot,
        failure: failure,
        message: '${_messageForFailure(failure)} Unable to refresh prompts.',
      );
    }
  }

  SessionPromptsFailure _failureFor(Object error) => switch (error) {
    ApiError(:final statusCode) when statusCode == 409 =>
      SessionPromptsFailure.conflict,
    ApiError(:final statusCode) when statusCode >= 400 && statusCode < 500 =>
      SessionPromptsFailure.validation,
    _ => SessionPromptsFailure.network,
  };

  String _messageFor(Object error) => _messageForFailure(_failureFor(error));

  String _messageForFailure(SessionPromptsFailure failure) => switch (failure) {
    SessionPromptsFailure.conflict =>
      'Prepared prompts changed elsewhere. Review the refreshed list and try again.',
    SessionPromptsFailure.validation => 'This prompt change is not valid.',
    SessionPromptsFailure.network =>
      'Could not save prompts. Check your connection and try again.',
    SessionPromptsFailure.unexpected => 'Could not save prompts.',
  };
}
