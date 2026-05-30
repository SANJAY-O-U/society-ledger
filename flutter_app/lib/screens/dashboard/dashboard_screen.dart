import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/common_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FIX: select() only rebuilds when isManagement changes (login/role change),
    // not on every auth state emission.
    final isManagement = ref.watch(
      authNotifierProvider.select((s) => s.valueOrNull?.isManagement ?? false),
    );

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      body: SafeArea(
        child: isManagement
            ? const _AdminDashboard()
            : const _MemberDashboard(),
      ),
    );
  }
}

// ─── Admin Dashboard ───────────────────────────────────────────────────────────
class _AdminDashboard extends ConsumerWidget {
  const _AdminDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(adminDashboardProvider);
    // FIX: use .select() to only rebuild when name/role changes,
    // not on any auth state change. Previously watched full authNotifierProvider
    // which rebuilt the entire dashboard on any auth event.
    final userName = ref.watch(
      authNotifierProvider.select((s) => s.valueOrNull?.name),
    );
    final userRole = ref.watch(
      authNotifierProvider.select((s) => s.valueOrNull?.displayRole),
    );

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(adminDashboardProvider),
      child: CustomScrollView(
        slivers: [
          // ─── App Bar ─────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Good ${_greeting()}, ${userName?.split(' ').first ?? 'User'}! 👋',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(userRole ?? '', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
                onPressed: () => context.push('/admin'),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: dashAsync.when(
              loading: () => const SliverToBoxAdapter(child: ShimmerLoader(count: 6, height: 100)),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(child: Text('Error: $e')),
              ),
              data: (data) => SliverList(
                delegate: SliverChildListDelegate([
                  // ─── Finance Stats Grid ─────────────────────────────────
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: [
                      StatCard(
                        title: 'Monthly Collection',
                        value: formatCurrency(data.finance.monthlyCollection),
                        icon: Icons.trending_up_rounded,
                        color: AppTheme.success,
                        subtitle: 'This month',
                        onTap: () => context.push('/payments/history'),
                      ),
                      StatCard(
                        title: 'Pending Dues',
                        value: formatCurrency(data.finance.totalPendingDues),
                        icon: Icons.pending_actions_rounded,
                        color: AppTheme.error,
                        subtitle: 'Outstanding',
                        onTap: () => context.push('/ledger'),
                      ),
                      StatCard(
                        title: 'Monthly Expense',
                        value: formatCurrency(data.finance.monthlyExpenses),
                        icon: Icons.receipt_outlined,
                        color: AppTheme.warning,
                        onTap: () => context.push('/admin/expenses'),
                      ),
                      StatCard(
                        title: 'Active Members',
                        value: '${data.members.active}',
                        icon: Icons.people_outline_rounded,
                        color: AppTheme.primary,
                        subtitle: '${data.members.total} total',
                        onTap: () => context.push('/admin/members'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ─── Complaints Row ─────────────────────────────────────
                  Row(children: [
                    Expanded(child: _MiniStatCard(
                      label: 'Open Complaints',
                      value: '${data.complaints.open}',
                      icon: Icons.bug_report_outlined,
                      color: AppTheme.error,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _MiniStatCard(
                      label: 'In Progress',
                      value: '${data.complaints.inProgress}',
                      icon: Icons.pending_outlined,
                      color: AppTheme.warning,
                    )),
                  ]),
                  const SizedBox(height: 20),

                  // ─── Collection Trend Chart ─────────────────────────────
                  if (data.collectionTrend.isNotEmpty) ...[
                    const SectionHeader(title: 'Collection Trend'),
                    const SizedBox(height: 12),
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: _CollectionChart(points: data.collectionTrend),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ─── Expense Breakdown ──────────────────────────────────
                  if (data.expenseByCategory.isNotEmpty) ...[
                    const SectionHeader(title: 'Expense Breakdown'),
                    const SizedBox(height: 12),
                    Container(
                      height: 180,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: _ExpensePieChart(points: data.expenseByCategory),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ─── Quick Actions ──────────────────────────────────────
                  const SectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: 12),
                  _QuickActionsGrid(),
                  const SizedBox(height: 20),

                  // ─── Upcoming Events ────────────────────────────────────
                  if (data.upcomingEvents.isNotEmpty) ...[
                    SectionHeader(title: 'Upcoming Events', actionLabel: 'View All', onAction: () => context.push('/events')),
                    const SizedBox(height: 12),
                    ...data.upcomingEvents.map((e) => _EventItem(event: e)),
                    const SizedBox(height: 20),
                  ],

                  // ─── Recent Payments ────────────────────────────────────
                  if (data.recentPayments.isNotEmpty) ...[
                    SectionHeader(title: 'Recent Payments', actionLabel: 'View All', onAction: () => context.push('/payments/history')),
                    const SizedBox(height: 12),
                    ...data.recentPayments.map((p) => _PaymentItem(payment: p)),
                  ],
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

// ─── Member Dashboard ──────────────────────────────────────────────────────────
class _MemberDashboard extends ConsumerWidget {
  const _MemberDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(memberDashboardProvider);
    // FIX: select() so only name changes trigger rebuild, not full auth state
    final userName = ref.watch(
      authNotifierProvider.select((s) => s.valueOrNull?.name),
    );

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(memberDashboardProvider),
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppTheme.primary,
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                child: dashAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Hi, ${userName?.split(' ').first ?? 'User'}! 👋',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Flat ${data['data']?['member']?['wing']}-${data['data']?['member']?['flatNumber']}',
                          style: TextStyle(color: Colors.white.withOpacity(0.8))),
                      const SizedBox(height: 12),
                      Row(children: [
                        _HeaderStat(
                          label: 'Pending Dues',
                          value: formatCurrency((data['data']?['finance']?['pendingDues'] ?? 0).toDouble()),
                          color: AppTheme.warning,
                        ),
                        const SizedBox(width: 20),
                        _HeaderStat(
                          label: 'Monthly',
                          value: formatCurrency((data['data']?['member']?['monthlyMaintenance'] ?? 0).toDouble()),
                          color: Colors.white,
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: dashAsync.when(
              loading: () => const SliverToBoxAdapter(child: ShimmerLoader()),
              error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('$e'))),
              data: (data) => SliverList(
                delegate: SliverChildListDelegate([
                  // Pay Now Button
                  AppButton(
                    label: '💳  Pay Maintenance Now',
                    onPressed: () => context.push('/payments'),
                    color: AppTheme.success,
                  ),
                  const SizedBox(height: 20),

                  // Quick Links
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: [
                      _QuickLink(icon: Icons.receipt_long_outlined, label: 'Ledger', route: '/ledger'),
                      _QuickLink(icon: Icons.feedback_outlined, label: 'Complaints', route: '/complaints'),
                      _QuickLink(icon: Icons.event_outlined, label: 'Events', route: '/events'),
                      _QuickLink(icon: Icons.folder_outlined, label: 'Documents', route: '/documents'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Recent Transactions
                  if ((data['data']?['recentTransactions'] as List?)?.isNotEmpty == true) ...[
                    SectionHeader(title: 'Recent Transactions', actionLabel: 'View All', onAction: () => context.push('/ledger')),
                    const SizedBox(height: 12),
                  ],
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Supporting Widgets ────────────────────────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _MiniStatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CollectionChart extends StatelessWidget {
  final List<MonthlyChartPoint> points;
  const _CollectionChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return LineChart(LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => const FlLine(color: AppTheme.divider, strokeWidth: 1)),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 22,
          getTitlesWidget: (v, _) {
            const months = ['', 'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
            final idx = v.toInt();
            if (idx < 1 || idx > 12) return const SizedBox();
            return Text(months[idx], style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary));
          },
        )),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: points.map((p) => FlSpot(p.month.toDouble(), p.total / 1000)).toList(),
          isCurved: true,
          color: AppTheme.primary,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: AppTheme.primary.withOpacity(0.1)),
        ),
      ],
    ));
  }
}

class _ExpensePieChart extends StatelessWidget {
  final List<ExpenseCategoryPoint> points;
  const _ExpensePieChart({required this.points});

  static const _colors = [
    AppTheme.primary, AppTheme.success, AppTheme.warning,
    AppTheme.error, AppTheme.info, Color(0xFF8B5CF6), Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    return PieChart(PieChartData(
      sections: points.take(7).toList().asMap().entries.map((e) {
        final color = _colors[e.key % _colors.length];
        return PieChartSectionData(
          value: e.value.total,
          color: color,
          title: '',
          radius: 60,
        );
      }).toList(),
      sectionsSpace: 2,
      centerSpaceRadius: 30,
    ));
  }
}

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      {'icon': Icons.people_outline, 'label': 'Members', 'route': '/admin/members', 'color': AppTheme.primary},
      {'icon': Icons.receipt_outlined, 'label': 'Expenses', 'route': '/admin/expenses', 'color': AppTheme.warning},
      {'icon': Icons.inventory_2_outlined, 'label': 'Inventory', 'route': '/inventory', 'color': AppTheme.success},
      {'icon': Icons.upload_file_outlined, 'label': 'Documents', 'route': '/documents', 'color': AppTheme.info},
      {'icon': Icons.event_outlined, 'label': 'Events', 'route': '/events', 'color': const Color(0xFF8B5CF6)},
      {'icon': Icons.notifications_outlined, 'label': 'Notify', 'route': '/admin', 'color': AppTheme.error},
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: actions.map((a) => GestureDetector(
        onTap: () => context.push(a['route'] as String),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(a['icon'] as IconData, color: a['color'] as Color, size: 26),
              const SizedBox(height: 6),
              Text(a['label'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

class _EventItem extends StatelessWidget {
  final EventModel event;
  const _EventItem({required this.event});

  @override
  Widget build(BuildContext context) {
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
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text(
              event.startDate.day.toString(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('${formatDate(event.startDate, pattern: 'MMM d')} • ${event.venue ?? 'Society Premises'}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textTertiary),
        ],
      ),
    );
  }
}

class _PaymentItem extends StatelessWidget {
  final PaymentModel payment;
  const _PaymentItem({required this.payment});

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.member?.user?.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(payment.member?.flatIdentifier ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(formatCurrency(payment.amount), style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.success, fontSize: 15)),
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label, route;
  const _QuickLink({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primary, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _HeaderStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
    ],
  );
}