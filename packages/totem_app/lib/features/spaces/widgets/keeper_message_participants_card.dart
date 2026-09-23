import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/shared/router.dart';

/// Keeper-only card that opens the server-authorized session participant list.
class KeeperMessageParticipantsCard extends StatelessWidget {
  const KeeperMessageParticipantsCard({required this.session, super.key});

  final SessionDetailSchema session;

  static const _darkNavy = Color(0xFF1F293B);
  static const _mutedGray = Color(0xFF8C8A82);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Container(
            padding: const EdgeInsetsDirectional.only(
              start: 10,
              end: 12,
              top: 4,
              bottom: 4,
            ),
            decoration: const BoxDecoration(
              color: _darkNavy,
              borderRadius: BorderRadius.all(Radius.circular(100)),
            ),
            child: const Text(
              '\u{1F512}  Keeper Only',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                height: 1.5,
              ),
            ),
          ),
          const Text(
            'Message Participants',
            style: TextStyle(
              color: _darkNavy,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const Text(
            'Choose one participant to start a private conversation.',
            style: TextStyle(color: _mutedGray, fontSize: 12, height: 1.5),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push(
                RouteNames.sessionParticipants(session.slug),
                extra: session,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mauve,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                minimumSize: const Size.fromHeight(44),
                elevation: 0,
                textStyle: const TextStyle(
                  fontFamily: AppTheme.fontFamilySans,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
              child: const Text('View Participants'),
            ),
          ),
        ],
      ),
    );
  }
}
