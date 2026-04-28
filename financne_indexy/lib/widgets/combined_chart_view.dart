import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../mcs_bf.dart';
import '../mcs_bf_feeds.dart';
import '../models/app_models.dart';
import '../services/local_notification_service.dart';

class CombinedChartView extends StatefulWidget {
  final Map<String, List<DayData>> allData;
  final McsBfFeedLibrary feedLibrary;
  final List<FinancialIndex> activeIndices;
  final bool useDrawdownAndStrictBreadthFilters;
  final bool disableTwoDayBuyConfirmation;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  const CombinedChartView({
    super.key,
    required this.allData,
    required this.feedLibrary,
    required this.activeIndices,
    required this.useDrawdownAndStrictBreadthFilters,
    required this.disableTwoDayBuyConfirmation,
    required this.onRetry,
    required this.onOpenSettings,
  });

  @override
  State<CombinedChartView> createState() => _CombinedChartViewState();
}

const _kPeriods = [
  (label: '1T', days: 5, desc: 'posledný týždeň', maxPoints: 7),
  (label: '2T', days: 10, desc: 'posledné 2 týždne', maxPoints: 7),
  (label: '1M', days: 21, desc: 'posledný mesiac', maxPoints: 15),
  (label: '3M', days: 63, desc: 'posledné 3 mesiace', maxPoints: 15),
  (label: '6M', days: 126, desc: 'posledných 6 mesiacov', maxPoints: 18),
  (label: '1R', days: 252, desc: 'posledný rok', maxPoints: 20),
  (label: '2R', days: 504, desc: 'posledné 2 roky', maxPoints: 22),
  (label: '5R', days: 1260, desc: 'posledných 5 rokov', maxPoints: 26),
];

enum _IndexDisplayMode {
  all,
  builtIn,
  custom,
}

final Set<String> _kBuiltInTickers = {
  for (final index in kAllIndices) index.ticker,
};

class _McsHistoryPoint {
  final DateTime date;
  final double? mcs;
  final McsSignal signal;
  final bool buyPlus;

  const _McsHistoryPoint({
    required this.date,
    required this.mcs,
    required this.signal,
    required this.buyPlus,
  });
}

class _McsComputationResult {
  final McsSignalSnapshot snapshot;
  final List<_McsHistoryPoint> history;

  const _McsComputationResult({
    required this.snapshot,
    required this.history,
  });
}

