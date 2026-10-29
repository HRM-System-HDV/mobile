import 'dart:async';
import 'dart:convert';

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
/// - SOAP (`/soap/payroll`) đi qua gateway nguyên vẹn XML, không bọc envelope.
class ApiClient {
  final String baseUrl;
  final Duration timeout;
  String? _cookie;
  String? _accessToken;

  ApiClient({String? baseUrl, Duration? timeout})
      : baseUrl = baseUrl ?? CompanyConfig.apiBaseUrl,
        timeout = timeout ?? CompanyConfig.apiTimeout;

  void setSession({String? cookie, String? accessToken}) {
    _cookie = cookie;
    _accessToken = accessToken;
  }

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    if (_cookie != null) h['Cookie'] = _cookie!;
    if (_accessToken != null) h['Authorization'] = 'Bearer $_accessToken';
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

  /// GET JSON, trả về `data` trong envelope.
  Future<dynamic> getJson(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    late http.Response res;
    try {
      res = await http.get(uri, headers: _headers(json: false)).timeout(timeout);
    } on TimeoutException {
      throw const ApiException('TIMEOUT', 'Hết thời gian chờ máy chủ', 504);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      dynamic body;
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        body = null;
      }
      _throwFromBody(res.statusCode, body);
    }
    final body = jsonDecode(res.body);
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  /// POST JSON, trả về `data` trong envelope.
  Future<dynamic> postJson(String path, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl$path');
    late http.Response res;
    try {
      res = await http
          .post(uri, headers: _headers(), body: jsonEncode(payload))
          .timeout(timeout);
    } on TimeoutException {
      throw const ApiException('TIMEOUT', 'Hết thời gian chờ máy chủ', 504);
    }
    // Lưu cookie phiên hrm-session nếu server set.
    final setCookie = res.headers['set-cookie'];
    if (setCookie != null && setCookie.contains('hrm-session')) {
      _cookie = setCookie.split(';').first;
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      dynamic body;
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        body = null;
      }
      _throwFromBody(res.statusCode, body);
    }
    final body = jsonDecode(res.body);
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  /// POST SOAP nguyên vẹn XML (gateway không bọc envelope).
  Future<String> postSoap(String xmlBody) async {
    final uri = Uri.parse('$baseUrl/soap/payroll');
    late http.Response res;
    try {
      res = await http
          .post(uri,
              headers: {
                'Content-Type': 'text/xml; charset=utf-8',
                if (_cookie != null) 'Cookie': _cookie!,
              },
              body: xmlBody)
          .timeout(timeout);
    } on TimeoutException {
      throw const ApiException('TIMEOUT', 'Hết thời gian chờ máy chủ', 504);
    }
    return res.body;
  }

  Future<dynamic> putJson(String path, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl$path');
    late http.Response res;
    try {
      res = await http
          .put(uri, headers: _headers(), body: jsonEncode(payload))
          .timeout(timeout);
    } on TimeoutException {
      throw const ApiException('TIMEOUT', 'Hết thời gian chờ máy chủ', 504);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      dynamic body;
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        body = null;
      }
      _throwFromBody(res.statusCode, body);
    }
    final body = jsonDecode(res.body);
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  Future<void> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    late http.Response res;
    try {
      res = await http.delete(uri, headers: _headers(json: false)).timeout(timeout);
    } on TimeoutException {
      throw const ApiException('TIMEOUT', 'Hết thời gian chờ máy chủ', 504);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      dynamic body;
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        body = null;
      }
      _throwFromBody(res.statusCode, body);
    }
  }
}
