import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';

class EventDetailScreen extends ConsumerWidget {
  final String eventSlug;

  const EventDetailScreen({super.key, required this.eventSlug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventSlug));

    return Scaffold(
      body: eventAsync.when(
        data: (event) => _buildEventDetail(context, event),
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (err, stack) => Center(
              child: Text(
                'Error loading event details: ${err.toString()}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
      ),
    );
  }

  Widget _buildEventDetail(BuildContext context, EventDetailSchema event) {
    // Format event duration
    final durationText =
        event.duration > 0 ? '${event.duration} min' : 'Duration not specified';

    // Format event start time
    final startDateTime = event.start;
    final dateFormat = DateFormat.yMMMMd(); // e.g., January 21, 2023
    final timeFormat = DateFormat.jm(); // e.g., 7:30 PM

    return CustomScrollView(
      slivers: [
        // App Bar with event title
        SliverAppBar(
          expandedHeight: 180.0,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              event.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 3.0,
                    color: Color.fromARGB(150, 0, 0, 0),
                  ),
                ],
              ),
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Event background (using a placeholder for now)
                Container(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.7),
                  child: const Center(
                    child: Icon(Icons.event, size: 50, color: Colors.white70),
                  ),
                ),
                // Gradient overlay for better text visibility
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share',
              onPressed: () {
                // Sharing functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sharing this event...')),
                );
              },
            ),
          ],
        ),

        // Content sections
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and time section
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 24),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateFormat.format(startDateTime),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${timeFormat.format(startDateTime)} • $durationText',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            if (event.recurring.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.repeat,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Recurring: ${event.recurring}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Host info (Space)
                Row(
                  children: [
                    Chip(
                      avatar: const Icon(Icons.groups, size: 16),
                      label: Text('Hosted by ${event.space.author.name}'),
                      backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(4),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View Space'),
                      onPressed: () {
                        context.push('/spaces/${event.space.slug}');
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Event status indicators
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (event.seatsLeft > 0)
                      _buildStatusChip(
                        '${event.seatsLeft} seats left',
                        Icons.chair,
                        Colors.green,
                      ),
                    if (event.price > 0)
                      _buildStatusChip(
                        _formatPrice(event.price),
                        Icons.attach_money,
                        Colors.amber,
                      ),
                    if (!event.open)
                      _buildStatusChip(
                        'Private event',
                        Icons.lock,
                        Colors.orange,
                      ),
                    if (event.subscribers > 0)
                      _buildStatusChip(
                        '${event.subscribers} attending',
                        Icons.person,
                        Colors.blue,
                      ),
                  ],
                ),

                const SizedBox(height: 24),

                // Description
                const Text(
                  'About this event',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Html(data: event.description),

                const SizedBox(height: 32),

                // Timezone info
                if (event.userTimezone != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Times shown in ${event.userTimezone}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 32),

                // Call to action buttons
                _buildActionButtons(context, event),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, EventDetailSchema event) {
    // Different buttons based on event state
    if (event.cancelled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.cancel, color: Colors.red, size: 32),
            const SizedBox(height: 8),
            const Text(
              'This event has been cancelled',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
      );
    }

    if (event.ended) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.replay),
          label: const Text('Event ended - View recording'),
          onPressed: () {
            // Navigate to recording
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    }

    if (event.started && event.joinable) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.video_call),
          label: const Text('Join Now'),
          onPressed: () {
            if (event.joinUrl != null) {
              // Launch join URL
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Joining event...')));
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    }

    // Default: upcoming event
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: const Text('Add to Calendar'),
                onPressed: () {
                  // Calendar functionality
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                icon:
                    event.attending
                        ? const Icon(Icons.check)
                        : const Icon(Icons.person_add),
                label: Text(event.attending ? 'Attending' : 'RSVP'),
                onPressed: () {
                  // RSVP functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        event.attending
                            ? 'You are already attending'
                            : 'RSVP confirmed!',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      event.attending
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        if (event.subscribed != null && event.subscribed!)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.notifications_active,
                  size: 16,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                const Text(
                  'You will receive notifications for this event',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatPrice(int price) {
    if (price == 0) return 'Free';
    // Assuming price is in cents
    final dollars = price / 100;
    return NumberFormat.currency(symbol: '\$').format(dollars);
  }
}
