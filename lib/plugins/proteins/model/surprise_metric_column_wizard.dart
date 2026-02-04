import 'package:biocentral/sdk/biocentral_sdk.dart';
import 'package:biocentral/sdk/data/biocentral_python_companion.dart';

class SurpriseMetricColumnWizardFactory extends ColumnWizardFactory {
  @override
  ColumnWizard create({required List<String> columnNames, required Map<String, dynamic> valueMap, required BiocentralPythonCompanion companion}) {
    return SurpriseMetricColumnWizard(columnNames, valueMap.map((k, v) => MapEntry(k, toSurprisMetric(v, k))), companion);
  }

  @override
  TypeDetector getTypeDetector() {
    final String prefix = 'SurpriseMetric(class:';
    return TypeDetector(SurpriseMetric, (value) => value.startsWith(prefix));
  }

  SurpriseMetric toSurprisMetric(String obj, String sequenceId) {
    final content = obj.substring(15, obj.length - 1);
    final entries = content.split(',');
  
    final Map<String, double> factors = {};
    final Map<String, double> values = {};
    String surpriseClass = '';
    double factor = 0;
  
    for (final entry in entries) {
      final parts = entry.split(':');
      if (parts.length < 2) continue;
      
      final key = parts[0];
      final value = parts[1];
      
      if (key == 'class') {
        surpriseClass = value;
      } else if (key == 'factor') {
        factor = double.parse(value);
      } else {
        final splits = value.split('|');
        factors[key] = double.parse(splits[0]);
        values[key] = double.parse(splits[1]);
      }
    }
    if (surpriseClass == 'extremly surprising' || surpriseClass == 'highly surprising') {
      print(obj);
    }

    return SurpriseMetric(sequenceId, factor, surpriseClass,
      values['length']!, factors['length']!,
      values['alphaHelix']!, factors['alphaHelix']!,
      values['betaSheet']!, factors['betaSheet']!,
      values['coil']!, factors['coil']!,
      values['freeEnergy']!, factors['freeEnergy']!,
      values['hydrophobicity']!, factors['hydrophobicity']!,
      values['mutability']!, factors['mutability']!,
      values['stability']!, factors['stability']!,
      values['volume']!, factors['volume']!,);
  }
}


class SurpriseMetricColumnWizard extends ColumnWizard {
  @override
  final Map<String, SurpriseMetric> valueMap;

  SurpriseMetricColumnWizard(super.columnNames, this.valueMap, super.companion);

  List<String> getFilterKeys() => valueMap.values
        .map((m) => m.surpriseClass)
        .toSet()
        .toList();

  List<String> getSequencesWithFilter(String filter) => valueMap.values
        .where((m) => filter == '' || m.surpriseClass == filter)
        .map((m) => m.sequenceId)
        .toList();

  int getAmount(String className) => valueMap.values.where((m) => m.surpriseClass == className).length;

  SurpriseMetric getForSequence(String sequenceId) {
    return valueMap[sequenceId] ?? SurpriseMetric(sequenceId, 0.0, 'notFound', 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
  }
}

class SurpriseMetric {
  final String sequenceId;
  final double factor;
  final String surpriseClass;

  final double length;
  final double alphaHelix;
  final double betaSheet;
  final double coil;
  final double freeEnergy;
  final double hydrophobicity;
  final double mutability;
  final double stability;
  final double volume;

  final double lengthFactor;
  final double alphaHelixFactor;
  final double betaSheetFactor;
  final double coilFactor;
  final double freeEnergyFactor;
  final double hydrophobicityFactor;
  final double mutabilityFactor;
  final double stabilityFactor;
  final double volumeFactor;

  SurpriseMetric(this.sequenceId, this.factor, this.surpriseClass,
    this.length, this.lengthFactor,
    this.alphaHelix, this.alphaHelixFactor,
    this.betaSheet, this.betaSheetFactor,
    this.coil, this.coilFactor,
    this.freeEnergy, this.freeEnergyFactor,
    this.hydrophobicity, this.hydrophobicityFactor,
    this.mutability, this.mutabilityFactor,
    this.stability, this.stabilityFactor,
    this.volume, this.volumeFactor);
}