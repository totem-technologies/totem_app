import 'package:livekit_client/livekit_client.dart';

bool isSessionErrorShownInline(Object error) =>
    error is ConnectException ||
    error is MediaConnectException ||
    error is UnexpectedStateException ||
    error is NegotiationError ||
    error is TrackCreateException ||
    error is TrackPublishException;
