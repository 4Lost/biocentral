import 'dart:math';

import 'package:biocentral/plugins/proteins/model/sequence_column_wizard.dart';
import 'package:biocentral/sdk/model/column_wizard_abstract.dart';
import 'package:flutter/material.dart';

abstract class ColumnWizardOperation<T extends ColumnWizardOperationResult> {
  final List<String> newColumnNames;

  ColumnWizardOperation(this.newColumnNames);

  Future<T> operate(ColumnWizard columnWizard);
}

abstract class ColumnWizardOperationResult {}

class ColumnWizardAddOperationResult extends ColumnWizardOperationResult {
  final List<String> newColumnNames;
  final Map<String, dynamic> newColumnValues;

  ColumnWizardAddOperationResult(this.newColumnNames, this.newColumnValues);
}

class ColumnWizardRemoveOperationResult extends ColumnWizardOperationResult {
  final List<int> indicesToRemove;

  ColumnWizardRemoveOperationResult(this.indicesToRemove);
}

class ColumnWizardShuffleOperation extends ColumnWizardOperation<ColumnWizardAddOperationResult> {
  static const int defaultSeed = 42;

  final int seed;

  ColumnWizardShuffleOperation(super.newColumnNames, this.seed);

  @override
  Future<ColumnWizardAddOperationResult> operate(ColumnWizard columnWizard) async {
    final Map<String, String> result = {};
    for (final entry in columnWizard.valueMap.entries) {
      final List<String> shuffled = entry.value.toString().characters.toList()..shuffle(Random(seed));
      result[entry.key] = shuffled.join();
    }
    return ColumnWizardAddOperationResult(newColumnNames, result);
  }
}

class ColumnWizardToBinaryOperation extends ColumnWizardOperation<ColumnWizardAddOperationResult> {
  static const String defaultValueTrue = 'true';
  static const String defaultValueFalse = 'false';

  final String compareToValue;
  final String valueTrue;
  final String valueFalse;

  ColumnWizardToBinaryOperation(super.newColumnName, this.compareToValue, this.valueTrue, this.valueFalse);

  @override
  Future<ColumnWizardAddOperationResult> operate(ColumnWizard columnWizard) async {
    final Map<String, String> result = {};

    for (final entry in columnWizard.valueMap.entries) {
      result[entry.key] = entry.value.toString() == compareToValue ? valueTrue : valueFalse;
    }
    return ColumnWizardAddOperationResult(newColumnNames, result);
  }
}

class ColumnWizardRemoveMissingOperation extends ColumnWizardOperation<ColumnWizardRemoveOperationResult> {
  ColumnWizardRemoveMissingOperation(super.newColumnName);

  @override
  Future<ColumnWizardRemoveOperationResult> operate(ColumnWizard columnWizard) async {
    final List<int> missingIndices = await columnWizard.getMissingIndices();
    return ColumnWizardRemoveOperationResult(missingIndices);
  }
}

enum ColumnWizardOutlierRemovalMethod {
  byStandardDeviation,
}

class ColumnWizardRemoveOutliersOperation extends ColumnWizardOperation<ColumnWizardRemoveOperationResult> {
  final ColumnWizardOutlierRemovalMethod method;

  ColumnWizardRemoveOutliersOperation(super.newColumnName, this.method);

  @override
  Future<ColumnWizardRemoveOperationResult> operate(ColumnWizard columnWizard) async {
    switch (method) {
      case ColumnWizardOutlierRemovalMethod.byStandardDeviation:
        {
          // TODO Make this more generic
          if (columnWizard is NumericStats) {
            final mean = await columnWizard.mean();
            final stdDev = await columnWizard.stdDev();
            final lowerBound = mean - 2 * stdDev;
            final upperBound = mean + 2 * stdDev;
            final List<int> indicesToRemove = columnWizard.numericValues.indexed
                .where((element) => element.$2 < lowerBound || element.$2 > upperBound)
                .map((element) => element.$1)
                .toList();
            return ColumnWizardRemoveOperationResult(indicesToRemove);
          }
        }
    }
    return ColumnWizardRemoveOperationResult([]);
  }
}

