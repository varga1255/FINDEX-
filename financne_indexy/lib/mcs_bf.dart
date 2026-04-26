import 'dart:math' as math;

enum McsSignal { kup, podrz, predaj }

enum VolatilityMode { externalVolatility, realizedVolatility21d }

class DailyMarketInput {
  final DateTime date;
  final double adjustedClose;
  final double? externalVolatility;
  final double? sentimentZ;
  final double? bullishPct;
  final double? bearishPct;
  final double? breadth50;
  final double? breadth200;

  const DailyMarketInput({
    required this.date,
    required this.adjustedClose,
    this.externalVolatility,
    this.sentimentZ,
    this.bullishPct,
    this.bearishPct,
    this.breadth50,
    this.breadth200,
  });
}

class McsBfConfig {
  final double buyThreshold;
  final double sellThreshold;
  final int rsiPeriod;
  final int sma20Period;
  final int sma50Period;
  final int sma200Period;
  final int volatilityPercentileWindow;
  final int realizedVolatilityWindow;
  final int sentimentZWindow;
  final int breadthDeltaDays;
  final int drawdownLookbackDays;
  final VolatilityMode volatilityMode;
  final bool useBasicBreadthFilter;
  final bool useDrawdownAndStrictBreadthFilters;
  final bool useTwoDayBuyConfirmation;
  final double basicBreadthMax;
  final double strictBreadthMax;
  final double strictBreadthDeltaMin;
  final double drawdownMinDip;
  final double strongMarketRsiMin;
  final double volatilityJumpThreshold;
  final double volatilityDropThreshold;
  final double nearSma200Band;

  const McsBfConfig({
    this.buyThreshold = 35.0,
    this.sellThreshold = -35.0,
    this.rsiPeriod = 14,
    this.sma20Period = 20,
    this.sma50Period = 50,
    this.sma200Period = 200,
    this.volatilityPercentileWindow = 252,
    this.realizedVolatilityWindow = 21,
    this.sentimentZWindow = 156,
    this.breadthDeltaDays = 5,
    this.drawdownLookbackDays = 63,
    this.volatilityMode = VolatilityMode.externalVolatility,
    this.useBasicBreadthFilter = true,
    this.useDrawdownAndStrictBreadthFilters = true,
    this.useTwoDayBuyConfirmation = true,
    this.basicBreadthMax = 40.0,
    this.strictBreadthMax = 35.0,
    this.strictBreadthDeltaMin = 5.0,
    this.drawdownMinDip = -0.05,
    this.strongMarketRsiMin = 45.0,
    this.volatilityJumpThreshold = 0.10,
    this.volatilityDropThreshold = -0.10,
    this.nearSma200Band = 0.02,
  });
}

class McsBfDay {
  final DateTime date;
  final double adjustedClose;
  final McsSignal finalSignal;
  final McsSignal rawSignal;
  final McsSignal signalBeforeTwoDayConfirmation;
  final double? mcs;
  final double? rsi14;
  final double? sma20;
  final double? sma50;
  final double? sma200;
  final double? volatility;
  final double? volatilityPercentile;
  final double? volatilityChange5;
  final double? sentimentZ;
  final double? breadth50;
  final double? breadth50D5;
  final double? drawdown63;
  final double? rScore;
  final double? vScore;
  final double? sScore;
  final double? trendScore;
  final bool strictBreadthSetup;
  final bool strictBreadthPass;
  final bool drawdownFilterTriggered;
  final bool twoDayConfirmationPass;
  final List<String> reasonFlags;

  const McsBfDay({
    required this.date,
    required this.adjustedClose,
    required this.finalSignal,
    required this.rawSignal,
    required this.signalBeforeTwoDayConfirmation,
    required this.mcs,
    required this.rsi14,
    required this.sma20,
    required this.sma50,
    required this.sma200,
    required this.volatility,
    required this.volatilityPercentile,
    required this.volatilityChange5,
    required this.sentimentZ,
    required this.breadth50,
    required this.breadth50D5,
    required this.drawdown63,
    required this.rScore,
    required this.vScore,
    required this.sScore,
    required this.trendScore,
    required this.strictBreadthSetup,
    required this.strictBreadthPass,
    required this.drawdownFilterTriggered,
    required this.twoDayConfirmationPass,
    required this.reasonFlags,
  });
}

class McsBfAlgorithm {
  const McsBfAlgorithm._();

