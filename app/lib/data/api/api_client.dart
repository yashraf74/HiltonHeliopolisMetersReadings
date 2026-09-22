import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/strings.dart';
import '../db/database.dart';
import '../models.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.code});

  final int statusCode;
  final String message;
  final String? code;

  bool get isUnauthorized => statusCode == 401;
  bool get isUpgradeRequired => statusCode == 426;
  bool get isMaintenance => statusCode == 503 && code == 'maintenance';

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

class ReadingsPage {
  const ReadingsPage({required this.rows, required this.nextCursor});

  final List<Map<String, dynamic>> rows;
  final String? nextCursor;
}

class LoginResult {
  const LoginResult({required this.token, required this.user});

  final String token;
  final AuthUser user;
}

/// Thin typed wrapper over the Worker's REST API. Holds no state except
/// callbacks supplying the bearer token and reporting connectivity / gate
/// events (upgrade required, maintenance).
class ApiClient {
  ApiClient({
    required String Function() tokenProvider,
    required String appVersion,
    http.Client? httpClient,
    String baseUrl = BuildConfig.apiBaseUrl,
    void Function(bool reachable)? onReachability,
    void Function(ApiException e)? onGate,
  }) : _tokenProvider = tokenProvider,
       _appVersion = appVersion,
       _http = httpClient ?? http.Client(),
       _baseUrl = baseUrl,
       _onReachability = onReachability,
       _onGate = onGate;

  final String Function() _tokenProvider;
  final String _appVersion;
  final http.Client _http;
  final String _baseUrl;

  /// Reports ground-truth connectivity: true after any completed request,
  /// false when the server could not be reached at all.
  final void Function(bool reachable)? _onReachability;

  /// Called on 426 (upgrade required) and 503 maintenance responses.
  final void Function(ApiException e)? _onGate;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl/api$path').replace(queryParameters: query);

  Map<String, String> _headers({bool auth = true, String? contentType}) => {
    'X-App-Version': _appVersion,
    'Content-Type': ?contentType,
    if (auth) 'Authorization': 'Bearer ${_tokenProvider()}',
  };

  Future<Map<String, dynamic>> _json(Future<http.Response> request) async {
    final http.Response response;
    try {
      response = await request.timeout(BuildConfig.requestTimeout);
    } on SocketException {
      _onReachability?.call(false);
      throw NetworkException();
    } on HttpException {
      _onReachability?.call(false);
      throw NetworkException();
    } on http.ClientException {
      _onReachability?.call(false);
      throw NetworkException();
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) {
        _onReachability?.call(false);
        throw NetworkException();
      }
      rethrow;
    }
    _onReachability?.call(true);

