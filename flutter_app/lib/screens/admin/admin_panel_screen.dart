import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

// ─── Admin Panel Screen ───────────────────────────────────────────────────────
class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(title: const Text('Admin Panel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin info banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(user?.displayRole ?? '', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('Management', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _AdminCard(icon: Icons.people_outline, label: 'Members', subtitle: 'Manage all members', color: AppTheme.primary, route: '/admin/members'),
                _AdminCard(icon: Icons.receipt_long_outlined, label: 'Expenses', subtitle: 'Track expenses', color: AppTheme.warning, route: '/admin/expenses'),
                _AdminCard(icon: Icons.pending_actions_outlined, label: 'Pending Dues', subtitle: 'View & collect dues', color: AppTheme.error, route: '/ledger'),
                _AdminCard(icon: Icons.inventory_2_outlined, label: 'Inventory', subtitle: 'Manage assets', color: AppTheme.success, route: '/inventory'),
              ],
            ),
            const SizedBox(height: 20),

            const Text('Tools', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _AdminCard(icon: Icons.auto_mode_outlined, label: 'Generate Maintenance', subtitle: 'Auto-create bills', color: AppTheme.info, onTap: () => _generateMaintenance(context, ref)),
                _AdminCard(icon: Icons.currency_rupee_outlined, label: 'Record Payment', subtitle: 'Log cash/cheque', color: const Color(0xFF8B5CF6), route: '/payments'),
                _AdminCard(icon: Icons.upload_file_outlined, label: 'Upload Document', subtitle: 'Notices & circulars', color: AppTheme.success, route: '/documents'),
                _AdminCard(icon: Icons.notifications_active_outlined, label: 'Send Notification', subtitle: 'Broadcast alert', color: AppTheme.error, onTap: () => _showNotifySheet(context, ref)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateMaintenance(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Generate Maintenance'),
        content: Text('Generate maintenance bills for all active members for ${_currentMonthYear()}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Generate')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.safePost('/ledger/generate-maintenance', data: {
        'month': DateTime.now().month,
        'year': DateTime.now().year,
      });
      AppSnackbar.showSuccess(context, 'Maintenance generated for ${res['created']} members');
    } catch (e) {
      AppSnackbar.showError(context, e.toString());
    }
  }

  void _showNotifySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SendNotificationSheet(),
    );
  }

  String _currentMonthYear() {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[DateTime.now().month - 1]} ${DateTime.now().year}';
  }
}

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final String? route;
  final VoidCallback? onTap;

  const _AdminCard({
    required this.icon, required this.label, required this.subtitle,
    required this.color, this.route, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? (route != null ? () => context.push(route!) : null),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const Spacer(),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _SendNotificationSheet extends ConsumerStatefulWidget {
  const _SendNotificationSheet();

  @override
  ConsumerState<_SendNotificationSheet> createState() => _SendNotificationSheetState();
}

class _SendNotificationSheetState extends ConsumerState<_SendNotificationSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _send() async {
    if (_titleCtrl.text.isEmpty || _bodyCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.safePost('/notifications/send', data: {
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'targetType': 'all',
        'type': 'general',
      });
      Navigator.pop(context);
      AppSnackbar.showSuccess(context, 'Notification sent to all members');
    } catch (e) {
      AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Send Notification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.title)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Message', prefixIcon: Icon(Icons.message_outlined)),
          ),
          const SizedBox(height: 20),
          AppButton(label: '📢 Send to All Members', onPressed: _isLoading ? null : _send, isLoading: _isLoading),
        ],
      ),
    );
  }
}