  static List<McsBfDay> calculate(
    List<DailyMarketInput> inputRows, {
    McsBfConfig config = const McsBfConfig(),
  }) {
    final rows = [...inputRows]..sort((a, b) => a.date.compareTo(b.date));
    if (rows.isEmpty) return const [];

    final close = rows.map((row) => row.adjustedClose).toList(growable: false);
    final sma20 = _simpleMovingAverage(close, config.sma20Period);
    final sma50 = _simpleMovingAverage(close, config.sma50Period);
    final sma200 = _simpleMovingAverage(close, config.sma200Period);
    final rsi = _wilderRsi(close, config.rsiPeriod);
    final drawdown = _rollingDrawdown(close, config.drawdownLookbackDays);

    final volatility = switch (config.volatilityMode) {
      VolatilityMode.externalVolatility =>
        rows.map((row) => row.externalVolatility).toList(growable: false),
      VolatilityMode.realizedVolatility21d =>
        _realizedVolatility(close, config.realizedVolatilityWindow),
    };

    final volatilityPercentile =
        _rollingPercentile(volatility, config.volatilityPercentileWindow);
    final volatilityChange5 = _percentChange(volatility, 5);
    final sentimentZ = _resolveSentimentZ(rows, config.sentimentZWindow);
    final breadth50 = rows.map((row) => row.breadth50).toList(growable: false);
    final breadth50D5 = _difference(breadth50, config.breadthDeltaDays);

    final signalBeforeTwoDayConfirmation = List<McsSignal>.filled(
      rows.length,
      McsSignal.podrz,
    );
    final output = List<McsBfDay?>.filled(rows.length, null);

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rsiValue = rsi[i];
      final sma20Value = sma20[i];
      final sma50Value = sma50[i];
      final sma200Value = sma200[i];
      final volValue = volatility[i];
      final volPercentileValue = volatilityPercentile[i];
      final volChangeValue = volatilityChange5[i];
      final sentimentValue = sentimentZ[i];
      final breadthValue = breadth50[i];
      final breadthDeltaValue = breadth50D5[i];
      final drawdownValue = drawdown[i];

      final breadthRequired =
          config.useBasicBreadthFilter ||
          config.useDrawdownAndStrictBreadthFilters;
      final enoughData =
          [
            rsiValue,
            sma20Value,
            sma50Value,
            sma200Value,
            volValue,
            volPercentileValue,
            volChangeValue,
            sentimentValue,
          ].every((value) => value != null) &&
          (!breadthRequired ||
              (breadthValue != null && breadthDeltaValue != null));

      if (!enoughData) {
        output[i] = McsBfDay(
          date: row.date,
          adjustedClose: row.adjustedClose,
          finalSignal: McsSignal.podrz,
          rawSignal: McsSignal.podrz,
          signalBeforeTwoDayConfirmation: McsSignal.podrz,
          mcs: null,
          rsi14: rsiValue,
          sma20: sma20Value,
          sma50: sma50Value,
          sma200: sma200Value,
          volatility: volValue,
          volatilityPercentile: volPercentileValue,
          volatilityChange5: volChangeValue,
          sentimentZ: sentimentValue,
          breadth50: breadthValue,
          breadth50D5: breadthDeltaValue,
          drawdown63: drawdownValue,
          rScore: null,
          vScore: null,
          sScore: null,
          trendScore: null,
          strictBreadthSetup: false,
          strictBreadthPass: true,
          drawdownFilterTriggered: false,
          twoDayConfirmationPass: true,
          reasonFlags: const ['insufficient_history'],
        );
        continue;
      }

      final closeValue = row.adjustedClose;
      final rsiReady = rsiValue!;
      final sma20Ready = sma20Value!;
      final sma50Ready = sma50Value!;
      final sma200Ready = sma200Value!;
      final volPercentileReady = volPercentileValue!;
      final volChangeReady = volChangeValue!;
      final sentimentReady = sentimentValue!;
      final breadthReady = breadthValue!;
      final breadthDeltaReady = breadthDeltaValue!;

      final rScore = _clip((50.0 - rsiReady) / 20.0);
      final volatilityLevelScore = _clip((volPercentileReady - 50.0) / 50.0);
      final volatilityMomentumScore = volChangeReady < config.volatilityDropThreshold
          ? 0.25
          : volChangeReady > config.volatilityJumpThreshold
          ? -0.25
          : 0.0;
      final vScore = _clip(volatilityLevelScore + volatilityMomentumScore);
      final sScore = _clip(-sentimentReady / 2.0);
      final trendScore = _trendScore(
        closeValue,
        sma50Ready,
        sma200Ready,
        config.nearSma200Band,
      );
      final mcs =
          100.0 *
          (0.30 * rScore + 0.25 * vScore + 0.25 * sScore + 0.20 * trendScore);

      final rawSignal = mcs >= config.buyThreshold
          ? McsSignal.kup
          : mcs <= config.sellThreshold
          ? McsSignal.predaj
          : McsSignal.podrz;

      final bearTrendConfirmation =
          rsiReady > 30.0 || closeValue > sma20Ready || volChangeReady <= 0.0;
      var signal =
          rawSignal == McsSignal.kup &&
              trendScore < 0.0 &&
              !bearTrendConfirmation
          ? McsSignal.podrz
          : rawSignal;

      final reasonFlags = <String>[];
      if (rawSignal == McsSignal.kup && signal == McsSignal.podrz) {
        reasonFlags.add('bear_trend_without_confirmation');
      }

      final normalBreadthPass = config.useBasicBreadthFilter
          ? breadthReady < config.basicBreadthMax || breadthDeltaReady > 0.0
          : true;
      final strictBreadthSetup =
          closeValue > sma200Ready && rsiReady > config.strongMarketRsiMin;
      final strictBreadthPass =
          config.useDrawdownAndStrictBreadthFilters && strictBreadthSetup
          ? breadthReady < config.strictBreadthMax ||
                breadthDeltaReady > config.strictBreadthDeltaMin
          : normalBreadthPass;

      if (signal == McsSignal.kup && !strictBreadthPass) {
        signal = McsSignal.podrz;
        reasonFlags.add(
          strictBreadthSetup && config.useDrawdownAndStrictBreadthFilters
              ? 'strict_breadth_filter'
              : 'basic_breadth_filter',
        );
      }

      final drawdownFilterTriggered =
          config.useDrawdownAndStrictBreadthFilters &&
          signal == McsSignal.kup &&
          closeValue > sma200Ready &&
          rsiReady > config.strongMarketRsiMin &&
          drawdownValue != null &&
          drawdownValue > config.drawdownMinDip;

      if (drawdownFilterTriggered) {
        signal = McsSignal.podrz;
        reasonFlags.add('drawdown_filter');
      }

      signalBeforeTwoDayConfirmation[i] = signal;
      final twoDayConfirmationPass =
          config.useTwoDayBuyConfirmation && signal == McsSignal.kup
          ? i > 0 && signalBeforeTwoDayConfirmation[i - 1] == McsSignal.kup
          : true;
      final finalSignal =
          signal == McsSignal.kup && !twoDayConfirmationPass
          ? McsSignal.podrz
          : signal;
      if (signal == McsSignal.kup && !twoDayConfirmationPass) {
        reasonFlags.add('waiting_second_kup_day');
      }

      output[i] = McsBfDay(
        date: row.date,
        adjustedClose: row.adjustedClose,
        finalSignal: finalSignal,
        rawSignal: rawSignal,
        signalBeforeTwoDayConfirmation: signal,
        mcs: mcs,
        rsi14: rsiReady,
        sma20: sma20Ready,
        sma50: sma50Ready,
        sma200: sma200Ready,
        volatility: volValue,
        volatilityPercentile: volPercentileReady,
        volatilityChange5: volChangeReady,
        sentimentZ: sentimentReady,
        breadth50: breadthReady,
        breadth50D5: breadthDeltaReady,
        drawdown63: drawdownValue,
        rScore: rScore,
        vScore: vScore,
        sScore: sScore,
        trendScore: trendScore,
        strictBreadthSetup: strictBreadthSetup,
        strictBreadthPass: strictBreadthPass,
        drawdownFilterTriggered: drawdownFilterTriggered,
        twoDayConfirmationPass: twoDayConfirmationPass,
        reasonFlags: reasonFlags,
      );
    }

