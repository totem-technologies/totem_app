/// Orders reads and writes across provider instances sharing a storage key.
/// Completed entries retain neither preferences nor session owners.
class AdmissionStorageQueue {
  static final _tails = <String, Future<void>>{};

  static Future<T> run<T>(String key, Future<T> Function() action) {
    final previous = _tails[key] ?? Future<void>.value();
    final operation = previous.then((_) => action());
    late final Future<void> settled;
    settled = operation
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() {
          if (identical(_tails[key], settled)) _tails.remove(key);
        });
    _tails[key] = settled;
    return operation;
  }
}
