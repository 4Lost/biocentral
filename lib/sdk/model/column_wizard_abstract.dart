import 'dart:math';

import 'package:biocentral/sdk/data/biocentral_python_companion.dart';
import 'package:biocentral/sdk/model/column_wizard_operations.dart';
import 'package:biocentral/sdk/presentation/plots/biocentral_bar_compare_plot.dart';
import 'package:biocentral/sdk/presentation/plots/biocentral_bar_plot.dart';
import 'package:biocentral/sdk/util/biocentral_exception.dart';
import 'package:biocentral/sdk/util/constants.dart';
import 'package:biocentral/sdk/util/logging.dart';
import 'package:collection/collection.dart';
import 'package:fpdart/fpdart.dart';

import 'package:ml_linalg/vector.dart';

abstract class ColumnWizardFactory<T extends ColumnWizard> {
  T create(
      {required List<String> columnNames,
      required Map<String, dynamic> valueMap,
      required BiocentralPythonCompanion companion});

  TypeDetector getTypeDetector();
}

final class TypeDetector {
  final Type type;
  final bool Function(dynamic value) detectionFunction;
  final double priority;

  TypeDetector(this.type, this.detectionFunction) : priority = _calculatePriority(type);

  static double _calculatePriority(Type type) {
    if (type == int) return 0.9;
    if (type == double) return 0.8;
    if (type == num) return 0.7;
    if (type == String) return 0.1;
    return 1; // Priority for custom types should always be the highest
  }
}

abstract class ColumnWizard {
  final List<String> columnNames;
  final BiocentralPythonCompanion companion;

  Map<String, dynamic> get valueMap;

  ColumnWizard(this.columnNames, this.companion);

  Type get type => valueMap.values.firstOrNull.runtimeType;

  bool get compare => false;

  int? _length;

  Future<int> length() async {
    return _length ??= valueMap.keys.length;
  }

  bool _valueIsInvalid(dynamic value) {
    return value == null || value.toString().isEmpty || double.tryParse(value.toString())?.isNaN == true;
  }

  List<int>? _missingIndices;

  Future<List<int>> getMissingIndices() async {
    if (_missingIndices != null) {
      return _missingIndices!;
    }
    final List<int> missingIndices = [];
    for ((int, dynamic) indexValue in valueMap.values.indexed) {
      final int index = indexValue.$1;
      final dynamic value = indexValue.$2;

      if (_valueIsInvalid(value)) {
        missingIndices.add(index);
      }
    }
    _missingIndices = missingIndices;
    return _missingIndices!;
  }

  Future<int> numberMissing() async {
    return (await getMissingIndices()).length;
  }

  Map<String, int>? _counts;

  Future<Map<String, int>> getCounts() async {
    if (_counts != null) {
      return _counts!;
    }

    final Map<String, int> counts = {};
    for (dynamic value in valueMap.values) {
      if (_valueIsInvalid(value)) {
        continue;
      }
      final String valueString = value.toString();
      counts.putIfAbsent(valueString, () => 0);

      counts[valueString] = counts[valueString]! + 1;
    }
    _counts = counts;
    return _counts!;
  }

  Future<bool> handleAsDiscrete() async {
    final Map<String, int> counts = await getCounts();
    return counts.keys.length <= Constants.discreteColumnThreshold;
  }

  Set<ColumnOperationType> getAvailableOperations() {
    return {ColumnOperationType.toBinary, ColumnOperationType.removeMissing, ColumnOperationType.calculateLength};//, ColumnOperationType.calculateSupriseFactor
  }

  Future<Map<String, int>> _getBarPlotDataPoints() async {
    if (await handleAsDiscrete()) {
      final Map<String, int> counts = await getCounts();
      return counts;
    } else {
      // TODO BINS
      return {};
    }
  }

  Future<BiocentralBarPlotData> getBarPlotData() async {
    final Map<String, int> dataPoints = await _getBarPlotDataPoints();
    return BiocentralBarPlotData.withoutErrors(dataPoints.map((k, v) => MapEntry(k, v.toDouble())));
  }
}

