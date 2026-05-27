import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});
  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  late Razorpay _razorpay;
  bool _isLoading = false;
  String? _currentOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _initiatePayment(double amount, String description) async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final month = DateTime.now().month;
      final year = DateTime.now().year;

      final res = await dio.safePost('/payments/create-order', data: {
        'amount': amount,
        'description': description,
        'month': month,
        'year': year,
      });

      _currentOrderId = res['paymentId'];

      final user = ref.read(authNotifierProvider).valueOrNull;
      final options = {
        'key': res['key'],
        'amount': res['amount'],
        'currency': res['currency'],
        'order_id': res['orderId'],
        'name': 'Society Ledger',
        'description': description,
        'prefill': {
          'name': user?.name ?? '',
          'contact': '+91${user?.phone ?? ''}',
          if (user?.email != null) 'email': user!.email,
        },
        'theme': {'color': '#1E40AF'},
      };

      _razorpay.open(options);
    } catch (e) {
      AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.safePost('/payments/verify', data: {
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
        'paymentId': _currentOrderId,
      });

      AppSnackbar.showSuccess(context, '✅ Payment of successful!');
      ref.invalidate(memberDashboardProvider);
    } catch (e) {
      AppSnackbar.showError(context, 'Payment verification failed: $e');
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    AppSnackbar.showError(context, 'Payment failed: ${response.message}');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    AppSnackbar.showSuccess(context, 'External wallet selected: ${response.walletName}');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.read(authNotifierProvider).valueOrNull;
    final isManagement = user?.isManagement ?? false;

    // Admin has no member profile — show payment history / offline recording
    if (isManagement && user?.member == null) {
      return Scaffold(
        backgroundColor: AppTheme.surfaceLight,
        appBar: AppBar(title: const Text('Payments')),
        body: const PaymentHistoryScreen(),
      );
    }

    final dashAsync = ref.watch(memberDashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Pay Maintenance'),
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.history_outlined, size: 18),
            label: const Text('History'),
          ),
        ],
      ),
      body: dashAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: ShimmerLoader()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          final memberData = data['data']?['member'];
          final financeData = data['data']?['finance'];
          final monthlyAmount = (memberData?['monthlyMaintenance'] ?? 0).toDouble();
          final pendingDues = (financeData?['pendingDues'] ?? 0).toDouble();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Balance Card ────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Flat ${memberData?['wing']}-${memberData?['flatNumber']}',
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text('Pending Dues', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                      Text(formatCurrency(pendingDues),
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        _BalanceStat(label: 'Monthly Amt', value: formatCurrency(monthlyAmount)),
                        _BalanceStat(label: 'Due Day', value: '${memberData?['dueDay']}th'),
                        _BalanceStat(label: 'Status', value: pendingDues > 0 ? 'Due' : 'Clear',
                            valueColor: pendingDues > 0 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Pay Options ─────────────────────────────────────────
                const Text('Pay Now', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),

                if (pendingDues > 0) _PaymentOption(
                  icon: Icons.warning_amber_rounded,
                  color: AppTheme.error,
                  title: 'Clear All Pending Dues',
                  subtitle: formatCurrency(pendingDues),
                  onTap: _isLoading ? null : () => _initiatePayment(pendingDues, 'Pending Dues Clearance'),
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 10),
                _PaymentOption(
                  icon: Icons.calendar_today_outlined,
                  color: AppTheme.primary,
                  title: 'This Month\'s Maintenance',
                  subtitle: formatCurrency(monthlyAmount),
                  onTap: _isLoading ? null : () => _initiatePayment(monthlyAmount,
                      'Monthly Maintenance - ${_monthName(DateTime.now().month)} ${DateTime.now().year}'),
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 24),

                // ─── Custom Amount ─────────────────────────────────────
                const Text('Custom Amount', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _CustomAmountCard(onPay: (amount, desc) => _initiatePayment(amount, desc), isLoading: _isLoading),

                const SizedBox(height: 24),

                // ─── Payment Methods ───────────────────────────────────
                const Text('Accepted Payment Methods', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(children: [
                  _MethodChip(label: 'UPI', icon: Icons.account_balance_wallet_outlined),
                  const SizedBox(width: 8),
                  _MethodChip(label: 'Cards', icon: Icons.credit_card_outlined),
                  const SizedBox(width: 8),
                  _MethodChip(label: 'Net Banking', icon: Icons.account_balance_outlined),
                ]),

                const SizedBox(height: 32),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.lock_outlined, size: 14, color: AppTheme.textTertiary),
                  const SizedBox(width: 4),
                  Text('Secured by Razorpay', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  String _monthName(int month) {
    const names = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return names[month - 1];
  }
}

class _BalanceStat extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _BalanceStat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
    ],
  );
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback? onTap;
  final bool isLoading;

  const _PaymentOption({
    required this.icon, required this.color, required this.title,
    required this.subtitle, this.onTap, this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(subtitle, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
              ]),
            ),
            if (isLoading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _CustomAmountCard extends StatefulWidget {
  final Function(double, String) onPay;
  final bool isLoading;
  const _CustomAmountCard({required this.onPay, this.isLoading = false});

  @override
  State<_CustomAmountCard> createState() => _CustomAmountCardState();
}

class _CustomAmountCardState extends State<_CustomAmountCard> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController(text: 'Society Payment');

  @override
  void dispose() { _amountCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(children: [
        TextFormField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount (₹)', prefixIcon: Icon(Icons.currency_rupee)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descCtrl,
          decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description_outlined)),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: 'Pay Custom Amount',
          onPressed: widget.isLoading ? null : () {
            final amount = double.tryParse(_amountCtrl.text);
            if (amount == null || amount <= 0) {
              AppSnackbar.showError(context, 'Please enter a valid amount');
              return;
            }
            widget.onPay(amount, _descCtrl.text.isNotEmpty ? _descCtrl.text : 'Society Payment');
          },
          isLoading: widget.isLoading,
        ),
      ]),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _MethodChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: AppTheme.textSecondary),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
    ]),
  );
}

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentsProvider(const {}));
    return Scaffold(
      appBar: AppBar(title: const Text('Payment History')),
      body: paymentsAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: ShimmerLoader()),
        error: (e, _) => Center(child: Text('$e')),
        data: (payments) => payments.isEmpty
            ? const EmptyState(icon: Icons.payment_outlined, title: 'No Payments', subtitle: 'No payment records found')
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: payments.length,
                itemBuilder: (_, i) {
                  final p = payments[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        Text(p.paidAt != null ? formatDate(p.paidAt!) : '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(formatCurrency(p.amount), style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.success, fontSize: 15)),
                        StatusBadge(p.status),
                      ]),
                    ]),
                  );
                },
              ),
      ),
    );
  }
}