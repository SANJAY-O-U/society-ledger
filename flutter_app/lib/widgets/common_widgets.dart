import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';

// ─── App Button ────────────────────────────────────────────────────────────────
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? color;
  final bool outlined;

  const AppButton({
    super.key, required this.label, required this.onPressed,
    this.isLoading = false, this.icon, this.color, this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = outlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: color ?? AppTheme.primary,
              side: BorderSide(color: color ?? AppTheme.primary, width: 1.5),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _buildChild(),
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color ?? AppTheme.primary,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _buildChild(),
          );
    return btn;
  }

  Widget _buildChild() {
    if (isLoading) {
      return const SizedBox(
        width: 22, height: 22,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(label)],
      );
    }
    return Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));
  }
}

// ─── App Snackbar ──────────────────────────────────────────────────────────────
class AppSnackbar {
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
      ]),
      backgroundColor: AppTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
      ]),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}

// ─── Stat Card ─────────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  const StatCard({
    super.key, required this.title, required this.value,
    required this.icon, required this.color, this.subtitle, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
               mainAxisSize: MainAxisSize.min,   // ADD THIS
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (onTap != null) const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textTertiary),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel!, style: const TextStyle(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

// ─── Status Badge ──────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge(this.status, {super.key});

  Color get _color {
    switch (status.toLowerCase()) {
      case 'paid': case 'approved': case 'resolved': case 'available': return AppTheme.success;
      case 'pending': case 'open': case 'pending_approval': return AppTheme.warning;
      case 'overdue': case 'rejected': case 'closed': case 'disposed': return AppTheme.error;
      case 'in_progress': case 'created': case 'in_use': return AppTheme.info;
      default: return AppTheme.textSecondary;
    }
  }

  String get _label => status.replaceAll('_', ' ').toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(_label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _color)),
    );
  }
}

// ─── Priority Badge ────────────────────────────────────────────────────────────
class PriorityBadge extends StatelessWidget {
  final String priority;
  const PriorityBadge(this.priority, {super.key});

  Color get _color {
    switch (priority) {
      case 'urgent': return AppTheme.error;
      case 'high': return const Color(0xFFEA580C);
      case 'medium': return AppTheme.warning;
      default: return AppTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
      child: Text(priority.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _color)),
    );
  }
}

// ─── Shimmer Loader ────────────────────────────────────────────────────────────
class ShimmerLoader extends StatelessWidget {
  final int count;
  final double height;

  const ShimmerLoader({super.key, this.count = 3, this.height = 80});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (_) => Shimmer.fromColors(
          baseColor: const Color(0xFFE2E8F0),
          highlightColor: const Color(0xFFF8FAFC),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: height,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ───────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key, required this.icon, required this.title, required this.subtitle,
    this.actionLabel, this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppTheme.textTertiary),
            ),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              AppButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Currency Formatter ────────────────────────────────────────────────────────
String formatCurrency(double amount) {
  return '₹${NumberFormat('#,##,###').format(amount)}';
}

String formatDate(DateTime date, {String pattern = 'd MMM yyyy'}) {
  return DateFormat(pattern).format(date);
}

// ─── Info Row ──────────────────────────────────────────────────────────────────
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;

  const InfoRow({super.key, required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textTertiary),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: valueColor ?? AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
