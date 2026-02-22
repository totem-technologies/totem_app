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
import 'package:totem_app/features/home/widgets/session_metadata.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/assets.dart';
import 'package:totem_app/shared/date.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

/// A card widget displaying an upcoming session with its details.
class UpcomingSessionCard extends ConsumerStatefulWidget {
  const UpcomingSessionCard({
    required this.data,
    super.key,
    this.onTap,
  });

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

  static const double _imageWidth = 130;
  static const double _borderRadius = 20;
  static const double _contentPadding = 10;

  @override
  ConsumerState<UpcomingSessionCard> createState() =>
      _UpcomingSessionCardState();
}

class _UpcomingSessionCardState extends ConsumerState<UpcomingSessionCard> {
  bool? _optimisticAttending;
  bool _loading = false;

  bool get _isAttending => _optimisticAttending ?? widget.data.attending;

  @override
  void didUpdateWidget(UpcomingSessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.sessionSlug != widget.data.sessionSlug ||
        oldWidget.data.attending != widget.data.attending) {
      _optimisticAttending = null;
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = formatShortDate(widget.data.start);
    final formattedTime = formatTimeOnly(widget.data.start);
    final formattedTimePeriod = formatTimePeriod(widget.data.start);

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
      child: DecoratedBox(
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
            child: IntrinsicHeight(
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
                          _buildMetadataRow(
                            formattedDate: formattedDate,
                            formattedTime: formattedTime,
                            formattedTimePeriod: formattedTimePeriod,
                          ),
                          _buildSpaceName(),
                          _buildSessionTitle(),
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

  Widget _buildMetadataRow({
    required String formattedDate,
    required String formattedTime,
    required String formattedTimePeriod,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SessionMetadataItem(
          icon: TotemIcons.calendar,
          text: formattedDate,
          textStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.slate,
          ),
        ),

        SessionTimeMetadata(
          time: formattedTime,
          period: formattedTimePeriod,
        ),
        SessionSeatsMetadata(seatsLeft: widget.data.seatsLeft),
      ],
    );
  }

  Widget _buildSpaceName() {
    final displayText = (widget.data.category?.isNotEmpty ?? false)
        ? widget.data.category!
        : widget.data.spaceTitle;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 20,
      ),
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

  Widget _buildSessionTitle() {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 38,
      ),
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

  Widget _buildKeeperRow(BuildContext context) {
    return Row(
      children: [
        UserAvatar.fromUserSchema(
          widget.data.author,
          radius: 14.12,
          borderWidth: 0,
        ),
        const SizedBox(width: 4),
        const Text(
          'with ',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: AppTheme.slate,
          ),
        ),
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
        _buildAttendButton(context),
      ],
    );
  }

  Widget _buildAttendButton(BuildContext context) {
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

  void _navigateToSession(BuildContext context) {
    context.push(
      RouteNames.spaceSession(widget.data.spaceSlug, widget.data.sessionSlug),
    );
  }
}
