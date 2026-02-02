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
    final params = content.split(',');
  
    final Map<String, double> values = {};
    String surpriseClass = '';
  
    for (final param in params) {
      final parts = param.split(':');
      if (parts.length < 2) continue;
      
      final key = parts[0];
      final value = parts[1].replaceAll('{', '').replaceAll('}', '');
      
      if (key == 'class') {
        surpriseClass = value;
      } else {
        values[key] = double.parse(value);
      }
    }

    return SurpriseMetric(values['length']!, values['alphaHelix']!, values['betaSheet']!, values['coil']!, values['freeEnergy']!, values['hydrophobicity']!, values['mutability']!, values['stability']!, values['volume']!, sequenceId, values['factor']!, surpriseClass);
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
    return valueMap[sequenceId] ?? SurpriseMetric(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, sequenceId, 0.0, 'notFound');
  }
}

class SurpriseMetric {
  final double length;
  final double alphaHelix;
  final double betaSheet;
  final double coil;
  final double freeEnergy;
  final double hydrophobicity;
  final double mutability;
  final double stability;
  final double volume;

  final String sequenceId;
  final double factor;
  final String surpriseClass;

  SurpriseMetric(this.length, this.alphaHelix, this.betaSheet, this.coil, this.freeEnergy, this.hydrophobicity, this.mutability, this.stability, this.volume, this.sequenceId, this.factor, this.surpriseClass);
}