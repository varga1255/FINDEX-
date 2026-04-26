import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

enum McsBfRegion { usa, world, europe }

class McsBfFeedSeries {
  final Map<DateTime, double> breadth50;
  final Map<DateTime, double> breadth200;
  final Map<DateTime, double> sentimentZ;
  final Map<DateTime, double> volatility;
  final Map<String, String> sourceLabels;

  const McsBfFeedSeries({
    this.breadth50 = const {},
    this.breadth200 = const {},
    this.sentimentZ = const {},
    this.volatility = const {},
    this.sourceLabels = const {},
  });

  bool get hasBreadth50 => breadth50.isNotEmpty;
  bool get hasBreadth200 => breadth200.isNotEmpty;
  bool get hasSentimentZ => sentimentZ.isNotEmpty;
  bool get hasVolatility => volatility.isNotEmpty;

  String sourceLabel(String field, String fallback) =>
      sourceLabels[field]?.trim().isNotEmpty == true
      ? sourceLabels[field]!
      : fallback;
}

class McsBfFeedLibrary {
  final Map<McsBfRegion, McsBfFeedSeries> _bundles;

  const McsBfFeedLibrary(this._bundles);

  McsBfFeedSeries? bundleForRegion(McsBfRegion region) => _bundles[region];

  static Future<McsBfFeedLibrary> loadFromAssets() async {
    final usa = await _loadRegionAsset(
      McsBfRegion.usa,
      'assets/mcs_bf_feeds/usa.json',
    );
    final world = await _loadRegionAsset(
      McsBfRegion.world,
      'assets/mcs_bf_feeds/world.json',
    );
    final europe = await _loadRegionAsset(
      McsBfRegion.europe,
      'assets/mcs_bf_feeds/europe.json',
    );

    return McsBfFeedLibrary({
      McsBfRegion.usa: usa,
      McsBfRegion.world: world,
      McsBfRegion.europe: europe,
    });
  }

  static Future<McsBfFeedSeries> _loadRegionAsset(
    McsBfRegion region,
    String assetPath,
  ) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      return _parseRegionJson(raw, region);
    } catch (_) {
      return const McsBfFeedSeries();
    }
  }

  static McsBfFeedSeries _parseRegionJson(String raw, McsBfRegion region) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const McsBfFeedSeries();

    final sourcesRaw = decoded['sources'];
    final sources = <String, String>{};
    if (sourcesRaw is Map) {
      for (final entry in sourcesRaw.entries) {
        if (entry.key != null && entry.value != null) {
          sources[entry.key.toString()] = entry.value.toString();
        }
      }
    }

    final series = decoded['series'];
    if (series is! Map<String, dynamic>) {
      return McsBfFeedSeries(sourceLabels: sources);
    }

    return McsBfFeedSeries(
      breadth50: _parsePoints(series['breadth50']),
      breadth200: _parsePoints(series['breadth200']),
      sentimentZ: _parsePoints(series['sentimentZ']),
      volatility: _parsePoints(series['volatility']),
      sourceLabels: sources,
    );
  }

  static Map<DateTime, double> _parsePoints(Object? raw) {
    if (raw is! List) return const {};
    final result = <DateTime, double>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final dateRaw = item['date'];
      final valueRaw = item['value'];
      if (dateRaw == null || valueRaw == null) continue;
      final date = DateTime.tryParse(dateRaw.toString());
      final value = valueRaw is num
          ? valueRaw.toDouble()
          : double.tryParse(valueRaw.toString());
      if (date == null || value == null) continue;
      result[DateTime(date.year, date.month, date.day)] = value;
    }
    return result;
  }
}
