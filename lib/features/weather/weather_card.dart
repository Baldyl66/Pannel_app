import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import '../settings/settings_controller.dart';
import 'weather_service.dart';

/// Ouvre la recherche de ville et enregistre le choix.
Future<void> pickWeatherCity(BuildContext context) async {
  final settings = context.app.settings;
  final location = await showAppSheet<WeatherLocation>(
    context,
    title: 'Ville pour la météo',
    subtitle: 'Aucune localisation n\'est utilisée',
    builder: (_) => const _CitySearch(),
  );
  if (location != null) await settings.setWeather(location);
}

/// Carte météo de l'accueil.
class WeatherCard extends StatefulWidget {
  final WeatherLocation? location;
  const WeatherCard({super.key, required this.location});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  final _service = WeatherService();
  WeatherSnapshot? _data;
  WeatherLocation? _location;
  bool _loading = false;
  bool _failed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _location = widget.location;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(WeatherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final location = widget.location;
    if (location?.latitude != _location?.latitude || location?.longitude != _location?.longitude) {
      _location = location;
      _data = null;
      _load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _timer?.cancel();
    final location = _location;
    if (location == null) return;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final data = await _service.fetch(location);
      if (!mounted || location != _location) return;
      setState(() => _data = data);
    } catch (e) {
      debugPrint('Météo : $e');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    _timer = Timer(const Duration(minutes: 20), _load);
  }

  @override
  Widget build(BuildContext context) {
    final location = _location;
    if (location == null) {
      return ConnectServiceCard(
        icon: const Icon(Icons.wb_sunny_rounded),
        brandColor: const Color(0xFFFFB020),
        service: 'Météo',
        description: 'Choisissez votre ville pour voir la météo du jour.',
        actionLabel: 'Choisir',
        onConnect: () => pickWeatherCity(context),
      );
    }
    final data = _data;
    if (data == null) {
      if (_failed) {
        return ConnectServiceCard(
          icon: const Icon(Icons.cloud_off_rounded),
          brandColor: AppColors.textSecondary,
          service: location.name,
          description: '',
          error: 'Météo indisponible pour le moment.',
          onConnect: _load,
        );
      }
      return const SkeletonBox(height: 176);
    }

    final theme = Theme.of(context);
    final condition = data.condition;
    final white70 = Colors.white.withValues(alpha: 0.75);

    return AppCard(
      onTap: _loading ? null : _load,
      onLongPress: () => pickWeatherCity(context),
      padding: const EdgeInsets.all(AppSpacing.lg),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: condition.gradient,
      ),
      borderColor: Colors.white.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.near_me_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            location.name,
                            style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${data.temperature.round()}°',
                      style: theme.textTheme.displayLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: -3),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(condition.icon, color: Colors.white, size: 36),
                  const SizedBox(height: AppSpacing.sm),
                  Text(condition.label, style: theme.textTheme.titleSmall?.copyWith(color: Colors.white)),
                  Text(
                    'Max ${data.max.round()}°  Min ${data.min.round()}°',
                    style: theme.textTheme.labelMedium?.copyWith(color: white70),
                  ),
                  Text(
                    'Ressenti ${data.apparent.round()}° · Pluie ${data.precipitationChance} %',
                    style: theme.textTheme.labelMedium?.copyWith(color: white70),
                  ),
                ],
              ),
            ],
          ),
          if (data.hours.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final (i, h) in data.hours.take(6).indexed)
                  Column(
                    children: [
                      Text(
                        i == 0 ? 'Maint.' : DateFormat('HH', 'fr_FR').format(h.time),
                        style: theme.textTheme.labelMedium?.copyWith(color: white70),
                      ),
                      const SizedBox(height: 6),
                      Icon(WeatherCondition.fromCode(h.code, isDay: h.time.hour >= 7 && h.time.hour < 20).icon, color: Colors.white, size: 20),
                      const SizedBox(height: 6),
                      Text('${h.temperature.round()}°', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white)),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CitySearch extends StatefulWidget {
  const _CitySearch();

  @override
  State<_CitySearch> createState() => _CitySearchState();
}

class _CitySearchState extends State<_CitySearch> {
  final _service = WeatherService();
  Timer? _debounce;
  List<WeatherLocation> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _loading = true);
      List<WeatherLocation> results = [];
      try {
        results = await _service.searchCity(query);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        _searched = query.trim().length >= 2;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Paris, Lyon, Bruxelles…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_searched && _results.isEmpty && !_loading)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text('Aucune ville trouvée', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          ),
        for (final r in _results)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            leading: const Icon(Icons.location_city_rounded),
            title: Text(r.name),
            subtitle: r.region == null ? null : Text(r.region!),
            onTap: () {
              Haptics.selection();
              Navigator.pop(context, r);
            },
          ),
      ],
    );
  }
}
