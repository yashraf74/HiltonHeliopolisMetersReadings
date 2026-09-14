import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/strings.dart';
import '../db/database.dart';
import '../models.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thrown when the device could not reach the server at all (no network,
/// DNS failure, timeout). Distinct from [ApiException] so callers can treat
/// it as "try again later" rather than "the server rejected this".
class NetworkException implements Exception {
  @override
  String toString() => S.networkError;
}

class LoginResult {
  const LoginResult({required this.token, required this.user});

  final String token;
  final AuthUser user;
}

/// Thin typed wrapper over the Worker's REST API. Holds no state except a
/// callback that supplies the current bearer token.
class ApiClient {
  ApiClient({
    required String Function() tokenProvider,
    http.Client? httpClient,
    String baseUrl = AppConfig.apiBaseUrl,
  }) : _tokenProvider = tokenProvider,
       _http = httpClient ?? http.Client(),
       _baseUrl = baseUrl;

  final String Function() _tokenProvider;
  final http.Client _http;
  final String _baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl/api$path').replace(queryParameters: query);

  Map<String, String> _headers({bool auth = true, String? contentType}) => {
    'Content-Type': ?contentType,
    if (auth) 'Authorization': 'Bearer ${_tokenProvider()}',
  };

  Future<Map<String, dynamic>> _json(Future<http.Response> request) async {
    final http.Response response;
    try {
      response = await request.timeout(AppConfig.requestTimeout);
    } on SocketException {
      throw NetworkException();
    } on HttpException {
      throw NetworkException();
    } on http.ClientException {
      throw NetworkException();
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) throw NetworkException();
      rethrow;
    }

    Map<String, dynamic> body = const {};
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        body = const {};
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw ApiException(
      response.statusCode,
      body['error'] as String? ?? S.serverError,
    );
  }

  // ---- auth ---------------------------------------------------------------

  Future<LoginResult> login(String username, String password) async {
    final body = await _json(
      _http.post(
        _uri('/auth/login'),
        headers: _headers(auth: false, contentType: 'application/json'),
        body: jsonEncode({'username': username, 'password': password}),
      ),
    );
    return LoginResult(
      token: body['token'] as String,
      user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
    );
  }

  // ---- meters -------------------------------------------------------------

  Future<List<Meter>> fetchMeters({bool includeInactive = false}) async {
    final body = await _json(
      _http.get(
        _uri('/meters', includeInactive ? {'includeInactive': '1'} : null),
        headers: _headers(),
      ),
    );
    final rows = body['meters'] as List<dynamic>;
    return rows.map((r) => _meterFromJson(r as Map<String, dynamic>)).toList();
  }

  Future<String> createMeter({
    required MeterType type,
    required String location,
    required int floorNumber,
    String? description,
  }) async {
    final body = await _json(
      _http.post(
        _uri('/meters'),
        headers: _headers(contentType: 'application/json'),
        body: jsonEncode({
          'type': type.name,
          'location': location,
          'floorNumber': floorNumber,
          'description': description,
        }),
      ),
    );
    return body['id'] as String;
  }

  Future<void> updateMeter(
    String id, {
    MeterType? type,
    String? location,
    int? floorNumber,
    String? description,
  }) async {
    await _json(
      _http.put(
        _uri('/meters/$id'),
        headers: _headers(contentType: 'application/json'),
        body: jsonEncode({
          'type': ?type?.name,
          'location': ?location,
          'floorNumber': ?floorNumber,
          'description': ?description,
        }),
      ),
    );
  }

  Future<void> retireMeter(String id) async {
    await _json(_http.delete(_uri('/meters/$id'), headers: _headers()));
  }

  // ---- photos & readings --------------------------------------------------

  Future<String> uploadPhoto(
    List<int> bytes, {
    String contentType = 'image/jpeg',
  }) async {
    final body = await _json(
      _http.post(
        _uri('/photos'),
        headers: _headers(contentType: contentType),
        body: bytes,
      ),
    );
    return body['photoKey'] as String;
  }

  Uri photoUri(String key) => _uri('/photos', {'key': key});

  Map<String, String> get authHeaders => _headers();

  /// Idempotent on the server by [id]; safe to retry.
  Future<String> submitReading({
    required String id,
    required String meterId,
    required double value,
    required String photoKey,
    required String loggedAt,
  }) async {
    final body = await _json(
      _http.post(
        _uri('/readings'),
        headers: _headers(contentType: 'application/json'),
        body: jsonEncode({
          'id': id,
          'meterId': meterId,
          'value': value,
          'photoKey': photoKey,
          'loggedAt': loggedAt,
        }),
      ),
    );
    return body['syncedAt'] as String;
  }

  Future<List<Map<String, dynamic>>> fetchReadings(
    Map<String, String> filters,
  ) async {
    final body = await _json(
      _http.get(
        _uri('/readings', filters.isEmpty ? null : filters),
        headers: _headers(),
      ),
    );
    return (body['readings'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Meter _meterFromJson(Map<String, dynamic> j) => Meter(
    id: j['id'] as String,
    type: j['type'] as String,
    location: j['location'] as String,
    floorNumber: j['floor_number'] as int,
    description: j['description'] as String?,
    isActive: (j['is_active'] as int) == 1,
    updatedAt: j['updated_at'] as String,
  );
}
