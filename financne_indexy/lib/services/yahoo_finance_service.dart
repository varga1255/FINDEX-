import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';

class YahooFinanceService {
  static Future<List<DayData>> fetchData(String ticker) async {
    final encoded = Uri.encodeComponent(ticker);
    final uri = Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/$encoded?interval=1d&range=6y',
    );
    final response = await http.get(
      uri,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Chyba servera: ${response.statusCode}');
    }
    final json = jsonDecode(response.body);
    final chart = json['chart'];
    final error = chart['error'];
    if (error != null) {
      final description =
          (error['description'] ?? 'Neznáma chyba Yahoo Finance').toString();
      throw Exception(description);
    }
    final result = chart['result'];
    if (result == null || (result as List).isEmpty) {
      throw Exception('Žiadne dáta: $ticker');
    }
    final timestamps = List<int>.from(result[0]['timestamp']);
    final closes = List<dynamic>.from(result[0]['indicators']['quote'][0]['close']);
    final days = <DayData>[];
    for (int i = 0; i < timestamps.length; i++) {
      if (closes[i] != null) {
        days.add(
          DayData(
            date: DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000),
            close: (closes[i] as num).toDouble(),
          ),
        );
      }
    }
    return days;
  }

  static Future<String?> validateTicker(String ticker) async {
    try {
      final data = await fetchData(ticker);
      if (data.isEmpty) {
        return 'Yahoo Finance nevrátil žiadne použiteľné denné dáta pre ticker $ticker.';
      }
      return null;
    } catch (e) {
      final raw = e.toString();
      final message = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      return 'Ticker $ticker sa nepodarilo načítať z Yahoo Finance. $message';
    }
  }
}