    return output.whereType<McsBfDay>().toList(growable: false);
  }

  static double _trendScore(
    double close,
    double sma50,
    double sma200,
    double nearSma200Band,
  ) {
    if ((close / sma200 - 1.0).abs() < nearSma200Band) return 0.0;
    if (close > sma200 && sma50 > sma200) return 1.0;
    if (close > sma200) return 0.5;
    if (close < sma200 && sma50 < sma200) return -1.0;
    return -0.5;
  }

  static double _clip(double value, [double low = -1.0, double high = 1.0]) {
    return value.clamp(low, high).toDouble();
  }

  static List<double?> _simpleMovingAverage(List<double> values, int period) {
    final out = List<double?>.filled(values.length, null);
    var sum = 0.0;
    for (var i = 0; i < values.length; i++) {
      sum += values[i];
      if (i >= period) sum -= values[i - period];
      if (i >= period - 1) out[i] = sum / period;
    }
    return out;
  }

  static List<double?> _rollingMax(List<double> values, int period) {
    final out = List<double?>.filled(values.length, null);
    for (var i = 0; i < values.length; i++) {
      final start = math.max(0, i - period + 1);
      if (i - start + 1 >= math.min(period, 20)) {
        out[i] = values
            .sublist(start, i + 1)
            .reduce((a, b) => a > b ? a : b);
      }
    }
    return out;
  }

  static List<double?> _rollingDrawdown(List<double> values, int period) {
    final maxValues = _rollingMax(values, period);
    return List<double?>.generate(values.length, (i) {
      final maxValue = maxValues[i];
      if (maxValue == null || maxValue == 0.0) return null;
      return values[i] / maxValue - 1.0;
    }, growable: false);
  }

  static List<double?> _wilderRsi(List<double> values, int period) {
    final out = List<double?>.filled(values.length, null);
    if (values.length < period + 1) return out;

    final alpha = 1.0 / period;
    double? avgGain;
    double? avgLoss;
    var observations = 0;

    for (var i = 1; i < values.length; i++) {
      final delta = values[i] - values[i - 1];
      final gain = delta > 0 ? delta : 0.0;
      final loss = delta < 0 ? -delta : 0.0;

      avgGain = avgGain == null ? gain : alpha * gain + (1.0 - alpha) * avgGain!;
      avgLoss = avgLoss == null ? loss : alpha * loss + (1.0 - alpha) * avgLoss!;
      observations += 1;

      if (observations >= period) {
        final gainValue = avgGain ?? 0.0;
        final lossValue = avgLoss ?? 0.0;
        if (lossValue == 0.0) {
          out[i] = 100.0;
        } else {
          final rs = gainValue / lossValue;
          out[i] = 100.0 - (100.0 / (1.0 + rs));
        }
      }
    }
    return out;
  }

  static List<double?> _realizedVolatility(List<double> values, int period) {
    final returns = List<double?>.filled(values.length, null);
    for (var i = 1; i < values.length; i++) {
      returns[i] = values[i] / values[i - 1] - 1.0;
    }

    final out = List<double?>.filled(values.length, null);
    for (var i = 0; i < returns.length; i++) {
      if (i < period) continue;
      final window = returns.sublist(i - period + 1, i + 1).whereType<double>().toList();
      if (window.length == period) {
        final std = _sampleStd(window);
        out[i] = std * math.sqrt(252.0) * 100.0;
      }
    }
    return out;
  }

  static List<double?> _rollingPercentile(List<double?> values, int period) {
    final out = List<double?>.filled(values.length, null);
    for (var i = 0; i < values.length; i++) {
      if (i < period - 1) continue;
      final window = values.sublist(i - period + 1, i + 1).whereType<double>().toList();
      final current = values[i];
      if (current != null && window.length == period) {
        final countLessOrEqual = window.where((value) => value <= current).length;
        out[i] = 100.0 * (countLessOrEqual - 0.5) / window.length;
      }
    }
    return out;
  }

  static List<double?> _percentChange(List<double?> values, int lag) {
    return List<double?>.generate(values.length, (i) {
      if (i < lag) return null;
      final current = values[i];
      final previous = values[i - lag];
      if (current == null || previous == null || previous == 0.0) return null;
      return current / previous - 1.0;
    }, growable: false);
  }

  static List<double?> _difference(List<double?> values, int lag) {
    return List<double?>.generate(values.length, (i) {
      if (i < lag) return null;
      final current = values[i];
      final previous = values[i - lag];
      if (current == null || previous == null) return null;
      return current - previous;
    }, growable: false);
  }

  static List<double?> _resolveSentimentZ(
    List<DailyMarketInput> rows,
    int window,
  ) {
    if (rows.any((row) => row.sentimentZ != null)) {
      return rows.map((row) => row.sentimentZ).toList(growable: false);
    }

    final bbs = rows.map((row) {
      final bullish = row.bullishPct;
      final bearish = row.bearishPct;
      if (bullish != null && bearish != null) return bullish - bearish;
      return null;
    }).toList(growable: false);

    final out = List<double?>.filled(rows.length, null);
    for (var i = 0; i < bbs.length; i++) {
      if (i < window - 1) continue;
      final windowValues = bbs.sublist(i - window + 1, i + 1).whereType<double>().toList();
      final current = bbs[i];
      if (current != null && windowValues.length >= math.max(2, window ~/ 3)) {
        final mean = windowValues.reduce((a, b) => a + b) / windowValues.length;
        final std = _sampleStd(windowValues);
        out[i] = std == 0.0 ? 0.0 : (current - mean) / std;
      }
    }
    return out;
  }

  static double _sampleStd(List<double> values) {
    if (values.length <= 1) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    var varianceSum = 0.0;
    for (final value in values) {
      varianceSum += math.pow(value - mean, 2).toDouble();
    }
    return math.sqrt(varianceSum / (values.length - 1));
  }
}
