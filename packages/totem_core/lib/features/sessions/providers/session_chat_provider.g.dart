// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_chat_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Read-only projection; messages live only in SessionChatService.

@ProviderFor(sessionChatMessages)
final sessionChatMessagesProvider = SessionChatMessagesFamily._();

/// Read-only projection; messages live only in SessionChatService.

final class SessionChatMessagesProvider
    extends
        $FunctionalProvider<
          List<SessionChatMessage>,
          List<SessionChatMessage>,
          List<SessionChatMessage>
        >
    with $Provider<List<SessionChatMessage>> {
  /// Read-only projection; messages live only in SessionChatService.
  SessionChatMessagesProvider._({
    required SessionChatMessagesFamily super.from,
    required SessionController super.argument,
  }) : super(
         retry: null,
         name: r'sessionChatMessagesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionChatMessagesHash();

  @override
  String toString() {
    return r'sessionChatMessagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<SessionChatMessage>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<SessionChatMessage> create(Ref ref) {
    final argument = this.argument as SessionController;
    return sessionChatMessages(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SessionChatMessage> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SessionChatMessage>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SessionChatMessagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionChatMessagesHash() =>
    r'15ee6f262e9addc4c7e5a70f1c825d35535b8b6d';

/// Read-only projection; messages live only in SessionChatService.

final class SessionChatMessagesFamily extends $Family
    with
        $FunctionalFamilyOverride<List<SessionChatMessage>, SessionController> {
  SessionChatMessagesFamily._()
    : super(
        retry: null,
        name: r'sessionChatMessagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Read-only projection; messages live only in SessionChatService.

  SessionChatMessagesProvider call(SessionController session) =>
      SessionChatMessagesProvider._(argument: session, from: this);

  @override
  String toString() => r'sessionChatMessagesProvider';
}
