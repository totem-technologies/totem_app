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
