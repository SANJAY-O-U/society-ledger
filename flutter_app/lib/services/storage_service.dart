import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static late SharedPreferences _prefs;
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─── Tokens ────────────────────────────────────────────────────────────────
  static Future<void> saveAccessToken(String token) async {
    await _secureStorage.write(key: 'access_token', value: token);
  }

  static Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: 'access_token');
  }

  static Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: 'refresh_token', value: token);
  }

  static Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: 'refresh_token');
  }

  // ─── User Data ─────────────────────────────────────────────────────────────
  static Future<void> saveUser(Map<String, dynamic> user) async {
    await _prefs.setString('user_data', jsonEncode(user));
  }

  static Map<String, dynamic>? getUser() {
    final str = _prefs.getString('user_data');
    if (str == null) return null;
    return jsonDecode(str) as Map<String, dynamic>;
  }

  static String? getUserRole() {
    return getUser()?['role'] as String?;
  }

  static bool get isLoggedIn {
  final user = getUser();
  if (user == null) return false;
  // Also verify we have a valid access token
  final token = _prefs.getString('access_token_check');
  // Access token is stored in secure storage (async) so we
  // just check user data existence here — the API interceptor
  // handles actual token refresh on 401
  return true;
}
   static Future<bool> get isSessionValid async {
  final user = getUser();
  if (user == null) return false;
  final token = await getAccessToken();
  return token != null;
}
static Future<bool> get hasValidSession async {
  final user = getUser();          // sync — from SharedPreferences
  if (user == null) return false;
  
  final token = await getAccessToken();  // async — from SecureStorage
  if (token == null) {
    // Token is missing but user data exists — inconsistent state.
    // Clear everything so app starts fresh.
    await clearAll();
    return false;
  }
  return true;
}
  // ─── Theme / Preferences ──────────────────────────────────────────────────
  static Future<void> setDarkMode(bool value) async {
    await _prefs.setBool('dark_mode', value);
  }

  static bool get isDarkMode => _prefs.getBool('dark_mode') ?? false;

  // ─── FCM Token ─────────────────────────────────────────────────────────────
  static Future<void> saveFCMToken(String token) async {
    await _prefs.setString('fcm_token', token);
  }

  static String? getFCMToken() => _prefs.getString('fcm_token');

  // ─── Clear ─────────────────────────────────────────────────────────────────
  static Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await _prefs.clear();
  }
}
