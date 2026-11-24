import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class LocationHelper {
  /// Mendeteksi kota saat ini berdasarkan GPS atau fallback IP
  static Future<String?> detectCurrentCity() async {
    try {
      // 1. Coba deteksi via GPS/Geolocator
      final gpsCity = await _detectViaGps();
      if (gpsCity != null && gpsCity.isNotEmpty) {
        return _cleanCityName(gpsCity);
      }
    } catch (e) {
      debugPrint('GPS detection failed: $e');
    }

    // 2. Fallback via IP Geolocation (Berguna jika pengguna menolak izin GPS atau di simulator/web)
    try {
      final ipCity = await _detectViaIp();
      if (ipCity != null && ipCity.isNotEmpty) {
        return _cleanCityName(ipCity);
      }
    } catch (e) {
      debugPrint('IP detection failed: $e');
    }

    return null;
  }

  static Future<String?> _detectViaGps() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    // Ambil posisi terakhir atau posisi saat ini dengan timeout singkat
    Position? position;
    try {
      position = await Geolocator.getLastKnownPosition();
    } catch (_) {}

    position ??= await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 5),
      ),
    );

    // Reverse geocoding via geocoding package
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // Prioritaskan subAdministrativeArea (Kabupaten/Kota), lalu locality (Kota/Kecamatan), lalu administrativeArea (Provinsi)
        final candidate = place.subAdministrativeArea ?? place.locality ?? place.administrativeArea;
        if (candidate != null && candidate.isNotEmpty) {
          return candidate;
        }
      }
    } catch (_) {
      // Jika geocoding lokal gagal (misal di web atau tanpa Google Play Services), reverse geocode via OpenStreetMap Nominatim
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}',
        );
        final res = await http.get(url, headers: {'User-Agent': 'KLIK-Mobile-App/1.0'});
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final addr = data['address'] as Map<String, dynamic>?;
          if (addr != null) {
            return addr['city'] ?? addr['county'] ?? addr['municipality'] ?? addr['state'];
          }
        }
      } catch (_) {}
    }

    return null;
  }

  static Future<String?> _detectViaIp() async {
    final apis = [
      'https://ipwho.is/',
      'https://ipapi.co/json/',
      'http://ip-api.com/json',
    ];

    for (final url in apis) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final city = data['city'] as String?;
          if (city != null && city.isNotEmpty) {
            return city;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  static String _cleanCityName(String raw) {
    var cleaned = raw.trim();
    // Hilangkan prefix umum di Indonesia seperti "Kota Administrasi", "Kota ", "Kabupaten ", "Kab. "
    cleaned = cleaned.replaceAll(
      RegExp(r'^(Kota\s+Administrasi|Kota|Kabupaten|Kab\.)\s+', caseSensitive: false),
      '',
    );
    return cleaned.trim();
  }
}
