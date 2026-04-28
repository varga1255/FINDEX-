import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mcs_bf.dart';
import '../mcs_bf_feeds.dart';
import '../models/app_models.dart';
import '../services/yahoo_finance_service.dart';
import '../widgets/combined_chart_view.dart';
import 'settings_screen.dart';
import 'user_guide_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _kDefaultAppBarColor = Color(0xFF1565C0);

  Set<String> _selectedTickers = kDefaultTickers;
  List<FinancialIndex> _customIndices = const [];
  bool _useDrawdownAndStrictBreadthFilters = true;
  bool _disableTwoDayBuyConfirmation = false;
  Future<AppDataBundle>? _allDataFuture;
  DateTime? _dataDate;
  Color _appBarColor = _kDefaultAppBarColor;
  bool _appBarBuyPlus = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(kPrefKey);
    final customJson = prefs.getString(kCustomIndicesPrefKey);
    final customIndices = _decodeCustomIndices(customJson);
    final useDrawdownAndStrictBreadthFilters =
        prefs.getBool(kUseDrawdownAndStrictBreadthFiltersPrefKey) ?? true;
    final disableTwoDayBuyConfirmation =
        prefs.getBool(kDisableTwoDayBuyConfirmationPrefKey) ?? false;
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        _selectedTickers = saved.toSet();
        _customIndices = customIndices;
        _useDrawdownAndStrictBreadthFilters =
            useDrawdownAndStrictBreadthFilters;
        _disableTwoDayBuyConfirmation = disableTwoDayBuyConfirmation;
      });
    } else {
      setState(() {
        _customIndices = customIndices;
        _useDrawdownAndStrictBreadthFilters =
            useDrawdownAndStrictBreadthFilters;
        _disableTwoDayBuyConfirmation = disableTwoDayBuyConfirmation;
      });
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(kPrefKey, _selectedTickers.toList());
    await prefs.setString(
      kCustomIndicesPrefKey,
      _encodeCustomIndices(_customIndices),
    );
    await prefs.setBool(
      kUseDrawdownAndStrictBreadthFiltersPrefKey,
      _useDrawdownAndStrictBreadthFilters,
    );
    await prefs.setBool(
      kDisableTwoDayBuyConfirmationPrefKey,
      _disableTwoDayBuyConfirmation,
    );
  }

  List<FinancialIndex> _decodeCustomIndices(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .toList()
          .asMap()
          .entries
          .map((entry) {
            final slotIndex = entry.key;
            final item = entry.value;
            final fallbackColor =
                kCustomIndexColors[slotIndex % kCustomIndexColors.length];
            final rawColor = (item['color'] as num?)?.toInt();
            return FinancialIndex(
              name: (item['name'] ?? '').toString(),
              ticker: (item['ticker'] ?? '').toString(),
              color: _looksLikeLegacyCustomGray(rawColor)
                  ? fallbackColor
                  : Color(rawColor ?? fallbackColor.value),
              region: 'Vlastné',
              desc: (item['desc'] ?? '').toString(),
            );
          })
          .where(
            (idx) => idx.name.trim().isNotEmpty && idx.ticker.trim().isNotEmpty,
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  bool _looksLikeLegacyCustomGray(int? colorValue) {
    if (colorValue == null) return true;
    return colorValue >= 0xFF607D8B &&
        colorValue <= 0xFF607D8B + ((kCustomIndexSlots - 1) * 0x000A0A0A);
  }

  String _encodeCustomIndices(List<FinancialIndex> indices) {
    final encoded = indices
        .map(
          (idx) => {
            'name': idx.name,
            'ticker': idx.ticker,
            'desc': idx.desc,
            'color': idx.color.value,
          },
        )
        .toList();
    return jsonEncode(encoded);
  }

  List<FinancialIndex> get _allIndices => [...kAllIndices, ..._customIndices];

  List<FinancialIndex> get _activeIndices =>
      _allIndices.where((i) => _selectedTickers.contains(i.ticker)).toList();

  Set<String> get _dataTickersToLoad {
    final tickers = _activeIndices.map((idx) => idx.ticker).toSet();
    if (_activeIndices.any((idx) => idx.ticker != '^VIX')) {
      tickers.add('^VIX');
    }
    return tickers;
  }

  Future<AppDataBundle> _fetchAll() async {
    final entries = await Future.wait(
      _dataTickersToLoad.map(
        (ticker) => YahooFinanceService.fetchData(ticker)
            .then((d) => MapEntry(ticker, d))
            .catchError((_) => MapEntry(ticker, <DayData>[])),
      ),
    );
    final feedLibrary = await McsBfFeedLibrary.loadFromAssets();
    final data = Map.fromEntries(entries);
    DateTime? maxDate;
    for (final list in data.values) {
      if (list.isNotEmpty) {
        final last = list.last.date;
        if (maxDate == null || last.isAfter(maxDate)) maxDate = last;
      }
    }
    final resolvedAppBarSignal = _resolveSp500Signal(data, feedLibrary);
    if (mounted) {
      setState(() {
        _dataDate = maxDate;
        _appBarColor = resolvedAppBarSignal?.color ?? _kDefaultAppBarColor;
        _appBarBuyPlus = resolvedAppBarSignal?.buyPlus ?? false;
      });
    } else {
      _dataDate = maxDate;
      _appBarColor = resolvedAppBarSignal?.color ?? _kDefaultAppBarColor;
      _appBarBuyPlus = resolvedAppBarSignal?.buyPlus ?? false;
    }
    return AppDataBundle(marketData: data, feedLibrary: feedLibrary);
  }

  void _load() => setState(() {
        _appBarColor = _kDefaultAppBarColor;
        _appBarBuyPlus = false;
        _allDataFuture = _fetchAll();
      });

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  Map<DateTime, DayData> _seriesMap(List<DayData> data) {
    return {for (final day in data) _dateOnly(day.date): day};
  }

  Map<DateTime, double?> _movingAverageMap(List<DayData> data, int period) {
    final result = <DateTime, double?>{};
    if (data.isEmpty) return result;
    var sum = 0.0;
    for (int i = 0; i < data.length; i++) {
      sum += data[i].close;
      if (i >= period) sum -= data[i - period].close;
      result[_dateOnly(data[i].date)] = i >= period - 1 ? sum / period : null;
    }
    return result;
  }

  Map<DateTime, double?> _buildBreadthMap(
    List<FinancialIndex> signalIndices,
    Map<String, List<DayData>> allData,
    int period,
    List<FinancialIndex> sourceIndices,
  ) {
    final indices = sourceIndices;
    final dates = <DateTime>{};
    final priceMaps = <String, Map<DateTime, DayData>>{};
    final averageMaps = <String, Map<DateTime, double?>>{};

    for (final idx in indices) {
      final series = allData[idx.ticker] ?? const <DayData>[];
      final priceMap = _seriesMap(series);
      priceMaps[idx.ticker] = priceMap;
      averageMaps[idx.ticker] = _movingAverageMap(series, period);
      dates.addAll(priceMap.keys);
    }

    final sortedDates = dates.toList()..sort();
    final result = <DateTime, double?>{};
    for (final date in sortedDates) {
      var total = 0;
      var above = 0;
      for (final idx in indices) {
        final day = priceMaps[idx.ticker]?[date];
        final average = averageMaps[idx.ticker]?[date];
        if (day == null || average == null) continue;
        total += 1;
        if (day.close > average) above += 1;
      }
      result[date] = total == 0 ? null : above / total * 100.0;
    }
    return result;
  }

  Map<DateTime, double?> _buildSentimentProxyMap(
    List<FinancialIndex> signalIndices,
    Map<String, List<DayData>> allData,
    List<FinancialIndex> sourceIndices,
  ) {
    final indices = sourceIndices;
    final perDateValues = <DateTime, List<double>>{};

    for (final idx in indices) {
      final series = allData[idx.ticker] ?? const <DayData>[];
      for (int i = 20; i < series.length; i++) {
        final previous = series[i - 20].close;
        if (previous == 0) continue;
        final ret20 = series[i].close / previous - 1.0;
        perDateValues.putIfAbsent(_dateOnly(series[i].date), () => []).add(ret20);
      }
    }

    final sortedDates = perDateValues.keys.toList()..sort();
    final averaged = <DateTime, double>{};
    for (final date in sortedDates) {
      final values = perDateValues[date]!;
      averaged[date] = values.reduce((a, b) => a + b) / values.length;
    }

    final result = <DateTime, double?>{};
    final orderedDates = averaged.keys.toList()..sort();
    for (int i = 0; i < orderedDates.length; i++) {
      final date = orderedDates[i];
      if (i < 155) {
        result[date] = null;
        continue;
      }
      final window = orderedDates
          .sublist(i - 155, i + 1)
          .map((d) => averaged[d]!)
          .toList(growable: false);
      final mean = window.reduce((a, b) => a + b) / window.length;
      final variance = window
              .map((value) => math.pow(value - mean, 2).toDouble())
              .reduce((a, b) => a + b) /
          (window.length - 1);
      final std = math.sqrt(variance);
      result[date] = std == 0 ? 0 : (averaged[date]! - mean) / std;
    }
    return result;
  }

  bool _usesExternalVolatility(String ticker) {
    const vixProxyTickers = {'^GSPC', '^IXIC', '^DJI', '^RUT', 'URTH'};
    return vixProxyTickers.contains(ticker);
  }

  McsBfRegion? _regionForIndex(FinancialIndex index) {
    switch (index.region) {
      case 'USA':
        return McsBfRegion.usa;
      case 'Svet':
        return McsBfRegion.world;
      case 'Európa':
        return McsBfRegion.europe;
      default:
        return null;
    }
  }

  Color _mcsSignalColor(McsSignal signal) {
    switch (signal) {
      case McsSignal.kup:
        return const Color(0xFF2E7D32);
      case McsSignal.predaj:
        return const Color(0xFFC62828);
      case McsSignal.podrz:
        return const Color(0xFFEF6C00);
    }
  }

  List<FinancialIndex> _mcsPlusPeerIndices(
    FinancialIndex index,
    List<FinancialIndex> signalIndices,
  ) {
    if (_isKoreaIndex(index)) {
      final peers = signalIndices.where(_isKoreaIndex).toList(growable: false);
      return peers.isEmpty ? [index] : peers;
    }
    if (index.region == 'USA' || index.region == 'Európa') {
      final peers = signalIndices
          .where((idx) => idx.region == index.region)
          .toList(growable: false);
      return peers.isEmpty ? signalIndices : peers;
    }
    if (index.region == 'Svet') {
      final peers = signalIndices
          .where(
            (idx) =>
                idx.region == 'USA' ||
                idx.region == 'Svet' ||
                idx.region == 'Európa',
          )
          .toList(growable: false);
      return peers.isEmpty ? signalIndices : peers;
    }
    final peers = signalIndices
        .where((idx) => idx.region == index.region)
        .toList(growable: false);
    return peers.isEmpty ? signalIndices : peers;
  }

  bool _isKoreaIndex(FinancialIndex index) {
    final name = index.name.toLowerCase();
    final ticker = index.ticker.toUpperCase();
    return index.region == 'Kórea' ||
        name.contains('korea') ||
        ticker == 'EWY' ||
        ticker.startsWith('CSKR');
  }

  McsBfConfig _mcsPlusConfig(FinancialIndex index, bool useExternalVolatility) {
    final volatilityMode = useExternalVolatility
        ? VolatilityMode.externalVolatility
        : VolatilityMode.realizedVolatility21d;
    if (index.region == 'Európa') {
      return McsBfConfig(
        volatilityMode: volatilityMode,
        buyThreshold: 42,
        basicBreadthMax: 35,
        strictBreadthMax: 30,
        strictBreadthDeltaMin: 7.5,
        drawdownMinDip: -0.08,
        strongMarketRsiMin: 50,
        useDrawdownAndStrictBreadthFilters:
            _useDrawdownAndStrictBreadthFilters,
        useTwoDayBuyConfirmation: !_disableTwoDayBuyConfirmation,
      );
    }
    if (_isKoreaIndex(index)) {
      return McsBfConfig(
        volatilityMode: volatilityMode,
        buyThreshold: 40,
        basicBreadthMax: 35,
        strictBreadthMax: 30,
        strictBreadthDeltaMin: 7.5,
        drawdownMinDip: -0.10,
        strongMarketRsiMin: 50,
        useDrawdownAndStrictBreadthFilters:
            _useDrawdownAndStrictBreadthFilters,
        useTwoDayBuyConfirmation: !_disableTwoDayBuyConfirmation,
      );
    }
    if (index.region == 'Svet') {
      return McsBfConfig(
        volatilityMode: volatilityMode,
        buyThreshold: 38,
        useDrawdownAndStrictBreadthFilters:
            _useDrawdownAndStrictBreadthFilters,
        useTwoDayBuyConfirmation: !_disableTwoDayBuyConfirmation,
      );
    }
    return McsBfConfig(
      volatilityMode: volatilityMode,
      useDrawdownAndStrictBreadthFilters:
          _useDrawdownAndStrictBreadthFilters,
      useTwoDayBuyConfirmation: !_disableTwoDayBuyConfirmation,
    );
  }

  bool _latestAcceptedMcsPlusBuy(List<McsBfDay> calculated) {
    const cooldownTradingDays = 20;
    var lastAcceptedBuyIndex = -cooldownTradingDays;
    var latestValidIndex = -1;
    var latestAccepted = false;
    for (var i = 0; i < calculated.length; i++) {
      final day = calculated[i];
      if (day.mcs == null) continue;
      latestValidIndex = i;
      if (day.finalSignal == McsSignal.kup &&
          i - lastAcceptedBuyIndex >= cooldownTradingDays) {
        lastAcceptedBuyIndex = i;
        latestAccepted = true;
      } else {
        latestAccepted = false;
      }
    }
    return latestValidIndex >= 0 &&
        latestAccepted &&
        calculated[latestValidIndex].finalSignal == McsSignal.kup;
  }

  _AppBarSignalState? _resolveSp500Signal(
    Map<String, List<DayData>> allData,
    McsBfFeedLibrary feedLibrary,
  ) {
    final signalIndices = _activeIndices.where((idx) => idx.ticker != '^VIX').toList();
    FinancialIndex? sp500Index;
    for (final idx in signalIndices) {
      if (idx.ticker == '^GSPC') {
        sp500Index = idx;
        break;
      }
    }
    if (sp500Index == null) return null;

    final series = allData[sp500Index.ticker] ?? const <DayData>[];
    if (series.isEmpty) return null;

    final breadth50ByDate = _buildBreadthMap(
      signalIndices,
      allData,
      50,
      signalIndices,
    );
    final breadth200ByDate = _buildBreadthMap(
      signalIndices,
      allData,
      200,
      signalIndices,
    );
    final sentimentByDate = _buildSentimentProxyMap(
      signalIndices,
      allData,
      signalIndices,
    );
    final vixByDate = _seriesMap(allData['^VIX'] ?? const <DayData>[]);
    final region = _regionForIndex(sp500Index);
    final feedBundle = region == null ? null : feedLibrary.bundleForRegion(region);
    final hasRealVolatility = feedBundle?.hasVolatility == true;
    final useExternalVolatility =
        hasRealVolatility ||
        (_usesExternalVolatility(sp500Index.ticker) && vixByDate.isNotEmpty);

    final inputs = series.map((day) {
      final date = _dateOnly(day.date);
      final realVolatility = feedBundle?.volatility[date];
      return DailyMarketInput(
        date: date,
        adjustedClose: day.close,
        externalVolatility: realVolatility ??
            (useExternalVolatility ? vixByDate[date]?.close : null),
        sentimentZ: feedBundle?.sentimentZ[date] ?? sentimentByDate[date],
        breadth50: feedBundle?.breadth50[date] ?? breadth50ByDate[date],
        breadth200: feedBundle?.breadth200[date] ?? breadth200ByDate[date],
      );
    }).toList(growable: false);

    final calculated = McsBfAlgorithm.calculate(
      inputs,
      config: McsBfConfig(
        volatilityMode: useExternalVolatility
            ? VolatilityMode.externalVolatility
            : VolatilityMode.realizedVolatility21d,
        useDrawdownAndStrictBreadthFilters:
            _useDrawdownAndStrictBreadthFilters,
        useTwoDayBuyConfirmation: !_disableTwoDayBuyConfirmation,
      ),
    );
    if (calculated.isEmpty) return null;
    McsBfDay? latest;
    for (final day in calculated.reversed) {
      if (day.mcs != null) {
        latest = day;
        break;
      }
    }
    latest ??= calculated.last;
    var buyPlus = false;
    if (latest.finalSignal == McsSignal.kup) {
      final plusPeers = _mcsPlusPeerIndices(sp500Index, signalIndices);
      final plusBreadth50ByDate = _buildBreadthMap(
        signalIndices,
        allData,
        50,
        plusPeers,
      );
      final plusBreadth200ByDate = _buildBreadthMap(
        signalIndices,
        allData,
        200,
        plusPeers,
      );
      final plusSentimentByDate = _buildSentimentProxyMap(
        signalIndices,
        allData,
        plusPeers,
      );
      final plusInputs = series.map((day) {
        final date = _dateOnly(day.date);
        final realVolatility = feedBundle?.volatility[date];
        return DailyMarketInput(
          date: date,
          adjustedClose: day.close,
          externalVolatility: realVolatility ??
              (useExternalVolatility ? vixByDate[date]?.close : null),
          sentimentZ: feedBundle?.sentimentZ[date] ?? plusSentimentByDate[date],
          breadth50: feedBundle?.breadth50[date] ?? plusBreadth50ByDate[date],
          breadth200:
              feedBundle?.breadth200[date] ?? plusBreadth200ByDate[date],
        );
      }).toList(growable: false);
      final plusCalculated = McsBfAlgorithm.calculate(
        plusInputs,
        config: _mcsPlusConfig(sp500Index, useExternalVolatility),
      );
      buyPlus = _latestAcceptedMcsPlusBuy(plusCalculated);
    }
    return _AppBarSignalState(
      color: buyPlus
          ? const Color(0xFF1B5E20)
          : _mcsSignalColor(latest.finalSignal),
      buyPlus: buyPlus,
    );
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<SettingsResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          selectedTickers: Set.from(_selectedTickers),
          customIndices: List.from(_customIndices),
          useDrawdownAndStrictBreadthFilters:
              _useDrawdownAndStrictBreadthFilters,
          disableTwoDayBuyConfirmation: _disableTwoDayBuyConfirmation,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _customIndices = result.customIndices;
        _useDrawdownAndStrictBreadthFilters =
            result.useDrawdownAndStrictBreadthFilters;
        _disableTwoDayBuyConfirmation = result.disableTwoDayBuyConfirmation;
        final availableTickers = _allIndices.map((idx) => idx.ticker).toSet();
        _selectedTickers = result.selectedTickers.intersection(availableTickers);
        if (_selectedTickers.isEmpty && kAllIndices.isNotEmpty) {
          _selectedTickers = {kAllIndices.first.ticker};
        }
        _appBarColor = _kDefaultAppBarColor;
        _appBarBuyPlus = false;
        _allDataFuture = null;
      });
      await _savePrefs();
    }
  }

  void _openUserGuide() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserGuideScreen()),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1565C0), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _openUserGuide,
                tooltip: 'Používateľská príručka',
                icon: const Icon(
                  Icons.info_outline,
                  color: Color(0xFF1565C0),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Icon(Icons.show_chart, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 20),
            const Text(
              'Financial Market Composite Signal',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _activeIndices.map((i) => i.name).join(' · '),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Načítať dáta'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('Zmeniť výber indexov'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'Vyžaduje internetové pripojenie',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        leadingWidth: 38,
        leading: IconButton(
          icon: const Icon(Icons.info_outline, size: 22),
          onPressed: _openUserGuide,
          tooltip: 'Používateľská príručka',
          padding: const EdgeInsets.only(left: 4, right: 2),
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
        ),
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _appBarBuyPlus
                  ? 'Financial Market Composite Signal ++'
                  : 'Financial Market Composite Signal',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            if (_dataDate != null)
              Text(
                'dáta k ${DateFormat('d. M. yyyy').format(_dataDate!)}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        backgroundColor: _appBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _allDataFuture == null
          ? _buildWelcome()
          : FutureBuilder<AppDataBundle>(
              future: _allDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        Text('Načítavam dáta indexov...'),
                      ],
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 52,
                          ),
                          const SizedBox(height: 12),
                          Text('${snapshot.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Skúsiť znova'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return CombinedChartView(
                  allData: snapshot.data!.marketData,
                  feedLibrary: snapshot.data!.feedLibrary,
                  activeIndices: _activeIndices,
                  useDrawdownAndStrictBreadthFilters:
                      _useDrawdownAndStrictBreadthFilters,
                  disableTwoDayBuyConfirmation: _disableTwoDayBuyConfirmation,
                  onRetry: _load,
                  onOpenSettings: _openSettings,
                );
              },
            ),
    );
  }
}

class _AppBarSignalState {
  final Color color;
  final bool buyPlus;

  const _AppBarSignalState({
    required this.color,
    required this.buyPlus,
  });
}
