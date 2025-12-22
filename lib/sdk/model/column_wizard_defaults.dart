
import 'package:biocentral/sdk/data/biocentral_python_companion.dart';
import 'package:ml_linalg/vector.dart';

import 'package:biocentral/sdk/model/column_wizard_abstract.dart';
import 'package:biocentral/sdk/model/column_wizard_operations.dart';

abstract class NumColumnWizard extends ColumnWizard {
  NumColumnWizard(super.columnName, super.companion);

  @override
  Set<ColumnOperationType> getAvailableOperations() {
    return super.getAvailableOperations()..addAll([ColumnOperationType.removeOutliers, ColumnOperationType.clamp]);
  }
}

class IntColumnWizardFactory extends ColumnWizardFactory {
  @override
  ColumnWizard create({required List<String> columnNames, required Map<String, dynamic> valueMap, required BiocentralPythonCompanion companion}) {
    if (columnNames.length < 2 || columnNames[1] == '') {
      return IntNormalColumnWizard(columnNames, valueMap.map((k, v) => MapEntry(k, v is int ? v : int.parse(v.toString())),), companion,);
    }
    return IntCompareColumnWizard(columnNames, valueMap.map((key, val) => MapEntry(key, (val as Map<String, dynamic>).map((k, v) => MapEntry(k, v is int ? v : int.parse(v.toString()))))), companion);
  }

  @override
  TypeDetector getTypeDetector() {
    return TypeDetector(int, (value) => value is int
        || value is! Map<String, dynamic> && int.tryParse(value) != null
        || value is Map<String, dynamic> && value.values.every((v) => v is int || int.tryParse(v) != null)
      );
  }
}

abstract class IntColumnWizard extends NumColumnWizard {
  IntColumnWizard(super.columnNames, super.companion);
}

class IntNormalColumnWizard extends IntColumnWizard with NumericStats, CounterStats {
  @override
  final Map<String, int> valueMap;

  IntNormalColumnWizard(super.columnNames, this.valueMap, super.companion);

  @override
  Vector get numericValues => Vector.fromList(valueMap.values.map((e) => e.toDouble()).toList());
}

class IntCompareColumnWizard extends IntColumnWizard with NumericCompareStats, CounterCompareStats {
  @override
  final Map<String, Map<String, int>> valueMap;

  IntCompareColumnWizard(super.columnNames, this.valueMap, super.companion);

  @override
  bool get compare => true;

  @override
  Iterable<String> getKeys() => valueMap.keys;

  @override
  Vector numericValues(String columnName) {
    return Vector.fromList(valueMap[columnName]!.values.map((e) => e.toDouble()).toList());
  }
}

class DoubleColumnWizardFactory extends ColumnWizardFactory {
  @override
  ColumnWizard create({required List<String> columnNames, required Map<String, dynamic> valueMap, required BiocentralPythonCompanion companion}) {
    if (columnNames.length < 2 || columnNames[1] == '') {
      return DoubleNormalColumnWizard(columnNames, valueMap.map((k, v) => MapEntry(k, v is double ? v : double.parse(v.toString())),), companion,);
    }
    return DoubleCompareColumnWizard(columnNames, valueMap.map((key, val) => MapEntry(key, (val as Map<String, dynamic>).map((k, v) => MapEntry(k, v is double ? v : double.parse(v.toString()))))), companion);
  }

  @override
  TypeDetector getTypeDetector() {
    return TypeDetector(double, (value) => value is double
        || value is! Map<String, dynamic> && double.tryParse(value) != null
        || value is Map<String, dynamic> && value.values.every((v) => v is double || double.tryParse(v) != null)
      );
  }
}

abstract class DoubleColumnWizard extends NumColumnWizard {
  DoubleColumnWizard(super.columnName, super.companion);
}

class DoubleNormalColumnWizard extends DoubleColumnWizard with NumericStats, CounterStats {
  @override
  final Map<String, double> valueMap;

  DoubleNormalColumnWizard(super.columnName, this.valueMap, super.companion);

  @override
  Vector get numericValues => Vector.fromList(valueMap.values.toList());
}

class DoubleCompareColumnWizard extends DoubleColumnWizard with NumericCompareStats, CounterCompareStats {
  @override
  final Map<String, Map<String, double>> valueMap;

  DoubleCompareColumnWizard(super.columnName, this.valueMap, super.companion);

  @override
  bool get compare => true;

  @override
  Vector numericValues(String columnName) {
    return Vector.fromList(valueMap[columnName]!.values.map((e) => e.toDouble()).toList());
  }
  
  @override
  Iterable<String> getKeys() => valueMap.keys;
}

class StringColumnWizardFactory extends ColumnWizardFactory {
  @override
  ColumnWizard create({required List<String> columnNames, required Map<String, dynamic> valueMap, required BiocentralPythonCompanion companion}) {
    if (columnNames.length < 2 || columnNames[1] == '') {
      return StringNormalColumnWizard(columnNames, valueMap.map((k, v) => MapEntry(k, v.toString())), companion,);
    }
    return StringCompareColumnWizard(columnNames, valueMap.map((key, val) => MapEntry(key, (val as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString())))), companion);
  }

  @override
  TypeDetector getTypeDetector() {
    // Every value can be transformed to a string, so detection is always true
    return TypeDetector(String, (value) => true);
  }
}

abstract class StringColumnWizard extends ColumnWizard {
  StringColumnWizard(super.columnName, super.companion);

  @override
  Set<ColumnOperationType> getAvailableOperations() {
    return super.getAvailableOperations()..add(ColumnOperationType.shuffle);
  }

  @override
  Future<bool> handleAsDiscrete() async {
    return true;
  }
}

class StringNormalColumnWizard extends StringColumnWizard with CounterStats {
  @override
  final Map<String, String> valueMap;

  StringNormalColumnWizard(super.columnName, this.valueMap, super.companion);
}

class StringCompareColumnWizard extends StringColumnWizard with CounterCompareStats {
  @override
  final Map<String, Map<String, String>> valueMap;

  StringCompareColumnWizard(super.columnName, this.valueMap, super.companion);

  @override
  bool get compare => true;
  
  @override
  Iterable<String> getKeys() => valueMap.keys;
}
