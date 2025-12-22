import 'dart:math';
import 'package:bio_flutter/bio_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:biocentral/sdk/biocentral_sdk.dart';
import 'package:biocentral/sdk/data/biocentral_python_companion.dart';

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

  Future<DistributionStats> distribution() async {
    if(_distribution != null) {
      return _distribution!;
    }

    final DistributionStats result = await compute(DistributionStats.calculateDistribution, valueMap.values.map((sequence) => sequence.toString()).toList());
    _distribution = result;
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

  Future<List<DistributionStats>> distributionByKeys(String firstColumn, String secondColumn) async {
    if(_distribution != null && _distribution![firstColumn] != null && _distribution![secondColumn] != null) {
      return [_distribution![firstColumn]!, _distribution![secondColumn]!];
    }
    _distribution ??= {};

    if (_distribution![firstColumn] == null) {
      final DistributionStats result = await compute(DistributionStats.calculateDistribution, valueMap[firstColumn]!.values.map((sequence) => sequence.toString()).toList());
      _distribution![firstColumn] = result;
    }

    if (_distribution![secondColumn] == null) {
      final DistributionStats result = await compute(DistributionStats.calculateDistribution, valueMap[secondColumn]!.values.map((sequence) => sequence.toString()).toList());
      _distribution![secondColumn] = result;
    }

    return [_distribution![firstColumn]!, _distribution![secondColumn]!];
  }
}

class DistributionStats {
  final List<double> lenDistribution;
  final Map<String, double> lenStats;
  final Map<String, double> seqDistribution;
  final Map<int, Map<String, double>> posSeqDistribution;

  DistributionStats(this.lenDistribution, this.lenStats, this.seqDistribution, this.posSeqDistribution);

  static Future<DistributionStats> calculateDistribution(List<String> sequences) async {
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
      for (var i = 0; i < seq.length; i++) {
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
      final List<double> lengths = List.of(lenDistribution);
      lengths.sort();

      final int n = lengths.length;
      final double mean = lengths.reduce((a, b) => a + b) / n;

      final double variance = lengths
              .map((x) => pow(x - mean, 2))
              .reduce((a, b) => a + b) /
          n;

      final double stdDev = sqrt(variance);

      double percentile(List<double> sortedList, double p) {
        final double rank = p * (sortedList.length - 1);
        final int lower = rank.floor();
        final int upper = rank.ceil();
        if (lower == upper) return sortedList[lower].toDouble();
        final double weight = rank - lower;
        return sortedList[lower] * (1 - weight) + sortedList[upper] * weight;
      }

      lenStats = {
        'min': lengths.first.toDouble(),
        'max': lengths.last.toDouble(),
        'mean': mean,
        'variance': variance,
        'std_dev': stdDev,
        'p01': percentile(lengths, 0.01),
        'p99': percentile(lengths, 0.99),
      };
    }

    return DistributionStats(lenDistribution, lenStats, seqDistribution, posSeqDistribution);
  }
}
