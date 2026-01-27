import 'dart:math' as math;
import 'package:bio_flutter/bio_flutter.dart';
import 'package:biocentral/sdk/util/point.dart';
import 'package:flutter/foundation.dart';
import 'package:biocentral/sdk/biocentral_sdk.dart';
import 'package:biocentral/sdk/data/biocentral_python_companion.dart';
import 'package:fpdart/fpdart.dart';

class SequenceColumnWizardFactory extends ColumnWizardFactory {
  @override
  ColumnWizard create({required List<String> columnNames, required Map<String, dynamic> valueMap, required BiocentralPythonCompanion companion}) {
    if (columnNames.length < 2 || columnNames[1] == '') {
      return SequenceNormalColumnWizard(columnNames, valueMap.map((k, v) => MapEntry(k, v as Sequence)), companion);
    }
    return SequenceCompareColumnWizard(columnNames, valueMap.map((key, val) => MapEntry(key, (val as Map<String, dynamic>).map((k, v) => MapEntry(k, v as Sequence)))), companion);
  }

  @override
  TypeDetector getTypeDetector() {
    return TypeDetector(Sequence, (value) => value is Sequence || value is Map<String, dynamic> && value.values.every((v) => v is Sequence));
  }
}
abstract class SequenceColumnWizard extends ColumnWizard {
  @override
  Type get type => Sequence;

  SequenceColumnWizard(super.columnNames, super.companion);
}

class SequenceNormalColumnWizard extends SequenceColumnWizard with CounterStats {
  @override
  final Map<String, Sequence> valueMap;

  SequenceNormalColumnWizard(super.columnNames, this.valueMap, super.companion);

  Map<String, double>? _composition;

  Future<Map<String, double>> composition() async {
    if(_composition != null) {
      return _composition!;
    }

    final Map<String, int> counts = {};
    int totalCount = 0;

    for (Sequence sequence in valueMap.values) {
      for (String token in sequence.toString().split('')) {
        counts[token] = (counts[token] ?? 0) + 1;
        totalCount++;
      }
    }

    final Map<String, double> compositionResult = counts.map((k, v) => MapEntry(k, v / totalCount));
    _composition = compositionResult;

    return _composition!;
  }

  DistributionStats? _distribution;
  Map<String, ScaleStats> _scaleStats = {};
  List<double>? _lenDistribution;

  Future<DistributionStats> distribution() async {
    if(_distribution != null) {
      return _distribution!;
    }

    final Future<({
      List<double> lenDistribution,
      Map<String, double> lenStats,
      Map<String, double> seqDistribution,
      Map<int, Map<String, double>> posSeqDistribution})> futureDistStats = compute(DistributionStats.calculateAADistribution, valueMap.values.map((sequence) => sequence.toString()).toList());
    
    final Future<Either<BiocentralException, Map<String, dynamic>>> futureScaleStats = companion.getScales(valueMap.values.map((sequence) => sequence.toString()).toList());

    final ({
      List<double> lenDistribution,
      Map<String, double> lenStats,
      Map<String, double> seqDistribution,
      Map<int, Map<String, double>> posSeqDistribution}) distStats = await futureDistStats;

    final Map<String, PointScaleStats> pointScaleStats = {};

    (await futureScaleStats).match(
      (exception) => logger.e(exception),
      (data) {
        for (final entry in data['results'].entries) {
          _scaleStats[entry.key] = ScaleStats(entry.value['stats']['min'], entry.value['stats']['max'], entry.value['stats']['mean'], entry.value['stats']['stdDev'], Map<String, double>.from(entry.value['valuesPerSequence']));
          pointScaleStats[entry.key] = _scaleStats[entry.key]!.toPointScaleStats();
        }
      },
    );

    _lenDistribution = distStats.lenDistribution;
    _distribution = DistributionStats(DistributionStats.generateKdePoints(distStats.lenDistribution, distStats.lenStats), distStats.lenStats, distStats.seqDistribution, distStats.posSeqDistribution, pointScaleStats);

    return _distribution!;
  }
}

class SequenceCompareColumnWizard extends SequenceColumnWizard with CounterCompareStats {
  @override
  final Map<String, Map<String, Sequence>> valueMap;

  SequenceCompareColumnWizard(super.columnNames, this.valueMap, super.companion);

  @override
  bool get compare => true;

  @override
  Iterable<String> getKeys() {
    return valueMap.keys;
  }

  Map<String, Map<String, double>>? _composition;

  Future<Map<String, Map<String, double>>> composition() async {
    if(_composition != null) {
      return _composition!;
    }
    _composition = {};

    for (MapEntry<String, Map<String, Sequence>> entry in valueMap.entries) {
      final Map<String, int> counts = {};
      int totalCount = 0;

      for (Sequence sequence in entry.value.values) {
        for (String token in sequence.toString().split('')) {
          counts[token] = (counts[token] ?? 0) + 1;
          totalCount++;
        }
      }

      final Map<String, double> compositionResult = counts.map((k, v) => MapEntry(k, v / totalCount));
      _composition![entry.key] = compositionResult;
    }

    return _composition!;
  }

