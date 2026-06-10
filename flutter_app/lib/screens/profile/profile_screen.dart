// ============================================================
// inventory_screen.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../providers/theme_provider.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _search = '';
  String? _category;
  String? _status;
  Timer? _debounce;
  String _debouncedSearch = '';
  String get _filterKey => 'search:$_debouncedSearch|category:${_category ?? ''}|status:${_status ?? ''}';
  Map<String, dynamic> get _params => {
    if (_search.isNotEmpty) 'search': _search,
    if (_category != null) 'category': _category,
    if (_status != null) 'status': _status,
  };
  @override
void dispose() {
  _debounce?.cancel();
  super.dispose();
}
  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          if (user?.isManagement == true)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _showAddItemSheet(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 400), () {
    if (mounted) setState(() {
      _search = v;
      _debouncedSearch = v;
    });
  });
},
                  decoration: InputDecoration(
                    hintText: 'Search inventory...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _search = ''))
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(label: 'All', selected: _status == null, onTap: () => setState(() => _status = null)),
                      _FilterChip(label: 'Available', selected: _status == 'available', onTap: () => setState(() => _status = 'available')),
                      _FilterChip(label: 'In Use', selected: _status == 'in_use', onTap: () => setState(() => _status = 'in_use')),
                      _FilterChip(label: 'Maintenance', selected: _status == 'maintenance', onTap: () => setState(() => _status = 'maintenance')),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: inventoryAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: ShimmerLoader()),
              error: (e, _) => Center(child: Text('$e')),
              data: (items) => items.isEmpty
                  ? const EmptyState(icon: Icons.inventory_2_outlined, title: 'No Items', subtitle: 'No inventory items found')
                  : RefreshIndicator(
                      onRefresh: () async => ref.refresh(inventoryProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: items.length,
                        itemBuilder: (_, i) => _InventoryTile(item: items[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddInventorySheet(),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppTheme.primary : AppTheme.divider),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w500,
        color: selected ? Colors.white : AppTheme.textSecondary,
      )),
    ),
  );
}

class _InventoryTile extends StatelessWidget {
  final InventoryItem item;
  const _InventoryTile({required this.item});

  Color get _statusColor {
    switch (item.status) {
      case 'available': return AppTheme.success;
      case 'in_use': return AppTheme.warning;
      case 'maintenance': return AppTheme.info;
      default: return AppTheme.error;
    }
  }

  IconData get _categoryIcon {
    switch (item.category) {
      case 'electronics': return Icons.devices_outlined;
      case 'furniture': return Icons.chair_outlined;
      case 'tools': return Icons.build_outlined;
      case 'sports': return Icons.sports_outlined;
      default: return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_categoryIcon, color: _statusColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text('${item.category} • ${item.location ?? 'No location'}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(item.status),
              const SizedBox(height: 4),
              Text('${item.availableQuantity}/${item.quantity} available',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddInventorySheet extends ConsumerStatefulWidget {
  const _AddInventorySheet();

  @override
  ConsumerState<_AddInventorySheet> createState() => _AddInventorySheetState();
}

class _AddInventorySheetState extends ConsumerState<_AddInventorySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _locationCtrl = TextEditingController();
  String _category = 'other';
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.safePost('/inventory', data: {
        'itemName': _nameCtrl.text.trim(),
        'category': _category,
        'quantity': int.parse(_qtyCtrl.text),
        'location': _locationCtrl.text.trim(),
      });
      ref.refresh(inventoryProvider);
      Navigator.pop(context);
      AppSnackbar.showSuccess(context, 'Item added to inventory');
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
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Inventory Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Item Name *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: ['furniture', 'electronics', 'tools', 'cleaning', 'sports', 'event', 'safety', 'other']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase())))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  validator: (v) => (v == null || int.tryParse(v) == null) ? 'Invalid' : null,
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(labelText: 'Location'),
                )),
              ],
            ),
            const SizedBox(height: 20),
            AppButton(label: 'Add Item', onPressed: _isLoading ? null : _submit, isLoading: _isLoading),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// documents_screen.dart
