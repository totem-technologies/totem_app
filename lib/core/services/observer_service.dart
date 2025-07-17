import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/shared/logger.dart';

class ObserverService extends ProviderObserver {
  @override
  void didAddProvider(
    ProviderObserverContext context,
    Object? value,
  ) {
    logger.d('Provider ${context.provider.name} was initialized with $value');
  }

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    logger.d('Provider ${context.provider.name} was disposed');
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    logger.d(
      'Provider ${context.provider.name} updated from ''$previousValue to ''$newValue',
    );
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    logger.d(
      'Provider ${context.provider.name} threw an error.',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
