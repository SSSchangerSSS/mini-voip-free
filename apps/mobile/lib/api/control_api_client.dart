import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_models.dart';

/// Control API client (spec section 7). TLS verification is NEVER disabled here
/// (spec 11.1) — no badCertificateCallback overrides exist in this codebase.
/// Base URL is always `https://` + domain — scheme/host come from the user-supplied
/// domain at login; path/version are fixed.
class ControlApiClient {
  final http.Client _http;
  final Duration requestTimeout;
  String? _token;

  /// Set at sign-in / restore from the secure store. The domain is user input;
  /// scheme is always https and the path is fixed by the contract.
  String domain;
  Uri get baseUri => Uri.parse('https://$domain/api/v1');

  ControlApiClient({required this.domain, http.Client? client,
      this.requestTimeout = const Duration(seconds: 15)})
      : _http = client ?? http.Client();

  void setToken(String? token) => _token = token;

  void setDomain(String d) => domain = d;

  Map<String, String> _headers({bool auth = true, String? idempotencyKey}) {
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Idempotency-Key': ?idempotencyKey, // null-aware value: entry omitted when key absent
      if (auth && _token != null) 'Authorization': 'Bearer $_token',
    };
    return h;
  }

  ApiProblem _problem(http.Response res) {
    String code = 'INTERNAL';
    String? traceId;
    String? callId;
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (j is Map<String, dynamic>) {
        code = (j['code'] as String?) ?? code;
        traceId = j['traceId'] as String?;
        callId = j['callId'] as String?;
      }
    } catch (_) {
      // non-JSON error body — keep the generic code
    }
    return ApiProblem(res.statusCode, code, traceId: traceId, callId: callId);
  }

  Future<LoginResult> login({
    required String extension,
    required String password,
    required String installationId,
    required String platform,
  }) async {
    final res = await _http.post(
      baseUri.replace(path: '${baseUri.path}/sessions'),
      headers: _headers(auth: false),
      body: jsonEncode({
        'extension': extension,
        'password': password,
        'installationId': installationId,
        'platform': platform,
      }),
    ).timeout(requestTimeout);
    if (res.statusCode != 200) throw _problem(res);
    return LoginResult.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<MeResponse> me() async {
    final res = await _http.get(baseUri.replace(path: '${baseUri.path}/me'),
        headers: _headers()).timeout(requestTimeout);
    if (res.statusCode != 200) throw _problem(res);
    return MeResponse.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<void> registerPush({
    required String provider,
    required String token,
    required String environment,
  }) async {
    final res = await _http.put(
      baseUri.replace(path: '${baseUri.path}/devices/current/push'),
      headers: _headers(),
      body: jsonEncode({
        'provider': provider,
        'token': token,
        'environment': environment,
      }),
    ).timeout(requestTimeout);
    if (res.statusCode != 204) throw _problem(res);
  }

  Future<CallDto?> currentCall({String? attemptId}) async {
    final uri = baseUri.replace(
      path: '${baseUri.path}/calls/current',
      queryParameters: attemptId == null ? null : {'attemptId': attemptId},
    );
    final res = await _http.get(uri, headers: _headers()).timeout(requestTimeout);
    if (res.statusCode != 200) throw _problem(res);
    final text = utf8.decode(res.bodyBytes);
    if (text == 'null' || text.isEmpty) return null;
    return CallDto.fromJson(jsonDecode(text) as Map<String, dynamic>);
  }

  Future<CallDto> callAction(String path, String callId,
      {String? idempotencyKey, Map<String, dynamic>? body}) async {
    final res = await _http.post(
      baseUri.replace(path: '${baseUri.path}/calls/$callId/$path'),
      headers: _headers(idempotencyKey: idempotencyKey),
      body: jsonEncode(body ?? const <String, dynamic>{}),
    ).timeout(requestTimeout);
    if (res.statusCode == 200 || res.statusCode == 202) {
      return CallDto.fromJson(
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
    }
    throw _problem(res);
  }

  Future<void> logout() async {
    final res = await _http.delete(
        baseUri.replace(path: '${baseUri.path}/sessions/current'),
        headers: _headers()).timeout(requestTimeout);
    if (res.statusCode != 204 && res.statusCode != 401) throw _problem(res);
  }
}
