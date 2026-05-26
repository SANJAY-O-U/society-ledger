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
    return getUser() != null;
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
