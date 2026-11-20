/// Observes an existing signaling connection without owning it or its tracks.
abstract class ServerAdmissionConnection {
  bool get isConnected;
  bool get hasMediaPermissions;
  String get localSid;
  bool isPresent(String identity);
  Stream<ServerAdmissionConnectionEvent> get admissionEvents;
  Future<void> dispose();
}

enum ServerAdmissionConnectionEvent {
  permissionsChanged,
  reconnected,
  disconnected,
  terminated,
  notification,
  presenceChanged,
}
