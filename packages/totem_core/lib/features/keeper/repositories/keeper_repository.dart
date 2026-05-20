import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/core/services/repository_utils.dart';

part 'keeper_repository.g.dart';

// Disable automatic retry for this provider.
Duration? _noRetry(int retryCount, Object error) => null;

@Riverpod(retry: _noRetry)
Future<KeeperProfileSchema> keeperProfile(Ref ref, String slug) async {
  final apiService = ref.read(apiServiceProvider);
  return RepositoryUtils.handleApiCall<KeeperProfileSchema>(
    apiCall: () => apiService.users.totemUsersMobileApiKeeper(slug: slug),
    operationName: 'get keeper profile',
  );
}
