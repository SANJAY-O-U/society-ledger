import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

// ─── Complaints List Screen ───────────────────────────────────────────────────
class ComplaintsScreen extends ConsumerStatefulWidget {
  const ComplaintsScreen({super.key});
  @override
  ConsumerState<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends ConsumerState<ComplaintsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _statusFilters = ['all', 'open', 'in_progress', 'resolved', 'closed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusFilters.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Complaints & Issues'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: _statusFilters.map((s) => Tab(text: s == 'all' ? 'All' : s.replaceAll('_', ' ').toUpperCase())).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/complaints/create'),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Complaint', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statusFilters.map((status) => _ComplaintsList(
          status: status == 'all' ? null : status,
        )).toList(),
      ),
    );
  }
}

class _ComplaintsList extends ConsumerWidget {
  final String? status;
  const _ComplaintsList({this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(complaintsProvider(status ?? ''));

    return complaintsAsync.when(
      loading: () => const Padding(padding: EdgeInsets.all(16), child: ShimmerLoader()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (complaints) => complaints.isEmpty
          ? const EmptyState(
              icon: Icons.feedback_outlined,
              title: 'No Complaints',
              subtitle: 'No complaints found in this category',
            )
          : RefreshIndicator(
              onRefresh: () async => ref.refresh(complaintsProvider(status ?? '')),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: complaints.length,
                itemBuilder: (_, i) => _ComplaintCard(complaint: complaints[i]),
              ),
            ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final ComplaintModel complaint;
  const _ComplaintCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/complaints/${complaint.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(complaint.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                PriorityBadge(complaint.priority),
              ],
            ),
            const SizedBox(height: 6),
            Text(complaint.description,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Row(
              children: [
                StatusBadge(complaint.status),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(complaint.category.replaceAll('_', ' '),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ),
                const Spacer(),
                Text(formatDate(complaint.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
              ],
            ),
            if (complaint.responses.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.reply_outlined, size: 14, color: AppTheme.textTertiary),
                  const SizedBox(width: 4),
                  Text('${complaint.responses.length} response(s)',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Complaint Detail Screen ──────────────────────────────────────────────────
class ComplaintDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const ComplaintDetailScreen({super.key, required this.id});

  @override
  ConsumerState<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends ConsumerState<ComplaintDetailScreen> {
  final _responseCtrl = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _responseCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitResponse() async {
    if (_responseCtrl.text.trim().isEmpty) return;
    setState(() => _isSending = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.safePost('/complaints/${widget.id}/respond', data: {
        'message': _responseCtrl.text.trim(),
        'isInternal': false,
      });
      _responseCtrl.clear();
      ref.refresh(complaintDetailProvider(widget.id));
      AppSnackbar.showSuccess(context, 'Response submitted');
    } catch (e) {
      AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.safePut('/complaints/${widget.id}/status', data: {'status': status});
      ref.refresh(complaintDetailProvider(widget.id));
      AppSnackbar.showSuccess(context, 'Status updated to $status');
    } catch (e) {
      AppSnackbar.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final complaintAsync = ref.watch(complaintDetailProvider(widget.id));
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final isManagement = user?.isManagement ?? false;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Complaint Details'),
        actions: [
          if (isManagement)
            PopupMenuButton<String>(
              onSelected: _updateStatus,
              itemBuilder: (_) => ['in_progress', 'resolved', 'closed', 'rejected']
                  .map((s) => PopupMenuItem(value: s, child: Text(s.replaceAll('_', ' ').toUpperCase())))
                  .toList(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.more_vert),
              ),
            ),
        ],
      ),
      body: complaintAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: ShimmerLoader(count: 4, height: 120)),
        error: (e, _) => Center(child: Text('$e')),
        data: (complaint) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Header ────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(complaint.title,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              ),
                              PriorityBadge(complaint.priority),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            StatusBadge(complaint.status),
                            const SizedBox(width: 8),
                            Text('# ${complaint.ticketNumber}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ]),
                          const SizedBox(height: 12),
                          Text(complaint.description,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5)),
                          const SizedBox(height: 12),
                          InfoRow(icon: Icons.category_outlined, label: 'Category',
                              value: complaint.category.replaceAll('_', ' ')),
                          InfoRow(icon: Icons.calendar_today_outlined, label: 'Raised on',
                              value: formatDate(complaint.createdAt)),
                        ],
                      ),
                    ),

                    // ─── Images ────────────────────────────────────────
                    if (complaint.images.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Attachments', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: complaint.images.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              complaint.images[i],
                              width: 100, height: 100, fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // ─── Responses ─────────────────────────────────────
                    if (complaint.responses.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Responses', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 8),
                      ...complaint.responses
                          .where((r) => !r.isInternal)
                          .map((r) => _ResponseBubble(response: r)),
                    ],

                    // ─── Rating (if resolved) ──────────────────────────
                    if (complaint.isResolved && complaint.rating == null) ...[
                      const SizedBox(height: 16),
                      _RatingCard(complaintId: complaint.id),
                    ],

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // ─── Reply Box ─────────────────────────────────────────────
            if (!complaint.isResolved)
              Container(
                padding: EdgeInsets.only(
                  left: 16, right: 16, top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, -2))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _responseCtrl,
                        decoration: InputDecoration(
                          hintText: 'Add a response...',
                          filled: true,
                          fillColor: AppTheme.surfaceLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _isSending ? null : _submitResponse,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: _isSending
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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
}

class _ResponseBubble extends StatelessWidget {
  final ComplaintResponse response;
  const _ResponseBubble({required this.response});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(response.respondedByName ?? 'Staff',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.primary)),
              const Spacer(),
              Text(formatDate(response.timestamp, pattern: 'd MMM, h:mm a'),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
            ],
          ),
          const SizedBox(height: 6),
          Text(response.message,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}

class _RatingCard extends ConsumerStatefulWidget {
  final String complaintId;
  const _RatingCard({required this.complaintId});

  @override
  ConsumerState<_RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends ConsumerState<_RatingCard> {
  int _rating = 0;
  final _feedbackCtrl = TextEditingController();

  Future<void> _submitRating() async {
    if (_rating == 0) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.safePut('/complaints/${widget.complaintId}/feedback', data: {
        'rating': _rating,
        'feedback': _feedbackCtrl.text,
      });
      ref.refresh(complaintDetailProvider(widget.complaintId));
      AppSnackbar.showSuccess(context, 'Feedback submitted!');
    } catch (e) {
      AppSnackbar.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rate this resolution', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (i) => GestureDetector(
              onTap: () => setState(() => _rating = i + 1),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: AppTheme.warning, size: 32,
                ),
              ),
            )),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _feedbackCtrl,
            decoration: const InputDecoration(hintText: 'Optional feedback...'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          AppButton(label: 'Submit Feedback', onPressed: _rating > 0 ? _submitRating : null),
        ],
      ),
    );
  }
}

// ─── Create Complaint Screen ──────────────────────────────────────────────────
class CreateComplaintScreen extends ConsumerStatefulWidget {
  const CreateComplaintScreen({super.key});

