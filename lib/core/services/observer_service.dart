import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/shared/logger.dart';

class ObserverService extends ProviderObserver {
  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    logger.d('Provider ${provider.name} was initialized with $value');
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    logger.d('Provider ${provider.name} was disposed');
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    logger.d(
      'Provider ${provider.name} updated from $previousValue to $newValue',
    );
  }

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    logger.d(
      'Provider ${provider.name} threw an error.',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
