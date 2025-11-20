import 'package:totem_app/api/models/event_detail_schema.dart';

extension ListExtension<T> on List<T> {
  List<T> reversedIf(bool condition) {
    return condition ? reversed.toList() : this;
  }
}

extension StringExtension on String {
  String uppercaseFirst() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

extension EventDetailSchemaExtension on EventDetailSchema {
  static const Duration joinBeforeTime = Duration(minutes: 10);
  bool get canJoinNow => start.isAfter(DateTime.now().subtract(joinBeforeTime));
}
