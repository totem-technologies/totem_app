import 'package:material_ui/material_ui.dart';

// Entry visuals follow the catalog's cream / slate / mauve palette. Typography
// inherits the host's font (Montserrat in Widgetbook, the app font in production).
const entrySlate = Color(0xFF262F37);
const entryMauve = Color(0xFF987AA5);
const entryCream = Color(0xFFF3F1E9);

const entryTitle = TextStyle(
  fontSize: 21,
  fontWeight: FontWeight.w600,
  height: 1.2,
  color: entrySlate,
);
const entrySubtitle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  height: 1.2,
  color: entrySlate,
);
const entryBody = TextStyle(fontSize: 16, height: 1.5, color: entrySlate);
const entryMuted = TextStyle(
  fontSize: 14,
  height: 1.5,
  color: Color(0xFF787D7E),
);

class SessionEntryAction extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.secondary = false,
    this.quiet = false,
    this.compact = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool quiet;
  final bool compact;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final color = quiet || secondary ? entryMauve : Colors.white;
    final child = Container(
      constraints: BoxConstraints(
        minHeight: compact
            ? 36
            : quiet
            ? 44
            : 52,
        minWidth: compact || quiet ? 0 : 140,
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: quiet || secondary
            ? Colors.transparent
            : onPressed == null
            ? const Color(0xFFE9E3EC)
            : entryMauve,
        border: secondary ? Border.all(color: entryMauve, width: 1.5) : null,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: compact ? 14 : 16,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: onPressed == null ? entrySlate : color,
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Opacity(
        opacity: onPressed == null ? 0.65 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(999),
            child: expand
                ? SizedBox(width: double.infinity, child: child)
                : child,
          ),
        ),
      ),
    );
  }
}
