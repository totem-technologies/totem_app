import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/models/summary_spaces_schema.dart';
import 'package:totem_app/features/home/models/upcoming_session_data.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/features/spaces/widgets/filter.dart';
import 'package:totem_app/features/spaces/widgets/session_date_group.dart';
import 'package:totem_app/features/spaces/widgets/sessions_header.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/utils.dart';
import 'package:totem_app/shared/widgets/empty_indicator.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

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
}

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
                : _buildSessionsList(groupedSessions),
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

  Widget _buildSessionsList(List<SessionDateGroup> groupedSessions) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 20),
      itemCount: groupedSessions.length,
      itemBuilder: (_, index) => SessionDateGroupWidget(
        dateGroup: groupedSessions[index],
      ),
    );
  }

  List<UpcomingSessionData> _extractAllSessions(SummarySpacesSchema summary) {
    final now = DateTime.now();
    final sessions = <UpcomingSessionData>[];

    for (final space in summary.explore) {
      for (final event in space.nextEvents) {
        final isFutureSession = event.start.isAfter(now);
        final hasAvailableSeats = event.seatsLeft > 0;
        final userIsAttending = event.attending;

        if (isFutureSession && (hasAvailableSeats || userIsAttending)) {
          sessions.add(UpcomingSessionData.fromSpaceAndSession(space, event));
        }
      }
    }

    return sessions..sort((a, b) => a.start.compareTo(b.start));
  }

  List<String> _extractCategories(List<UpcomingSessionData> sessions) {
    return sessions
        .map((s) => s.category)
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

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

  List<SessionDateGroup> _groupSessionsByDate(
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
        .map((e) => SessionDateGroup(date: e.key, sessions: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}
