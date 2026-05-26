import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

// ─── Auth State ────────────────────────────────────────────────────────────────
final authStateProvider = FutureProvider<UserModel?>((ref) async {
  final userData = StorageService.getUser();
  if (userData == null) return null;
  return UserModel.fromJson(userData);
});

// ─── Current User ──────────────────────────────────────────────────────────────
final currentUserProvider = StateProvider<UserModel?>((ref) {
  final userData = StorageService.getUser();
  if (userData == null) return null;
  return UserModel.fromJson(userData);
});

// ─── Auth Notifier ─────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final Dio _dio;

  AuthNotifier(this._dio) : super(const AsyncValue.loading()) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final userData = StorageService.getUser();
    if (userData != null) {
      state = AsyncValue.data(UserModel.fromJson(userData));
    } else {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> sendOTP(String phone) async {
    await _dio.safePost('/auth/send-otp', data: {'phone': phone});
  }

  Future<UserModel> verifyOTP({
    required String firebaseToken,
    required String phone,
    String? name,
  }) async {
    final fcmToken = await NotificationService.getToken();
    final res = await _dio.safePost('/auth/verify-otp', data: {
      'firebaseToken': firebaseToken,
      'phone': phone,
      if (name != null) 'name': name,
      if (fcmToken != null) 'fcmToken': fcmToken,
    });

    await _saveAuth(res);
    final user = UserModel.fromJson(res['user']);
    state = AsyncValue.data(user);
    return user;
  }

  Future<UserModel> login({String? email, String? phone, required String password}) async {
    final res = await _dio.safePost('/auth/login', data: {
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      'password': password,
    });
    await _saveAuth(res);
    final user = UserModel.fromJson(res['user']);
    state = AsyncValue.data(user);
    return user;
  }

  Future<void> logout() async {
    try {
      final fcmToken = StorageService.getFCMToken();
      await _dio.safePost('/auth/logout', data: {'fcmToken': fcmToken});
    } catch (_) {}
    await StorageService.clearAll();
    state = const AsyncValue.data(null);
  }

  Future<void> refreshUser() async {
    try {
      final res = await _dio.safeGet('/auth/me');
      final user = UserModel.fromJson(res['user']);
      await StorageService.saveUser(res['user']);
      state = AsyncValue.data(user);
    } catch (_) {}
  }

  Future<void> _saveAuth(Map<String, dynamic> res) async {
    await StorageService.saveAccessToken(res['accessToken']);
    await StorageService.saveRefreshToken(res['refreshToken']);
    await StorageService.saveUser(res['user']);

    // Update FCM token on server
    final fcmToken = StorageService.getFCMToken();
    if (fcmToken != null) {
      try {
        await _dio.safePut('/auth/fcm-token', data: {'fcmToken': fcmToken});
      } catch (_) {}
    }
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthNotifier(dio);
});