class ColumnWizardClampOperation extends ColumnWizardOperation<ColumnWizardRemoveOperationResult> {
  final double? low;
  final double? high;

  ColumnWizardClampOperation(super.newColumnName, this.low, this.high);

  bool _isInRange(num value) {
    bool inRange = true;
    if (low != null) {
      inRange = value > low!;
    }
    if (high != null) {
      inRange = inRange && value < high!;
    }
    return inRange;
  }

  @override
  Future<ColumnWizardRemoveOperationResult> operate(ColumnWizard columnWizard) async {
    if (columnWizard is NumericStats) {
      final List<int> indicesToRemove = columnWizard.numericValues.indexed
          .where((element) => !_isInRange(element.$2))
          .map((element) => element.$1)
          .toList();
      return ColumnWizardRemoveOperationResult(indicesToRemove);
    }
    return ColumnWizardRemoveOperationResult([]);
  }
}

class ColumnWizardCalculateLengthOperation extends ColumnWizardOperation<ColumnWizardAddOperationResult> {
  ColumnWizardCalculateLengthOperation(super.newColumnName);

  @override
  Future<ColumnWizardAddOperationResult> operate(ColumnWizard columnWizard) async {
    final Map<String, int> result = Map.fromEntries(
        columnWizard.valueMap.entries.map((entry) => MapEntry(entry.key, entry.value.toString().length)));

    return ColumnWizardAddOperationResult(newColumnNames, result);
  }
}

class ColumnWizardcalculateSupriseFactorOperation extends ColumnWizardOperation<ColumnWizardAddOperationResult> {
  ColumnWizardcalculateSupriseFactorOperation(super.newColumnName);

  @override
  Future<ColumnWizardAddOperationResult> operate(ColumnWizard columnWizard) async {
    if (columnWizard is! SequenceNormalColumnWizard) return ColumnWizardAddOperationResult(newColumnNames, columnWizard.valueMap);

    final SequenceStats data = (columnWizard).getSequenceStats();
    final Map<String, double> means = data.means;
    final Map<String, double> stdDevs = data.stdDevs;
    
    final Map<String, String> surpriseFactor = {};
    for (SequenceValues values in data.values) {
      final double length = (means['length']! - values.length).abs() / stdDevs['length']!;
      final double hydrophobicity = (means['hydrophobicity']! - values.hydrophobicity).abs() / stdDevs['hydrophobicity']!;
      final double stability = (means['stability']! - values.stability).abs() / stdDevs['stability']!;
      final double freeEnergy = (means['freeEnergy']! - values.freeEnergy).abs() / stdDevs['freeEnergy']!;
      final double volume = (means['volume']! - values.volume).abs() / stdDevs['volume']!;
      final double alphaHelix = (means['alphaHelix']! - values.alphaHelix).abs() / stdDevs['alphaHelix']!;
      final double betaSheet = (means['betaSheet']! - values.betaSheet).abs() / stdDevs['betaSheet']!;
      final double coil = (means['coil']! - values.coil).abs() / stdDevs['coil']!;
      final double mutability = (means['mutability']! - values.mutability).abs() / stdDevs['mutability']!;

      final double factor = (length
        + hydrophobicity
        + stability
        + freeEnergy
        + volume
        + alphaHelix
        + betaSheet
        + coil
        + mutability) / 9;
      
      final String surpriseClass = factor >= 5.0 ? 'extremly surprising' :
          factor >= 4 ? 'highly surprising' :
          factor >= 3 ? 'surprising' :
          factor >= 2.5 ? 'slightly surprising' : 'ordinary';

        surpriseFactor[values.sequence] = 'SurpriseMetric(class:${surpriseClass},factor:${factor},length:${length},hydrophobicity:${hydrophobicity},stability:${stability},freeEnergy:${freeEnergy},volume:${volume},alphaHelix:${alphaHelix},betaSheet:${betaSheet},coil:${coil},mutability:${mutability})';
    }

    return ColumnWizardAddOperationResult(newColumnNames, surpriseFactor);
  }
}

// TODO Replace enum with types to allow extensibility of operations in plugins
enum ColumnOperationType { toBinary, removeMissing, removeOutliers, calculateLength, calculateSupriseFactor, shuffle, clamp }
