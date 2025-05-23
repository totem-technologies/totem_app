import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class TotemIcons {
  static const home = '''
<svg width="26" height="26" viewBox="0 0 26 26" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M2.16492 13.2126C2.16492 10.8288 2.16492 9.63691 2.70575 8.64885C3.24658 7.6608 4.23466 7.04757 6.21078 5.82113L8.29412 4.52815C10.383 3.23171 11.4275 2.5835 12.5816 2.5835C13.7356 2.5835 14.7801 3.23171 16.8691 4.52815L18.9524 5.82112C20.9286 7.04757 21.9166 7.6608 22.4574 8.64885C22.9983 9.63691 22.9983 10.8288 22.9983 13.2126V14.797C22.9983 18.8604 22.9983 20.8921 21.7778 22.1544C20.5575 23.4168 18.5933 23.4168 14.6649 23.4168H10.4983C6.56988 23.4168 4.6057 23.4168 3.3853 22.1544C2.16492 20.8921 2.16492 18.8604 2.16492 14.797V13.2126Z" stroke="#717171" stroke-width="1.6"/>
<path d="M9.45657 17.1665C10.3424 17.8231 11.4197 18.2082 12.5816 18.2082C13.7434 18.2082 14.8207 17.8231 15.7066 17.1665" stroke="#717171" stroke-width="1.6" stroke-linecap="round"/>
</svg>
''';

  static const spaces = '''
<svg width="28" height="28" viewBox="0 0 28 28" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M26.7755 14C26.7755 20.9036 21.1791 26.5 14.2755 26.5C7.3719 26.5 1.77545 20.9036 1.77545 14C1.77545 7.09644 7.3719 1.5 14.2755 1.5C21.1791 1.5 26.7755 7.09644 26.7755 14Z" stroke="#717171" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

  static const blog = '''
<svg width="26" height="26" viewBox="0 0 26 26" fill="none" xmlns="http://www.w3.org/2000/svg">
<mask id="mask0_308_1489" style="mask-type:luminance" maskUnits="userSpaceOnUse" x="0" y="0" width="26" height="26">
<path d="M25.8877 0.5H0.887695V25.5H25.8877V0.5Z" fill="white"/>
</mask>
<g mask="url(#mask0_308_1489)">
<path d="M6.35645 20.0312V2.06641C6.35645 2.06641 6.35645 1.28125 7.1377 1.28125H24.3252C24.3252 1.28125 25.1064 1.28516 25.1064 2.06641V22.3789C25.1064 22.3789 25.1064 24.7188 22.7627 24.7188H4.0127C4.0127 24.7188 1.66895 24.7227 1.66895 21.5977V9.87891C1.66895 9.87891 1.66895 9.09375 2.4502 9.09375H4.0127M11.0439 5.96875H14.9502M11.0439 9.09375H20.4189M11.0439 12.2188H20.4189M11.0439 15.3438H20.4189M11.0439 18.4688H20.4189" stroke="#717171" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/>
</g>
</svg>
''';
}

class TotemIcon extends StatelessWidget {
  const TotemIcon(this.icon, {super.key, this.size, this.color});

  final String icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final iconSize = size ?? iconTheme.size ?? 24.0;
    final iconColor = color ?? iconTheme.color ?? Colors.black;

    return SvgPicture.string(
      icon,
      width: iconSize,
      height: iconSize,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      fit: BoxFit.contain,
    );
  }
}
