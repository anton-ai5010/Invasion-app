import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'models.dart';
import 'cache.dart';

class Api {
  final String baseUrl;
  String? _token;
  String _locale = 'ru';

  Api({required this.baseUrl});

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _locale = prefs.getString('locale') ?? 'ru';
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove('auth_token');
    } else {
      await prefs.setString('auth_token', token);
    }
  }

  Future<void> setLocale(String locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale);
  }

  Map<String, String> get _headers {
    final h = {
      'Content-Type': 'application/json',
      'Accept-Language': _locale,
    };
    if (_token != null) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  Future<bool> _hasNetwork() async {
    final res = await Connectivity().checkConnectivity();
    return res.contains(ConnectivityResult.mobile) || 
           res.contains(ConnectivityResult.wifi) || 
           res.contains(ConnectivityResult.ethernet);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (queryParams != null) {
      uri = uri.replace(queryParameters: queryParams);
    }

    http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: _headers);
        break;
      case 'POST':
        response = await http.post(
          uri,
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: _headers);
        break;
      default:
        throw Exception('Unsupported method: $method');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {};
      }
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw ApiException(
        code: error['code'] ?? 'UNKNOWN_ERROR',
        message: error['detail'] ?? 'Unknown error',
      );
    }
  }

  // Auth
  Future<void> register(String email, String username, String password) async {
    await _request('POST', '/auth/register', body: {
      'email': email,
      'username': username,
      'password': password,
      'locale': _locale,
    });
  }

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept-Language': _locale,
      },
      body: {
        'username': email,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await setToken(data['access_token']);
    } else {
      final error = jsonDecode(response.body);
      throw ApiException(
        code: error['code'] ?? 'UNKNOWN_ERROR',
        message: error['detail'] ?? 'Unknown error',
      );
    }
  }

  Future<User> getMe() async {
    final data = await _request('GET', '/auth/me');
    return User.fromJson(data);
  }

  Future<void> logout() async {
    await setToken(null);
  }

  // Zones
  Future<List<Zone>> getZones({bool force = false}) async {
    const key = 'zones_v1';
    if (!force) {
      final cached = await Cache.getJson(key);
      if (cached != null) {
        final list = (cached['_list'] as List).cast<dynamic>();
        return list.map((e) => Zone.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    if (!await _hasNetwork()) {
      // оффлайн и нет кэша → ошибка
      final cached = await Cache.getJson(key);
      if (cached != null) {
        final list = (cached['_list'] as List).cast<dynamic>();
        return list.map((e) => Zone.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw ApiException(code: 'NO_NETWORK', message: 'Нет сети и нет локального кэша');
    }
    final data = await _request('GET', '/zones');
    final list = data as List;
    await Cache.setJson(key, list, ttl: const Duration(minutes: 10));
    return list.map((z) => Zone.fromJson(z)).toList();
  }

  Future<ZoneLayout> getZoneLayout(int zoneId, {bool force = false}) async {
    final key = 'zone_layout_v1_$zoneId';
    if (!force) {
      final cached = await Cache.getJson(key);
      if (cached != null) return ZoneLayout.fromJson(cached);
    }
    if (!await _hasNetwork()) {
      final cached = await Cache.getJson(key);
      if (cached != null) return ZoneLayout.fromJson(cached);
      throw ApiException(code: 'NO_NETWORK', message: 'Нет сети и нет локального кэша');
    }
    final data = await _request('GET', '/zones/$zoneId/layout');
    await Cache.setJson(key, data, ttl: const Duration(minutes: 10));
    return ZoneLayout.fromJson(data);
  }

  // Bookings
  Future<Booking> createBooking(int seatId, DateTime startTime, int hours) async {
    final data = await _request('POST', '/bookings', body: {
      'seat_id': seatId,
      'start_time': startTime.toUtc().toIso8601String(),
      'hours': hours,
    });
    return Booking.fromJson(data);
  }

  Future<List<Booking>> getMyBookings() async {
    final data = await _request('GET', '/bookings');
    return (data as List).map((b) => Booking.fromJson(b)).toList();
  }

  Future<Booking> cancelBooking(int bookingId) async {
    final data = await _request('POST', '/bookings/$bookingId/cancel');
    return Booking.fromJson(data);
  }

  // Availability
  Future<List<SeatAvailability>> getSeatAvailability(
    DateTime date, {
    int? zoneId,
    int? seatId,
  }) async {
    final params = {
      'date_utc': date.toUtc().toIso8601String().split('T')[0],
    };
    if (zoneId != null) params['zone_id'] = zoneId.toString();
    if (seatId != null) params['seat_id'] = seatId.toString();

    final data = await _request('GET', '/availability/seats', queryParams: params);
    return (data as List).map((s) => SeatAvailability.fromJson(s)).toList();
  }

  // Admin methods
  Future<List<AdminBooking>> adminBookingsToday({int? zoneId}) async {
    final qp = <String, String>{};
    if (zoneId != null) qp['zone_id'] = '$zoneId';
    final data = await _request('GET', '/admin/bookings/today', queryParams: qp);
    final map = data as Map<String, dynamic>;
    final items = (map['items'] as List).cast<Map<String, dynamic>>();
    return items.map((e) => AdminBooking.fromJson(e)).toList();
  }

  Future<void> adminMarkPaid(int bookingId) async {
    await _request('POST', '/admin/bookings/$bookingId/mark_paid');
  }

  Future<void> adminComplete(int bookingId) async {
    await _request('POST', '/admin/bookings/$bookingId/complete');
  }

  Future<void> adminNoShow(int bookingId) async {
    await _request('POST', '/admin/bookings/$bookingId/no_show');
  }

  Future<RowPriceResult> adminUpdateRowPrice({
    required int zoneId,
    required String row,
    int? hourlyPriceRub,
    String? seatType,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (hourlyPriceRub != null) body['hourly_price_rub'] = hourlyPriceRub;
    if (seatType != null) body['seat_type'] = seatType;
    if (isActive != null) body['is_active'] = isActive;
    
    final data = await _request(
      'POST',
      '/admin/zones/$zoneId/rows/$row/price',
      body: body,
    );
    return RowPriceResult.fromJson(data);
  }
}

class ApiException implements Exception {
  final String code;
  final String message;

  ApiException({required this.code, required this.message});

  @override
  String toString() => 'ApiException: $code - $message';
}