// ─── Members Screen ───────────────────────────────────────────────────────────
class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  String _search = '';
  String? _wing;

  @override
  Widget build(BuildContext context) {
    final params = <String, dynamic>{
      if (_search.isNotEmpty) 'search': _search,
      if (_wing != null) 'wing': _wing,
    };
    final membersAsync = ref.watch(membersListProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Members'),
        actions: [
          IconButton(icon: const Icon(Icons.person_add_outlined), onPressed: () => context.push('/admin/members/add')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Search by name, phone, or flat...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: membersAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: ShimmerLoader()),
              error: (e, _) => Center(child: Text('$e')),
              data: (members) => members.isEmpty
                  ? const EmptyState(icon: Icons.people_outline, title: 'No Members', subtitle: 'No members found')
                  : RefreshIndicator(
                      onRefresh: () async => ref.refresh(membersListProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: members.length,
                        itemBuilder: (_, i) => _MemberListTile(member: members[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberListTile extends StatelessWidget {
  final MemberModel member;
  const _MemberListTile({required this.member});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/admin/members/${member.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              child: Text(
                (member.user?.name ?? 'U')[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.user?.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(member.user?.phone ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(member.flatIdentifier,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary, fontSize: 13)),
                ),
                const SizedBox(height: 3),
                Text(formatCurrency(member.monthlyMaintenance),
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Placeholder screens ──────────────────────────────────────────────────────
class MemberDetailScreen extends ConsumerWidget {
  final String id;
  const MemberDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(memberDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Member Details')),
      body: memberAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: ShimmerLoader()),
        error: (e, _) => Center(child: Text('$e')),
        data: (member) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.divider)),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      child: Text((member.user?.name ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                    ),
                    const SizedBox(height: 12),
                    Text(member.user?.name ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(member.flatIdentifier, style: const TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 16),
                    InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: member.user?.phone ?? ''),
                    if (member.user?.email != null)
                      InfoRow(icon: Icons.email_outlined, label: 'Email', value: member.user!.email!),
                    InfoRow(icon: Icons.square_foot_outlined, label: 'Area', value: '${member.flatArea} sq.ft'),
                    InfoRow(icon: Icons.home_outlined, label: 'Ownership', value: member.ownershipType),
                    InfoRow(icon: Icons.currency_rupee_outlined, label: 'Monthly Maintenance', value: formatCurrency(member.monthlyMaintenance)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'View Ledger',
                onPressed: () => context.push('/ledger?memberId=${member.id}'),
                outlined: true,
                icon: Icons.receipt_long_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddMemberScreen extends StatelessWidget {
  const AddMemberScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Add Member')), body: const Center(child: Text('Add Member Form')));
}

// ─── Expenses Screen ──────────────────────────────────────────────────────────
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => context.push('/admin/expenses/add')),
        ],
      ),
      body: expensesAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: ShimmerLoader()),
        error: (e, _) => Center(child: Text('$e')),
        data: (expenses) => expenses.isEmpty
            ? const EmptyState(icon: Icons.receipt_outlined, title: 'No Expenses', subtitle: 'No expense records found')
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: expenses.length,
                itemBuilder: (_, i) {
                  final e = expenses[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.receipt_outlined, color: AppTheme.warning, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text('${e.category.replaceAll('_', ' ')} • ${formatDate(e.date)}',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(formatCurrency(e.amount), style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.error, fontSize: 15)),
                            StatusBadge(e.status),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'miscellaneous';
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.safePost('/expenses', data: {
        'title': _titleCtrl.text.trim(),
        'amount': double.parse(_amountCtrl.text),
        'category': _category,
        'description': _descCtrl.text.trim(),
      });
      ref.refresh(expensesProvider);
      context.pop();
      AppSnackbar.showSuccess(context, 'Expense recorded');
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
      appBar: AppBar(title: const Text('Add Expense')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title *', prefixIcon: Icon(Icons.title)),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (₹) *', prefixIcon: Icon(Icons.currency_rupee)),
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Invalid amount' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ['property_tax', 'water_bill', 'electricity_bill', 'security_salary',
                    'cleaning', 'lift_maintenance', 'repairs', 'garden', 'miscellaneous']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description_outlined)),
              ),
              const SizedBox(height: 24),
              AppButton(label: 'Save Expense', onPressed: _isLoading ? null : _submit, isLoading: _isLoading),
            ],
          ),
        ),
      ),
    );
  }
}
