import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../settings/settings_controller.dart';

/// Météo actuelle et prévisions du jour.
class WeatherSnapshot {
  final double temperature;
  final double apparent;
  final int code;
  final bool isDay;
  final double min;
  final double max;
  final int precipitationChance;
  final double wind;
  final List<HourForecast> hours;

  const WeatherSnapshot({
    required this.temperature,
    required this.apparent,
    required this.code,
    required this.isDay,
    required this.min,
    required this.max,
    required this.precipitationChance,
    required this.wind,
    required this.hours,
  });

  WeatherCondition get condition => WeatherCondition.fromCode(code, isDay: isDay);
}

class HourForecast {
  final DateTime time;
  final double temperature;
  final int code;
  const HourForecast(this.time, this.temperature, this.code);
}

/// Traduction des codes météo WMO utilisés par Open-Meteo.
class WeatherCondition {
  final String label;
  final IconData icon;
  final List<Color> gradient;

  const WeatherCondition(this.label, this.icon, this.gradient);

  static const _clearDay = [Color(0xFF2F80ED), Color(0xFF56CCF2)];
  static const _clearNight = [Color(0xFF141E30), Color(0xFF243B55)];
  static const _cloudy = [Color(0xFF4B5563), Color(0xFF6B7280)];
  static const _rain = [Color(0xFF1F2937), Color(0xFF3B5B7D)];
  static const _storm = [Color(0xFF1E1B4B), Color(0xFF4C1D95)];
  static const _snow = [Color(0xFF64748B), Color(0xFFB8C6DB)];

  static WeatherCondition fromCode(int code, {bool isDay = true}) {
    if (code == 0) {
      return isDay
          ? const WeatherCondition('Ensoleillé', Icons.wb_sunny_rounded, _clearDay)
          : const WeatherCondition('Ciel dégagé', Icons.nightlight_round, _clearNight);
    }
    if (code <= 2) {
      return WeatherCondition('Éclaircies', isDay ? Icons.wb_cloudy_rounded : Icons.nights_stay_rounded, isDay ? _clearDay : _clearNight);
    }
    if (code == 3) return const WeatherCondition('Couvert', Icons.cloud_rounded, _cloudy);
    if (code == 45 || code == 48) return const WeatherCondition('Brouillard', Icons.foggy, _cloudy);
    if (code >= 51 && code <= 57) return const WeatherCondition('Bruine', Icons.grain_rounded, _rain);
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      return const WeatherCondition('Pluie', Icons.water_drop_rounded, _rain);
    }
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return const WeatherCondition('Neige', Icons.ac_unit_rounded, _snow);
    }
    if (code >= 95) return const WeatherCondition('Orage', Icons.thunderstorm_rounded, _storm);
    return const WeatherCondition('Variable', Icons.cloud_queue_rounded, _cloudy);
  }
}

/// Client Open-Meteo : gratuit, sans clé, sans géolocalisation.
class WeatherService {
  final http.Client _client;
  WeatherService([http.Client? client]) : _client = client ?? http.Client();

  Future<List<WeatherLocation>> searchCity(String query) async {
    if (query.trim().length < 2) return [];
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': query.trim(),
      'count': '8',
      'language': 'fr',
      'format': 'json',
    });
    final response = await _client.get(uri);
    if (response.statusCode != 200) return [];
    final results = (json.decode(response.body)['results'] as List?) ?? const [];
    return results.map((r) {
      final region = [r['admin1'], r['country']].whereType<String>().where((s) => s.isNotEmpty).join(', ');
      return WeatherLocation(
        name: r['name'] as String,
        region: region,
        latitude: (r['latitude'] as num).toDouble(),
        longitude: (r['longitude'] as num).toDouble(),
      );
    }).toList();
  }

  Future<WeatherSnapshot> fetch(WeatherLocation location) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${location.latitude}',
      'longitude': '${location.longitude}',
      'current': 'temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m',
      'hourly': 'temperature_2m,weather_code',
      'daily': 'temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'forecast_days': '2',
      'timezone': 'auto',
    });
    final response = await _client.get(uri);
    if (response.statusCode != 200) throw Exception('Météo indisponible (${response.statusCode})');
    final data = json.decode(response.body) as Map<String, dynamic>;
    final current = data['current'] as Map<String, dynamic>;
    final daily = data['daily'] as Map<String, dynamic>;
    final hourly = data['hourly'] as Map<String, dynamic>;

    final now = DateTime.now();
    final currentHour = DateTime(now.year, now.month, now.day, now.hour);
    final times = (hourly['time'] as List).map((t) => DateTime.parse(t as String)).toList();
    final hours = <HourForecast>[];
    for (var i = 0; i < times.length && hours.length < 8; i++) {
      if (!times[i].isBefore(currentHour)) {
        hours.add(HourForecast(
          times[i],
          (hourly['temperature_2m'][i] as num).toDouble(),
          (hourly['weather_code'][i] as num).toInt(),
        ));
      }
    }

    return WeatherSnapshot(
      temperature: (current['temperature_2m'] as num).toDouble(),
      apparent: (current['apparent_temperature'] as num).toDouble(),
      code: (current['weather_code'] as num).toInt(),
      isDay: (current['is_day'] as num?) != 0,
      wind: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      min: (daily['temperature_2m_min'][0] as num).toDouble(),
      max: (daily['temperature_2m_max'][0] as num).toDouble(),
      precipitationChance: (daily['precipitation_probability_max'][0] as num?)?.toInt() ?? 0,
      hours: hours,
    );
  }
}
