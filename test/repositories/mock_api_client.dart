import 'package:mobile/src/core/network/api_client.dart';

/// Captured request info for assertions.
class CapturedRequest {
  final String method;
  final String path;
  final Map<String, String>? query;
  final Map<String, dynamic>? payload;

  const CapturedRequest({
    required this.method,
    required this.path,
    this.query,
    this.payload,
  });
}

/// Zero-dependency mock for ApiClient in repository unit tests.
class MockApiClient extends ApiClient {
  final List<CapturedRequest> requests = [];

  dynamic getJsonResponse;
  dynamic postJsonResponse;
  dynamic putJsonResponse;
  String? postSoapResponse;

  dynamic Function(String path, Map<String, String>? query)? getJsonHandler;
  dynamic Function(String path, Map<String, dynamic> payload)? postJsonHandler;
  dynamic Function(String path, Map<String, dynamic> payload)? putJsonHandler;
  void Function(String path)? deleteHandler;

  MockApiClient() : super(baseUrl: 'http://mock-gateway:4000');

  void reset() {
    requests.clear();
    getJsonResponse = null;
    postJsonResponse = null;
    putJsonResponse = null;
    postSoapResponse = null;
    getJsonHandler = null;
    postJsonHandler = null;
    putJsonHandler = null;
    deleteHandler = null;
  }

  @override
  Future<dynamic> getJson(String path, {Map<String, String>? query}) async {
    requests.add(CapturedRequest(
      method: 'GET',
      path: path,
      query: query,
    ));
    if (getJsonHandler != null) {
      return getJsonHandler!(path, query);
    }
    return getJsonResponse;
  }

  @override
  Future<dynamic> postJson(String path, Map<String, dynamic> payload) async {
    requests.add(CapturedRequest(
      method: 'POST',
      path: path,
      payload: payload,
    ));
    if (postJsonHandler != null) {
      return postJsonHandler!(path, payload);
    }
    return postJsonResponse;
  }

  @override
  Future<dynamic> putJson(String path, Map<String, dynamic> payload) async {
    requests.add(CapturedRequest(
      method: 'PUT',
      path: path,
      payload: payload,
    ));
    if (putJsonHandler != null) {
      return putJsonHandler!(path, payload);
    }
    return putJsonResponse;
  }

  @override
  Future<void> delete(String path) async {
    requests.add(CapturedRequest(
      method: 'DELETE',
      path: path,
    ));
    if (deleteHandler != null) {
      deleteHandler!(path);
    }
  }

  @override
  Future<String> postSoap(String xmlBody) async {
    requests.add(CapturedRequest(
      method: 'SOAP',
      path: '/soap/payroll',
      payload: {'xml': xmlBody},
    ));
    return postSoapResponse ?? '<soap:Envelope/>';
  }
}
