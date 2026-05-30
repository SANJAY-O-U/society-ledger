import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showCalendar = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final isManagement = user?.isManagement ?? false;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Events & Notices'),
        actions: [
          IconButton(
            icon: Icon(_showCalendar ? Icons.list_rounded : Icons.calendar_month_outlined),
            onPressed: () => setState(() => _showCalendar = !_showCalendar),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [Tab(text: 'Upcoming'), Tab(text: 'All Events')],
        ),
      ),
      floatingActionButton: isManagement
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateEventSheet(context),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create Event', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: Column(
        children: [
          if (_showCalendar) _EventCalendar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _EventsList(upcomingOnly: true),
                _EventsList(upcomingOnly: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateEventSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateEventSheet(),
    );
  }
}

class _EventsList extends ConsumerWidget {
  final bool upcomingOnly;
  const _EventsList({required this.upcomingOnly});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = upcomingOnly ? {'upcoming': 'true'} : <String, dynamic>{};
    final eventsAsync = ref.watch(eventsProvider);

    return eventsAsync.when(
      loading: () => const Padding(padding: EdgeInsets.all(16), child: ShimmerLoader()),
      error: (e, _) => Center(child: Text('$e')),
      data: (events) => events.isEmpty
          ? const EmptyState(
              icon: Icons.event_outlined,
              title: 'No Events',
              subtitle: 'No events scheduled at this time',
            )
          : RefreshIndicator(
              onRefresh: () async => ref.refresh(eventsProvider),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                itemBuilder: (_, i) => _EventCard(event: events[i]),
              ),
            ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventModel event;
  const _EventCard({required this.event});

  Color get _categoryColor {
    switch (event.category) {
      case 'meeting': return AppTheme.primary;
      case 'festival': return const Color(0xFFD97706);
      case 'maintenance_notice': return AppTheme.error;
      case 'sports': return AppTheme.success;
      default: return AppTheme.info;
    }
  }

  IconData get _categoryIcon {
    switch (event.category) {
      case 'meeting': return Icons.groups_outlined;
      case 'festival': return Icons.celebration_outlined;
      case 'maintenance_notice': return Icons.build_outlined;
      case 'sports': return Icons.sports_outlined;
      default: return Icons.event_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/events/${event.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Date box
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _categoryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    event.startDate.day.toString(),
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _categoryColor),
                  ),
                  Text(
                    formatDate(event.startDate, pattern: 'MMM'),
                    style: TextStyle(fontSize: 12, color: _categoryColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_categoryIcon, size: 14, color: _categoryColor),
                        const SizedBox(width: 4),
                        Text(
                          event.category.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(fontSize: 10, color: _categoryColor, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(event.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_outlined, size: 12, color: AppTheme.textTertiary),
                        const SizedBox(width: 3),
                        Text(formatDate(event.startDate, pattern: 'h:mm a'),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        if (event.venue != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textTertiary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(event.venue!,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ],
                    ),
                    if (event.rsvpCount > 0) ...[
                      const SizedBox(height: 4),
                      Text('${event.rsvpCount} attending',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                    ],
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCalendar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);

    return Container(
      color: Colors.white,
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: DateTime.now(),
        calendarStyle: const CalendarStyle(
          selectedDecoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle),
          markerDecoration: BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        eventLoader: (day) {
          if (eventsAsync.value == null) return [];
          return eventsAsync.value!.where((e) => isSameDay(e.startDate, day)).toList();
        },
        onDaySelected: (selected, focused) {},
      ),
    );
  }
}

// ─── Event Detail Screen ──────────────────────────────────────────────────────
class EventDetailScreen extends ConsumerWidget {
  final String id;
  const EventDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(id));

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      body: eventAsync.when(
        loading: () => const Scaffold(body: Padding(padding: EdgeInsets.all(16), child: ShimmerLoader())),
        error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
        data: (event) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary.withOpacity(0.8), AppTheme.primaryDark],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: const Center(child: Icon(Icons.event_outlined, color: Colors.white, size: 64)),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Details card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        InfoRow(icon: Icons.calendar_today_outlined, label: 'Date',
                            value: formatDate(event.startDate, pattern: 'EEEE, d MMMM yyyy')),
                        InfoRow(icon: Icons.access_time_outlined, label: 'Time',
                            value: '${formatDate(event.startDate, pattern: 'h:mm a')} – ${formatDate(event.endDate, pattern: 'h:mm a')}'),
                        if (event.venue != null)
                          InfoRow(icon: Icons.location_on_outlined, label: 'Venue', value: event.venue!),
                        InfoRow(icon: Icons.people_outline, label: 'Category',
                            value: event.category.replaceAll('_', ' ')),
                        const SizedBox(height: 12),
                        if (event.description.isNotEmpty)
                          Text(event.description,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.6)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // RSVP buttons
                  const Text('Will you attend?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _RSVPButton(eventId: event.id, status: 'attending', label: '✅ Yes', color: AppTheme.success)),
                      const SizedBox(width: 10),
                      Expanded(child: _RSVPButton(eventId: event.id, status: 'maybe', label: '🤔 Maybe', color: AppTheme.warning)),
                      const SizedBox(width: 10),
                      Expanded(child: _RSVPButton(eventId: event.id, status: 'not_attending', label: '❌ No', color: AppTheme.error)),
                    ],
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RSVPButton extends ConsumerStatefulWidget {
  final String eventId, status, label;
  final Color color;
  const _RSVPButton({required this.eventId, required this.status, required this.label, required this.color});

  @override
  ConsumerState<_RSVPButton> createState() => _RSVPButtonState();
}

class _RSVPButtonState extends ConsumerState<_RSVPButton> {
  bool _loading = false;

  Future<void> _rsvp() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.safePost('/events/${widget.eventId}/rsvp', data: {'status': widget.status});
      AppSnackbar.showSuccess(context, 'RSVP updated!');
    } catch (e) {
      AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: _loading ? null : _rsvp,
    style: OutlinedButton.styleFrom(
      foregroundColor: widget.color,
      side: BorderSide(color: widget.color),
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: _loading
        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: widget.color, strokeWidth: 2))
        : Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
  );
}

class _CreateEventSheet extends ConsumerStatefulWidget {
  const _CreateEventSheet();

  @override
  ConsumerState<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends ConsumerState<_CreateEventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  String _category = 'meeting';
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1, hours: 2));
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.safePost('/events', data: {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _category,
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate.toIso8601String(),
        'venue': _venueCtrl.text.trim(),
        'isPublished': true,
      });
      ref.refresh(eventsProvider);
      Navigator.pop(context);
      AppSnackbar.showSuccess(context, 'Event created!');
    } catch (e) {
      AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Create New Event', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Event Title *'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ['meeting', 'festival', 'maintenance_notice', 'sports', 'cultural', 'other']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' ').toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _venueCtrl,
                decoration: const InputDecoration(labelText: 'Venue', prefixIcon: Icon(Icons.location_on_outlined)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 20),
              AppButton(label: 'Create Event', onPressed: _isLoading ? null : _submit, isLoading: _isLoading),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
