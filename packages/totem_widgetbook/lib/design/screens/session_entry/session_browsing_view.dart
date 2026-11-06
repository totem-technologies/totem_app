import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/session_entry_info_card.dart';
import 'package:totem_core/features/sessions/widgets/session_entry_style.dart';

/// Session details before joining. All imagery, descriptions, offers and
/// navigation come from the host; this view does not load a session.
class SessionBrowsingView extends StatelessWidget {
  const SessionBrowsingView({
    required this.spaceName,
    required this.sessionName,
    required this.keeperName,
    required this.dateLabel,
    required this.timeLabel,
    required this.facts,
    super.key,
    this.heroPhoto,
    this.keeperPhoto,
    this.about,
    this.similarSession,
    this.keeperLocation,
    this.keeperBio,
    this.onJoin,
    this.onBack,
    this.onShare,
    this.onKeeperProfile,
  });

  final String spaceName;
  final String sessionName;
  final String keeperName;
  final String dateLabel;
  final String timeLabel;
  final List<SessionEntryFact> facts;
  final ImageProvider? heroPhoto;
  final ImageProvider? keeperPhoto;
  final String? about;
  final Widget? similarSession;
  final String? keeperLocation;
  final String? keeperBio;
  final VoidCallback? onJoin;
  final VoidCallback? onBack;
  final VoidCallback? onShare;
  final VoidCallback? onKeeperProfile;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 640;
      return ColoredBox(
        color: const Color(0xFFFCEFE4),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: wide ? 560 : double.infinity,
              ),
              child: Padding(
                padding: EdgeInsets.only(top: wide ? 24 : 0, bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 24,
                  children: [
                    _hero(wide),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 10,
                        children: [
                          Text(spaceName, style: entryMuted),
                          Semantics(
                            header: true,
                            child: Text(sessionName, style: entryTitle),
                          ),
                          Row(
                            spacing: 6,
                            children: [
                              if (keeperPhoto != null)
                                CircleAvatar(
                                  radius: 19,
                                  backgroundImage: keeperPhoto,
                                ),
                              const Text('with', style: entryBody),
                              Flexible(
                                child: Text(keeperName, style: entrySubtitle),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SessionEntryInfoCard(
                      facts: facts,
                      dateLabel: dateLabel,
                      timeLabel: timeLabel,
                      onJoin: onJoin,
                    ),
                    if (about != null && about!.isNotEmpty)
                      _section(
                        'About this session',
                        Text(about!, style: entryBody),
                      ),
                    if (similarSession != null)
                      _section('Upcoming Similar Sessions', similarSession!),
                    if (keeperBio != null ||
                        keeperLocation != null ||
                        onKeeperProfile != null)
                      _section(
                        'Meet The Keeper',
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 10,
                              children: [
                                Row(
                                  spacing: 10,
                                  children: [
                                    if (keeperPhoto != null)
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundImage: keeperPhoto,
                                      ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            keeperName,
                                            style: entrySubtitle,
                                          ),
                                          if (keeperLocation != null)
                                            Text(
                                              keeperLocation!,
                                              style: entryMuted,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (keeperBio != null)
                                  Text(keeperBio!, style: entryMuted),
                                if (onKeeperProfile != null)
                                  TextButton(
                                    onPressed: onKeeperProfile,
                                    child: const Text('View Profile'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _hero(bool wide) => Padding(
    padding: EdgeInsets.symmetric(horizontal: wide ? 20 : 0),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(wide ? 20 : 0),
      child: SizedBox(
        height: wide ? 300 : 262,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (heroPhoto != null)
              Image(image: heroPhoto!, fit: BoxFit.cover)
            else
              const ColoredBox(color: entryCream),
            Positioned(
              top: 10,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filled(
                    tooltip: 'Back to the Space',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  if (onShare != null)
                    IconButton.filled(
                      tooltip: 'Share',
                      onPressed: onShare,
                      icon: const Icon(Icons.share_outlined),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 20,
      children: [
        Semantics(header: true, child: Text(title, style: entrySubtitle)),
        child,
      ],
    ),
  );
}
