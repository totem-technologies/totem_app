import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/api/models/mobile_space_detail_schema.dart';
import 'package:totem_app/api/models/next_session_schema.dart';
import 'package:totem_app/api/models/session_detail_schema.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/features/home/models/upcoming_session_data.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/assets.dart';
import 'package:totem_app/shared/date.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

/// A card widget displaying an upcoming session with its details.
///
/// Design specs from Figma (node 2252:1202):
/// - White background, 20px rounded corners, 131px height
/// - Left: Image (130px width, rounded left corners only)
/// - Right: Content area with 10px padding containing metadata, title, and CTA
///
/// The attend button makes an RSVP API call and updates its state accordingly.
class UpcomingSessionCard extends ConsumerStatefulWidget {
  const UpcomingSessionCard({
    required this.data,
    super.key,
    this.onTap,
  });

  /// Convenience constructor from SessionDetailSchema
  factory UpcomingSessionCard.fromSessionDetail(
    SessionDetailSchema session, {
    Key? key,
    VoidCallback? onTap,
  }) {
    return UpcomingSessionCard(
      key: key,
      data: UpcomingSessionData.fromSessionDetail(session),
      onTap: onTap,
    );
  }

  /// Convenience constructor from space and session
  factory UpcomingSessionCard.fromSpaceAndSession(
    MobileSpaceDetailSchema space,
    NextSessionSchema session, {
    Key? key,
    VoidCallback? onTap,
  }) {
    return UpcomingSessionCard(
      key: key,
      data: UpcomingSessionData.fromSpaceAndSession(space, session),
      onTap: onTap,
    );
  }

  final UpcomingSessionData data;
  final VoidCallback? onTap;

  /// Card dimensions from Figma design
  static const double _cardHeight = 131;
  static const double _imageWidth = 130;
  static const double _borderRadius = 20;
  static const double _contentPadding = 10;

  @override
  ConsumerState<UpcomingSessionCard> createState() =>
      _UpcomingSessionCardState();
}

class _UpcomingSessionCardState extends ConsumerState<UpcomingSessionCard> {
  /// Track attending state locally for optimistic UI updates during API calls.
  /// This is only used temporarily - we always sync back to widget.data.attending
  /// when the widget updates or when not loading.
  bool? _optimisticAttending;

  /// Loading state for the attend button
  bool _loading = false;

  /// Returns the current attending status.
  /// Uses optimistic state during loading, otherwise uses data from provider.
  bool get _isAttending => _optimisticAttending ?? widget.data.attending;

  @override
  void didUpdateWidget(UpcomingSessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When widget data updates (e.g., from provider refresh), clear optimistic state
    // so we use the fresh data from the provider
    if (oldWidget.data.sessionSlug != widget.data.sessionSlug ||
        oldWidget.data.attending != widget.data.attending) {
      _optimisticAttending = null;
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Format date and time for display using shared utilities
    final formattedDate = formatShortDate(widget.data.start);
    final formattedTime = formatTimeOnly(widget.data.start);
    final formattedTimePeriod = formatTimePeriod(widget.data.start);

    // Build semantic label for accessibility
    final semanticLabel = [
      widget.data.sessionTitle,
      formattedDate,
      '$formattedTime $formattedTimePeriod',
      '${widget.data.seatsLeft} seats left',
      'with ${widget.data.author.name ?? ''}',
      if (_isAttending) 'Attending' else 'Not attending',
    ].join(', ');

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      // Container provides subtle border and shadow for depth (Apple-style)
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            UpcomingSessionCard._borderRadius,
          ),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            UpcomingSessionCard._borderRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap ?? () => _navigateToSession(context),
            child: SizedBox(
              height: UpcomingSessionCard._cardHeight,
              child: Row(
                children: [
                  // Left: Session image with rounded left corners only
                  _buildThumbnail(),

                  // Right: Content area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(
                        UpcomingSessionCard._contentPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top: Metadata row (date, time, seats)
                          _buildMetadataRow(
                            formattedDate: formattedDate,
                            formattedTime: formattedTime,
                            formattedTimePeriod: formattedTimePeriod,
                          ),

                          // Middle: Space/category name
                          _buildSpaceName(),

                          // Middle: Session title
                          _buildSessionTitle(),

                          // Bottom: Keeper info and attend button
                          _buildKeeperRow(context),
                        ],
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
  }

  /// Builds the thumbnail image with rounded left corners only.
  Widget _buildThumbnail() {
    final imageUrl = widget.data.imageUrl;

    return SizedBox(
      width: UpcomingSessionCard._imageWidth,
      height: double.infinity,
      child: imageUrl != null && imageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: getFullUrl(imageUrl),
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey.shade200,
              ),
              errorWidget: (context, url, error) => Image.asset(
                TotemAssets.genericBackground,
                fit: BoxFit.cover,
              ),
            )
          : Image.asset(
              TotemAssets.genericBackground,
              fit: BoxFit.cover,
            ),
    );
  }

