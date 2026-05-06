import 'package:characters/characters.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';

extension ListExtension<T> on List<T> {
  List<T> reversedIf(bool condition) {
    return condition ? reversed.toList() : this;
  }
}

extension StringExtension on String {
  String uppercaseFirst() {
    if (isEmpty) return this;
    final chars = characters;
    final first = chars.firstOrNull ?? '';
    return '${first.toUpperCase()}${chars.skip(1)}';
  }
}

extension SessionDetailSchemaExtension on SessionDetailSchema {
  bool canJoinNow([UserSchema? user]) {
    if (ended) return false;
    var joinBeforeTime = const Duration(minutes: 10);
    if (user != null && (user.isStaff || user.slug == space.author.slug)) {
      joinBeforeTime = const Duration(hours: 1);
    }

    final now = DateTime.now();
    final end = start.add(Duration(minutes: duration));
    return start.isBefore(now.add(joinBeforeTime)) && end.isAfter(now);
  }
}

extension MobileSpaceDetailSchemaExtension on MobileSpaceDetailSchema {
  static MobileSpaceDetailSchema copyWith(
    MobileSpaceDetailSchema space, {
    String? title,
    String? imageLink,
    String? shortDescription,
    String? content,
    PublicUserSchema? author,
    String? category,
    int? subscribers,
    int? price,
    List<NextSessionSchema>? nextEvents,
    String? recurring,
  }) {
    return MobileSpaceDetailSchema(
      slug: space.slug,
      title: title ?? space.title,
      imageLink: imageLink ?? space.imageLink,
      shortDescription: shortDescription ?? space.shortDescription,
      content: content ?? space.content,
      author: author ?? space.author,
      category: category ?? space.category,
      subscribers: subscribers ?? space.subscribers,
      nextEvents: nextEvents ?? space.nextEvents,
      recurring: recurring ?? space.recurring,
      price: price ?? space.price,
    );
  }
}
