import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/api_service.dart';

// ─── Dashboard ─────────────────────────────────────────────────────────────────
final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboardData>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.safeGet('/dashboard/admin');
  return AdminDashboardData.fromJson(res);
});

final memberDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  return await dio.safeGet('/dashboard/member');
});

// ─── Members ───────────────────────────────────────────────────────────────────
final membersListProvider = FutureProvider.autoDispose.family<List<MemberModel>, Map<String, dynamic>>(
  (ref, params) async {
    final dio = ref.watch(dioProvider);
    final res = await dio.safeGet('/members', params: params);
    final list = res['data'] as List? ?? [];
    return list.map((m) => MemberModel.fromJson(m)).toList();
  },
);

final memberDetailProvider = FutureProvider.autoDispose.family<MemberModel, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
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

final ledgerProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, LedgerParams>(
  (ref, params) async {
    final dio = ref.watch(dioProvider);
    return await dio.safeGet('/ledger/${params.memberId}', params: {
      'page': params.page,
      if (params.month != null) 'month': params.month,
      if (params.year != null) 'year': params.year,
    });
  },
);

final pendingDuesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.safeGet('/ledger/pending-dues');
  return (res['data'] as List? ?? []).cast<Map<String, dynamic>>();
});

// ─── Payments ──────────────────────────────────────────────────────────────────
final paymentsProvider = FutureProvider.autoDispose.family<List<PaymentModel>, Map<String, dynamic>>(
  (ref, params) async {
    final dio = ref.watch(dioProvider);
    final res = await dio.safeGet('/payments', params: params);
    final list = res['data'] as List? ?? [];
    return list.map((p) => PaymentModel.fromJson(p)).toList();
  },
);

final paymentStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  return await dio.safeGet('/payments/stats');
});

// ─── Complaints ────────────────────────────────────────────────────────────────
final complaintsProvider = FutureProvider.autoDispose.family<List<ComplaintModel>, Map<String, dynamic>>(
  (ref, params) async {
    final dio = ref.watch(dioProvider);
    final res = await dio.safeGet('/complaints', params: params);
    final list = res['data'] as List? ?? [];
    return list.map((c) => ComplaintModel.fromJson(c)).toList();
  },
);

final complaintDetailProvider = FutureProvider.autoDispose.family<ComplaintModel, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.safeGet('/complaints/$id');
  return ComplaintModel.fromJson(res['data']);
});

// ─── Events ────────────────────────────────────────────────────────────────────
final eventsProvider = FutureProvider.autoDispose.family<List<EventModel>, Map<String, dynamic>>(
  (ref, params) async {
    final dio = ref.watch(dioProvider);
    final res = await dio.safeGet('/events', params: params);
    final list = res['data'] as List? ?? [];
    return list.map((e) => EventModel.fromJson(e)).toList();
  },
);

final eventDetailProvider = FutureProvider.autoDispose.family<EventModel, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.safeGet('/events/$id');
  return EventModel.fromJson(res['data']);
});

// ─── Expenses ──────────────────────────────────────────────────────────────────
final expensesProvider = FutureProvider.autoDispose.family<List<ExpenseModel>, Map<String, dynamic>>(
  (ref, params) async {
    final dio = ref.watch(dioProvider);
    final res = await dio.safeGet('/expenses', params: params);
    final list = res['data'] as List? ?? [];
    return list.map((e) => ExpenseModel.fromJson(e)).toList();
  },
);

// ─── Inventory ─────────────────────────────────────────────────────────────────
final inventoryProvider = FutureProvider.autoDispose.family<List<InventoryItem>, Map<String, dynamic>>(
  (ref, params) async {
    final dio = ref.watch(dioProvider);
    final res = await dio.safeGet('/inventory', params: params);
    final list = res['data'] as List? ?? [];
    return list.map((i) => InventoryItem.fromJson(i)).toList();
  },
);

// ─── Documents ─────────────────────────────────────────────────────────────────
final documentsProvider = FutureProvider.autoDispose.family<List<DocumentModel>, Map<String, dynamic>>(
  (ref, params) async {
    final dio = ref.watch(dioProvider);
    final res = await dio.safeGet('/documents', params: params);
    final list = res['data'] as List? ?? [];
    return list.map((d) => DocumentModel.fromJson(d)).toList();
  },
);

// ─── Notifications ─────────────────────────────────────────────────────────────
final notificationsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  return await dio.safeGet('/notifications');
});

// ─── Refresh ───────────────────────────────────────────────────────────────────
// A simple counter to force refresh
final refreshCounterProvider = StateProvider<int>((ref) => 0);
