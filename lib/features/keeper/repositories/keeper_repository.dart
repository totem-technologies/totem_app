import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/core/services/repository_utils.dart';

part 'keeper_repository.g.dart';

// Disable automatic retry for this provider.
Duration? _noRetry(int retryCount, Object error) => null;

@Riverpod(retry: _noRetry)
Future<KeeperProfileSchema> keeperProfile(Ref ref, String slug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<KeeperProfileSchema>(
    apiCall: () => apiService.users.totemUsersMobileApiKeeper(slug: slug),
    operationName: 'get keeper profile',
  );
}