    Map<String, dynamic> body = const {};
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        body = const {};
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    final error = ApiException(
      response.statusCode,
      body['error'] as String? ?? S.serverError,
      code: body['code'] as String?,
    );
    if (error.isUpgradeRequired || error.isMaintenance) _onGate?.call(error);
    throw error;
  }

  // ---- auth & config ------------------------------------------------------

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

  Future<AppConfig> fetchConfig() async {
    final body = await _json(
      _http.get(_uri('/config'), headers: _headers(auth: false)),
    );
    return AppConfig.fromJson(body);
  }

  Future<AppSettings> fetchSettings() async {
    final body = await _json(_http.get(_uri('/settings'), headers: _headers()));
    return AppSettings.fromJson(body);
  }

  Future<AppSettings> saveSettings(AppSettings settings) async {
    final body = await _json(
      _http.put(
        _uri('/settings'),
        headers: _headers(contentType: 'application/json'),
        body: jsonEncode(settings.toJson()),
      ),
    );
    return AppSettings.fromJson(body);
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
    required String name,
    required String area,
    String? number,
    String? photoKey,
    int? todoOrder,
    int? exportOrder,
  }) async {
    final body = await _json(
      _http.post(
        _uri('/meters'),
        headers: _headers(contentType: 'application/json'),
        body: jsonEncode({
          'type': type.name,
          'name': name,
          'area': area,
          'number': number ?? '',
          'photoKey': ?photoKey,
          'todoOrder': todoOrder,
          'exportOrder': exportOrder,
        }),
      ),
    );
    return body['id'] as String;
  }

  /// [photoKey]: pass a key to set, `null` with [clearPhoto] to remove,
  /// omit both to leave the photo unchanged. Order numbers are always sent
  /// (null clears).
  Future<void> updateMeter(
    String id, {
    MeterType? type,
    String? name,
    String? area,
    String? number,
    String? photoKey,
    bool clearPhoto = false,
    int? todoOrder,
    int? exportOrder,
  }) async {
    await _json(
      _http.put(
        _uri('/meters/$id'),
        headers: _headers(contentType: 'application/json'),
        body: jsonEncode({
          'type': ?type?.name,
          'name': ?name,
          'area': ?area,
          'number': ?number,
          if (photoKey != null || clearPhoto) 'photoKey': photoKey,
          'todoOrder': todoOrder,
          'exportOrder': exportOrder,
        }),
      ),
    );
  }

  Future<void> retireMeter(String id) async {
    await _json(_http.delete(_uri('/meters/$id'), headers: _headers()));
  }

  // ---- photos & readings --------------------------------------------------

  /// [forMeter] stores under meters/ (moderator-only reference photos).
  Future<String> uploadPhoto(
    List<int> bytes, {
    String contentType = 'image/jpeg',
    bool forMeter = false,
  }) async {
    final body = await _json(
      _http.post(
        _uri('/photos', forMeter ? {'kind': 'meter'} : null),
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

  /// Emails an exported workbook to the signed-in user's own address and
  /// returns that address.
  Future<String> emailExport(String fileName, List<int> bytes) async {
    final body = await _json(
      _http.post(
        _uri('/exports/email'),
        headers: _headers(contentType: 'application/json'),
        body: jsonEncode({
          'fileName': fileName,
          'content': base64Encode(bytes),
        }),
      ),
    );
    return body['sentTo'] as String;
  }

  static const readingsPageSize = 50;

  Future<ReadingsPage> fetchReadings(
    Map<String, String> filters, {
    String? cursor,
    int limit = readingsPageSize,
    bool forExport = false,
  }) async {
    final body = await _json(
      _http.get(
        _uri('/readings', {
          ...filters,
          // Local offset so the default sort groups readings by local day.
          'tz': '${DateTime.now().timeZoneOffset.inMinutes}',
          'limit': '$limit',
          'cursor': ?cursor,
          if (forExport) 'export': '1',
        }),
        headers: _headers(),
      ),
    );
    return ReadingsPage(
      rows: (body['readings'] as List<dynamic>).cast<Map<String, dynamic>>(),
      nextCursor: body['nextCursor'] as String?,
    );
  }

  /// Walks every page for an export. [maxRows] is a safety cap.
  Future<List<Map<String, dynamic>>> fetchAllReadings(
    Map<String, String> filters, {
    int maxRows = 20000,
  }) async {
    final all = <Map<String, dynamic>>[];
    String? cursor;
    do {
      final page = await fetchReadings(
        filters,
        cursor: cursor,
        limit: 200,
        forExport: true,
      );
      all.addAll(page.rows);
      cursor = page.nextCursor;
    } while (cursor != null && all.length < maxRows);
    return all;
  }

  Future<void> updateReadingValue(String id, double value) async {
    await _json(
      _http.put(
        _uri('/readings/$id'),
        headers: _headers(contentType: 'application/json'),
        body: jsonEncode({'value': value}),
      ),
    );
  }

  Future<void> deleteReading(String id) async {
    await _json(_http.delete(_uri('/readings/$id'), headers: _headers()));
  }

  // ---- users --------------------------------------------------------------

  Future<List<UserName>> fetchUserNames() async {
    final body = await _json(
      _http.get(_uri('/users/names'), headers: _headers()),
    );
    return (body['users'] as List<dynamic>)
        .map(
          (u) => UserName(
            id: u['id'] as String,
            fullName: u['fullName'] as String,
          ),
        )
        .toList();
  }

  Future<List<AppUser>> fetchUsers() async {
    final body = await _json(_http.get(_uri('/users'), headers: _headers()));
    return (body['users'] as List<dynamic>)
        .map((u) => AppUser.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  Future<String> createUser({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required UserRole role,
  }) async {
    final body = await _json(
      _http.post(
        _uri('/users'),
        headers: _headers(contentType: 'application/json'),
        body: jsonEncode({
          'username': username,
          'password': password,
          'fullName': fullName,
          'email': email,
          'role': role.name,
        }),
      ),
    );
    return body['id'] as String;
  }

  Future<void> updateUser(
    String id, {
    String? fullName,
    String? email,
    UserRole? role,
    bool? isActive,
    String? password,
  }) async {
    await _json(
      _http.put(
        _uri('/users/$id'),
        headers: _headers(contentType: 'application/json'),
        body: jsonEncode({
          'fullName': ?fullName,
          'email': ?email,
          'role': ?role?.name,
          'isActive': ?isActive,
          'password': ?password,
        }),
      ),
    );
  }

  // ---- dashboard ----------------------------------------------------------

  Future<Map<String, dynamic>> fetchDashboard(
    DateTime from,
    DateTime to,
  ) async {
    final tz = DateTime.now().timeZoneOffset.inMinutes;
    return _json(
      _http.get(
        _uri('/dashboard', {
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
          'tz': '$tz',
        }),
        headers: _headers(),
      ),
    );
  }

  Meter _meterFromJson(Map<String, dynamic> j) => Meter(
    id: j['id'] as String,
    name: j['name'] as String,
    type: j['type'] as String,
    area: j['area'] as String? ?? '',
    number: j['number'] as String?,
    photoKey: j['photo_key'] as String?,
    lastLoggedAt: j['last_logged_at'] as String?,
    lastValue: (j['last_value'] as num?)?.toDouble(),
    todoOrder: j['todo_order'] as int?,
    exportOrder: j['export_order'] as int?,
    isActive: (j['is_active'] as int) == 1,
    updatedAt: j['updated_at'] as String,
  );
}
