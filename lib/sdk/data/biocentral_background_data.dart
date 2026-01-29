import 'dart:convert';
import 'package:biocentral/plugins/proteins/model/sequence_column_wizard.dart';
import 'package:biocentral/sdk/util/point.dart';
import 'package:flutter/services.dart';

class BiocentralBackgroundData {
  static final String _backgroundAAPath = 'assets/background_dist/distribution_AA.json';

  static Future<List<Point>> getAALengthDistribution() async {
    final jsonData = await rootBundle.loadString(_backgroundAAPath);
    final List<dynamic> data = (json.decode(jsonData) as Map<String, dynamic>)['lengthKde'];

    final List<Point> points = [];

    for (var pointData in data) {
      points.add(Point((pointData[0] as num).toDouble(), (pointData[1] as num).toDouble()));
    }
    points.sort((a, b) => a.x.compareTo(b.x));

    return points;
  }

  static Future<Map<String, double>> getAALengthStats() async {
    final jsonData = await rootBundle.loadString(_backgroundAAPath);
    final Map<String, dynamic> rawData = (json.decode(jsonData) as Map<String, dynamic>)['lengthStats'];
    
    return Map<String, double>.from(rawData);
  }

  static Future<Map<String, double>> getAASequenceDistribution() async {
    final jsonData = await rootBundle.loadString(_backgroundAAPath);
    final Map<String, dynamic> data = (json.decode(jsonData) as Map<String, dynamic>)['distribution'];

    final double total = data.values.fold(0.0, (a, b) => a + (b as num).toDouble());
    final Map<String, double> parsed = {};

    data.forEach((aa, count) {
      parsed[aa] = ((count as num).toDouble() / total) * 100;
    });

    return parsed;
  }

  static Future<Map<int, Map<String, double>>> getAAPositionalSequenceDistribution(Iterable<int> keys) async {
    final jsonData = await rootBundle.loadString(_backgroundAAPath);
    final Map<String, dynamic> data = (json.decode(jsonData) as Map<String, dynamic>)['positionalDistribution'];

    final Map<int, Map<String, double>> parsed = {};

    data.forEach((posStr, aaCounts) {
      final pos = int.parse(posStr);
      if (keys.contains(pos)) {
        final Map<String, num> counts = Map<String, num>.from(aaCounts);
        final double totalAtPosition = counts.values.fold(0.0, (a, b) => a + b.toDouble());
        final dist = counts.map(
          (aa, c) => MapEntry(aa, (c.toDouble() / totalAtPosition) * 100),
        );
        parsed[pos] = dist;
      }
    });

    return parsed;
  }

  static Future<PointScaleStats> getScale(String feature) async {
    final String scalePath = 'assets/background_dist/distribution_scales_$feature.json';
    final jsonData = await rootBundle.loadString(scalePath);
    final Map<String, dynamic> data = json.decode(jsonData) as Map<String, dynamic>;

    final List<dynamic> dataValues = data['values'] as List<dynamic>;
    final List<Point> points = [];

    for (var pointData in dataValues) {
      points.add(Point((pointData[0] as num).toDouble(), (pointData[1] as num).toDouble()));
    }
    points.sort((a, b) => a.x.compareTo(b.x));

    final Map<String, dynamic> stats = Map<String, dynamic>.from(data['stats']);
    final double mean = stats['mean'] as double;
    final double min = stats['min'] as double;
    final double max = stats['max'] as double;
    final double stdDev = stats['stdDev'] as double;

    return PointScaleStats(min, max, mean, stdDev, points);
  }
}