  Map<String, DistributionStats>? _distribution;
  Map<String, Map<String, ScaleStats>> scaleStats = {};

  Future<List<DistributionStats>> distributionByKeys(String firstColumn, String secondColumn) async {
    if(_distribution != null && _distribution![firstColumn] != null && _distribution![secondColumn] != null) {
      return [_distribution![firstColumn]!, _distribution![secondColumn]!];
    }
    _distribution ??= {};

    if (_distribution![firstColumn] == null) {
      final Future<({List<double> lenDistribution,
        Map<String, double> lenStats,
        Map<String, double> seqDistribution,
        Map<int, Map<String, double>> posSeqDistribution})> futureDistStats = compute(DistributionStats.calculateAADistribution, valueMap[firstColumn]!.values.map((sequence) => sequence.toString()).toList());

      final Future<Either<BiocentralException, Map<String, dynamic>>> futureScaleStats = companion.getScales(valueMap[firstColumn]!.values.map((sequence) => sequence.toString()).toList());

      final ({
        List<double> lenDistribution,
        Map<String, double> lenStats,
        Map<String, double> seqDistribution,
        Map<int, Map<String, double>> posSeqDistribution}) distStats = await futureDistStats;

      final Map<String, PointScaleStats> listScaleStats = {};

      final Map<String, ScaleStats> scaleStats = {};
      (await futureScaleStats).match(
        (exception) => logger.e(exception),
        (data) {
          for (final entry in data.entries) {
            scaleStats[entry.key] = ScaleStats(entry.value['min'], entry.value['max'], entry.value['mean'], entry.value['stdDev'], Map<String, double>.from(entry.value['valuesPerSequence']));
            listScaleStats[entry.key] = scaleStats[entry.key]!.toPointScaleStats();
          }
        },
      );

      _distribution![firstColumn] = DistributionStats(DistributionStats.generateKdePoints(distStats.lenDistribution, distStats.lenStats), distStats.lenStats, distStats.seqDistribution, distStats.posSeqDistribution, listScaleStats);
    }

    if (_distribution![secondColumn] == null) {
      final Future<({List<double> lenDistribution,
        Map<String, double> lenStats,
        Map<String, double> seqDistribution,
        Map<int, Map<String, double>> posSeqDistribution})> futureDistStats = compute(DistributionStats.calculateAADistribution, valueMap[secondColumn]!.values.map((sequence) => sequence.toString()).toList());

      final Future<Either<BiocentralException, Map<String, dynamic>>> futureScaleStats = companion.getScales(valueMap[secondColumn]!.values.map((sequence) => sequence.toString()).toList());

      final ({
        List<double> lenDistribution,
        Map<String, double> lenStats,
        Map<String, double> seqDistribution,
        Map<int, Map<String, double>> posSeqDistribution}) distStats = await futureDistStats;

      final Map<String, PointScaleStats> listScaleStats = {};

      final Map<String, ScaleStats> scaleStats = {};
      (await futureScaleStats).match(
        (exception) => logger.e(exception),
        (data) {
          for (final entry in data.entries) {
            listScaleStats[entry.key] = scaleStats[entry.key]!.toPointScaleStats();
          }
        },
      );

      _distribution![firstColumn] = DistributionStats(DistributionStats.generateKdePoints(distStats.lenDistribution, distStats.lenStats), distStats.lenStats, distStats.seqDistribution, distStats.posSeqDistribution, listScaleStats);
    }

    return [_distribution![firstColumn]!, _distribution![secondColumn]!];
  }

}

class DistributionStats {
  final List<Point> lenKdePoints;
  final Map<String, double> lenStats;
  final Map<String, double> seqDistribution;
  final Map<int, Map<String, double>> posSeqDistribution;
  final Map<String, PointScaleStats> scaleStats;

  DistributionStats(this.lenKdePoints, this.lenStats, this.seqDistribution, this.posSeqDistribution, this.scaleStats);
 
  PointScaleStats getScaleStats(String feature) => scaleStats[feature] ?? PointScaleStats(0, 0, 0, 0, []);

  static List<Point> generateKdePoints(List<double> lenDistribution, Map<String, double> lenStats) {
    List<Point> lenKdePoints = [];
    final double range = lenStats['max']! - lenStats['min']!;
    final double bandwidth = 20;

    for (int i = 0; i < 100; i++) {
      final double x = lenStats['min']! + (i / 100) * range;
      double y = 0;
      for (double value in lenDistribution) {
          y += math.exp(-math.pow(x - value, 2) / (2 * bandwidth * bandwidth));
      }
    
      y /= lenDistribution.length * bandwidth * math.sqrt(2 * math.pi);
      lenKdePoints.add(Point(x, y));
    }
    final double sumKDE = lenKdePoints.fold(0.0, (sum, point) => sum + point.y);
    lenKdePoints = [for (Point point in lenKdePoints) Point(point.x, point.y / sumKDE)];

    return lenKdePoints;
  }