mixin NumericStats on ColumnWizard {
  Vector get numericValues;

  Future<double> max() async {
    return numericValues.max();
  }

  Future<double> min() async {
    return numericValues.min();
  }

  Future<double> mean() async {
    return numericValues.mean();
  }

  Future<double> median() async {
    return numericValues.median();
  }

  double? _mode;

  Future<double> mode() async {
    if (_mode == null) {
      final Map<double, int> frequencyMap = {};
      for (final value in numericValues) {
        frequencyMap[value] = (frequencyMap[value] ?? 0) + 1;
      }
      int maxFrequency = 0;
      double modeValue = 0;
      frequencyMap.forEach((key, value) {
        if (value > maxFrequency) {
          maxFrequency = value;
          modeValue = key;
        }
      });
      _mode = modeValue;
    }
    return _mode!;
  }

  double? _variance;

  Future<double> variance() async {
    if (_variance == null) {
      final double mean = await this.mean();
      _variance = numericValues.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / (numericValues.length - 1);
    }
    return _variance!;
  }

  double? _stdDev;

  Future<double> stdDev() async {
    if (_stdDev == null) {
      final double variance = await this.variance();
      _stdDev = sqrt(variance);
    }
    return _stdDev!;
  }

  Future<List<int>> detectOutliers({double? lowerBound, double? upperBound}) async {
    (double, double) bounds = await calculateStandardBounds();
    lowerBound ??= bounds.$1;
    upperBound ??= bounds.$2;

    final List<int> outlierIndices = [];
    for ((int, num) indexValue in numericValues.indexed) {
      if (indexValue.$2 < lowerBound || indexValue.$2 > upperBound) {
        outlierIndices.add(indexValue.$1);
      }
    }
    return outlierIndices;
  }

  Future<(double, double)> calculateStandardBounds() async {
    final double mu = await mean();
    final double sigma = await stdDev();
    return (mu - 3 * sigma, mu + 3 * sigma);
  }

  Future<List<List<double>>> toBins({int numberBins = 10}) async {
    final double max = await this.max();
    final double min = await this.min();

    double binSize = (max - min).abs() / numberBins;
    if (binSize == 0.0) {
      binSize = min;
    }
    final List<List<double>> result = List.generate(numberBins, (_) => []);

    for (double value in numericValues.sorted((a, b) => a.compareTo(b))) {
      int binIndex = ((value - min) / binSize).floor();
      if (binIndex == numberBins) {
        // Handle edge case where value is the maximum
        binIndex--;
      }
      result[binIndex].add(value);
    }
    return result;
  }

  List<Map<String, dynamic>>? _distResults;

  Future<List<Map<String, dynamic>>?> getDistributions() async {
    final List<String> types = [
      'normal',
      't',
      'lognorm',
      'chi2',
      'gamma',
      //'beta',
      //'weibull',
      //'exponental',
      //'uniform',
      //'bernoulli',
      //'binomial',
      //'geometric',
      //'poisson'
    ];
    final Either<BiocentralException, Map<String, dynamic>> response =
        await companion.testDistributions(numericValues.toList(), types);
    response.match(
      (exception) {
        logger.e(exception);
      },
      (data) {
        final results = <Map<String, dynamic>>[];
        for (final map in data['results']) {
          final convertedMap = Map<String, dynamic>.from(map);
          results.add(convertedMap);
        }
        _distResults = results;
      },
    );
    return _distResults;
  }
}

