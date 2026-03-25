part of 'session_controller.dart';

extension DevicesControl on SessionController {
  Future<void> setupDeviceChangeListener() async {
    await _devices.setupDeviceChangeListener();
  }

  String? get selectedCameraDeviceId => _devices.selectedCameraDeviceId;

  LocalVideoTrack? get localVideoTrack => _devices.localVideoTrack;

  Future<void> switchCameraPosition() async {
    await _devices.switchCameraPosition();
  }

  LocalAudioTrack? get localAudioTrack => _devices.localAudioTrack;

  bool get isSpeakerphoneEnabled => _devices.isSpeakerphoneEnabled;

  Future<void> setSpeakerphone(bool enabled) =>
      _devices.setSpeakerphone(enabled);

  String? get selectedAudioDeviceId => _devices.selectedAudioDeviceId;

  Future<void> selectAudioDevice(MediaDevice device) =>
      _devices.selectAudioDevice(device);

  String? get selectedAudioOutputDeviceId =>
      _devices.selectedAudioOutputDeviceId;

  Future<void> selectAudioOutputDevice(MediaDevice device) =>
      _devices.selectAudioOutputDevice(device);

  bool get isMicrophoneEnabled => _devices.isMicrophoneEnabled;

  Future<void> enableMicrophone() => _devices.enableMicrophone();

  Future<void> disableMicrophone() => _devices.disableMicrophone();

  bool get isCameraEnabled => _devices.isCameraEnabled;

  Future<void> enableCamera() async {
    await _devices.enableCamera();
  }

  Future<void> disableCamera() => _devices.disableCamera();
}
