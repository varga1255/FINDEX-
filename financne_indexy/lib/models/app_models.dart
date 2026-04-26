import 'package:flutter/material.dart';

import '../mcs_bf.dart';
import '../mcs_bf_feeds.dart';

class FinancialIndex {
  final String name;
  final String ticker;
  final Color color;
  final String region;
  final String desc;

  const FinancialIndex({
    required this.name,
    required this.ticker,
    required this.color,
    required this.region,
    required this.desc,
  });
}

class SettingsResult {
  final Set<String> selectedTickers;
  final List<FinancialIndex> customIndices;
  final bool useDrawdownAndStrictBreadthFilters;
  final bool disableTwoDayBuyConfirmation;

  const SettingsResult({
    required this.selectedTickers,
    required this.customIndices,
    required this.useDrawdownAndStrictBreadthFilters,
    required this.disableTwoDayBuyConfirmation,
  });
}

class DayData {
  final DateTime date;
  final double close;

  DayData({required this.date, required this.close});
}

class AppDataBundle {
  final Map<String, List<DayData>> marketData;
  final McsBfFeedLibrary feedLibrary;

  const AppDataBundle({
    required this.marketData,
    required this.feedLibrary,
  });
}

class McsSignalSnapshot {
  final McsBfDay? signal;
  final bool buyPlus;
  final String breadthSource;
  final String sentimentSource;
  final String volatilitySource;

  const McsSignalSnapshot({
    required this.signal,
    this.buyPlus = false,
    required this.breadthSource,
    required this.sentimentSource,
    required this.volatilitySource,
  });
}

const List<FinancialIndex> kAllIndices = [
  FinancialIndex(
    name: 'S&P 500',
    ticker: '^GSPC',
    color: Color(0xFF2E7D32),
    region: 'USA',
    desc: '500 najväčších amerických spoločností',
  ),
  FinancialIndex(
    name: 'NASDAQ Composite',
    ticker: '^IXIC',
    color: Color(0xFFE65100),
    region: 'USA',
    desc: 'Všetky akcie burzy NASDAQ, dôraz na technológie',
  ),
  FinancialIndex(
    name: 'Dow Jones',
    ticker: '^DJI',
    color: Color(0xFF1565C0),
    region: 'USA',
    desc: '30 blue-chip amerických priemyselných spoločností',
  ),
  FinancialIndex(
    name: 'Russell 2000',
    ticker: '^RUT',
    color: Color(0xFF0288D1),
    region: 'USA',
    desc: '2000 malých amerických spoločností',
  ),
  FinancialIndex(
    name: 'MSCI World',
    ticker: 'URTH',
    color: Color(0xFF6A1B9A),
    region: 'Svet',
    desc: '~1 500 akcií z 23 rozvinutých krajín sveta (ETF)',
  ),
  FinancialIndex(
    name: 'Euro Stoxx 50',
    ticker: '^STOXX50E',
    color: Color(0xFFC62828),
    region: 'Európa',
    desc: '50 blue-chip spoločností z eurozóny',
  ),
  FinancialIndex(
    name: 'STOXX Europe 600',
    ticker: '^STOXX',
    color: Color(0xFFAD1457),
    region: 'Európa',
    desc: '600 európskych spoločností zo 17 krajín',
  ),
  FinancialIndex(
    name: 'DAX',
    ticker: '^GDAXI',
    color: Color(0xFF558B2F),
    region: 'Európa',
    desc: '40 najväčších nemeckých spoločností',
  ),
];

const Set<String> kDefaultTickers = {
  '^GSPC',
  '^IXIC',
  'URTH',
  '^STOXX50E',
  '^STOXX',
};

const String kPrefKey = 'selectedTickers';
const String kCustomIndicesPrefKey = 'customIndices';
const String kUseDrawdownAndStrictBreadthFiltersPrefKey =
    'useDrawdownAndStrictBreadthFilters';
const String kDisableTwoDayBuyConfirmationPrefKey =
    'disableTwoDayBuyConfirmation';
const int kCustomIndexSlots = 10;