mixin NumericCompareStats on ColumnWizard {
  Vector numericValues(String columnName);
  Iterable<String> getKeys();

  Future<double> max(String columnName) async {
    return numericValues(columnName).max();
  }

  Future<double> min(String columnName) async {
    return numericValues(columnName).min();
  }

  Future<double> mean(String columnName) async {
    return numericValues(columnName).mean();
  }

  Future<double> median(String columnName) async {
    return numericValues(columnName).median();
  }

  Map<String, double>? _mode;

  Future<double> mode(String columnName) async {
    if (_mode != null) return _mode![columnName]!;

    _mode = {};

    for (final key in await getKeys()) {
      final Map<double, int> frequencyMap = {};
      for (final value in numericValues(key)) {
        frequencyMap[value] = (frequencyMap[value] ?? 0) + 1;
      }
      int maxFrequency = 0;
      double modeValue = 0;
      frequencyMap.forEach((key, value) {
        if (value > maxFrequency) {
          maxFrequency = value;
          modeValue = key;
        }
      });
      _mode![columnName] = modeValue;
    }

    return _mode![columnName]!;
  }

  Map<String, double>? _variance;

  Future<double> variance(String columnName) async {
    if (_variance != null) return _variance![columnName]!;

    _variance = {};

    for (final key in await getKeys()) {
      final double mean = await this.mean(key);
      _variance![columnName] = numericValues(key).map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / (numericValues(key).length - 1);
    }

    return _variance![columnName]!;
  }

  Map<String, double>? _stdDev;

  Future<double> stdDev(String columnName) async {
    if (_stdDev != null) return _stdDev![columnName]!;

    _stdDev = {};

    for (final key in getKeys()) {
      if (_stdDev == null) {
        final double variance = await this.variance(key);
        _stdDev![columnName] = sqrt(variance);
      }
    }

    return _stdDev![columnName]!;
  }

  Future<List<int>> detectOutliers(String columnName, {double? lowerBound, double? upperBound}) async {
    final (double, double) bounds = await calculateStandardBounds(columnName);
    lowerBound ??= bounds.$1;
    upperBound ??= bounds.$2;

    final List<int> outlierIndices = [];
    for ((int, num) indexValue in numericValues(columnName).indexed) {
      if (indexValue.$2 < lowerBound || indexValue.$2 > upperBound) {
        outlierIndices.add(indexValue.$1);
      }
    }
    return outlierIndices;
  }

  Future<(double, double)> calculateStandardBounds(String columnName) async {
    final double mu = await mean(columnName);
    final double sigma = await stdDev(columnName);
    return (mu - 3 * sigma, mu + 3 * sigma);
  }

  Future<List<List<double>>> toBins(String columnName, {int numberBins = 10}) async {
    final double max = await this.max(columnName);
    final double min = await this.min(columnName);

    double binSize = (max - min).abs() / numberBins;
    if (binSize == 0.0) {
      binSize = min;
    }
    final List<List<double>> result = List.generate(numberBins, (_) => []);

    for (double value in numericValues(columnName).sorted((a, b) => a.compareTo(b))) {
      int binIndex = ((value - min) / binSize).floor();
      if (binIndex == numberBins) {
        // Handle edge case where value is the maximum
        binIndex--;
      }
      result[binIndex].add(value);
    }
    return result;
  }

  Map<String, List<Map<String, dynamic>>>? _distResults;

  Future<List<List<Map<String, dynamic>>>?> getDistributions(String firstColumn, String secondColumn) async {
    if (_distResults != null || _distResults![firstColumn] != null || _distResults![secondColumn] != null) {
      return [_distResults![firstColumn]!, _distResults![secondColumn]!];
    }

    _distResults ??= {};
    final List<String> types = [
      'normal',
      't',
      'lognorm',
      'chi2',
      'gamma',
      //'beta',
      //'weibull',
      //'exponental',
      //'uniform',
      //'bernoulli',
      //'binomial',
      //'geometric',
      //'poisson'
    ];
    final List<Map<String, dynamic>> results = [];

    if (_distResults![firstColumn] == null) {
      final Either<BiocentralException, Map<String, dynamic>> response =
        await companion.testDistributions(numericValues(firstColumn).toList(), types);
      response.match(
        (exception) {
          logger.e(exception);
        },
        (data) {
          for (final map in data['results']) {
            final convertedMap = Map<String, dynamic>.from(map);
            results.add(convertedMap);
          }
          _distResults![firstColumn] = results;
        },
      );
    }

    if (_distResults![secondColumn] == null) {
      final Either<BiocentralException, Map<String, dynamic>> response =
        await companion.testDistributions(numericValues(secondColumn).toList(), types);
      response.match(
        (exception) {
          logger.e(exception);
        },
        (data) {
          for (final map in data['results']) {
            final convertedMap = Map<String, dynamic>.from(map);
            results.add(convertedMap);
          }
          _distResults![secondColumn] = results;
        },
      );
    }
    
    if (_distResults![firstColumn] == null || _distResults![secondColumn] == null) {
      return null;
    }
    return [_distResults![firstColumn]!, _distResults![secondColumn]!];
  }
}

