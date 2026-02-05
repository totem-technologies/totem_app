import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

// Provider to track the selected category filter for sessions
class SelectedCategoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void toggleCategory(String? category) {
    state = (state == category) ? null : category;
  }
}

// Provider
final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryNotifier, String?>(
      SelectedCategoryNotifier.new,
      name: 'Selected Category Provider',
    );

// Provider to track "My Sessions" filter state (shows only attending sessions)
class MySessionsFilterNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void setFilter(bool value) {
    state = value;
  }
}

// Provider for My Sessions filter
final mySessionsFilterProvider =
    NotifierProvider<MySessionsFilterNotifier, bool>(
      MySessionsFilterNotifier.new,
      name: 'My Sessions Filter Provider',
    );

class SpacesDiscoveryScreen extends ConsumerWidget {
  const SpacesDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(spacesSummaryProvider);
    ref.sentryReportFullyDisplayed(spacesSummaryProvider);

    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isMySessionsSelected = ref.watch(mySessionsFilterProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: summary.when(
          data: (summaryData) {
            // Extract all sessions from the summary (no limit for discovery screen)
            final allSessions = _extractAllSessions(summaryData);

            if (allSessions.isEmpty) {
              return EmptyIndicator(
                icon: TotemIcons.spacesFilled,
                text: 'No sessions available yet.',
                onRetry: () => ref.refresh(spacesSummaryProvider.future),
              );
            }

            // Extract unique categories from sessions
            final categories = _extractCategories(allSessions);

            // Filter sessions by "My Sessions" (attending) first
            var filteredSessions = isMySessionsSelected
                ? allSessions.where((session) => session.attending).toList()
                : allSessions;

            // Then filter by selected category
            if (selectedCategory != null) {
              filteredSessions = filteredSessions
                  .where((session) => session.category == selectedCategory)
                  .toList();
            }

            // Group sessions by date for display
            final groupedSessions = _groupSessionsByDate(filteredSessions);

            return Column(
              children: [
                // Fixed header - Sessions title with "My Sessions" button
                _SessionsHeader(
                  isMySessionsSelected: isMySessionsSelected,
                  onMySessionsTapped: () {
                    // Toggle the "My Sessions" filter
                    ref.read(mySessionsFilterProvider.notifier).toggle();
                  },
                ),
                // Fixed category filter bar
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SpacesFilterBar(
                    categories: categories,
                    selectedCategory: selectedCategory,
                    onCategorySelected: (category) {
                      ref
                          .read(selectedCategoryProvider.notifier)
                          .toggleCategory(category);
                    },
                  ),
                ),
                // Scrollable content - sessions grouped by date
                Expanded(
                  child: RefreshIndicator.adaptive(
                    onRefresh: () => ref.refresh(spacesSummaryProvider.future),
                    child: filteredSessions.isEmpty
                        ? ListView(
                            children: [
                              _buildNoResultsMessage(
                                isMySessionsSelected
                                    ? 'My Sessions'
                                    : (selectedCategory ?? 'All'),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsetsDirectional.only(
                              start: 16,
                              end: 16,
                              bottom: 20,
                            ),
                            itemCount: groupedSessions.length,
                            itemBuilder: (context, index) {
                              final dateGroup = groupedSessions[index];
                              return _SessionDateGroup(
                                date: dateGroup.date,
                                sessions: dateGroup.sessions,
                              );
                            },
                          ),
                  ),
                ),
              ],
            );
          },
          error: (err, stack) => ErrorScreen(
            error: err,
            showHomeButton: false,
            onRetry: () => ref.refresh(spacesSummaryProvider.future),
          ),
          loading: () {
            return Column(
              children: [
                // Fixed header - Sessions title with "My Sessions" button
                _SessionsHeader(
                  isMySessionsSelected: isMySessionsSelected,
                  onMySessionsTapped: () {
                    ref.read(mySessionsFilterProvider.notifier).toggle();
                  },
                ),
                // Loading indicator
                const Expanded(
                  child: Center(child: LoadingIndicator()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Extracts all upcoming sessions from the summary, sorted by start time.
  List<UpcomingSessionData> _extractAllSessions(
    SummarySpacesSchema summaryData,
  ) {
    final sessions = <UpcomingSessionData>[];
    final now = DateTime.now();

    for (final space in summaryData.explore) {
      for (final event in space.nextEvents) {
        // Include sessions that haven't started yet and have seats available
        if (event.start.isAfter(now) && event.seatsLeft > 0) {
          sessions.add(UpcomingSessionData.fromSpaceAndSession(space, event));
        }
      }
    }

    // Sort by start time
    sessions.sort((a, b) => a.start.compareTo(b.start));
    return sessions;
  }

  /// Extracts unique categories from sessions list.
  List<String> _extractCategories(List<UpcomingSessionData> sessions) {
    final categories = <String>{
      for (final session in sessions)
        if (session.category != null && session.category!.isNotEmpty)
          session.category!,
    }.toList()..sort();

    return categories;
  }

  /// Groups sessions by date for display with date indicators.
  List<_SessionDateGroupData> _groupSessionsByDate(
    List<UpcomingSessionData> sessions,
  ) {
    final Map<DateTime, List<UpcomingSessionData>> grouped = {};

    for (final session in sessions) {
      // Normalize to date only (strip time)
      final dateKey = DateTime(
        session.start.year,
        session.start.month,
        session.start.day,
      );

      grouped.putIfAbsent(dateKey, () => []).add(session);
    }

    // Convert to list and sort by date
    final result =
        grouped.entries
            .map((e) => _SessionDateGroupData(date: e.key, sessions: e.value))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    return result;
  }

  Widget _buildNoResultsMessage(String category) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No sessions in "$category"',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try selecting a different category',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data holder for a group of sessions on the same date.
class _SessionDateGroupData {
  const _SessionDateGroupData({
    required this.date,
    required this.sessions,
  });

  final DateTime date;
  final List<UpcomingSessionData> sessions;
}

/// Widget displaying a date group with date indicator on the left and sessions on the right.
class _SessionDateGroup extends StatelessWidget {
  const _SessionDateGroup({
    required this.date,
    required this.sessions,
  });

  final DateTime date;
  final List<UpcomingSessionData> sessions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date indicator on the left
          _DateIndicator(date: date),
          const SizedBox(width: 12),
          // Sessions column on the right
          Expanded(
            child: Column(
              children: [
                for (int i = 0; i < sessions.length; i++) ...[
                  _SessionCard(data: sessions[i]),
                  if (i < sessions.length - 1) const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical session card widget matching the Figma design.
/// Shows image on top, time/seats, category, title, and facilitator row.
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.data});

  final UpcomingSessionData data;

  static const double _borderRadius = 16;
  static const double _imageHeight = 160;

  @override
  Widget build(BuildContext context) {
    final formattedTime = formatTimeOnly(data.start);
    final formattedTimePeriod = formatTimePeriod(data.start);

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
            // Session image
            _buildImage(),
            // Content section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time and seats row
                  _buildTimeSeatsRow(formattedTime, formattedTimePeriod),
                  const SizedBox(height: 8),
                  // Category/short description
                  _buildSpaceTitle(),
                  const SizedBox(height: 4),
                  // Session title
                  _buildTitle(),
                  const SizedBox(height: 10),
                  // Facilitator row
                  _buildFacilitatorRow(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    final imageUrl = data.imageUrl;

    return SizedBox(
      height: _imageHeight,
      width: double.infinity,
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

  Widget _buildTimeSeatsRow(String formattedTime, String formattedTimePeriod) {
    return Row(
      children: [
        // Time with clock icon
        Icon(
          Icons.access_time_outlined,
          size: 14,
          color: AppTheme.slate.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 4),
        Text(
          '$formattedTime $formattedTimePeriod',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.slate.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(width: 16),
        // Seats left with icon
        TotemIcon(
          TotemIcons.seats,
          size: 14,
          color: AppTheme.slate.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 4),
        Text(
          '${data.seatsLeft} seats left',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.slate.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildSpaceTitle() {
    return Text(
      data.spaceTitle,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppTheme.slate.withValues(alpha: 0.6),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTitle() {
    return Text(
      data.sessionTitle,
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

  Widget _buildFacilitatorRow(BuildContext context) {
    return Row(
      children: [
        // Facilitator avatar
        UserAvatar.fromUserSchema(
          data.author,
          radius: 14,
          borderWidth: 0,
        ),
        const SizedBox(width: 6),
        // "with" text
        Text(
          'with ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppTheme.slate.withValues(alpha: 0.7),
          ),
        ),
        // Facilitator name
        Expanded(
          child: Text(
            data.author.name ?? '',
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

  void _navigateToSession(BuildContext context) {
    context.push(
      RouteNames.spaceEvent(data.spaceSlug, data.sessionSlug),
    );
  }
}

/// Date indicator widget showing day number, day of week, and "Today" label.
///
/// Design variations:
/// - Today: Purple badge with "21 WED", "Today" label below
/// - Not today: Gray "NOV" text, large day number, gray "WED" text
class _DateIndicator extends StatelessWidget {
  const _DateIndicator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = date == today;

    // Format day number and day of week
    final dayNumber = date.day.toString();
    final dayOfWeek = _getDayOfWeekShort(date.weekday);
    final monthName = _getMonthShort(date.month);

    if (isToday) {
      return _buildTodayIndicator(dayNumber, dayOfWeek);
    } else {
      return _buildDateIndicator(dayNumber, dayOfWeek, monthName);
    }
  }

  /// Builds the "Today" date indicator with purple badge and "Today" label
  Widget _buildTodayIndicator(String dayNumber, String dayOfWeek) {
    return SizedBox(
      width: 50,
      height: 70,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: const BoxDecoration(
                  color: AppTheme.mauve,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Text(
                  '$dayNumber ${dayOfWeek.toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.white,
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
                    color: Color(0xff7D8287),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the standard date indicator for non-today dates
  /// Shows: NOV (gray), 9 (large), WED (gray)
  Widget _buildDateIndicator(
    String dayNumber,
    String dayOfWeek,
    String monthName,
  ) {
    return SizedBox(
      width: 50,
      height: 70,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffC4C4C4).withValues(alpha: 0.7),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff7D8287),
                      height: 1.2,
                    ),
                  ),
                  // Day of week
                  Text(
                    dayOfWeek.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xff7D8287),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDayOfWeekShort(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _getMonthShort(int month) {
    const months = [
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
    ];
    return months[month - 1];
  }
}

/// Header widget displaying "Sessions" title and "My Sessions" button.
/// The button has selected/unselected states for filtering attending sessions.
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
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // "Sessions" title
          Text(
            'Sessions',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          // "My Sessions" button with selected/unselected state
          _buildMySessionsButton(theme),
        ],
      ),
    );
  }

  Widget _buildMySessionsButton(ThemeData theme) {
    return GestureDetector(
      onTap: onMySessionsTapped,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMySessionsSelected
              ? theme.colorScheme.primary
              : Colors.white,
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
            // Icon: people icon (different colors based on state)
            TotemIcon(
              TotemIcons.mySessions,
              size: 16,
              color: isMySessionsSelected
                  ? Colors.white
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            // Label
            Text(
              'My Sessions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isMySessionsSelected
                    ? Colors.white
                    : theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
