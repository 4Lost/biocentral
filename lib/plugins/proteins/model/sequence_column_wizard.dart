import 'dart:math';
import 'package:bio_flutter/bio_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:biocentral/sdk/biocentral_sdk.dart';
import 'package:biocentral/sdk/data/biocentral_python_companion.dart';

class SequenceColumnWizardFactory extends ColumnWizardFactory {
  @override
  ColumnWizard create({required List<String> columnNames, required Map<String, dynamic> valueMap, required BiocentralPythonCompanion companion}) {
    return SequenceColumnWizard(columnNames, valueMap.map((k, v) => MapEntry(k, v as Sequence)), companion);
  }

  @override
  TypeDetector getTypeDetector() {
    return TypeDetector(Sequence, (value) => value is Sequence);
  }
}

class SequenceColumnWizard extends ColumnWizard with CounterStats {
  @override
  final Map<String, Sequence> valueMap;

  @override
  Type get type => Sequence;

  SequenceColumnWizard(super.columnNames, this.valueMap, super.companion);

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
    Map<int, Map<String, int>> posSeqDistribution,
  })? _distribution;

  Future<({
    Map<String, Map<String, double>> lenDistribution,
    Map<String, double> seqDistribution,
    Map<int, Map<String, int>> posSeqDistribution,
  })> distribution() async {
    if(_distribution != null) {
      return _distribution!;
    }

    final ({
    Map<String, Map<String, double>> lenDistribution,
    Map<String, double> seqDistribution,
    Map<int, Map<String, int>> posSeqDistribution,
  }) result = await compute(_calculateDistribution, valueMap.values.map((sequence) => sequence.toString()).toList());
    _distribution = result;
    return _distribution!;
}

Future<({
  Map<String, Map<String, double>> lenDistribution,
  Map<String, double> seqDistribution,
  Map<int, Map<String, int>> posSeqDistribution,
})> _calculateDistribution(List<String> sequences) async {
  const letters = [
    'A', 'C', 'D', 'E', 'F', 'G', 'H', 'I',
    'K', 'L', 'M', 'N', 'P', 'Q', 'R', 'S',
    'T', 'V', 'W', 'Y', 'X', 'U'
  ];

  // Initialize results
  final Map<String, Map<String, double>> lenDistribution = {};
  final Map<String, double> seqDistribution = {for (final l in letters) l: 0};
  final Map<int, Map<String, int>> posSeqDistribution = {};
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


  /*
  Future<Map<String, Map<String, double>>> lengthDistribution() async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final Map<String, Map<String, double>> convertedMap = {};
    final Either<BiocentralException, Map<String, dynamic>> response = await companion.lengthDistribution(valueMap.values.map((sequence) => sequence.toString()).toList());

    response.fold(
      (exception) {
        logger.e(exception);
      },
      (map) {
        convertedMap['length_stats'] = Map<String, double>.from(map['length_stats']);
        convertedMap['length_kde'] = Map<String, double>.from(map['length_kde']);
      },
    );
    stopwatch.stop();
    print('time elapsed: ${stopwatch.elapsed}');
    return convertedMap;
  }

  Future<Map<String, double>> sequenceDistribution() async {
    final Stopwatch stopwatch = Stopwatch()..start();
    Map<String, double> convertedMap = {};
    final Either<BiocentralException, Map<String, dynamic>> response = await companion.sequenceDistribution(valueMap.values.map((sequence) => sequence.toString()).toList());

    response.fold(
      (exception) {
        logger.e(exception);
      },
      (map) {
        convertedMap = Map<String, double>.from(map);
      },
    );
    stopwatch.stop();
    print('time elapsed: ${stopwatch.elapsed}');
    return convertedMap;
  }

  Future<Map<int, Map<String, int>>> positionalSequenceDistribution() async {
    final Stopwatch stopwatch = Stopwatch()..start();
    Map<int, Map<String, int>> convertedMap = {};
    final Either<BiocentralException, Map<int, dynamic>> response = await companion.positionalSequenceDistribution(valueMap.values.map((sequence) => sequence.toString()).toList());

    response.fold(
      (exception) {
        logger.e(exception);
      },
      (map) {
        Map<String, int> bufferMap = {};
        for (var key in map.keys) {
          bufferMap = Map<String, int>.from(map[key]);
          convertedMap[key] = bufferMap;
        }
      },
    );
    stopwatch.stop();
    print('time elapsed: ${stopwatch.elapsed}');
    return convertedMap;
  }*/
}
