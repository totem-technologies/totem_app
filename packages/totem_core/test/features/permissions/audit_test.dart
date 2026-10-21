// Enforces the audit rules in lib/features/permissions/README.md: platform
// permission APIs are only touched from the files that own them.
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';

/// Source roots of every app that ships `totem_core`, relative to this
/// package.
const _roots = ['lib', '../totem_app/lib', '../totem_web/lib'];

const _module = 'lib/features/permissions';

const _firebaseNotificationPermissions =
    '../totem_app/lib/features/auth/services/'
    'firebase_notification_permissions.dart';

Map<String, String> _sources() => {
  for (final root in _roots)
    if (Directory(root).existsSync())
      for (final file in Directory(
        root,
      ).listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart') && !file.path.endsWith('.g.dart'))
          file.path: _withoutCommentLines(file.readAsStringSync()),
};

/// Drops comment lines, so docs may name the APIs they explain.
String _withoutCommentLines(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// The files outside [allowed] that match [pattern].
List<String> _violations(Pattern pattern, {Set<String> allowed = const {}}) => [
  for (final MapEntry(key: path, value: source) in _sources().entries)
    if (!allowed.contains(path) && source.contains(pattern)) path,
];

/// The only code outside the module it may import from `totem_core`: shared
/// UI and error reporting, none of which depends on sessions.
const _sharedImports = {
  'package:totem_core/core/config/theme.dart',
  'package:totem_core/core/errors/error_handler.dart',
  'package:totem_core/shared/totem_icons.dart',
  'package:totem_core/shared/widgets/confirmation_dialog.dart',
  'package:totem_core/shared/widgets/sheet_drag_handle.dart',
};

/// Packages that mean capture or LiveKit.
const _capturePackages = [
  'package:livekit_client/',
  'package:flutter_webrtc/',
  'package:dart_webrtc/',
];

final _directive = RegExp(r'^\s*(?:import|export)\b[^;]*;', multiLine: true);
final _quoted = RegExp("""['"]([^'"]+)['"]""");

/// Imports and exports in [dir] that reach outside the permission module:
/// a capture package, or `totem_core` code other than [_sharedImports],
/// including through relative paths and conditional imports.
List<String> _outsideImports(String dir) => [
  for (final MapEntry(key: path, value: source) in _sources().entries)
    if (path.startsWith(dir))
      for (final directive in _directive.allMatches(source))
        for (final match in _quoted.allMatches(directive.group(0)!))
          if (_leavesModule(path, match.group(1)!)) '$path: ${match.group(1)}',
];

bool _leavesModule(String path, String uri) {
  if (uri.startsWith('dart:')) return false;
  if (_capturePackages.any(uri.startsWith)) return true;
  if (uri.startsWith('package:totem_core/')) {
    return !uri.startsWith('package:totem_core/features/permissions/') &&
        !_sharedImports.contains(uri);
  }
  if (uri.startsWith('package:')) return false;
  final resolved = Uri.file(path).resolve(uri).path;
  return !resolved.contains('$_module/');
}

void main() {
  test('sources were found', () {
    check(_sources().keys.where((path) => path.startsWith(_module)))
        .isNotEmpty();
  });

  test('1: only the native adapter and classify use permission_handler', () {
    check(
      _violations(
        'package:permission_handler/',
        allowed: {
          '$_module/adapters/native_media_permissions.dart',
          '$_module/classify.dart',
        },
      ),
    ).isEmpty();
  });

  test('1: only the web adapter queries browser permissions', () {
    check(
      _violations(
        RegExp(r'\.permissions\s*\.query|navigator\.permissions'),
        allowed: {'$_module/adapters/web_media_permissions.dart'},
      ),
    ).isEmpty();
  });

  test('2: notification permission has a single owner', () {
    check(
      _violations(
        RegExp(r'requestPermission\(|NotificationPermission\b'),
        allowed: {_firebaseNotificationPermissions},
      ),
    ).isEmpty();
  });

  test('2/N2: nothing asks for a battery optimization exemption', () {
    check(
      _violations(
        RegExp('IgnoreBatteryOptimization|IgnoringBatteryOptimizations'),
      ),
    ).isEmpty();
    final manifest = File(
      '../totem_app/android/app/src/main/AndroidManifest.xml',
    );
    if (manifest.existsSync()) {
      check(manifest.readAsStringSync())
          .not((it) => it.contains('IGNORE_BATTERY_OPTIMIZATIONS'));
    }
  });

  test('3: only platform_info reads the user agent or touch points', () {
    check(
      _violations(
        RegExp('userAgent|maxTouchPoints'),
        allowed: {
          '$_module/platform_info.dart',
          '$_module/platform_info_web.dart',
          '$_module/platform_info_stub.dart',
        },
      ),
    ).isEmpty();
  });

  test('3: the module branches on PlatformInfo, not on platform globals', () {
    final platformGlobals = RegExp(
      r'\bPlatform\.is|defaultTargetPlatform|kIsWeb|kIsWasm',
    );
    final offenders = [
      for (final path in _violations(
        platformGlobals,
        allowed: {'$_module/platform_info.dart'},
      ))
        if (path.startsWith(_module)) path,
    ];
    check(offenders).isEmpty();
  });

  test('WS2: the module never captures media itself', () {
    final offenders = [
      for (final path in _violations('getUserMedia'))
        if (path.startsWith(_module)) path,
    ];
    // classify.dart only mentions it to recognize error messages.
    check(offenders).deepEquals(['$_module/classify.dart']);
  });

  test('5: the module knows nothing of LiveKit or sessions', () {
    check(_outsideImports(_module)).isEmpty();
  });

  test('5: shared code the module uses never imports sessions', () {
    final offenders = [
      for (final import in _sharedImports)
        if (File(import.replaceFirst('package:totem_core/', 'lib/'))
            .readAsStringSync()
            .contains('features/sessions/'))
          import,
    ];
    check(offenders).isEmpty();
  });

  test('5: the import check resolves every kind of import', () {
    const file = '$_module/ui/recovery.dart';
    check(_leavesModule(file, '../model.dart')).isFalse();
    check(_leavesModule(file, 'recovery_content.dart')).isFalse();
    check(_leavesModule(file, '../../sessions/room.dart')).isTrue();
    check(_leavesModule(file, 'package:totem_core/features/sessions/x.dart'))
        .isTrue();
    check(_leavesModule(file, 'package:livekit_client/livekit.dart')).isTrue();
    check(_leavesModule(file, 'package:flutter/widgets.dart')).isFalse();
    // Conditional imports name every alternative.
    final conditional = _quoted
        .allMatches(
          "import 'a_stub.dart' if (dart.library.js_interop) "
          "'../../sessions/a_web.dart';",
        )
        .map((match) => match.group(1)!);
    check(conditional.where((uri) => _leavesModule(file, uri)))
        .deepEquals(['../../sessions/a_web.dart']);
  });

  test('5: the import check does catch session code', () {
    check(_outsideImports('lib/features/sessions')).isNotEmpty();
  });
}
