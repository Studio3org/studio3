import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

import '../config/api_config.dart';
import 'api_exception.dart';
import 'auth_session.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Dio? _dio;
  CookieJar? _cookieJar;
  Future<void>? _initFuture;
  Future<void>? _refreshFuture;

  // All 5 bottom-nav tabs fire their first request concurrently (they're
  // mounted together in an IndexedStack), so initialization must be shared
  // across concurrent callers rather than guarded by a plain bool — a bool
  // guard lets a second caller return early while _dio is still null,
  // causing it to dereference a null Dio client.
  Future<void> _ensureInitialized() {
    if (_dio != null) return Future.value();
    return _initFuture ??= _initialize().catchError((Object e) {
      _initFuture = null; // let a later call retry instead of staying stuck
      throw e;
    });
  }

  Future<void> _initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    _cookieJar = PersistCookieJar(
      storage: FileStorage('${dir.path}/.cookies/'),
    );
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      // The deployed backend (Render free tier) spins down after
      // inactivity and can take 30-60s to wake back up on the next
      // request — 30s was too tight and tripped on exactly that cold
      // start, especially on the first request of a session (e.g. sign-up
      // OTP generation).
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    _dio!.interceptors.add(CookieManager(_cookieJar!));
    _dio!.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final path = error.requestOptions.path;
        if (status == 401 &&
            error.requestOptions.extra['retried'] != true &&
            !path.contains('/api/auth/refresh') &&
            !path.contains('/api/auth/login') &&
            !path.contains('/api/auth/register')) {
          try {
            await _refreshToken();
            final opts = error.requestOptions;
            opts.extra['retried'] = true;
            opts.headers['Authorization'] =
                'Bearer ${AuthSession.instance.accessToken}';
            final response = await _dio!.fetch(opts);
            return handler.resolve(response);
          } catch (e) {
            // Only a genuine 401 from the refresh call itself means the
            // refresh token was actually rejected — a network error,
            // timeout, or backend 5xx during refresh is a transient
            // hiccup, not a real logout, so the session is left intact
            // to retry later.
            final refreshRejected = e is ApiException && e.statusCode == 401;
            if (refreshRejected) {
              await AuthSession.instance.clear();
            }
            return handler.next(error);
          }
        }
        return handler.next(error);
      },
    ));
  }

  Future<Dio> get _client async {
    await _ensureInitialized();
    return _dio!;
  }

  Map<String, String> _authHeaders({bool auth = false}) {
    final headers = <String, String>{};
    if (auth) {
      final token = AuthSession.instance.accessToken;
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool auth = false,
  }) async {
    try {
      final dio = await _client;
      final response = await dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
        options: Options(headers: _authHeaders(auth: auth)),
      );
      return _parseResponse(response);
    } on DioException catch (e) {
      throw _toApiException(e);
    } catch (e) {
      debugPrint('API error (non-Dio, GET $path): $e');
      throw ApiException(
        "Can't reach the server. Check your connection and try again.",
      );
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    try {
      final dio = await _client;
      final response = await dio.post<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(headers: _authHeaders(auth: auth)),
      );
      return _parseResponse(response);
    } on DioException catch (e) {
      throw _toApiException(e);
    } catch (e) {
      debugPrint('API error (non-Dio, POST $path): $e');
      throw ApiException(
        "Can't reach the server. Check your connection and try again.",
      );
    }
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    try {
      final dio = await _client;
      final response = await dio.patch<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(headers: _authHeaders(auth: auth)),
      );
      return _parseResponse(response);
    } on DioException catch (e) {
      throw _toApiException(e);
    } catch (e) {
      debugPrint('API error (non-Dio, PATCH $path): $e');
      throw ApiException(
        "Can't reach the server. Check your connection and try again.",
      );
    }
  }

  /// Replace a resource wholesale, as opposed to [patch]'s partial update.
  ///
  /// Used where a partial update cannot express the intent — replacing an event's artist
  /// list, for instance, where sending only additions would make removing somebody
  /// impossible.
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    try {
      final dio = await _client;
      final response = await dio.put<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(headers: _authHeaders(auth: auth)),
      );
      return _parseResponse(response);
    } on DioException catch (e) {
      throw _toApiException(e);
    } catch (e) {
      debugPrint('API error (non-Dio, PUT $path): $e');
      throw ApiException(
        "Can't reach the server. Check your connection and try again.",
      );
    }
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    try {
      final dio = await _client;
      final response = await dio.delete<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(headers: _authHeaders(auth: auth)),
      );
      return _parseResponse(response);
    } on DioException catch (e) {
      throw _toApiException(e);
    } catch (e) {
      debugPrint('API error (non-Dio, DELETE $path): $e');
      throw ApiException(
        "Can't reach the server. Check your connection and try again.",
      );
    }
  }

  Future<void> uploadToPresignedUrl({
    required String presignedPutUrl,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final uploadDio = Dio();
    try {
      await uploadDio.put<void>(
        presignedPutUrl,
        data: bytes,
        options: Options(
          headers: {'Content-Type': contentType},
          contentType: contentType,
        ),
      );
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  // Concurrent 401s (e.g. presign + create firing close together) must all
  // await the SAME refresh — a bool guard lets the second caller return
  // early without a new token and retry with the still-stale one, which
  // then fails permanently since a retried request isn't retried again.
  //
  // Must reset via `then(onError:)`/`catchError`, NOT `whenComplete` —
  // whenComplete doesn't count as "handling" the error for Dart's zone-level
  // unhandled-exception tracking, so a rejected shared future gets reported
  // as unhandled independently of whether callers actually await it (this
  // crashed the app: every 401 fired at startup threw as an unhandled
  // exception even though the interceptor's try/catch does await it).
  Future<void> _refreshToken() {
    return _refreshFuture ??= _performRefresh().then(
      (value) {
        _refreshFuture = null;
        return value;
      },
      onError: (Object error, StackTrace stackTrace) {
        _refreshFuture = null;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  Future<void> _performRefresh() async {
    final json = await post('/api/auth/refresh');
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final token = data['accessToken'] as String?;
    final userJson = data['user'] as Map<String, dynamic>?;
    if (token != null) {
      await AuthSession.instance.updateToken(token);
      if (userJson != null) {
        await AuthSession.instance.updateUserFromJson(userJson);
      }
    }
  }

  Future<void> refreshToken() => _refreshToken();

  Map<String, dynamic> _parseResponse(Response<Map<String, dynamic>> response) {
    return response.data ?? {'success': true};
  }

  /// Always plain, non-technical copy — nothing here should ever read like a
  /// stack trace or a Dio/HTTP internals dump (status codes, exception class
  /// names, "RequestOptions.validateStatus", the API's own base URL, etc.).
  /// The one exception is a message the *backend* sent, which is assumed to
  /// already be written for a user. Anything Dio generated on its own gets
  /// mapped to friendly copy here instead, with the real detail only going
  /// to the debug log for developers.
  ApiException _toApiException(DioException e) {
    final response = e.response;
    final statusCode = response?.statusCode;

    if (response?.data is Map<String, dynamic>) {
      final json = response!.data as Map<String, dynamic>;
      final serverMessage = json['message'] as String? ?? json['error'] as String?;
      if (serverMessage != null && serverMessage.trim().isNotEmpty) {
        return ApiException(serverMessage, statusCode: statusCode);
      }
    }

    if (statusCode == 429) {
      return ApiException(
        "You're doing that a little too fast — please wait a moment and try again.",
        statusCode: statusCode,
      );
    }
    if (statusCode == 401 || statusCode == 403) {
      return ApiException(
        "You don't have permission to do that.",
        statusCode: statusCode,
      );
    }
    if (statusCode == 404) {
      return ApiException(
        "We couldn't find that — it may have been removed.",
        statusCode: statusCode,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return ApiException(
        "Something went wrong on our end. Please try again in a moment.",
        statusCode: statusCode,
      );
    }
    if (e.type == DioExceptionType.connectionError) {
      return ApiException(
        "Can't reach the server. Check your connection and try again.",
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return ApiException(
        'Server is taking longer than usual to respond — it may be waking '
        'up from inactivity. Please try again in a moment.',
      );
    }

    debugPrint('API error (unmapped): ${e.type} ${e.message}');
    return ApiException('Something went wrong. Please try again.', statusCode: statusCode);
  }

  dynamic extractData(Map<String, dynamic> json) {
    return json['data'] ?? json;
  }

  List<Map<String, dynamic>> extractList(Map<String, dynamic> json) {
    final data = extractData(json);
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map<String, dynamic>) {
      for (final key in [
        'items',
        'pieces',
        'posts',
        'feed',
        'results',
        'orders',
        'sales',
        'addresses',
        'methods',
      ]) {
        final list = data[key];
        if (list is List) {
          return list.whereType<Map<String, dynamic>>().toList();
        }
      }
    }
    return const [];
  }
}