// ============================================================
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final params = _category != null ? {'category': _category} : <String, dynamic>{};
    final docsAsync = ref.watch(documentsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          if (user?.isManagement == true)
            IconButton(icon: const Icon(Icons.upload_file_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Category chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [null, 'notice', 'agm', 'circular', 'bill', 'policy', 'financial', 'other']
                  .map((c) => GestureDetector(
                    onTap: () => setState(() => _category = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: _category == c ? AppTheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _category == c ? AppTheme.primary : AppTheme.divider),
                      ),
                      child: Text(c == null ? 'All' : c.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500,
                            color: _category == c ? Colors.white : AppTheme.textSecondary,
                          )),
                    ),
                  ))
                  .toList(),
            ),
          ),

          Expanded(
            child: docsAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: ShimmerLoader()),
              error: (e, _) => Center(child: Text('$e')),
              data: (docs) => docs.isEmpty
                  ? const EmptyState(icon: Icons.folder_outlined, title: 'No Documents', subtitle: 'No documents available')
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (_, i) => _DocumentTile(doc: docs[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final DocumentModel doc;
  const _DocumentTile({required this.doc});

  IconData get _icon => doc.isPdf ? Icons.picture_as_pdf_outlined : Icons.description_outlined;
  Color get _iconColor => doc.isPdf ? AppTheme.error : AppTheme.primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(_icon, color: _iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  Text(doc.category.toUpperCase(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  const SizedBox(width: 8),
                  Text(formatDate(doc.createdAt), style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                ]),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined, color: AppTheme.primary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

// ============================================================
// profile_screen.dart
// ============================================================
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
  icon: const Icon(Icons.upload_file_outlined),
  onPressed: () => _showUploadDialog(context, ref),
),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppTheme.divider)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(user.displayRole, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  const SizedBox(height: 10),
                  if (user.member != null)
                    Text('Flat ${user.member!.flatIdentifier}', style: const TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Info section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Contact Information', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  InfoRow(icon: Icons.phone_outlined, label: 'Mobile', value: '+91 ${user.phone}'),
                  if (user.email != null)
                    InfoRow(icon: Icons.email_outlined, label: 'Email', value: user.email!),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Menu items
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                children: [
                  _ProfileMenuItem(icon: Icons.receipt_long_outlined, label: 'Transaction History', onTap: () => context.push('/payments/history')),
                  _ProfileMenuItem(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notifications coming soon'), behavior: SnackBarBehavior.floating),
                    );
                  }),
                  _ProfileMenuItem(icon: Icons.security_outlined, label: 'Change Password', onTap: () => _showChangePasswordDialog(context, ref)),
                  _ProfileMenuItem(icon: Icons.dark_mode_outlined, label: 'Dark Mode', onTap: () {
                    final themeMode = ref.read(themeModeProvider);
                    ref.read(themeModeProvider.notifier).state =
                        themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                  }),
                  if (user.isManagement)
                    _ProfileMenuItem(icon: Icons.admin_panel_settings_outlined, label: 'Admin Panel', color: AppTheme.primary, onTap: () => context.push('/admin')),
                  _ProfileMenuItem(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    color: AppTheme.error,
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Confirm Logout'),
                          content: const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Logout', style: TextStyle(color: AppTheme.error)),
                            ),
                          ],
                        ),
                      );
                     if (confirm == true) {
                        await ref.read(authNotifierProvider.notifier).logout();
                        
                     }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  void _showUploadDialog(BuildContext context, WidgetRef ref) {
  final titleCtrl = TextEditingController();
  String category = 'notice';

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Upload Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Document Title *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: ['notice', 'agm', 'circular', 'bill', 'policy', 'financial', 'other']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase())))
                  .toList(),
              onChanged: (v) => setState(() => category = v!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title is required')));
                return;
              }
              Navigator.pop(ctx);
              await _pickAndUploadFile(context, ref, titleCtrl.text.trim(), category);
            },
            child: const Text('Pick File'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _pickAndUploadFile(
    BuildContext context, WidgetRef ref, String title, String category) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) {
      AppSnackbar.showError(context, 'Could not access file');
      return;
    }

    final dio = ref.read(dioProvider);
    final formData = FormData.fromMap({
      'title': title,
      'category': category,
      'notify': 'true',
      'file': await MultipartFile.fromFile(
        file.path!,
        filename: file.name,
      ),
    });

    await dio.post('/documents', data: formData);
    ref.refresh(documentsProvider);
    ref.refresh(documentsProvider);
    AppSnackbar.showSuccess(context, 'Document uploaded successfully!');
  } catch (e) {
    AppSnackbar.showError(context, e.toString());
  }
}
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ProfileMenuItem({required this.icon, required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color ?? AppTheme.textSecondary, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color ?? AppTheme.textPrimary))),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}

void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
  final currentCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  bool loading = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: loading ? null : () async {
              if (newCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 6 characters')),
                );
                return;
              }
              setState(() => loading = true);
              try {
                final dio = ref.read(dioProvider);
                await dio.safePut('/auth/change-password', data: {
                  'currentPassword': currentCtrl.text,
                  'newPassword': newCtrl.text,
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password changed successfully'), backgroundColor: AppTheme.success),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
                );
              } finally {
                setState(() => loading = false);
              }
            },
            child: loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Update', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    ),
  );
}

// ─── Placeholder screens ──────────────────────────────────────────────────────
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Edit Profile')), body: const Center(child: Text('Edit Profile')));
}