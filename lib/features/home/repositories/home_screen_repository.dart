import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/models/summary_spaces_schema.dart';
import 'package:totem_app/core/services/api_service.dart';

@riverpod
Future<SummarySpacesSchema> listSpaces(Ref ref) {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  return mobileApiService.spaces.totemCirclesMobileApiGetSpacesSummary();
}
