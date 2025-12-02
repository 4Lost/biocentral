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
    return TypeDetector(Sequence, (value) => value is Sequence);
  }
}
abstract class SequenceColumnWizard extends ColumnWizard {
  @override
  Type get type => Sequence;

  SequenceColumnWizard(super.columnNames, super.companion);

  Future<dynamic> distribution();
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

  ({
    Map<String, Map<String, double>> lenDistribution,
    Map<String, double> seqDistribution,
    Map<int, Map<String, double>> posSeqDistribution,
  })? _distribution;

  @override
  Future<({
    Map<String, Map<String, double>> lenDistribution,
    Map<String, double> seqDistribution,
    Map<int, Map<String, double>> posSeqDistribution,
  })> distribution() async {
    if(_distribution != null) {
      return _distribution!;
    }

    final ({
    Map<String, Map<String, double>> lenDistribution,
    Map<String, double> seqDistribution,
    Map<int, Map<String, double>> posSeqDistribution,
  }) result = await compute(_calculateDistribution, valueMap.values.map((sequence) => sequence.toString()).toList());
    _distribution = result;
    return _distribution!;
  }

  Future<({
    Map<String, Map<String, double>> lenDistribution,
    Map<String, double> seqDistribution,
    Map<int, Map<String, double>> posSeqDistribution,
  })> _calculateDistribution(List<String> sequences) async {
    const letters = [
      'A', 'C', 'D', 'E', 'F', 'G', 'H', 'I',
      'K', 'L', 'M', 'N', 'P', 'Q', 'R', 'S',
      'T', 'V', 'W', 'Y', 'X', 'U'
    ];

    // Initialize results
    final Map<String, Map<String, double>> lenDistribution = {};
    final Map<String, double> seqDistribution = {for (final l in letters) l: 0};
    final Map<int, Map<String, double>> posSeqDistribution = {};
    lenDistribution['length_kde'] = {};
    lenDistribution['length_stats'] = {};

    final List<int> lengths = [];

    // Single pass through all sequences
    for (final seq in sequences) {
      final len = seq.length;
      lengths.add(len);

      // Update KDE-style length counts
      lenDistribution['length_kde']![len.toString()] =
          (lenDistribution['length_kde']![len.toString()] ?? 0) + 1;

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

    final totalCounts = lenDistribution['length_kde']!.values.reduce((a, b) => a + b);
    lenDistribution['length_kde']!.updateAll((key, value) => value / totalCounts);

    if (lengths.isNotEmpty) {
      lengths.sort();

      final int n = lengths.length;
      final double mean = lengths.reduce((a, b) => a + b) / n;

      final double variance = lengths
              .map((x) => pow(x - mean, 2))
              .reduce((a, b) => a + b) /
          n;

      final double stdDev = sqrt(variance);

      double percentile(List<int> sortedList, double p) {
        final double rank = p * (sortedList.length - 1);
        final int lower = rank.floor();
        final int upper = rank.ceil();
        if (lower == upper) return sortedList[lower].toDouble();
        final double weight = rank - lower;
        return sortedList[lower] * (1 - weight) + sortedList[upper] * weight;
      }

      lenDistribution['length_stats'] = {
        'min': lengths.first.toDouble(),
        'max': lengths.last.toDouble(),
        'mean': mean,
        'variance': variance,
        'std_dev': stdDev,
        'p01': percentile(lengths, 0.01),
        'p99': percentile(lengths, 0.99),
      };
    }

    return (
      lenDistribution: lenDistribution,
      seqDistribution: seqDistribution,
      posSeqDistribution: posSeqDistribution,
    );
  }
}

class SequenceCompareColumnWizard extends SequenceColumnWizard with CounterCompareStats {
  @override
  final Map<String, Map<String, Sequence>> valueMap;

  SequenceCompareColumnWizard(super.columnNames, this.valueMap, super.companion);

  @override
  bool get compare => true;

  @override
  Future<Iterable<String>> getKeys() async {
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

  Map<String, ({
    Map<String, Map<String, double>> lenDistribution,
    Map<String, double> seqDistribution,
    Map<int, Map<String, double>> posSeqDistribution,
  })>? _distribution;

  @override
  Future<Map<String, ({
    Map<String, Map<String, double>> lenDistribution,
    Map<String, double> seqDistribution,
    Map<int, Map<String, double>> posSeqDistribution,
  })>> distribution() async {
    if(_distribution != null) {
      return _distribution!;
    }
    _distribution = {};

    for (MapEntry<String, Map<String, Sequence>> entry in valueMap.entries) {
      final ({
        Map<String, Map<String, double>> lenDistribution,
        Map<String, double> seqDistribution,
        Map<int, Map<String, double>> posSeqDistribution,
      }) result = await compute(_calculateDistribution, entry.value.values.map((sequence) => sequence.toString()).toList());
      _distribution![entry.key] = result;
    }
    return _distribution!;
  }

  Future<({
    Map<String, Map<String, double>> lenDistribution,
    Map<String, double> seqDistribution,
    Map<int, Map<String, double>> posSeqDistribution,
  })> _calculateDistribution(List<String> sequences) async {
    const letters = [
      'A', 'C', 'D', 'E', 'F', 'G', 'H', 'I',
      'K', 'L', 'M', 'N', 'P', 'Q', 'R', 'S',
      'T', 'V', 'W', 'Y', 'X', 'U'
    ];

    // Initialize results
    final Map<String, Map<String, double>> lenDistribution = {};
    final Map<String, double> seqDistribution = {for (final l in letters) l: 0};
    final Map<int, Map<String, double>> posSeqDistribution = {};
    lenDistribution['length_kde'] = {};
    lenDistribution['length_stats'] = {};

    final List<int> lengths = [];

    // Single pass through all sequences
    for (final seq in sequences) {
      final len = seq.length;
      lengths.add(len);

      // Update KDE-style length counts
      lenDistribution['length_kde']![len.toString()] =
          (lenDistribution['length_kde']![len.toString()] ?? 0) + 1;

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

    final totalCounts = lenDistribution['length_kde']!.values.reduce((a, b) => a + b);
    lenDistribution['length_kde']!.updateAll((key, value) => value / totalCounts);

    if (lengths.isNotEmpty) {
      lengths.sort();

      final int n = lengths.length;
      final double mean = lengths.reduce((a, b) => a + b) / n;

      final double variance = lengths
              .map((x) => pow(x - mean, 2))
              .reduce((a, b) => a + b) /
          n;

      final double stdDev = sqrt(variance);

      double percentile(List<int> sortedList, double p) {
        final double rank = p * (sortedList.length - 1);
        final int lower = rank.floor();
        final int upper = rank.ceil();
        if (lower == upper) return sortedList[lower].toDouble();
        final double weight = rank - lower;
        return sortedList[lower] * (1 - weight) + sortedList[upper] * weight;
      }

      lenDistribution['length_stats'] = {
        'min': lengths.first.toDouble(),
        'max': lengths.last.toDouble(),
        'mean': mean,
        'variance': variance,
        'std_dev': stdDev,
        'p01': percentile(lengths, 0.01),
        'p99': percentile(lengths, 0.99),
      };
    }

    return (
      lenDistribution: lenDistribution,
      seqDistribution: seqDistribution,
      posSeqDistribution: posSeqDistribution,
    );
  }
}
