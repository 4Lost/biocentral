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

  @override
  Set<ColumnOperationType> getAvailableOperations() {
    final Set<ColumnOperationType> operations = super.getAvailableOperations();
    operations.add(ColumnOperationType.calculateSupriseFactor);
    return operations;
  }

  DistributionStats? _distribution;
  final Map<String, ScaleStats> _scaleStats = {};

  Future<DistributionStats> distribution() async {
    if(_distribution != null) {
      return _distribution!;
    }

    final Future<({
      List<Point> lenKdePoints,
      Map<String, double> lenStats,
      Map<String, double> seqDistribution,
      Map<int, Map<String, double>> posSeqDistribution})> futureDistStats = compute(DistributionStats.calculateAADistribution, valueMap.values.map((sequence) => sequence.toString()).toList());
    
    final Future<Either<BiocentralException, Map<String, dynamic>>> futureScaleStats = companion.getScales(valueMap.values.map((sequence) => sequence.toString()).toList());

    final ({
      List<Point> lenKdePoints,
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

    _distribution = DistributionStats(distStats.lenKdePoints, distStats.lenStats, distStats.seqDistribution, distStats.posSeqDistribution, pointScaleStats);

    return _distribution!;
  }

  SequenceStats getSequenceStats() {
    if (_scaleStats == {} || _distribution == null) {
      distribution();
    }
    
    final List<SequenceValues> sequenceValues = [];
    final Map<String, double> means = {};
    final Map<String, double> stdDevs = {};

    for (MapEntry<String, Sequence> entry in valueMap.entries) {
      final String sequence = entry.value.toString();
      final double hydVal = _scaleStats['hydrophobicity']!.valuesPerSequence[sequence]!;
      final double stabVal = _scaleStats['stability']!.valuesPerSequence[sequence]!;
      final double freVal = _scaleStats['freeEnergy']!.valuesPerSequence[sequence]!;
      final double volVal = _scaleStats['volume']!.valuesPerSequence[sequence]!;
      final double alpVal = _scaleStats['alphaHelix']!.valuesPerSequence[sequence]!;
      final double betVal = _scaleStats['betaSheet']!.valuesPerSequence[sequence]!;
      final double coiVal = _scaleStats['coil']!.valuesPerSequence[sequence]!;
      final double mutVal = _scaleStats['mutability']!.valuesPerSequence[sequence]!;

      sequenceValues.add(SequenceValues(
        entry.key,
        entry.value.toString().length,
        hydVal,
        stabVal,
        freVal,
        volVal,
        alpVal,
        betVal,
        coiVal,
        mutVal,
        ),);
    }

    means['length'] = _distribution!.lenStats['mean']!;
    stdDevs['length'] = _distribution!.lenStats['stdDev']!;

    for (MapEntry<String, ScaleStats> entry in _scaleStats.entries) {
      means[entry.key] = entry.value.mean;
      stdDevs[entry.key] = entry.value.stdDev;
    }

    return SequenceStats(sequenceValues, means, stdDevs);
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

  Map<String, DistributionStats>? _distribution;
  Map<String, Map<String, ScaleStats>> scaleStats = {};

  Future<List<DistributionStats>> distributionByKeys(String firstColumn, String secondColumn) async {
    if(_distribution != null && _distribution![firstColumn] != null && _distribution![secondColumn] != null) {
      return [_distribution![firstColumn]!, _distribution![secondColumn]!];
    }
    _distribution ??= {};

    for (String column in [firstColumn, secondColumn]) {
      if (_distribution![column] != null) continue;

      final List<String> values = valueMap[column]!.values.map((sequence) => sequence.toString()).toList();

      final Future<({List<Point> lenKdePoints,
        Map<String, double> lenStats,
        Map<String, double> seqDistribution,
        Map<int, Map<String, double>> posSeqDistribution})> futureDistStats = compute(DistributionStats.calculateAADistribution, values);

      final Future<Either<BiocentralException, Map<String, dynamic>>> futureScaleStats = companion.getScales(values);

      final ({
        List<Point> lenKdePoints,
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

      _distribution![column] = DistributionStats(distStats.lenKdePoints, distStats.lenStats, distStats.seqDistribution, distStats.posSeqDistribution, listScaleStats);
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

    for (int i = 0; i < 200; i++) {
      final double x = lenStats['min']! + (i / 200) * range;
      double y = 0;
      for (double value in lenDistribution) {
          y += math.exp(-math.pow(x - value, 2) / (2 * bandwidth * bandwidth));
      }
    
      y /= lenDistribution.length * bandwidth * math.sqrt(2 * math.pi);
      lenKdePoints.add(Point(x, y));
    }

    double area = 0.0;
    for (int i = 0; i < lenKdePoints.length - 1; i++) {
      final p1 = lenKdePoints[i];
      final p2 = lenKdePoints[i + 1];

      final double dx = p2.x - p1.x;
      final double avgY = (p1.y + p2.y) / 2.0;

      area += dx * avgY;
    }

    if (area > 0) lenKdePoints = [for (final p in lenKdePoints) Point(p.x, p.y / area)];

    return lenKdePoints;
  }

  static Future<({
    List<Point> lenKdePoints,
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
        'stdDev': stdDev,
        'p01': percentile(lenDistribution, 0.01),
        'p99': percentile(lenDistribution, 0.99),
      };
    }

    return (lenKdePoints: generateKdePoints(lenDistribution, lenStats), lenStats: lenStats, seqDistribution: seqDistribution, posSeqDistribution: posSeqDistribution);
   }
}

class ScaleStats {
  final double min;
  final double max;
  final double mean;
  final double stdDev;
  final Map<String, double> valuesPerSequence;

  ScaleStats(this.min, this.max, this.mean, this.stdDev, this.valuesPerSequence);
  PointScaleStats toPointScaleStats() {
    List<Point> kdePoints = [];
    final double range = max - min;
    final double bandwidth = 0.75 * stdDev * math.pow(valuesPerSequence.length, -1.0/5);

    for (int i = 0; i < 200; i++) {
      final double x = min + (i / 200) * range;
      double y = 0;
      for (double value in valuesPerSequence.values) {
          y += math.exp(-math.pow(x - value, 2) / (2 * bandwidth * bandwidth));
      }
    
      y /= valuesPerSequence.length * bandwidth * math.sqrt(2 * math.pi);
      kdePoints.add(Point(x, y));
    }

    double area = 0.0;
    for (int i = 0; i < kdePoints.length - 1; i++) {
      final p1 = kdePoints[i];
      final p2 = kdePoints[i + 1];

      final double dx = p2.x - p1.x;
      final double avgY = (p1.y + p2.y) / 2.0;

      area += dx * avgY;
    }

    if (area > 0) kdePoints = [for (final p in kdePoints) Point(p.x, p.y / area)];

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
}

class SequenceValues {
  final String sequence;
  final int length;
  final double hydrophobicity;
  final double stability;
  final double freeEnergy;
  final double volume;
  final double alphaHelix;
  final double betaSheet;
  final double coil;
  final double mutability;

  SequenceValues(this.sequence, this.length, this.hydrophobicity, this.stability, this.freeEnergy, this.volume, this.alphaHelix, this.betaSheet, this.coil, this.mutability);
}

class SequenceStats {
  final List<SequenceValues> values;
  final Map<String, double> means;
  final Map<String, double> stdDevs;

  SequenceStats(this.values, this.means, this.stdDevs);
}