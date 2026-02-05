import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
import 'package:totem_app/api/models/summary_spaces_schema.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/home/models/upcoming_session_data.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/features/spaces/widgets/filter.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/assets.dart';
import 'package:totem_app/shared/date.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/utils.dart';
import 'package:totem_app/shared/widgets/empty_indicator.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

// =============================================================================
// PROVIDERS
// =============================================================================

/// Provider to track the selected category filter for sessions.
final selectedCategoryProvider =
    NotifierProvider<_SelectedCategoryNotifier, String?>(
      _SelectedCategoryNotifier.new,
      name: 'selectedCategoryProvider',
    );

class _SelectedCategoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void toggle(String? category) {
    state = (state == category) ? null : category;
  }
}

/// Provider to track "My Sessions" filter state (shows only attending sessions).
final mySessionsFilterProvider =
    NotifierProvider<_MySessionsFilterNotifier, bool>(
      _MySessionsFilterNotifier.new,
      name: 'mySessionsFilterProvider',
    );

class _MySessionsFilterNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

// =============================================================================
// MAIN SCREEN
// =============================================================================

/// Sessions discovery screen displaying all available sessions grouped by date.
///
/// Features:
/// - Sessions grouped by date with visual date indicators
/// - Category filter bar for filtering by session category
/// - "My Sessions" toggle to show only attending sessions
/// - Pull-to-refresh support
class SpacesDiscoveryScreen extends ConsumerWidget {
  const SpacesDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(spacesSummaryProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isMySessionsSelected = ref.watch(mySessionsFilterProvider);

    ref.sentryReportFullyDisplayed(spacesSummaryProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: summary.when(
          data: (data) => _buildContent(
            context,
            ref,
            data,
            selectedCategory,
            isMySessionsSelected,
          ),
          loading: () => _buildLoadingState(ref, isMySessionsSelected),
          error: (err, _) => ErrorScreen(
            error: err,
            showHomeButton: false,
            onRetry: () => ref.refresh(spacesSummaryProvider.future),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    SummarySpacesSchema summaryData,
    String? selectedCategory,
    bool isMySessionsSelected,
  ) {
    final allSessions = _extractAllSessions(summaryData);

    if (allSessions.isEmpty) {
      return EmptyIndicator(
        icon: TotemIcons.spacesFilled,
        text: 'No sessions available yet.',
        onRetry: () => ref.refresh(spacesSummaryProvider.future),
      );
    }

    final categories = _extractCategories(allSessions);
    final filteredSessions = _filterSessions(
      allSessions,
      selectedCategory,
      isMySessionsSelected,
    );
    final groupedSessions = _groupSessionsByDate(filteredSessions);

    return Column(
      children: [
        _SessionsHeader(
          isMySessionsSelected: isMySessionsSelected,
          onMySessionsTapped: () =>
              ref.read(mySessionsFilterProvider.notifier).toggle(),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SpacesFilterBar(
            categories: categories,
            selectedCategory: selectedCategory,
            onCategorySelected: (category) =>
                ref.read(selectedCategoryProvider.notifier).toggle(category),
          ),
        ),
        Expanded(
          child: RefreshIndicator.adaptive(
            onRefresh: () => ref.refresh(spacesSummaryProvider.future),
            child: filteredSessions.isEmpty
                ? _buildEmptyFilterResult(
                    selectedCategory,
                    isMySessionsSelected,
                  )
                : _buildSessionsList(groupedSessions),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(WidgetRef ref, bool isMySessionsSelected) {
    return Column(
      children: [
        _SessionsHeader(
          isMySessionsSelected: isMySessionsSelected,
          onMySessionsTapped: () =>
              ref.read(mySessionsFilterProvider.notifier).toggle(),
        ),
        const Expanded(child: Center(child: LoadingIndicator())),
      ],
    );
  }

  Widget _buildEmptyFilterResult(String? category, bool isMySessionsSelected) {
    final filterName = isMySessionsSelected
        ? 'My Sessions'
        : (category ?? 'All');
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 100),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.filter_list, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No sessions in "$filterName"',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try selecting a different category',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionsList(List<_SessionDateGroup> groupedSessions) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 20),
      itemCount: groupedSessions.length,
      itemBuilder: (_, index) => _SessionDateGroupWidget(
        dateGroup: groupedSessions[index],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Data Processing
  // ---------------------------------------------------------------------------

  /// Extracts all upcoming sessions from the summary, sorted by start time.
  List<UpcomingSessionData> _extractAllSessions(SummarySpacesSchema summary) {
    final now = DateTime.now();
    final sessions = <UpcomingSessionData>[];

    for (final space in summary.explore) {
      for (final event in space.nextEvents) {
        if (event.start.isAfter(now) && event.seatsLeft > 0) {
          sessions.add(UpcomingSessionData.fromSpaceAndSession(space, event));
        }
      }
    }

    return sessions..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Extracts unique categories from sessions list.
  List<String> _extractCategories(List<UpcomingSessionData> sessions) {
    return sessions
        .map((s) => s.category)
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  /// Filters sessions by category and/or attending status.
  List<UpcomingSessionData> _filterSessions(
    List<UpcomingSessionData> sessions,
    String? category,
    bool onlyAttending,
  ) {
    var filtered = sessions;

    if (onlyAttending) {
      filtered = filtered.where((s) => s.attending).toList();
    }

    if (category != null) {
      filtered = filtered.where((s) => s.category == category).toList();
    }

    return filtered;
  }

  /// Groups sessions by date for display with date indicators.
  List<_SessionDateGroup> _groupSessionsByDate(
    List<UpcomingSessionData> sessions,
  ) {
    final grouped = <DateTime, List<UpcomingSessionData>>{};

    for (final session in sessions) {
      final dateKey = DateTime(
        session.start.year,
        session.start.month,
        session.start.day,
      );
      grouped.putIfAbsent(dateKey, () => []).add(session);
    }

    return grouped.entries
        .map((e) => _SessionDateGroup(date: e.key, sessions: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

/// Data holder for a group of sessions on the same date.
class _SessionDateGroup {
  const _SessionDateGroup({required this.date, required this.sessions});

  final DateTime date;
  final List<UpcomingSessionData> sessions;
}

// =============================================================================
// WIDGETS
// =============================================================================

/// Header widget displaying "Sessions" title and "My Sessions" filter button.
class _SessionsHeader extends StatelessWidget {
  const _SessionsHeader({
    required this.onMySessionsTapped,
    this.isMySessionsSelected = false,
  });

  final VoidCallback onMySessionsTapped;
  final bool isMySessionsSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20).copyWith(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Sessions',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          _MySessionsButton(
            isSelected: isMySessionsSelected,
            onTap: onMySessionsTapped,
          ),
        ],
      ),
    );
  }
}

/// Toggle button for filtering "My Sessions" (attending sessions).
class _MySessionsButton extends StatelessWidget {
  const _MySessionsButton({
    required this.isSelected,
    required this.onTap,
  });

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final contentColor = isSelected ? Colors.white : primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TotemIcon(TotemIcons.mySessions, size: 16, color: contentColor),
            const SizedBox(width: 8),
            Text(
              'My Sessions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: contentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget displaying a date group with date indicator and session cards.
class _SessionDateGroupWidget extends StatelessWidget {
  const _SessionDateGroupWidget({required this.dateGroup});

  final _SessionDateGroup dateGroup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DateIndicator(date: dateGroup.date),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                for (int i = 0; i < dateGroup.sessions.length; i++) ...[
                  _SessionCard(data: dateGroup.sessions[i]),
                  if (i < dateGroup.sessions.length - 1)
                    const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Date indicator widget with different styles for "today" and other dates.
class _DateIndicator extends StatelessWidget {
  const _DateIndicator({required this.date});

  final DateTime date;

  static const _width = 50.0;
  static const _height = 70.0;
  static const _borderRadius = 10.0;
  static const _secondaryTextColor = Color(0xff7D8287);
  static const _headerBgColor = Color(0xffC4C4C4);

  bool get _isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final dayNumber = date.day.toString();
    final dayOfWeek = _dayOfWeekShort(date.weekday);
    final monthName = _monthShort(date.month);

    return SizedBox(
      width: _width,
      height: _height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_borderRadius),
        ),
        child: _isToday
            ? _buildTodayContent(dayNumber, dayOfWeek)
            : _buildDateContent(dayNumber, dayOfWeek, monthName),
      ),
    );
  }

  Widget _buildTodayContent(String dayNumber, String dayOfWeek) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: const BoxDecoration(
              color: AppTheme.mauve,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(_borderRadius),
              ),
            ),
            child: Text(
              '$dayNumber ${dayOfWeek.toUpperCase()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const Expanded(
          flex: 2,
          child: Center(
            child: Text(
              'Today',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _secondaryTextColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateContent(
    String dayNumber,
    String dayOfWeek,
    String monthName,
  ) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: _headerBgColor.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_borderRadius),
              ),
            ),
            child: Text(
              monthName.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xff444444),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dayNumber,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _secondaryTextColor,
                  height: 1.2,
                ),
              ),
              Text(
                dayOfWeek.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _dayOfWeekShort(int weekday) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

  String _monthShort(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}

/// Vertical session card displaying session details.
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.data});

  final UpcomingSessionData data;

  static const _borderRadius = 16.0;
  static const _imageHeight = 160.0;
  static const _contentPadding = EdgeInsets.all(12);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToSession(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SessionImage(imageUrl: data.imageUrl, height: _imageHeight),
            Padding(
              padding: _contentPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SessionMetadata(
                    time: data.start,
                    seatsLeft: data.seatsLeft,
                  ),
                  const SizedBox(height: 8),
                  _SessionSpaceTitle(title: data.spaceTitle),
                  const SizedBox(height: 4),
                  _SessionTitle(title: data.sessionTitle),
                  const SizedBox(height: 10),
                  _SessionFacilitator(author: data.author),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToSession(BuildContext context) {
    context.push(RouteNames.spaceEvent(data.spaceSlug, data.sessionSlug));
  }
}

/// Session card image with placeholder and error handling.
class _SessionImage extends StatelessWidget {
  const _SessionImage({required this.imageUrl, required this.height});

  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: (imageUrl != null && imageUrl!.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: getFullUrl(imageUrl!),
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey.shade200),
              errorWidget: (_, __, ___) => Image.asset(
                TotemAssets.genericBackground,
                fit: BoxFit.cover,
              ),
            )
          : Image.asset(TotemAssets.genericBackground, fit: BoxFit.cover),
    );
  }
}

/// Session time and seats metadata row.
class _SessionMetadata extends StatelessWidget {
  const _SessionMetadata({required this.time, required this.seatsLeft});

  final DateTime time;
  final int seatsLeft;

  static final _textStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppTheme.slate.withValues(alpha: 0.8),
  );

  static final _iconColor = AppTheme.slate.withValues(alpha: 0.7);

  @override
  Widget build(BuildContext context) {
    final formattedTime = formatTimeOnly(time);
    final formattedPeriod = formatTimePeriod(time);

    return Row(
      children: [
        Icon(Icons.access_time_outlined, size: 14, color: _iconColor),
        const SizedBox(width: 4),
        Text('$formattedTime $formattedPeriod', style: _textStyle),
        const SizedBox(width: 16),
        TotemIcon(TotemIcons.seats, size: 14, color: _iconColor),
        const SizedBox(width: 4),
        Text('$seatsLeft seats left', style: _textStyle),
      ],
    );
  }
}

/// Session space title (subtitle).
class _SessionSpaceTitle extends StatelessWidget {
  const _SessionSpaceTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppTheme.slate.withValues(alpha: 0.6),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Session title (main heading).
class _SessionTitle extends StatelessWidget {
  const _SessionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.slate,
        height: 1.3,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Session facilitator row with avatar and name.
class _SessionFacilitator extends StatelessWidget {
  const _SessionFacilitator({required this.author});

  final PublicUserSchema author;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar.fromUserSchema(author, radius: 14, borderWidth: 0),
        const SizedBox(width: 6),
        Text(
          'with ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppTheme.slate.withValues(alpha: 0.7),
          ),
        ),
        Expanded(
          child: Text(
            author.name ?? '',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