  /// Builds the metadata row showing date, time, and seats left.
  /// Uses space-between layout to spread items across the width.
  Widget _buildMetadataRow({
    required String formattedDate,
    required String formattedTime,
    required String formattedTimePeriod,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Date with calendar icon
        _MetadataItem(
          icon: TotemIcons.calendar,
          text: formattedDate,
          textStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.slate,
          ),
        ),

        // Time with clock icon
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _MetadataIcon(icon: TotemIcons.clockCircle),
            const SizedBox(width: 2.4),
            Text(
              formattedTime,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.slate,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              formattedTimePeriod,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: AppTheme.gray,
              ),
            ),
          ],
        ),

        // Seats left with chair icon
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _MetadataIcon(icon: TotemIcons.seats),
            const SizedBox(width: 2.4),
            Text(
              '${widget.data.seatsLeft}',
              style: const TextStyle(
                fontSize: 8.3,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate,
              ),
            ),
            const SizedBox(width: 2),
            const Text(
              'seats left',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: AppTheme.gray,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the space/category name text with muted styling.
  Widget _buildSpaceName() {
    // Use space title as fallback if category is empty
    final displayText = (widget.data.category?.isNotEmpty ?? false)
        ? widget.data.category!
        : widget.data.spaceTitle;

    return SizedBox(
      height: 20,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.slate.withValues(alpha: 0.7),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// Builds the session title with bold styling.
  Widget _buildSessionTitle() {
    return SizedBox(
      height: 38,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          widget.data.sessionTitle,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.slate,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// Builds the keeper info row with avatar, name, and attend button.
  Widget _buildKeeperRow(BuildContext context) {
    return Row(
      children: [
        // Keeper avatar (28px diameter)
        UserAvatar.fromUserSchema(
          widget.data.author,
          radius: 14.12,
          borderWidth: 0,
        ),
        const SizedBox(width: 4),

        // "with" text
        const Text(
          'with ',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: AppTheme.slate,
          ),
        ),

        // Keeper name
        Expanded(
          child: Text(
            widget.data.author.name ?? '',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Attend/Attending button
        _buildAttendButton(context),
      ],
    );
  }

  /// Builds the attend button with different states:
  /// - "Attend" (outlined) - when not attending
  /// - "Attending" (filled) - when already attending
  /// - Loading indicator - when processing
  Widget _buildAttendButton(BuildContext context) {
    // Already attending - show filled "Attending" button
    if (_isAttending) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.mauve,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToSession(context),
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Attending',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Not attending - show outlined "Attend" button
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.mauve),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading ? null : _handleAttend,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: _loading
                ? const SizedBox(
                    width: 40,
                    child: LoadingIndicator(size: 16, color: AppTheme.mauve),
                  )
                : const Text(
                    'Attend',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.mauve,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Handles the attend button tap - makes RSVP API call.
  Future<void> _handleAttend() async {
    if (_isAttending || _loading || !mounted) return;

    setState(() => _loading = true);

    try {
      final mobileApiService = ref.read(mobileApiServiceProvider);
      final response = await mobileApiService.spaces
          .totemSpacesMobileApiMobileApiRsvpConfirm(
            eventSlug: widget.data.sessionSlug,
          );

      if (!mounted) return;

      if (response.attending) {
        setState(() {
          _optimisticAttending = true;
          _loading = false;
        });

        // Refresh the spaces summary to update seat counts and sync data
        // ignore: unused_result
        ref.refresh(spacesSummaryProvider.future);
      } else {
        setState(() {
          _optimisticAttending = null;
          _loading = false;
        });
        if (mounted) {
          showErrorPopup(
            context,
            icon: TotemIcons.spaces,
            title: 'Failed to attend',
            message: 'Please try again later',
          );
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace: stackTrace,
        message: 'Failed to attend session',
      );
      if (mounted) {
        setState(() {
          _optimisticAttending = null;
          _loading = false;
        });
        showErrorPopup(
          context,
          icon: TotemIcons.spaces,
          title: 'Failed to attend',
          message: 'Please try again later',
        );
      }
    }
  }

  /// Navigates to the session detail screen.
  void _navigateToSession(BuildContext context) {
    context.push(
      RouteNames.spaceEvent(widget.data.spaceSlug, widget.data.sessionSlug),
    );
  }
}

/// Helper widget for metadata items with icon and text.
class _MetadataItem extends StatelessWidget {
  const _MetadataItem({
    required this.icon,
    required this.text,
    required this.textStyle,
  });

  final String icon;
  final String text;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MetadataIcon(icon: icon),
        const SizedBox(width: 2.4),
        Text(text, style: textStyle),
      ],
    );
  }
}

/// Helper widget for metadata icons (10x10px).
class _MetadataIcon extends StatelessWidget {
  const _MetadataIcon({required this.icon});

  final String icon;

  @override
  Widget build(BuildContext context) {
    return TotemIcon(
      icon,
      size: 10,
      color: AppTheme.gray,
    );
  }
}