class _CombinedChartViewState extends State<CombinedChartView>
    with SingleTickerProviderStateMixin {
  int _periodIdx = 1;
  _IndexDisplayMode _displayMode = _IndexDisplayMode.all;
  final Set<String> _hiddenTickers = {};
  late final AnimationController _buyPlusPulse;

  @override
  void initState() {
    super.initState();
    _buyPlusPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
      lowerBound: 0.55,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _buyPlusPulse.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CombinedChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final displayedTickers = _displayedIndices.map((idx) => idx.ticker).toSet();
    _hiddenTickers.removeWhere((ticker) => !displayedTickers.contains(ticker));
  }

  int get _days => _kPeriods[_periodIdx].days;

  List<FinancialIndex> get _displayedIndices {
    switch (_displayMode) {
      case _IndexDisplayMode.builtIn:
        return widget.activeIndices
            .where((idx) => _kBuiltInTickers.contains(idx.ticker))
            .toList(growable: false);
      case _IndexDisplayMode.custom:
        return widget.activeIndices
            .where((idx) => !_kBuiltInTickers.contains(idx.ticker))
            .toList(growable: false);
      case _IndexDisplayMode.all:
        return widget.activeIndices;
    }
  }

  void _setDisplayMode(_IndexDisplayMode mode) {
    setState(() {
      _displayMode = mode;
      final displayedTickers = _displayedIndices.map((idx) => idx.ticker).toSet();
      _hiddenTickers.removeWhere((ticker) => !displayedTickers.contains(ticker));
    });
  }

  Widget _buildDisplayModeButton(_IndexDisplayMode mode, String label) {
    final selected = _displayMode == mode;
    return GestureDetector(
      onTap: () => _setDisplayMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1565C0) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  List<T> _downsample<T>(List<T> data, int maxN) {
    if (data.length <= maxN) return data;
    final result = <T>[];
    for (int i = 0; i < maxN; i++) {
      final idx = ((i * (data.length - 1)) / (maxN - 1)).round();
      result.add(data[idx]);
    }
    return result;
  }

  List<DayData> _slice(String ticker) {
    final d = widget.allData[ticker] ?? [];
    final p = _kPeriods[_periodIdx];
    final sliced = d.length <= p.days ? d : d.sublist(d.length - p.days);
    return _downsample(sliced, p.maxPoints);
  }

  List<DateTime> get _refDates {
    List<DateTime> best = [];
    for (final idx in widget.activeIndices) {
      final d = _slice(idx.ticker);
      if (d.length > best.length) best = d.map((e) => e.date).toList();
    }
    return best;
  }

  List<FlSpot> _pctSpots(List<DayData> data) {
    if (data.isEmpty) return [];
    final first = data.first.close;
    return data.asMap().entries
        .map(
          (e) => FlSpot(
            e.key.toDouble(),
            ((e.value.close - first) / first) * 100,
          ),
        )
        .toList();
  }

  String _fmtPct(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)} %';

  String _fmtVal(double v) {
    if (v >= 10000) return v.toStringAsFixed(0);
    if (v >= 1000) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  List<FinancialIndex> get _signalIndices =>
      widget.activeIndices.where((idx) => idx.ticker != '^VIX').toList();

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
    int period, [
    List<FinancialIndex>? sourceIndices,
  ]) {
    final indices = sourceIndices ?? _signalIndices;
    final dates = <DateTime>{};
    final priceMaps = <String, Map<DateTime, DayData>>{};
    final averageMaps = <String, Map<DateTime, double?>>{};

    for (final idx in indices) {
      final series = widget.allData[idx.ticker] ?? const <DayData>[];
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

  Map<DateTime, double?> _buildSentimentProxyMap([
    List<FinancialIndex>? sourceIndices,
  ]) {
    final indices = sourceIndices ?? _signalIndices;
    final perDateValues = <DateTime, List<double>>{};

    for (final idx in indices) {
      final series = widget.allData[idx.ticker] ?? const <DayData>[];
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
    const window = 156;
    final history = <double>[];
    for (final date in sortedDates) {
      final current = averaged[date]!;
      history.add(current);
      if (history.length < window) {
        result[date] = null;
        continue;
      }
      final windowValues = history.sublist(history.length - window);
      final mean = windowValues.reduce((a, b) => a + b) / windowValues.length;
      final variance = windowValues
              .map((value) => (value - mean) * (value - mean))
              .reduce((a, b) => a + b) /
          (windowValues.length - 1);
      final std = variance <= 0 ? 0.0 : math.sqrt(variance);
      result[date] = std == 0 ? 0.0 : (current - mean) / std;
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

  List<FinancialIndex> _mcsPlusPeerIndices(FinancialIndex index) {
    if (_isKoreaIndex(index)) {
      final peers = _signalIndices
          .where(_isKoreaIndex)
          .toList(growable: false);
      return peers.isEmpty ? [index] : peers;
    }
    if (index.region == 'USA' || index.region == 'Európa') {
      final peers = _signalIndices
          .where((idx) => idx.region == index.region)
          .toList(growable: false);
      return peers.isEmpty ? _signalIndices : peers;
    }
    if (index.region == 'Svet') {
      final peers = _signalIndices
          .where(
            (idx) =>
                idx.region == 'USA' ||
                idx.region == 'Svet' ||
                idx.region == 'Európa',
          )
          .toList(growable: false);
      return peers.isEmpty ? _signalIndices : peers;
    }
    final peers = _signalIndices
        .where((idx) => idx.region == index.region)
        .toList(growable: false);
    return peers.isEmpty ? _signalIndices : peers;
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
            widget.useDrawdownAndStrictBreadthFilters,
        useTwoDayBuyConfirmation: !widget.disableTwoDayBuyConfirmation,
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
            widget.useDrawdownAndStrictBreadthFilters,
        useTwoDayBuyConfirmation: !widget.disableTwoDayBuyConfirmation,
      );
    }
    if (index.region == 'Svet') {
      return McsBfConfig(
        volatilityMode: volatilityMode,
        buyThreshold: 38,
        useDrawdownAndStrictBreadthFilters:
            widget.useDrawdownAndStrictBreadthFilters,
        useTwoDayBuyConfirmation: !widget.disableTwoDayBuyConfirmation,
      );
    }
    return McsBfConfig(
      volatilityMode: volatilityMode,
      useDrawdownAndStrictBreadthFilters:
          widget.useDrawdownAndStrictBreadthFilters,
      useTwoDayBuyConfirmation: !widget.disableTwoDayBuyConfirmation,
    );
  }

  bool _latestAcceptedMcsPlusBuy(List<McsBfDay> calculated) {
    final acceptedFlags = _acceptedMcsPlusFlags(calculated);
    for (var i = calculated.length - 1; i >= 0; i--) {
      if (calculated[i].mcs != null) return acceptedFlags[i];
    }
    return false;
  }

  List<bool> _acceptedMcsPlusFlags(List<McsBfDay> calculated) {
    const cooldownTradingDays = 20;
    var lastAcceptedBuyIndex = -cooldownTradingDays;
    final accepted = List<bool>.filled(calculated.length, false);
    for (var i = 0; i < calculated.length; i++) {
      final day = calculated[i];
      if (day.mcs == null) continue;
      if (day.finalSignal == McsSignal.kup &&
          i - lastAcceptedBuyIndex >= cooldownTradingDays) {
        lastAcceptedBuyIndex = i;
        accepted[i] = true;
      }
    }
    return accepted;
  }

  _McsComputationResult _computeMcsResultForIndex(
    FinancialIndex idx, {
    required Map<DateTime, double?> breadth50ByDate,
    required Map<DateTime, double?> breadth200ByDate,
    required Map<DateTime, double?> sentimentByDate,
    required Map<DateTime, DayData> vixByDate,
  }) {
    final series = widget.allData[idx.ticker] ?? const <DayData>[];
    final region = _regionForIndex(idx);
    final feedBundle =
        region == null ? null : widget.feedLibrary.bundleForRegion(region);
    final hasRealBreadth =
        feedBundle?.hasBreadth50 == true && feedBundle?.hasBreadth200 == true;
    final hasRealSentiment = feedBundle?.hasSentimentZ == true;
    final hasRealVolatility = feedBundle?.hasVolatility == true;
    final useExternalVolatility =
        hasRealVolatility ||
        (_usesExternalVolatility(idx.ticker) && vixByDate.isNotEmpty);
    final breadthSource = hasRealBreadth
        ? feedBundle!.sourceLabel('breadth50', 'real breadth feed')
        : 'proxy z indexov';
    final sentimentSource = hasRealSentiment
        ? feedBundle!.sourceLabel('sentimentZ', 'real sentiment feed')
        : 'proxy z 20-dňových výnosov';
    final volatilitySource = hasRealVolatility
        ? feedBundle!.sourceLabel('volatility', 'real volatility feed')
        : useExternalVolatility
            ? 'VIX proxy'
            : '21-dňová realizovaná volatilita';

    if (series.isEmpty) {
      return _McsComputationResult(
        snapshot: McsSignalSnapshot(
          signal: null,
          breadthSource: breadthSource,
          sentimentSource: sentimentSource,
          volatilitySource: volatilitySource,
        ),
        history: const [],
      );
    }

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
            widget.useDrawdownAndStrictBreadthFilters,
        useTwoDayBuyConfirmation: !widget.disableTwoDayBuyConfirmation,
      ),
    );
    final latest = calculated.isEmpty
        ? null
        : calculated.lastWhere(
            (day) => day.mcs != null,
            orElse: () => calculated.last,
          );

    var buyPlus = false;
    var acceptedPlusFlags = List<bool>.filled(calculated.length, false);
    if (calculated.isNotEmpty && latest?.finalSignal == McsSignal.kup) {
      final plusPeers = _mcsPlusPeerIndices(idx);
      final plusBreadth50ByDate = _buildBreadthMap(50, plusPeers);
      final plusBreadth200ByDate = _buildBreadthMap(200, plusPeers);
      final plusSentimentByDate = _buildSentimentProxyMap(plusPeers);
      final plusInputs = series.map((day) {
        final date = _dateOnly(day.date);
        final realVolatility = feedBundle?.volatility[date];
        return DailyMarketInput(
          date: date,
          adjustedClose: day.close,
          externalVolatility: realVolatility ??
              (useExternalVolatility ? vixByDate[date]?.close : null),
          sentimentZ:
              feedBundle?.sentimentZ[date] ?? plusSentimentByDate[date],
          breadth50: feedBundle?.breadth50[date] ?? plusBreadth50ByDate[date],
          breadth200:
              feedBundle?.breadth200[date] ?? plusBreadth200ByDate[date],
        );
      }).toList(growable: false);
      final plusCalculated = McsBfAlgorithm.calculate(
        plusInputs,
        config: _mcsPlusConfig(idx, useExternalVolatility),
      );
      acceptedPlusFlags = _acceptedMcsPlusFlags(plusCalculated);
      buyPlus = _latestAcceptedMcsPlusBuy(plusCalculated);
    }

    final history = <_McsHistoryPoint>[
      for (var i = 0; i < calculated.length; i++)
        _McsHistoryPoint(
          date: calculated[i].date,
          mcs: calculated[i].mcs,
          signal: calculated[i].finalSignal,
          buyPlus: i < acceptedPlusFlags.length && acceptedPlusFlags[i],
        ),
    ];

    return _McsComputationResult(
      snapshot: McsSignalSnapshot(
        signal: latest,
        buyPlus: buyPlus,
        breadthSource: breadthSource,
        sentimentSource: sentimentSource,
        volatilitySource: volatilitySource,
      ),
      history: history,
    );
  }

  Map<String, _McsComputationResult> _buildMcsResults() {
    final breadth50ByDate = _buildBreadthMap(50);
    final breadth200ByDate = _buildBreadthMap(200);
    final sentimentByDate = _buildSentimentProxyMap();
    final vixByDate = _seriesMap(widget.allData['^VIX'] ?? const <DayData>[]);

    final results = <String, _McsComputationResult>{};
    for (final idx in _signalIndices) {
      results[idx.ticker] = _computeMcsResultForIndex(
        idx,
        breadth50ByDate: breadth50ByDate,
        breadth200ByDate: breadth200ByDate,
        sentimentByDate: sentimentByDate,
        vixByDate: vixByDate,
      );
    }
    return results;
  }

  List<_McsHistoryPoint> _historyForCurrentPeriod(
    List<_McsHistoryPoint> history,
  ) {
    if (history.length <= _days) return history;
    return history.sublist(history.length - _days);
  }

  List<String> _buyNotificationLines(
    Map<String, _McsComputationResult> results,
  ) {
    final lines = <String>[];
    for (final idx in widget.activeIndices) {
      final snapshot = results[idx.ticker]?.snapshot;
      if (snapshot == null) continue;
      if (snapshot.buyPlus) {
        lines.add('${idx.name} | BUY++');
        continue;
      }
      if (snapshot.signal?.finalSignal == McsSignal.kup) {
        lines.add('${idx.name} | BUY');
      }
    }
    return lines;
  }

  Future<void> _showBuySignalsNotification(
    BuildContext context,
    Map<String, _McsComputationResult> results,
  ) async {
    final lines = _buyNotificationLines(results);
    await LocalNotificationService.instance.showBuySignalsNotification(lines);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lines.isEmpty
              ? 'Notifikácia bola odoslaná bez BUY signálov.'
              : 'Notifikácia bola odoslaná pre ${lines.length} BUY signálov.',
        ),
      ),
    );
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

  String _mcsSignalBubbleLabel(McsSignal signal) {
    switch (signal) {
      case McsSignal.kup:
        return 'BUY';
      case McsSignal.predaj:
        return 'SELL';
      case McsSignal.podrz:
        return 'HOLD';
    }
  }

  String _mcsSignalExplanation(
    FinancialIndex index,
    McsSignalSnapshot snapshot,
  ) {
    final signal = snapshot.signal;
    if (signal == null || signal.mcs == null) {
      return 'Pre ${index.name} zatiaľ chýba dostatočná história dát na plný výpočet FMCS, preto signál ešte nie je spoľahlivo potvrdený.';
    }

    final parts = <String>[
      'FMCS ${_mcsSignalBubbleLabel(signal.finalSignal)} pre ${index.name}.',
    ];

    final trendScore = signal.trendScore ?? 0.0;
    if (trendScore >= 0.5) {
      parts.add(
        'Cena zostáva nad dlhodobým trendom SMA200, čo podporuje rastový výhľad.',
      );
    } else if (trendScore <= -0.5) {
      parts.add(
        'Cena je pod dlhodobým trendom SMA200, čo drží výhľad opatrný.',
      );
    } else {
      parts.add('Cena sa pohybuje blízko SMA200, takže trend nie je jednoznačný.');
    }

    final rsi = signal.rsi14 ?? 50.0;
    if (rsi < 35.0) {
      parts.add('RSI 14 je skôr prepredané.');
    } else if (rsi > 65.0) {
      parts.add('RSI 14 je zvýšené a trh je viac napnutý.');
    } else {
      parts.add('RSI 14 zostáva v neutrálnej zóne.');
    }

    final volChange = signal.volatilityChange5 ?? 0.0;
    if (volChange <= -0.10) {
      parts.add('Volatilita za 5 dní klesá, čo signálu pomáha.');
    } else if (volChange >= 0.10) {
      parts.add('Volatilita za 5 dní rastie, čo zvyšuje opatrnosť.');
    }

    final reasons = signal.reasonFlags;
    if (reasons.contains('drawdown_filter')) {
      parts.add('Drawdown filter zablokoval BUY po príliš malom poklese.');
    } else if (reasons.contains('strict_breadth_filter')) {
      parts.add('Prísny breadth filter zatiaľ nepotvrdil dostatočnú šírku rastu.');
    } else if (reasons.contains('basic_breadth_filter')) {
      parts.add('Breadth trhu je zatiaľ slabší.');
    } else if (reasons.contains('waiting_second_kup_day')) {
      parts.add('BUY ešte čaká na druhý potvrdzujúci obchodný deň.');
    } else {
      parts.add('Finálne FMCS dosiahlo ${signal.mcs!.toStringAsFixed(1)} bodu.');
    }

    return parts.join(' ');
  }

  Future<void> _showMcsExplanation(
    BuildContext context,
    FinancialIndex index,
    _McsComputationResult result,
  ) async {
    final snapshot = result.snapshot;
    final signal = snapshot.signal?.finalSignal ?? McsSignal.podrz;
    final signalColor = _mcsSignalColor(signal);
    final bubbleColor = snapshot.buyPlus
        ? const Color(0xFF1B5E20)
        : signalColor;
    final bubbleLabel = snapshot.buyPlus ? 'BUY++' : _mcsSignalBubbleLabel(signal);
    final periodHistory = _historyForCurrentPeriod(result.history);
    final scoreValues = periodHistory
        .where((point) => point.mcs != null)
        .map((point) => point.mcs!)
        .toList(growable: false);
    final double minScore = scoreValues.isEmpty
        ? -40.0
        : math.max(
            -100.0,
            ((scoreValues.reduce((a, b) => a < b ? a : b) - 8) / 10).floor() *
                10.0,
          ).toDouble();
    final double maxScore = scoreValues.isEmpty
        ? 40.0
        : math.min(
            100.0,
            ((scoreValues.reduce((a, b) => a > b ? a : b) + 8) / 10).ceil() *
                10.0,
          ).toDouble();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: index.name,
                style: TextStyle(
                  color: index.color,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              const TextSpan(
                text: ' | ',
                style: TextStyle(
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              TextSpan(
                text: _kPeriods[_periodIdx].label,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              const TextSpan(
                text: ' | ',
                style: TextStyle(
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              TextSpan(
                text: 'FMCS zdôvodnenie',
                style: TextStyle(
                  color: signalColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: math.min(
            MediaQuery.of(context).size.width * 0.88,
            440.0,
          ).toDouble(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: snapshot.buyPlus ? 64 : 52,
                        height: 22,
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: snapshot.buyPlus
                              ? [
                                  BoxShadow(
                                    color: bubbleColor.withOpacity(0.35),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          bubbleLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: bubbleColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Zavrieť',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _mcsSignalExplanation(index, snapshot),
                    style: const TextStyle(fontSize: 14, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 120,
                    padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: periodHistory.every((point) => point.mcs == null)
                        ? const Center(
                            child: Text(
                              'Pre toto obdobie ešte nie sú dostupné denné hodnoty FMCS.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          )
                        : LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: math.max(0, periodHistory.length - 1)
                                  .toDouble(),
                              minY: minScore,
                              maxY: maxScore,
                              extraLinesData: ExtraLinesData(
                                horizontalLines: [
                                  HorizontalLine(
                                    y: 35,
                                    color: const Color(0xFF2E7D32)
                                        .withOpacity(0.25),
                                    strokeWidth: 1,
                                    dashArray: const [6, 4],
                                  ),
                                  HorizontalLine(
                                    y: 0,
                                    color: const Color(0xFF9CA3AF),
                                    strokeWidth: 1,
                                    dashArray: const [4, 4],
                                  ),
                                  HorizontalLine(
                                    y: -35,
                                    color: const Color(0xFFC62828)
                                        .withOpacity(0.25),
                                    strokeWidth: 1,
                                    dashArray: const [6, 4],
                                  ),
                                ],
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 20,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: const Color(0xFFE5E7EB),
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 36,
                                    interval: 20,
                                    getTitlesWidget: (value, meta) => Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 22,
                                    getTitlesWidget: (value, meta) {
                                      if (periodHistory.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      final indexValue = value.round();
                                      if (indexValue < 0 ||
                                          indexValue >= periodHistory.length) {
                                        return const SizedBox.shrink();
                                      }
                                      final lastIndex = periodHistory.length - 1;
                                      final middleIndex = lastIndex ~/ 2;
                                      final shouldShow =
                                          indexValue == 0 ||
                                          indexValue == middleIndex ||
                                          indexValue == lastIndex;
                                      if (!shouldShow) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          DateFormat(
                                            'd.M.',
                                          ).format(periodHistory[indexValue].date),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipColor: (_) => Colors.white,
                                  fitInsideHorizontally: true,
                                  fitInsideVertically: true,
                                  tooltipPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  getTooltipItems: (touchedSpots) {
                                    return touchedSpots.map((spot) {
                                      final point = periodHistory[spot.x.round()];
                                      final stateLabel = point.buyPlus
                                          ? 'BUY++'
                                          : _mcsSignalBubbleLabel(point.signal);
                                      return LineTooltipItem(
                                        '${DateFormat('d. M. yyyy').format(point.date)}\n',
                                        const TextStyle(
                                          color: Color(0xFF1F2937),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.left,
                                        children: [
                                          TextSpan(
                                            text: index.name,
                                            style: const TextStyle(
                                              color: Color(0xFF1F2937),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                ' | ${point.mcs?.toStringAsFixed(1) ?? 'N/A'} | $stateLabel',
                                            style: const TextStyle(
                                              color: Color(0xFF1F2937),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  isCurved: true,
                                  curveSmoothness: 0.28,
                                  color: const Color(0xFF9CA3AF),
                                  barWidth: 2.2,
                                  spots: [
                                    for (var i = 0; i < periodHistory.length; i++)
                                      if (periodHistory[i].mcs != null)
                                        FlSpot(
                                          i.toDouble(),
                                          periodHistory[i].mcs!,
                                        ),
                                  ],
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (spot, _, __, ___) {
                                      final point = periodHistory[spot.x.round()];
                                      final dotColor = point.buyPlus
                                          ? const Color(0xFF1B5E20)
                                          : _mcsSignalColor(point.signal);
                                      return FlDotCirclePainter(
                                        radius: point.buyPlus ? 3.2 : 2.4,
                                        color: dotColor,
                                        strokeWidth: 0,
                                        strokeColor: dotColor,
                                      );
                                    },
                                  ),
                                  belowBarData: BarAreaData(show: false),
                                ),
                              ],
                          ),
                        ),
                  ),
                  const SizedBox(height: 14),
                  _buildModalMcsDetails(index, snapshot),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalMcsDetails(
    FinancialIndex index,
    McsSignalSnapshot snapshot,
  ) {
    final signal = snapshot.signal;
    final latestSeries = widget.allData[index.ticker];
    final latest =
        latestSeries != null && latestSeries.isNotEmpty ? latestSeries.last : null;
    final reasons = signal?.reasonFlags ?? const <String>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSplitDetailLine(
            leftLabel: 'FMCS',
            leftValue: signal?.mcs?.toStringAsFixed(1) ?? 'N/A',
            rightLabel: 'Cena',
            rightValue: latest != null ? _fmtVal(latest.close) : '—',
          ),
          const SizedBox(height: 2),
          _buildDetailLine('Breadth', snapshot.breadthSource),
          const SizedBox(height: 2),
          _buildDetailLine('Sentiment', snapshot.sentimentSource),
          const SizedBox(height: 2),
          _buildDetailLine('Volatilita', snapshot.volatilitySource),
          const SizedBox(height: 4),
          _buildDetailLine(
            'Režim',
            widget.disableTwoDayBuyConfirmation
                ? 'bez 2-dňového potvrdenia KÚP'
                : 's 2-dňovým potvrdením KÚP',
          ),
          const SizedBox(height: 2),
          _buildDetailLine(
            'Drawdown filter',
            widget.useDrawdownAndStrictBreadthFilters ? 'zapnuté' : 'vypnuté',
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildDetailLine(
              'Dôvody',
              reasons.map(_reasonLabel).join(', '),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSplitDetailLine({
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
  }) {
    return Row(
      children: [
        Expanded(child: _buildDetailLine(leftLabel, leftValue)),
        const SizedBox(width: 12),
        RichText(
          textAlign: TextAlign.right,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1F2937),
              height: 1.45,
            ),
            children: [
              TextSpan(
                text: '$rightLabel: ',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: rightValue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailLine(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF1F2937),
          height: 1.45,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  String _reasonLabel(String flag) {
    switch (flag) {
      case 'insufficient_history':
        return 'málo histórie';
      case 'bear_trend_without_confirmation':
        return 'slabé potvrdenie trendu';
      case 'basic_breadth_filter':
        return 'breadth filter';
      case 'strict_breadth_filter':
        return 'prísny breadth filter';
      case 'drawdown_filter':
        return 'drawdown filter';
      case 'waiting_second_kup_day':
        return 'čaká na 2. deň KÚP';
      default:
        return flag.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final mcsResults = _buildMcsResults();
    final displayedIndices = _displayedIndices;

    final visibleSeries = displayedIndices
        .where((idx) => !_hiddenTickers.contains(idx.ticker))
        .map((idx) {
          final data = _slice(idx.ticker);
          return (index: idx, data: data, spots: _pctSpots(data));
        })
        .where((series) => series.spots.isNotEmpty)
        .toList();

    List<DateTime> refDates = [];
    for (final series in visibleSeries) {
      if (series.data.length > refDates.length) {
        refDates = series.data.map((day) => day.date).toList();
      }
    }

    final lineBars = <LineChartBarData>[];
    for (final series in visibleSeries) {
      final idx = series.index;
      lineBars.add(
        LineChartBarData(
          spots: series.spots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: idx.color,
          barWidth: 0.6,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, pct, bar, i) => FlDotCirclePainter(
              radius: 3,
              color: idx.color,
              strokeWidth: 0,
              strokeColor: idx.color,
            ),
          ),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    double minY = 0, maxY = 0;
    for (final series in visibleSeries) {
      final data = series.data;
      final first = data.first.close;
      for (final d in data) {
        final pct = ((d.close - first) / first) * 100;
        if (pct < minY) minY = pct;
        if (pct > maxY) maxY = pct;
      }
    }
    final yPad = (maxY - minY).abs() * 0.12 + 0.5;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Sledované obdobie',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Načítať dáta',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.green[700],
                                ),
                              ),
                              IconButton(
                                onPressed: widget.onRetry,
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Color(0xFF2E7D32),
                                ),
                                tooltip: 'Načítať / obnoviť dáta',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                                splashRadius: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(_kPeriods.length, (i) {
                              final selected = i == _periodIdx;
                              return GestureDetector(
                                onTap: () => setState(() => _periodIdx = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFF1565C0)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    _kPeriods[i].label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? Colors.white
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildDisplayModeButton(
                                      _IndexDisplayMode.all,
                                      'Všetky',
                                    ),
                                    _buildDisplayModeButton(
                                      _IndexDisplayMode.builtIn,
                                      'Aplikačné IDX',
                                    ),
                                    _buildDisplayModeButton(
                                      _IndexDisplayMode.custom,
                                      'Vlastné IDX',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: widget.onOpenSettings,
                            icon: const Icon(
                              Icons.tune,
                              color: Color(0xFF1565C0),
                            ),
                            tooltip: 'Výber indexov',
                            visualDensity: VisualDensity.compact,
                            splashRadius: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      final pcts = displayedIndices
                          .where((idx) => !_hiddenTickers.contains(idx.ticker))
                          .map((idx) {
                            final d = _slice(idx.ticker);
                            if (d.isEmpty) return 0.0;
                            return (d.last.close - d.first.close) /
                                d.first.close *
                                100;
                          })
                          .toList();
                      final avg = pcts.isEmpty
                          ? 0.0
                          : pcts.reduce((a, b) => a + b) / pcts.length;
                      final isUp = avg >= 0;
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Priemerná zmena za obdobie: ${isUp ? '+' : ''}${avg.toStringAsFixed(2)} %',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isUp
                                    ? Colors.green[700]
                                    : Colors.red[700],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () =>
                                _showBuySignalsNotification(context, mcsResults),
                            icon: const Icon(
                              Icons.star,
                              color: Color(0xFFFBC02D),
                            ),
                            tooltip: 'Push BUY signály',
                            visualDensity: VisualDensity.compact,
                            splashRadius: 20,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 16, 14, 10),
              child: SizedBox(
                height: 300,
                child: displayedIndices.isEmpty
                    ? Center(
                        child: Text(
                          'Pre zvolený filter nie sú dostupné žiadne indexy.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : lineBars.isEmpty
                    ? Center(
                        child: Text(
                          'Vybrané indexy nemajú dostupné dáta pre zvolené obdobie.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : LineChart(
                        LineChartData(
                          minY: minY - yPad,
                          maxY: maxY + yPad,
                          lineBarsData: lineBars,
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) {
                                  final i = value.toInt();
                                  if (i < 0 || i >= refDates.length) {
                                    return const SizedBox();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      DateFormat('d.M').format(refDates[i]),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 56,
                                getTitlesWidget: (value, meta) {
                                  if (value == meta.min || value == meta.max) {
                                    return const SizedBox();
                                  }
                                  return Text(
                                    '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)} %',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey[600],
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            getDrawingHorizontalLine: (v) => FlLine(
                              color: v == 0
                                  ? Colors.grey.withOpacity(0.6)
                                  : Colors.grey.withOpacity(0.12),
                              strokeWidth: v == 0 ? 1.5 : 1,
                              dashArray: v == 0 ? null : [4, 4],
                            ),
                            getDrawingVerticalLine: (_) => FlLine(
                              color: Colors.grey.withOpacity(0.1),
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.withOpacity(0.3),
                              ),
                              left: BorderSide(
                                color: Colors.grey.withOpacity(0.3),
                              ),
                            ),
                          ),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => Colors.white,
                              fitInsideHorizontally: true,
                              fitInsideVertically: true,
                              tooltipPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.asMap().entries.map((entry) {
                                  final spot = entry.value;
                                  final barIdx = spot.barIndex;
                                  final series = barIdx < visibleSeries.length
                                      ? visibleSeries[barIdx]
                                      : visibleSeries.first;
                                  final idx = series.index;
                                  final dayIdx = spot.x.toInt();
                                  final dateStr = (entry.key == 0 &&
                                          dayIdx >= 0 &&
                                          dayIdx < refDates.length)
                                      ? DateFormat('d. M. yyyy').format(
                                          refDates[dayIdx],
                                        )
                                      : '';
                                  final data = series.data;
                                  final price = (dayIdx >= 0 && dayIdx < data.length)
                                      ? _fmtVal(data[dayIdx].close)
                                      : '';
                                  return LineTooltipItem(
                                    dateStr.isNotEmpty ? '$dateStr\n' : '',
                                    const TextStyle(
                                      color: Color(0xFF1F2937),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.left,
                                    children: [
                                      TextSpan(
                                        text: idx.name,
                                        style: TextStyle(
                                          color: idx.color,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            ' | $price | ${_fmtPct(spot.y)}',
                                        style: const TextStyle(
                                          color: Color(0xFF1F2937),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList();
                              },
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Zmena · ${_kPeriods[_periodIdx].desc}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isLandscape ? 3 : 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: displayedIndices.length,
            itemBuilder: (context, i) {
              final idx = displayedIndices[i];
              final data = _slice(idx.ticker);
              final result = mcsResults[idx.ticker] ??
                  const _McsComputationResult(
                    snapshot: McsSignalSnapshot(
                      signal: null,
                      breadthSource: 'nedostupné',
                      sentimentSource: 'nedostupné',
                      volatilitySource: 'nedostupné',
                    ),
                    history: [],
                  );
              final snapshot = result.snapshot;
              final signal = snapshot.signal?.finalSignal ?? McsSignal.podrz;
              final signalColor = _mcsSignalColor(signal);
              final signalBubbleColor = snapshot.buyPlus
                  ? const Color(0xFF1B5E20)
                  : signalColor;
              final signalBubbleLabel = snapshot.buyPlus
                  ? 'BUY++'
                  : _mcsSignalBubbleLabel(signal);
              final isHidden = _hiddenTickers.contains(idx.ticker);
              final pct = data.length >= 2
                  ? (data.last.close - data.first.close) /
                        data.first.close *
                        100
                  : null;
              final isUp = (pct ?? 0) >= 0;
              return Opacity(
                opacity: isHidden ? 0.35 : 1.0,
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              if (isHidden) {
                                _hiddenTickers.remove(idx.ticker);
                              } else {
                                _hiddenTickers.add(idx.ticker);
                              }
                            }),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: idx.color,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          idx.name,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          data.isNotEmpty
                                              ? _fmtVal(data.last.close)
                                              : '—',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showMcsExplanation(context, idx, result),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(5, 6, 7, 6),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: Colors.grey.shade100),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  pct != null
                                      ? '${isUp ? '+' : ''}${pct.toStringAsFixed(2)} %'
                                      : 'N/A',
                                  style: TextStyle(
                                    fontSize: 8.4,
                                    fontWeight: FontWeight.bold,
                                    color: pct == null
                                        ? Colors.grey
                                        : isUp
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                FadeTransition(
                                  opacity: snapshot.buyPlus
                                      ? _buyPlusPulse
                                      : const AlwaysStoppedAnimation<double>(1),
                                  child: Container(
                                    width: snapshot.buyPlus ? 43 : 34,
                                    height: snapshot.buyPlus ? 14 : 12,
                                    decoration: BoxDecoration(
                                      color: signalBubbleColor,
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: snapshot.buyPlus
                                          ? [
                                              BoxShadow(
                                                color: signalBubbleColor
                                                    .withOpacity(0.45),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      signalBubbleLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
                                      style: const TextStyle(
                                        fontSize: 6.2,
                                        height: 1.0,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                Text(
                  'Developed by Peter Varga',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Zdroj dát: Yahoo Finance',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'Minulé výnosy sú užitočné na pochopenie histórie aktíva, ale investičné rozhodnutia by mali byť založené na budúcich očakávaniach, vašich cieľoch a tolerancii rizika, nie na naivnej viere, že graf pôjde donekonečna smerom nahor 🙂',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.5, color: Colors.grey[600], height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF263238),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