  @override
  ConsumerState<CreateComplaintScreen> createState() => _CreateComplaintScreenState();
}

class _CreateComplaintScreenState extends ConsumerState<CreateComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'maintenance';
  String _priority = 'medium';
  List<XFile> _images = [];
  bool _isLoading = false;

  final _categories = ['maintenance', 'water', 'electricity', 'security',
      'cleanliness', 'parking', 'noise', 'neighbor', 'structural', 'suggestion', 'other'];
  final _priorities = ['low', 'medium', 'high', 'urgent'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 70);
    setState(() => _images = images.take(5).toList());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _category,
        'priority': _priority,
        ..._images.asMap().map((i, f) => MapEntry(
            'images', MultipartFile.fromFileSync(f.path, filename: f.name))),
      });

      await dio.post('/complaints', data: formData);
      ref.refresh(complaintsProvider(''));
      AppSnackbar.showSuccess(context, 'Complaint submitted successfully');
      context.pop();
    } catch (e) {
      AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(title: const Text('Raise Complaint')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title *', prefixIcon: Icon(Icons.title)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 14),

              // Description
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description *', prefixIcon: Icon(Icons.description_outlined)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
              ),
              const SizedBox(height: 14),

              // Category
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
                items: _categories.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontSize: 13)),
                )).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 14),

              // Priority
              const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: _priorities.map((p) => GestureDetector(
                  onTap: () => setState(() => _priority = p),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _priority == p ? AppTheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _priority == p ? AppTheme.primary : AppTheme.divider),
                    ),
                    child: Text(p.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: _priority == p ? Colors.white : AppTheme.textSecondary,
                        )),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),

              // Images
              const Text('Attach Images (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider, style: BorderStyle.solid),
                  ),
                  child: _images.isEmpty
                      ? const Center(child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: AppTheme.textTertiary),
                            SizedBox(width: 8),
                            Text('Add Photos', style: TextStyle(color: AppTheme.textTertiary)),
                          ]))
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(8),
                          itemCount: _images.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(_images[i].path, width: 64, height: 64, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 0, right: 0,
                                child: GestureDetector(
                                  onTap: () => setState(() => _images.removeAt(i)),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 28),

              AppButton(
                label: 'Submit Complaint',
                onPressed: _isLoading ? null : _submit,
                isLoading: _isLoading,
                icon: Icons.send_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}