  static Future<({
    List<double> lenDistribution,
    Map<String, double> lenStats,
    Map<String, double> seqDistribution,
    Map<int, Map<String, double>> posSeqDistribution})> calculateAADistribution(List<String> sequences) async {
    const letters = [
      'A', 'C', 'D', 'E', 'F', 'G', 'H', 'I',
      'K', 'L', 'M', 'N', 'P', 'Q', 'R', 'S',
      'T', 'V', 'W', 'Y', 'X', 'U',
    ];

    // Initialize results
    final List<double> lenDistribution = [];
    Map<String, double> lenStats = {};
    final Map<String, double> seqDistribution = {for (final l in letters) l: 0};
    final Map<int, Map<String, double>> posSeqDistribution = {};

    // Single pass through all sequences
    for (final seq in sequences) {
      final len = seq.length;
      lenDistribution.add(len.toDouble());

      // Update per-character and positional distributions
      for (var i = 0; i < len; i++) {
        final char = seq[i];
        if (letters.contains(char)) {
          seqDistribution[char] = (seqDistribution[char] ?? 0) + 1;

          posSeqDistribution.putIfAbsent(
            i,
            () => {for (final l in letters) l: 0},
          );
          posSeqDistribution[i]![char] =
              (posSeqDistribution[i]![char] ?? 0) + 1;
        }
      }
    }

    if (lenDistribution.isNotEmpty) {
      lenDistribution.sort();

      final amount = lenDistribution.length;

      final double mean = lenDistribution.reduce((a, b) => a + b) / amount;

      final double variance = lenDistribution
              .map((x) => math.pow(x - mean, 2))
              .reduce((a, b) => a + b) /
          amount;

      final double stdDev = math.sqrt(variance);

      double percentile(List<double> sortedList, double p) {
        final double rank = p * (sortedList.length - 1);
        final int lower = rank.floor();
        final int upper = rank.ceil();
        if (lower == upper) return sortedList[lower].toDouble();
        final double weight = rank - lower;
        return sortedList[lower] * (1 - weight) + sortedList[upper] * weight;
      }

      lenStats = {
        'min': lenDistribution.first.toDouble(),
        'max': lenDistribution.last.toDouble(),
        'mean': mean,
        'variance': variance,
        'std_dev': stdDev,
        'p01': percentile(lenDistribution, 0.01),
        'p99': percentile(lenDistribution, 0.99),
      };
    }

    return (lenDistribution: lenDistribution, lenStats: lenStats, seqDistribution: seqDistribution, posSeqDistribution: posSeqDistribution);
   }
}

class ScaleStats {
  final double min;
  final double max;
  final double mean;
  final double stdDev;
  final Map<String, double> valuesPerSequence;

  ScaleStats(this.min, this.max, this.mean, this.stdDev, this.valuesPerSequence);
/*
  static List<String> get availableScales => [
    'hydrophobicity',
    'stability',
    'freeEnergy',
    'volume',
    'alpha-helix',
    'beta-sheet',
    'coil',
    'mutability',
  ];
  */
  PointScaleStats toPointScaleStats() {
    List<Point> kdePoints = [];
    final double range = max - min;
    final double bandwidth = 0.75 * stdDev * math.pow(valuesPerSequence.length, -1.0/5);;

    for (int i = 0; i < 100; i++) {
      final double x = min + (i / 100) * range;
      double y = 0;
      for (double value in valuesPerSequence.values) {
          y += math.exp(-math.pow(x - value, 2) / (2 * bandwidth * bandwidth));
      }
    
      y /= valuesPerSequence.length * bandwidth * math.sqrt(2 * math.pi);
      kdePoints.add(Point(x, y));
    }
    final double sumKDE = kdePoints.fold(0.0, (sum, point) => sum + point.y);
    kdePoints = [for (Point point in kdePoints) Point(point.x, point.y / sumKDE)];

    return PointScaleStats(min, max, mean, stdDev, kdePoints);
  }
}


class PointScaleStats {
  final double min;
  final double max;
  final double mean;
  final double stdDev;
  final List<Point> values;

  PointScaleStats(this.min, this.max, this.mean, this.stdDev, this.values);
/*
  static List<String> get availableScales => [
    'hydrophobicity',
    'stability',
    'freeEnergy',
    'volume',
    'alpha-helix',
    'beta-sheet',
    'coil',
    'mutability',
  ];
  */
}

class SequenceStats {
  final Sequence sequence;
  final int length;
  final double hydrophobicity;

  SequenceStats(this.sequence, this.length, this.hydrophobicity);
}