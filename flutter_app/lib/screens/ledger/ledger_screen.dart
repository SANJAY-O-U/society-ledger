import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/common_widgets.dart';

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});
  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  int? _selectedMonth;
  int? _selectedYear;
  String? _memberId;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _loadMemberId();
  }

  void _loadMemberId() {
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user?.member != null) {
      setState(() => _memberId = user!.member!.id);
    }
  }

  LedgerParams get _params => LedgerParams(
    memberId: _memberId ?? '',
    month: _selectedMonth,
    year: _selectedYear,
  );

  @override
  Widget build(BuildContext context) {
    if (_memberId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ledger')),
        body: const EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No Member Profile',
          subtitle: 'Your account is not linked to a member profile yet. Please contact the admin.',
        ),
      );
    }

    final ledgerAsync = ref.watch(ledgerProvider(_params));

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('My Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: ledgerAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: ShimmerLoader()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final transactions = (data['data'] as List? ?? [])
              .map((t) => LedgerTransaction.fromJson(t))
              .toList();
          final summary = data['summary'] != null
              ? LedgerSummary.fromJson(data['summary'])
              : null;

          return Column(
            children: [
              // ─── Balance Summary Card ────────────────────────────────────
              if (summary != null) _SummaryCard(summary: summary),

              // ─── Filters ─────────────────────────────────────────────────
              _FilterChips(
                selectedMonth: _selectedMonth,
                selectedYear: _selectedYear,
                onClear: () => setState(() { _selectedMonth = null; _selectedYear = DateTime.now().year; }),
              ),

              // ─── Transaction List ────────────────────────────────────────
              Expanded(
                child: transactions.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No Transactions',
                        subtitle: 'No transactions found for selected filters',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: transactions.length,
                        itemBuilder: (_, i) => _TransactionTile(txn: transactions[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FilterSheet(
        selectedMonth: _selectedMonth,
        selectedYear: _selectedYear,
        onApply: (month, year) {
          setState(() { _selectedMonth = month; _selectedYear = year; });
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final LedgerSummary summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SumStat(label: 'Total Billed', value: formatCurrency(summary.totalDebit), color: Colors.white),
              _SumStat(label: 'Total Paid', value: formatCurrency(summary.totalCredit), color: const Color(0xFF86EFAC)),
              _SumStat(label: 'Pending', value: formatCurrency(summary.pendingAmount), color: const Color(0xFFFCA5A5)),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Current Balance: ', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text(
                formatCurrency(summary.currentBalance.abs()),
                style: TextStyle(
                  color: summary.currentBalance > 0 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Text(summary.currentBalance > 0 ? '(Due)' : '(Clear)',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SumStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SumStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    ],
  );
}

class _TransactionTile extends StatelessWidget {
  final LedgerTransaction txn;
  const _TransactionTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final isCredit = txn.isCredit;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: isCredit ? AppTheme.success.withOpacity(0.1) : AppTheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isCredit ? AppTheme.success : AppTheme.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  Text(formatDate(txn.date), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(width: 8),
                  StatusBadge(txn.status),
                ]),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}${formatCurrency(txn.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15,
                  color: isCredit ? AppTheme.success : AppTheme.error,
                ),
              ),
              Text('Bal: ${formatCurrency(txn.balance)}', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final int? selectedMonth, selectedYear;
  final VoidCallback onClear;
  const _FilterChips({this.selectedMonth, this.selectedYear, required this.onClear});

  @override
  Widget build(BuildContext context) {
    if (selectedMonth == null && selectedYear == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        if (selectedMonth != null) Chip(
          label: Text(['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][selectedMonth! - 1]),
          backgroundColor: AppTheme.primary.withOpacity(0.1),
          labelStyle: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w500),
        ),
        if (selectedYear != null) ...[
          const SizedBox(width: 8),
          Chip(
            label: Text('$selectedYear'),
            backgroundColor: AppTheme.primary.withOpacity(0.1),
            labelStyle: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w500),
          ),
        ],
        const Spacer(),
        TextButton(onPressed: onClear, child: const Text('Clear')),
      ]),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final int? selectedMonth, selectedYear;
  final Function(int?, int?) onApply;
  const _FilterSheet({this.selectedMonth, this.selectedYear, required this.onApply});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  int? _month, _year;

  @override
  void initState() {
    super.initState();
    _month = widget.selectedMonth;
    _year = widget.selectedYear;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          const Text('Month', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: List.generate(12, (i) {
              final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
              return ChoiceChip(
                label: Text(months[i]),
                selected: _month == i + 1,
                onSelected: (v) => setState(() => _month = v ? i + 1 : null),
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(color: _month == i + 1 ? Colors.white : AppTheme.textPrimary),
              );
            }),
          ),
          const SizedBox(height: 20),
          const Text('Year', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(3, (i) {
              final year = DateTime.now().year - i;
              return ChoiceChip(
                label: Text('$year'),
                selected: _year == year,
                onSelected: (v) => setState(() => _year = v ? year : null),
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(color: _year == year ? Colors.white : AppTheme.textPrimary),
              );
            }),
          ),
          const SizedBox(height: 24),
          AppButton(label: 'Apply Filter', onPressed: () => widget.onApply(_month, _year)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// Placeholder detail screen
class TransactionDetailScreen extends StatelessWidget {
  final String id;
  const TransactionDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Transaction Detail')),
    body: Center(child: Text('Transaction: $id')),
  );
}
