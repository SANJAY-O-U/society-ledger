import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

const String baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:5000/api');
final _inflightRequests = <String, Future<Map<String, dynamic>>>{};
final dioProvider = Provider<Dio>((ref) {
  ref.keepAlive(); // never recreate Dio
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  // Auth interceptor
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await StorageService.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        // Try refresh token
        final refreshed = await _tryRefreshToken(error.requestOptions);
        if (refreshed != null) return handler.resolve(refreshed);
      }
      return handler.next(error);
    },
  ));

  return dio;
});

Future<Response?> _tryRefreshToken(RequestOptions requestOptions) async {
  final refreshToken = await StorageService.getRefreshToken();
  if (refreshToken == null) return null;

  try {
    final dio = Dio(BaseOptions(baseUrl: baseUrl));
    final response = await dio.post('/auth/refresh-token', data: {'refreshToken': refreshToken});
    final newToken = response.data['accessToken'];
    await StorageService.saveAccessToken(newToken);

    final retryDio = Dio(BaseOptions(baseUrl: baseUrl));
    requestOptions.headers['Authorization'] = 'Bearer $newToken';
    return await retryDio.fetch(requestOptions);
  } catch (_) {
    await StorageService.clearAll();
    return null;
  }
}

// ─── API Exception ─────────────────────────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

// ─── Base API helper ──────────────────────────────────────────────────────────
extension DioHelper on Dio {
  Future<Map<String, dynamic>> safeGet(String path, {Map<String, dynamic>? params}) async {
  // Deduplicate concurrent identical requests
  final paramStr = params?.entries
      .where((e) => e.value != null)
      .map((e) => '${e.key}=${e.value}')
      .toList()?..sort();
  final dedupKey = '$path?${paramStr?.join('&') ?? ''}';

  if (_inflightRequests.containsKey(dedupKey)) {
    return _inflightRequests[dedupKey]!;
  }

  final future = () async {
    try {
      final res = await get(path, queryParameters: params);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(
        e.response?.data?['message'] ?? e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }();

  _inflightRequests[dedupKey] = future;
  try {
    return await future;
  } finally {
    _inflightRequests.remove(dedupKey);
  }
}

  Future<Map<String, dynamic>> safePost(String path, {dynamic data}) async {
    try {
      final res = await post(path, data: data);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(
        e.response?.data?['message'] ?? e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> safePut(String path, {dynamic data}) async {
    try {
      final res = await put(path, data: data);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(
        e.response?.data?['message'] ?? e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> safeDelete(String path) async {
    try {
      final res = await delete(path);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(
        e.response?.data?['message'] ?? e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
