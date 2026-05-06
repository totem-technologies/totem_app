import 'package:flutter/widgets.dart';
import 'package:flutter_html/flutter_html.dart';
// This import is necessary because we need the ImageBuiltIn class to be
// extended.
// ignore: implementation_imports
import 'package:flutter_html/src/builtins/image_builtin.dart' show ImageBuiltIn;

class TotemImageHtmlExtension extends ImageBuiltIn {
  @override
  InlineSpan build(ExtensionContext context) {
    final span = super.build(context) as WidgetSpan;
    return WidgetSpan(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: span.child,
      ),
    );
  }
}
