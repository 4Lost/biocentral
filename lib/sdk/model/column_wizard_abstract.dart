import 'dart:math';

import 'package:biocentral/sdk/data/biocentral_python_companion.dart';
import 'package:biocentral/sdk/presentation/plots/biocentral_bar_plot.dart';
import 'package:biocentral/sdk/util/biocentral_exception.dart';
import 'package:collection/collection.dart';
import 'package:biocentral/sdk/util/logging.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ml_linalg/vector.dart';

import 'package:biocentral/sdk/util/constants.dart';
import 'package:biocentral/sdk/model/column_wizard_operations.dart';

abstract class ColumnWizardFactory<T extends ColumnWizard> {
  T create({required String columnName, required Map<String, dynamic> valueMap, required BiocentralPythonCompanion companion});

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
  final String columnName;
  final BiocentralPythonCompanion companion;

  Map<String, dynamic> get valueMap;

  ColumnWizard(this.columnName, this.companion);

  Type get type => valueMap.values.firstOrNull.runtimeType;

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
    return {ColumnOperationType.toBinary, ColumnOperationType.removeMissing, ColumnOperationType.calculateLength};
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

  List<Map<String, dynamic>>? distResults;
  bool testRunning = false;

  Future<double> testDistributionTEST (String type) async {
    testRunning = true;
    final String typesAll = 'normal|t|lognorm|chi2|gamma|beta|weibull|exponental|uniform|bernoulli|binomial|geometric|poisson';
    final String types = 'normal';
    final Either<BiocentralException,List<dynamic>> response = await companion.testDistributions(numericValues.toList(), types);
    response.match(
      (exception) {
        logger.e(exception);
        print('error -----------------------------');
      },
      (data) {
        print(data);
        distResults = data.cast<Map<String, dynamic>>();
      },
    );
    return distResults != null ? distResults![0]['p_value'] : 0.0;
  }

  Future<bool> getDistributions() async {
    testRunning = true;
    final String typesAll = 'normal|t|lognorm|chi2|gamma|beta|weibull|exponental|uniform|bernoulli|binomial|geometric|poisson';
    final String types = 'normal';
    final Either<BiocentralException,List<dynamic>> response = await companion.testDistributions(numericValues.toList(), types);
    response.match(
      (exception) {
        logger.e(exception);
        print('error -----------------------------');
      },
      (data) {
        print(data);
        distResults = data.cast<Map<String, dynamic>>();
      },
    );
    testRunning = false;
    return distResults == null ? false: true;
  }

  Future<double> testDistribution(String type) async {
    print('test');
    while (testRunning) {
      await Future.delayed(const Duration(milliseconds: 250));
    }
    if (distResults == null) {
      if (await getDistributions() == false) {
        return -0.0;
      }
      
    }
    switch(type) {
      case 'normal':
        print(distResults);
        return distResults != null ? distResults![0]['p_value'] : 0.0;
      case 't':
        return distResults != null ? distResults![1]['p_value'] : 0.0;
      case 'lognorm':
        return distResults != null ? distResults![2]['p_value'] : 0.0;
      case 'chi2':
        return distResults != null ? distResults![3]['p_value'] : 0.0;
      case 'gamma':
        return distResults != null ? distResults![4]['p_value'] : 0.0;
      case 'beta':
        return distResults != null ? distResults![5]['p_value'] : 0.0;
      case 'weibull':
        return distResults != null ? distResults![6]['p_value'] : 0.0;
      case 'exponental':
        return distResults != null ? distResults![7]['p_value'] : 0.0;
      case 'uniform':
        return distResults != null ? distResults![8]['p_value'] : 0.0;
      case 'bernoulli':
        return distResults != null ? distResults![9]['p_value'] : 0.0;
      case 'binomial':
        return distResults != null ? distResults![10]['p_value'] : 0.0;
      case 'geometric':
        return distResults != null ? distResults![11]['p_value'] : 0.0;
      case 'poisson':
        return distResults != null ? distResults![12]['p_value'] : 0.0;
      default:
        return 0.0;
    }
  }

  Future<Map<String, dynamic>> getMostLikelyResult() async {
    if (distResults == null) {
      final String types = 'normal|t|lognorm|chi2|gamma|beta|weibull|exponental|uniform|bernoulli|binomial|geometric|poisson';
      final Either<BiocentralException,List<dynamic>> response = await companion.testDistributions(numericValues.toList(), types);
      response.match(
        (exception) {
          logger.e(exception);
        },
        (data) {
          print(data);
          distResults = data.cast<Map<String, dynamic>>();
        },
      );
    }
    int mostLikely = 0;
    double pValue = 0.0;
    for (int i = 0; i < 12; i++) {
      if (distResults?[i]['p_value'] > pValue) {
        mostLikely = i;
        pValue = distResults != null ? distResults![i]['p_value'] : 0.0;
      }
    }
    return distResults![mostLikely];
  }
}

mixin CounterStats on ColumnWizard {}

class ReOpenColumnWizardEffect {
  final String column;

  ReOpenColumnWizardEffect(this.column);
}