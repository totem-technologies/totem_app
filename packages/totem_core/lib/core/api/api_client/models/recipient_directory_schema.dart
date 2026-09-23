// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'keeper_recipient_schema.dart';
import 'participant_recipient_schema.dart';
import 'recipient_directory_kind.dart';

/// The first ordered keepers page is the recommendation source.
@immutable
final class RecipientDirectorySchema {
  const RecipientDirectorySchema({
    required this.kind,
    required this.keepers,
    required this.participants,
    required this.nextCursor,
  });

  factory RecipientDirectorySchema.fromJson(Map<String, dynamic> json) {
    return RecipientDirectorySchema(
      kind: RecipientDirectoryKind.fromJson(json['kind'] as String),
      keepers: (json['keepers'] as List<dynamic>)
          .map((e) => KeeperRecipientSchema.fromJson(e as Map<String, dynamic>))
          .toList(),
      participants: (json['participants'] as List<dynamic>)
          .map(
            (e) =>
                ParticipantRecipientSchema.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      nextCursor: json['next_cursor'] as String?,
    );
  }

  final RecipientDirectoryKind kind;

  final List<KeeperRecipientSchema> keepers;

  final List<ParticipantRecipientSchema> participants;

  final String? nextCursor;

  Map<String, dynamic> toJson() {
    return {
      'kind': kind.toJson(),
      'keepers': keepers.map((e) => e.toJson()).toList(),
      'participants': participants.map((e) => e.toJson()).toList(),
      'next_cursor': ?nextCursor,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('kind') &&
        json.containsKey('keepers') &&
        json.containsKey('participants') &&
        json.containsKey('next_cursor') &&
        json['next_cursor'] is String;
  }

  RecipientDirectorySchema copyWith({
    RecipientDirectoryKind? kind,
    List<KeeperRecipientSchema>? keepers,
    List<ParticipantRecipientSchema>? participants,
    String? Function()? nextCursor,
  }) {
    return RecipientDirectorySchema(
      kind: kind ?? this.kind,
      keepers: keepers ?? this.keepers,
      participants: participants ?? this.participants,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RecipientDirectorySchema &&
            kind == other.kind &&
            listEquals(keepers, other.keepers) &&
            listEquals(participants, other.participants) &&
            nextCursor == other.nextCursor;
  }

  @override
  int get hashCode {
    return Object.hash(
      kind,
      Object.hashAll(keepers),
      Object.hashAll(participants),
      nextCursor,
    );
  }

  @override
  String toString() {
    return 'RecipientDirectorySchema(kind: $kind, keepers: $keepers, participants: $participants, nextCursor: $nextCursor)';
  }
}
