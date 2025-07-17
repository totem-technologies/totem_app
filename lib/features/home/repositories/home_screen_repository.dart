import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/models/summary_spaces_schema.dart';
import 'package:totem_app/core/services/api_service.dart';

part 'home_screen_repository.g.dart';

@riverpod
Future<SummarySpacesSchema> spacesSummary(Ref ref) {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  return mobileApiService.spaces.totemCirclesMobileApiGetSpacesSummary();
}
