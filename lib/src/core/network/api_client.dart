import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/company.dart';

/// Lỗi API chuẩn theo envelope backend `{ error: { code, message } }`.
class ApiException implements Exception {
  final String code;
  final String message;
  final int status;

  const ApiException(this.code, this.message, this.status);

  @override
  String toString() => 'ApiException($code): $message';
}

/// Client gọi chung 1 api-gateway cho cả web và mobile.
///
/// - Base URL: [CompanyConfig.apiBaseUrl] (gateway :4000).
/// - Timeout tối đa 5000ms theo ràng buộc PTPMDV.
/// - Hiểu envelope `{ data }` / `{ error: { code, message } }`.
/// - Phiên đăng nhập nằm trong Keychain/Keystore khi bật "Ghi nhớ đăng nhập".
/// - Gặp 401 thì tự refresh token và gửi lại request đúng một lần.
/// - SOAP (`/soap/payroll`) đi qua gateway nguyên vẹn XML, không bọc envelope.
class ApiClient {
  final String baseUrl;
  final Duration timeout;

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _kAccessToken = 'hrm.accessToken';
  static const String _kRefreshToken = 'hrm.refreshToken';

  static String? _globalCookie;
  static String? _globalAccessToken;
  static String? _globalRefreshToken;
  static bool _remember = false;

  /// Nhiều request cùng dính 401 thì chỉ kéo theo một lần refresh.
  static Future<bool>? _refreshing;

  /// App gắn vào để đưa về màn đăng nhập khi refresh cũng hỏng.
  static void Function()? onSessionExpired;

  ApiClient({String? baseUrl, Duration? timeout})
      : baseUrl = baseUrl ?? CompanyConfig.apiBaseUrl,
        timeout = timeout ?? CompanyConfig.apiTimeout;

  void setSession({String? cookie, String? accessToken, String? refreshToken}) {
    if (cookie != null) _globalCookie = cookie;
    if (accessToken != null) _globalAccessToken = accessToken;
    if (refreshToken != null) _globalRefreshToken = refreshToken;
  }

  static void clearSession() {
    _globalCookie = null;
    _globalAccessToken = null;
    _globalRefreshToken = null;
    _remember = false;
  }