mixin CounterStats on ColumnWizard {}
mixin CounterCompareStats on ColumnWizard {
  @override
  Map<String, Map<String, dynamic>> get valueMap;
  
  Iterable<String> getKeys();

  Map<String, Map<String, int>>? _countsByColumn;
  
  Future<Map<String, int>> getCountsOfKey(String columnName) async {
    if (_countsByColumn != null && _countsByColumn![columnName] != null) return _countsByColumn![columnName]!;
    _countsByColumn ??= await _getCounts();
    print('test: ${_countsByColumn![columnName]!}');

    return _countsByColumn![columnName]!;
  }
  
  Future<List<Map<String, int>>> getCountsOfKeys(String firstColumn, String secondColumn) async {
    if (_countsByColumn != null && _countsByColumn![firstColumn] != null && _countsByColumn![secondColumn] != null) {
      return [_countsByColumn![firstColumn]!, _countsByColumn![firstColumn]!];
    }
    if (_countsByColumn != null) _countsByColumn = await _getCounts();

    return [_countsByColumn![firstColumn]!, _countsByColumn![firstColumn]!];
  }
  
  Future<Map<String, Map<String, int>>> _getCounts() async {
    final Map<String, Map<String, int>> result = {};

    for (MapEntry<String, Map<String, dynamic>> entry in valueMap.entries) {
      final Map<String, int> counts = {};
      for (dynamic value in entry.value.values) {
        if (_valueIsInvalid(value)) continue;

        final String valueString = value.toString();

        counts[valueString] = (counts[valueString] ?? 0) + 1;
      }
       result[entry.key] = counts;
    }

    return result;
  }

  @override
  Future<Map<String, int>> getCounts() async {
    if (_counts != null) return _counts!;
    if (_countsByColumn != null) _countsByColumn = await _getCounts();

    _counts = {};

    for (MapEntry<String, Map<String, int>> entry in _countsByColumn!.entries) {
      if (entry.value.keys.length > _counts!.keys.length) _counts = entry.value;
    }

    return _counts!;
  }

  Map<String, int>? _lengthByColumn;

  Future<int> lengthOfKey(String key) async {
    if(_lengthByColumn != null) return _lengthByColumn![key] ?? 0;

    _lengthByColumn = {};

    for (MapEntry<String, Map<String, dynamic>> entry in valueMap.entries) {
      _lengthByColumn![entry.key] = entry.value.keys.length;
    }

    return _lengthByColumn![key] ?? 0;
  }

  Map<String, List<int>>? _missingIndicesByColumn;

  Future<Map<String, List<int>>> _getMissingIndices() async {
    if (_missingIndices != null) {
      return _missingIndicesByColumn!;
    }
    _missingIndicesByColumn = {};

    for (MapEntry<String, Map<String, dynamic>> entry in valueMap.entries) {
      final List<int> missingIndices = [];
      for ((int, dynamic) indexValue in entry.value.values.indexed) {
        final int index = indexValue.$1;
        final dynamic value = indexValue.$2;

        if (_valueIsInvalid(value)) {
          missingIndices.add(index);
        }
      }
      _missingIndicesByColumn![entry.key] = missingIndices;
    }
    return _missingIndicesByColumn!;
  }

  Future<int> numberMissingOfKey(String key) async {
    return (await _getMissingIndices())[key]!.length;
  }

  Future<BiocentralBarComparePlotData> getBarPlotsData(String firstColumn, String secondColumn) async {
    final List<Map<String, int>> dataPoints = await _getBarPlotsDataPoints(firstColumn, secondColumn);
    return BiocentralBarComparePlotData.withoutErrors([dataPoints[0].map((k, v) => MapEntry(k, v.toDouble())), dataPoints[1].map((k, v) => MapEntry(k, v.toDouble()))]);
  }

  final Map<String, Map<String, int>> _barPlotDataPoints = {};

  Future<List<Map<String, int>>> _getBarPlotsDataPoints(String firstColumn, String secondColumn) async {
    if (_barPlotDataPoints.containsKey(firstColumn) && _barPlotDataPoints.containsKey(secondColumn)) {
      return [_barPlotDataPoints[firstColumn]!, _barPlotDataPoints[secondColumn]!];
    }

    if (!_barPlotDataPoints.containsKey(firstColumn)) _barPlotDataPoints[firstColumn] = await getCountsOfKey(firstColumn);
    if (!_barPlotDataPoints.containsKey(secondColumn)) _barPlotDataPoints[secondColumn] = await getCountsOfKey(secondColumn);

    return [_barPlotDataPoints[firstColumn]!, _barPlotDataPoints[secondColumn]!];
  }
}

class ReOpenColumnWizardEffect {
  final List<String> columns;

  ReOpenColumnWizardEffect(this.columns);
}
