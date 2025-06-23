import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/core/services/api_service.dart';

part 'keeper_repository.g.dart';

@riverpod
Future<KeeperProfileSchema> keeperProfile(Ref ref, String slug) async {
  final apiService = ref.watch(mobileApiServiceProvider);
  return apiService.client.totemUsersMobileApiKeeper(slug: slug);
}
