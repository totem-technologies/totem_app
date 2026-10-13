import 'dart:js_interop';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_web/core/navigation/browser_environment.dart';
import 'package:web/web.dart' as web;

void main() {
  test('runs the page exit handler only while one is set', () {
    final browser = BrowserEnvironment();
    var exits = 0;
    addTearDown(() => browser.setPageExitHandler(null));

    browser.setPageExitHandler(() => exits++);
    web.window.dispatchEvent(web.Event('pagehide'));
    check(exits).equals(1);

    browser.setPageExitHandler(null);
    web.window.dispatchEvent(web.Event('pagehide'));
    check(exits).equals(1);
  });

  test('leaves other page exit handlers in place', () {
    final browser = BrowserEnvironment();
    var otherExits = 0;
    web.window.onpagehide = ((web.Event _) => otherExits++).toJS;
    addTearDown(() {
      web.window.onpagehide = null;
      browser.setPageExitHandler(null);
    });

    browser
      ..setPageExitHandler(() {})
      ..setPageExitHandler(null);
    web.window.dispatchEvent(web.Event('pagehide'));

    check(otherExits).equals(1);
  });
}
