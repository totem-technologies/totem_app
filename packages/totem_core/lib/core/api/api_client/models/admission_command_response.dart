// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'admission_snapshot.dart';
import 'command_result.dart';

@immutable
final class AdmissionCommandResponse {
  const AdmissionCommandResponse({
    required this.commandId,
    required this.replayed,
    required this.results,
    required this.partialFailure,
    required this.snapshot,
  });

  factory AdmissionCommandResponse.fromJson(Map<String, dynamic> json) {
    return AdmissionCommandResponse(
      commandId: json['command_id'] as String,
      replayed: json['replayed'] as bool,
      results: (json['results'] as List<dynamic>)
          .map((e) => CommandResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      partialFailure: json['partial_failure'] as bool,
      snapshot: AdmissionSnapshot.fromJson(
        json['snapshot'] as Map<String, dynamic>,
      ),
    );
  }

  final String commandId;

  final bool replayed;

  final List<CommandResult> results;

  final bool partialFailure;

  final AdmissionSnapshot snapshot;

  Map<String, dynamic> toJson() {
    return {
      'command_id': commandId,
      'replayed': replayed,
      'results': results.map((e) => e.toJson()).toList(),
      'partial_failure': partialFailure,
      'snapshot': snapshot.toJson(),
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('command_id') &&
        json['command_id'] is String &&
        json.containsKey('replayed') &&
        json['replayed'] is bool &&
        json.containsKey('results') &&
        json.containsKey('partial_failure') &&
        json['partial_failure'] is bool &&
        json.containsKey('snapshot');
  }

  AdmissionCommandResponse copyWith({
    String? commandId,
    bool? replayed,
    List<CommandResult>? results,
    bool? partialFailure,
    AdmissionSnapshot? snapshot,
  }) {
    return AdmissionCommandResponse(
      commandId: commandId ?? this.commandId,
      replayed: replayed ?? this.replayed,
      results: results ?? this.results,
      partialFailure: partialFailure ?? this.partialFailure,
      snapshot: snapshot ?? this.snapshot,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AdmissionCommandResponse &&
            commandId == other.commandId &&
            replayed == other.replayed &&
            listEquals(results, other.results) &&
            partialFailure == other.partialFailure &&
            snapshot == other.snapshot;
  }

  @override
  int get hashCode {
    return Object.hash(
      commandId,
      replayed,
      Object.hashAll(results),
      partialFailure,
      snapshot,
    );
  }

  @override
  String toString() {
    return 'AdmissionCommandResponse(commandId: $commandId, replayed: $replayed, results: $results, partialFailure: $partialFailure, snapshot: $snapshot)';
  }
}