  /// Header cho ảnh phục vụ sau JWT của gateway (/api/files). Chỉ gắn khi URL
  /// cùng origin gateway để không lộ token ra dịch vụ ngoài (ảnh cũ lưu nơi khác).
  static Map<String, String>? imageHeadersFor(String url) {
    final uri = Uri.tryParse(url);
    final base = Uri.tryParse(CompanyConfig.apiBaseUrl);
    if (uri == null || base == null) return null;
    final sameOrigin =
        uri.scheme == base.scheme && uri.host == base.host && uri.port == base.port;
    if (!sameOrigin || !uri.path.startsWith('/api/files/')) return null;
    final h = <String, String>{};
    final cookie = _globalCookie;
    if (cookie != null) h['Cookie'] = cookie;
    final token = _globalAccessToken;
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  /// Bật thì ghi token vào Keychain/Keystore, tắt thì xóa bản đã lưu.
  /// Storage lỗi thì bỏ qua: phiên trong memory vẫn dùng được cho lần chạy này.
  static Future<void> persistSession({required bool remember}) async {
    _remember = remember;
    try {
      if (remember) {
        await _writeTokens();
      } else {
        await clearPersistedSession();
      }
    } catch (_) {}
  }

  /// Nạp phiên đã lưu lúc khởi động. True nghĩa là có token để đem thử `me()`.
  static Future<bool> restoreSession() async {
    try {
      final access = await _storage.read(key: _kAccessToken);
      if (access == null || access.isEmpty) return false;
      _globalAccessToken = access;
      _globalRefreshToken = await _storage.read(key: _kRefreshToken);
      _remember = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearPersistedSession() async {
    try {
      await _storage.delete(key: _kAccessToken);
      await _storage.delete(key: _kRefreshToken);
    } catch (_) {}
  }

  static Future<void> _writeTokens() async {
    final access = _globalAccessToken;
    if (access == null || access.isEmpty) return;
    await _storage.write(key: _kAccessToken, value: access);
    final refresh = _globalRefreshToken;
    if (refresh != null && refresh.isNotEmpty) {
      await _storage.write(key: _kRefreshToken, value: refresh);
    }
  }

  static Future<void> _expireSession() async {
    // Request khác trong cùng loạt 401 không bắn callback lặp lại.
    if (_globalAccessToken == null && _globalRefreshToken == null) return;
    clearSession();
    await clearPersistedSession();
    onSessionExpired?.call();
  }

  static void _captureCookie(http.Response res) {
    final setCookie = res.headers['set-cookie'];
    if (setCookie != null && setCookie.contains('hrm-session')) {
      _globalCookie = setCookie.split(';').first;
    }
  }

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    final cookie = _globalCookie;
    if (cookie != null) h['Cookie'] = cookie;
    final token = _globalAccessToken;
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  Never _throwFromBody(int status, dynamic body) {
    if (body is Map && body['error'] is Map) {
      final e = body['error'] as Map;
      throw ApiException(
        e['code']?.toString() ?? 'UNKNOWN',
        e['message']?.toString() ?? 'Lỗi hệ thống',
        status,
      );
    }
    throw ApiException('HTTP_$status', 'Lỗi hệ thống ($status)', status);
  }

  static dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  Future<http.Response> _request(
    String method,
    Uri uri, {
    bool json = true,
    String? body,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = _headers(json: json);
    if (extraHeaders != null) headers.addAll(extraHeaders);
    final req = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) req.body = body;
    try {
      return await Future.sync(() async {
        final streamed = await req.send();
        return http.Response.fromStream(streamed);
      }).timeout(timeout);
    } on TimeoutException {
      throw const ApiException('TIMEOUT', 'Hết thời gian chờ máy chủ', 504);
    } on http.ClientException {
      throw const ApiException('NETWORK', 'Không kết nối được máy chủ', 503);
    }
  }

  /// 401 thì refresh rồi gửi lại đúng một lần; refresh hỏng mới coi như hết phiên.
  Future<http.Response> _send(
    String method,
    Uri uri, {
    bool json = true,
    String? body,
    Map<String, String>? extraHeaders,
  }) async {
    final res = await _request(method, uri, json: json, body: body, extraHeaders: extraHeaders);
    if (res.statusCode != 401) return res;
    if (await _refreshSession()) {
      return _request(method, uri, json: json, body: body, extraHeaders: extraHeaders);
    }
    await _expireSession();
    return res;
  }

  Future<bool> _refreshSession() {
    final pending = _refreshing;
    if (pending != null) return pending;
    final token = _globalRefreshToken;
    if (token == null || token.isEmpty) return Future.value(false);
    final future = _performRefresh(token).whenComplete(() => _refreshing = null);
    _refreshing = future;
    return future;
  }

  /// Gọi thẳng, không qua [_send] để tránh đệ quy khi chính refresh bị 401.
  Future<bool> _performRefresh(String refreshToken) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final decoded = _tryDecode(res.body);
      final data = decoded is Map ? decoded['data'] : null;
      if (data is! Map) return false;
      final access = data['accessToken']?.toString();
      if (access == null || access.isEmpty) return false;
      _globalAccessToken = access;
      _globalRefreshToken = data['refreshToken']?.toString() ?? refreshToken;
      _captureCookie(res);
      if (_remember) await _writeTokens();
      return true;
    } catch (_) {
      return false;
    }
  }

  dynamic _unwrap(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _throwFromBody(res.statusCode, _tryDecode(res.body));
    }
    final body = jsonDecode(res.body);
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  /// GET JSON, trả về `data` trong envelope.
  Future<dynamic> getJson(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return _unwrap(await _send('GET', uri, json: false));
  }

  /// POST JSON, trả về `data` trong envelope.
  Future<dynamic> postJson(String path, Map<String, dynamic> payload) async {
    final res = await _send('POST', Uri.parse('$baseUrl$path'), body: jsonEncode(payload));
    _captureCookie(res);
    return _unwrap(res);
  }

  Future<dynamic> putJson(String path, Map<String, dynamic> payload) async {
    final res = await _send('PUT', Uri.parse('$baseUrl$path'), body: jsonEncode(payload));
    return _unwrap(res);
  }

  Future<void> delete(String path) async {
    final res = await _send('DELETE', Uri.parse('$baseUrl$path'), json: false);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _throwFromBody(res.statusCode, _tryDecode(res.body));
    }
  }

  /// POST SOAP nguyên vẹn XML (gateway không bọc envelope).
  Future<String> postSoap(String xmlBody) async {
    final res = await _send(
      'POST',
      Uri.parse('$baseUrl/soap/payroll'),
      json: false,
      body: xmlBody,
      extraHeaders: {'Content-Type': 'text/xml; charset=utf-8'},
    );
    return res.body;
  }
}