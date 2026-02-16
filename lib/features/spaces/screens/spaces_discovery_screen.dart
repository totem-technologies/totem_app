import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/features/home/models/upcoming_session_data.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/features/spaces/widgets/filter.dart';
import 'package:totem_app/features/spaces/widgets/session_card.dart';
import 'package:totem_app/features/spaces/widgets/session_date_group.dart';
import 'package:totem_app/features/spaces/widgets/sessions_header.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/utils.dart';
import 'package:totem_app/shared/widgets/empty_indicator.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

// Filter state providers
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

final mySessionsFilterProvider =
    NotifierProvider<_MySessionsFilterNotifier, bool>(
      _MySessionsFilterNotifier.new,
      name: 'mySessionsFilterProvider',
    );

class _MySessionsFilterNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  bool get mySessionFilter => state;

  set mySessionFilter(bool enabled) => state = enabled;
}

// Memoized data providers - only recompute when dependencies change
final _allSessionsProvider = Provider<List<UpcomingSessionData>>((ref) {
  final summaryAsync = ref.watch(spacesSummaryProvider);
  return summaryAsync.maybeWhen(
    data: (summary) {
      final exploreSessions = UpcomingSessionData.fromSummary(
        summary,
        limit: null,
        includeAttendingFullSessions: true,
      );

      // Also include sessions from upcoming that aren't already in explore
      final now = DateTime.now();
      final exploreSlugs = exploreSessions.map((s) => s.sessionSlug).toSet();
      final upcomingSessions = summary.upcoming
          .where(
            (s) =>
                !s.ended &&
                s.start.isAfter(now) &&
                !exploreSlugs.contains(s.slug),
          )
          .map(UpcomingSessionData.fromSessionDetail);

      return [...exploreSessions, ...upcomingSessions]
        ..sort((a, b) => a.start.compareTo(b.start));
    },
    orElse: () => [],
  );
});

final _sessionCategoriesProvider = Provider<List<String>>((ref) {
  final sessions = ref.watch(_allSessionsProvider);
  return sessions
      .map((s) => s.category)
      .whereType<String>()
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
});

final _filteredSessionsProvider = Provider<List<UpcomingSessionData>>((ref) {
  final sessions = ref.watch(_allSessionsProvider);
  final category = ref.watch(selectedCategoryProvider);
  final onlyAttending = ref.watch(mySessionsFilterProvider);

  var filtered = sessions;

  if (onlyAttending) {
    filtered = filtered.where((s) => s.attending).toList();
  }

  if (category != null) {
    filtered = filtered.where((s) => s.category == category).toList();
  }

  return filtered;
});

final _groupedSessionsProvider = Provider<List<SessionDateGroup>>((ref) {
  final sessions = ref.watch(_filteredSessionsProvider);
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
      .map((e) => SessionDateGroup(date: e.key, sessions: e.value))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
});

class SpacesDiscoveryScreen extends ConsumerWidget {
  const SpacesDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(spacesSummaryProvider);
    final isMySessionsSelected = ref.watch(mySessionsFilterProvider);

    ref.sentryReportFullyDisplayed(spacesSummaryProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: summaryAsync.when(
          data: (_) => _buildContent(context, ref),
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

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final allSessions = ref.watch(_allSessionsProvider);
    final categories = ref.watch(_sessionCategoriesProvider);
    final filteredSessions = ref.watch(_filteredSessionsProvider);
    final groupedSessions = ref.watch(_groupedSessionsProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isMySessionsSelected = ref.watch(mySessionsFilterProvider);

    if (allSessions.isEmpty) {
      return EmptyIndicator(
        icon: TotemIcons.spacesFilled,
        text: 'No sessions available yet.',
        onRetry: () => ref.refresh(spacesSummaryProvider.future),
      );
    }

    return Column(
      children: [
        SessionsHeader(
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
                : _buildSessionsList(context, groupedSessions, DateTime.now()),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(WidgetRef ref, bool isMySessionsSelected) {
    return Column(
      children: [
        SessionsHeader(
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

    final hintMessage = isMySessionsSelected
        ? "You haven't joined any sessions yet"
        : 'Try selecting a different category';

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 100),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isMySessionsSelected ? Icons.event_busy : Icons.filter_list,
                size: 60,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No sessions in "$filterName"',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hintMessage,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionsList(
    BuildContext context,
    List<SessionDateGroup> groupedSessions,
    DateTime today,
  ) {
    final isLargeScreen = MediaQuery.widthOf(context) > 600;

    if (isLargeScreen) {
      // On large screens, skip date grouping and show a 2-column grid
      final allSessions = groupedSessions.expand((g) => g.sessions).toList();
      return GridView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: 100,
        ).copyWith(bottom: 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 16 / 14,
        ),
        itemCount: allSessions.length,
        itemBuilder: (_, index) => SessionCard(data: allSessions[index]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 20),
      itemCount: groupedSessions.length,
      itemBuilder: (_, index) => SessionDateGroupWidget(
        dateGroup: groupedSessions[index],
        today: today,
      ),
    );
  }
}
