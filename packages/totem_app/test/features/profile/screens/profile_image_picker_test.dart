import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/profile/screens/profile_image_picker.dart';

List<int> header(String type, String brand) => [
  0,
  0,
  0,
  24,
  ...type.codeUnits,
  ...brand.codeUnits,
];

void main() {
  for (final brand in [
    'heic',
    'heix',
    'hevc',
    'heim',
    'heis',
    'mif1',
    'msf1',
  ]) {
    test('recognizes the $brand HEIF brand', () {
      check(isHeifImageHeader(header('ftyp', brand))).equals(true);
    });
  }

  test('rejects incomplete headers', () {
    final complete = header('ftyp', 'heic');
    for (var length = 0; length < 12; length++) {
      check(isHeifImageHeader(complete.sublist(0, length))).equals(false);
    }
  });

  test('rejects other file types and brands', () {
    check(isHeifImageHeader(header('free', 'heic'))).equals(false);
    check(isHeifImageHeader(header('ftyp', 'mp42'))).equals(false);
    check(
      isHeifImageHeader([0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0, 0, 0, 0, 0]),
    ).equals(false);
  });
}
