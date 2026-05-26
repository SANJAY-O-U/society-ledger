import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/ledger/ledger_screen.dart';
import '../screens/ledger/transaction_detail_screen.dart';
import '../screens/payments/payment_screen.dart';
import '../screens/payments/payment_history_screen.dart';
import '../screens/complaints/complaints_screen.dart';
import '../screens/complaints/complaint_detail_screen.dart';
import '../screens/complaints/create_complaint_screen.dart';
import '../screens/events/events_screen.dart';
import '../screens/events/event_detail_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/documents/documents_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/admin/admin_panel_screen.dart';
import '../screens/admin/members_screen.dart';
import '../screens/admin/member_detail_screen.dart';
import '../screens/admin/add_member_screen.dart';
import '../screens/admin/expenses_screen.dart';
import '../screens/admin/add_expense_screen.dart';
import '../widgets/main_shell.dart';

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<UserModel?>>(authNotifierProvider, (_, __) {
      notifyListeners();
    });
  }
  bool get isLoggedIn => _ref.read(authNotifierProvider).valueOrNull != null;
}

final _routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  return _RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isLoggedIn = notifier.isLoggedIn;
      final isSplash = state.matchedLocation == '/splash';
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      if (isSplash) return null;
      if (!isLoggedIn && !isAuthRoute) return '/auth/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/auth/otp',
        builder: (_, state) => OtpScreen(phone: state.extra as String),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/ledger', builder: (_, __) => const LedgerScreen()),
          GoRoute(path: '/payments', builder: (_, __) => const PaymentScreen()),
          GoRoute(path: '/complaints', builder: (_, __) => const ComplaintsScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/ledger/transaction/:id',
        builder: (_, state) => TransactionDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/payments/history', builder: (_, __) => const PaymentHistoryScreen()),
      GoRoute(
        path: '/complaints/:id',
        builder: (_, state) => ComplaintDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/complaints/create', builder: (_, __) => const CreateComplaintScreen()),
      GoRoute(path: '/events', builder: (_, __) => const EventsScreen()),
      GoRoute(
        path: '/events/:id',
        builder: (_, state) => EventDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
      GoRoute(path: '/documents', builder: (_, __) => const DocumentsScreen()),
      GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminPanelScreen()),
      GoRoute(path: '/admin/members', builder: (_, __) => const MembersScreen()),
      GoRoute(
        path: '/admin/members/:id',
        builder: (_, state) => MemberDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin/members/add', builder: (_, __) => const AddMemberScreen()),
      GoRoute(path: '/admin/expenses', builder: (_, __) => const ExpensesScreen()),
      GoRoute(path: '/admin/expenses/add', builder: (_, __) => const AddExpenseScreen()),
    ],
  );
});
