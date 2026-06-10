import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'dart:async';
// ─── Dashboard ─────────────────────────────────────────────────────────────────
final adminDashboardProvider = FutureProvider<AdminDashboardData>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.safeGet('/dashboard/admin');
  return AdminDashboardData.fromJson(res);
});

final memberDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  return await dio.safeGet('/dashboard/member');
});

// ─── Members ───────────────────────────────────────────────────────────────────
final membersListProvider = FutureProvider<List<MemberModel>>(
  (ref) async {
    final dio = ref.read(dioProvider);
    final res = await dio.safeGet('/members');
    final list = res['data'] as List? ?? [];
    return list.map((m) => MemberModel.fromJson(m)).toList();
  },
);

final memberDetailProvider = FutureProvider.family<MemberModel, String>((ref, id) async {
  // Keep alive for 5 minutes so back-navigation doesn't re-fetch
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);
  
  final dio = ref.read(dioProvider);
  final res = await dio.safeGet('/members/$id');
  return MemberModel.fromJson(res['data']);
});
// ─── Ledger ────────────────────────────────────────────────────────────────────
class LedgerParams {
  final String memberId;
  final int? month, year;
  final int page;
  LedgerParams({required this.memberId, this.month, this.year, this.page = 1});
}

final ledgerProvider = FutureProvider.family<Map<String, dynamic>, LedgerParams>(
  (ref, params) async {
    final dio = ref.read(dioProvider);
    return await dio.safeGet('/ledger/${params.memberId}', params: {
      'page': params.page,
      if (params.month != null) 'month': params.month,
      if (params.year != null) 'year': params.year,
    });
  },
);

final pendingDuesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.safeGet('/ledger/pending-dues');
  return (res['data'] as List? ?? []).cast<Map<String, dynamic>>();
});

// ─── Payments ──────────────────────────────────────────────────────────────────
final paymentsProvider = FutureProvider<List<PaymentModel>>(
  (ref) async {
    final dio = ref.read(dioProvider);
    final res = await dio.safeGet('/payments');
    final list = res['data'] as List? ?? [];
    return list.map((p) => PaymentModel.fromJson(p)).toList();
  },
);

final paymentStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  return await dio.safeGet('/payments/stats');
});

// ─── Complaints ────────────────────────────────────────────────────────────────
final complaintsProvider = FutureProvider.family<List<ComplaintModel>, String>(
  (ref, statusFilter) async {
    final dio = ref.read(dioProvider);
    final params = statusFilter.isNotEmpty ? {'status': statusFilter} : <String, dynamic>{};
    final res = await dio.safeGet('/complaints', params: params);
    final list = res['data'] as List? ?? [];
    return list.map((c) => ComplaintModel.fromJson(c)).toList();
  },
);

final complaintDetailProvider = FutureProvider.autoDispose.family<ComplaintModel, String>((ref, id) async {
  final dio = ref.read(dioProvider);
  final res = await dio.safeGet('/complaints/$id');
  return ComplaintModel.fromJson(res['data']);
});

// ─── Events ────────────────────────────────────────────────────────────────────
final eventsProvider = FutureProvider<List<EventModel>>(
  (ref) async {
    final dio = ref.read(dioProvider);
    final res = await dio.safeGet('/events');
    final list = res['data'] as List? ?? [];
    return list.map((e) => EventModel.fromJson(e)).toList();
  },
);

final eventDetailProvider = FutureProvider.autoDispose.family<EventModel, String>((ref, id) async {
  final dio = ref.read(dioProvider);
  final res = await dio.safeGet('/events/$id');
  return EventModel.fromJson(res['data']);
});

// ─── Expenses ──────────────────────────────────────────────────────────────────
final expensesProvider = FutureProvider<List<ExpenseModel>>(
  (ref) async {
    final dio = ref.read(dioProvider);
    final res = await dio.safeGet('/expenses');
    final list = res['data'] as List? ?? [];
    return list.map((e) => ExpenseModel.fromJson(e)).toList();
  },
);

// ─── Inventory ─────────────────────────────────────────────────────────────────
final inventoryProvider = FutureProvider<List<InventoryItem>>(
  (ref) async {
    final dio = ref.read(dioProvider);
    final res = await dio.safeGet('/inventory');
    final list = res['data'] as List? ?? [];
    return list.map((i) => InventoryItem.fromJson(i)).toList();
  },
);

// ─── Documents ─────────────────────────────────────────────────────────────────
final documentsProvider = FutureProvider<List<DocumentModel>>(
  (ref) async {
    final dio = ref.read(dioProvider);
    final res = await dio.safeGet('/documents');
    final list = res['data'] as List? ?? [];
    return list.map((d) => DocumentModel.fromJson(d)).toList();
  },
);

// ─── Notifications ─────────────────────────────────────────────────────────────
final notificationsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  return await dio.safeGet('/notifications');
});

// ─── Refresh ───────────────────────────────────────────────────────────────────
// A simple counter to force refresh
final refreshCounterProvider = StateProvider<int>((ref) => 0);