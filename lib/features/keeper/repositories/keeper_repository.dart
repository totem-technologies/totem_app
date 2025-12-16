import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/core/services/repository_utils.dart';

part 'keeper_repository.g.dart';

@riverpod
Future<KeeperProfileSchema> keeperProfile(Ref ref, String slug) async {
  final apiService = ref.watch(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<KeeperProfileSchema>(
    apiCall: () => apiService.users.totemUsersMobileApiKeeper(slug: slug),
    operationName: 'get keeper profile',
  );
}
