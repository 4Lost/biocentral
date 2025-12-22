import 'dart:convert';
import 'package:flutter/services.dart';

class BiocentralBackgroundData {
  static final String _backgroundPath = 'assets/background_dist/distribution_AA.json';

  static Future<List<double>> getAALengthDistribution() async {
    final raw = await rootBundle.loadString(_backgroundPath);
    final Map<String, double> jsonData = Map<String, double>.from((json.decode(raw) as Map<String, dynamic>)['length_kde']);

    final List<double> dist = [];

    for (MapEntry<String, double> entry in jsonData.entries) {
      for (int i = 0; i < entry.value; i++) {
        dist.add(double.parse(entry.key));
      }
    }
    
    return dist;
  }

  static Future<Map<String, double>> getAALengthStats() async {
    final raw = await rootBundle.loadString(_backgroundPath);

    final Map<String, dynamic> dist = (json.decode(raw) as Map<String, dynamic>)['length_stats'];
    final Map<String, double> stats = Map<String, double>.from(dist);

    return stats;
  }

  static Future<Map<String, double>> getAASequenceDistribution() async {
    final raw = await rootBundle.loadString(_backgroundPath);
    final Map<String, dynamic> jsonData = json.decode(raw);

    final Map<String, double> parsed = {};
    final Map<String, dynamic> dist = jsonData['distribution'];

    final double total = dist.values.fold(0.0, (a, b) => a + (b as num).toDouble());

    dist.forEach((aa, count) {
      parsed[aa] = ((count as num).toDouble() / total) * 100;
    });

    return parsed;
  }

  static Future<Map<int, Map<String, double>>> getAAPositionalSequenceDistribution(Iterable<int> keys) async {
  final raw = await rootBundle.loadString(_backgroundPath);
  final Map<String, dynamic> jsonData = json.decode(raw);

  final Map<int, Map<String, double>> parsed = {};
  final Map<String, dynamic> positional = jsonData['positional_distribution'];

  positional.forEach((posStr, aaCounts) {
    final pos = int.parse(posStr);
    if (keys.contains(pos)) {
      final Map<String, num> counts = Map<String, num>.from(aaCounts);

      final double totalAtPosition =
          counts.values.fold(0.0, (a, b) => a + b.toDouble());

      final dist = counts.map(
        (aa, c) => MapEntry(aa, (c.toDouble() / totalAtPosition) * 100),
      );

      parsed[pos] = dist;
    }
  });

  return parsed;
  }
}
