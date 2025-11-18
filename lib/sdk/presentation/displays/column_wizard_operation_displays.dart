import 'package:biocentral/sdk/biocentral_sdk.dart';
import 'package:flutter/material.dart';

class ColumnWizardOperationDisplayFactory {
  static Widget fromSelected({
    required ColumnOperationType columnOperationType,
    required List<String> selectedColumnNames,
    required void Function(ColumnWizardOperation) onCalculateCallback,
  }) {
    switch (columnOperationType) {
      case ColumnOperationType.toBinary:
        return ColumnWizardToBinaryOperationDisplay(
          selectedColumnNames: selectedColumnNames,
          onCalculateCallback: onCalculateCallback,
        );
      case ColumnOperationType.removeMissing:
        return ColumnWizardRemoveMissingOperationDisplay(
          selectedColumnNames: selectedColumnNames,
          onCalculateCallback: onCalculateCallback,
        );
      case ColumnOperationType.removeOutliers:
        return ColumnWizardRemoveOutliersOperationDisplay(
            selectedColumnNames: selectedColumnNames, onCalculateCallback: onCalculateCallback);
      case ColumnOperationType.clamp:
        return ColumnWizardClampOperationDisplay(
            selectedColumnNames: selectedColumnNames, onCalculateCallback: onCalculateCallback);
      case ColumnOperationType.calculateLength:
        return ColumnWizardCalculateLengthOperationDisplay(
            selectedColumnNames: selectedColumnNames, onCalculateCallback: onCalculateCallback);
      case ColumnOperationType.shuffle:
        return ColumnWizardShuffleOperationDisplay(
          selectedColumnNames: selectedColumnNames,
          onCalculateCallback: onCalculateCallback,
        );
    }
  }
}

abstract class ColumnWizardOperationDisplay<T extends ColumnWizardOperationResult> extends StatefulWidget {
  final List<String> selectedColumnNames;
  final void Function(ColumnWizardOperation) onCalculateCallback;

  const ColumnWizardOperationDisplay({required this.selectedColumnNames, required this.onCalculateCallback, super.key});
}

abstract class ColumnWizardOperationDisplayState<T extends ColumnWizardOperationResult>
    extends State<ColumnWizardOperationDisplay> {
  List<String> newColumnNames = [''];

  @override
  void initState() {
    super.initState();
    if (defaultColumnName().isNotEmpty) {
      newColumnNames = ['${widget.selectedColumnNames}-${defaultColumnName()}'];
    }
  }

  bool showNewColumnName() {
    return T == ColumnWizardAddOperationResult;
  }

  String defaultColumnName();

  ColumnWizardOperation? collect();

  void collectAndInvokeCallback() {
    final ColumnWizardOperation? operation = collect();
    if (operation != null) {
      widget.onCalculateCallback(operation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: buildParameterSelections(),
        ),
        buildNewColumnNameSelection(),
        buildCalculateButton(),
      ],
    );
  }

  Widget buildNewColumnNameSelection() {
    return Visibility(
      visible: showNewColumnName(),
      child: Flexible(
        child: TextFormField(
          initialValue: newColumnNames[0], //TODO check how this should be handled with multiple columns
          decoration: const InputDecoration(labelText: 'New Column Name'),
          onChanged: (String? value) {
            setState(() {
              newColumnNames = [value ?? ''];
            });
          },
        ),
      ),
    );
  }

  Widget buildCalculateButton() {
    return BiocentralSmallButton(onTap: collectAndInvokeCallback, label: 'Calculate');
  }

  List<Widget> buildParameterSelections();
}

class ColumnWizardShuffleOperationDisplay extends ColumnWizardOperationDisplay<ColumnWizardAddOperationResult> {
  const ColumnWizardShuffleOperationDisplay({
    required super.selectedColumnNames,
    required super.onCalculateCallback,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _ColumnWizardShuffleOperationDisplayState();
}

class _ColumnWizardShuffleOperationDisplayState
    extends ColumnWizardOperationDisplayState<ColumnWizardAddOperationResult> {
  int seed = ColumnWizardShuffleOperation.defaultSeed;

  @override
  String defaultColumnName() {
    return 'shuffled';
  }

  @override
  ColumnWizardOperation? collect() {
    return ColumnWizardShuffleOperation(newColumnNames, seed);
  }

  @override
  List<Widget> buildParameterSelections() {
    return [
      Flexible(
        child: TextFormField(
          initialValue: seed.toString(),
          decoration: const InputDecoration(labelText: 'Seed'),
          onChanged: (String? value) {
            setState(() {
              seed = int.tryParse(value ?? '') ?? ColumnWizardShuffleOperation.defaultSeed;
            });
          },
        ),
      ),
    ];
  }
}

class ColumnWizardToBinaryOperationDisplay extends ColumnWizardOperationDisplay<ColumnWizardAddOperationResult> {
  const ColumnWizardToBinaryOperationDisplay({
    required super.selectedColumnNames,
    required super.onCalculateCallback,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _ColumnWizardToBinaryOperationDisplayState();
}

class _ColumnWizardToBinaryOperationDisplayState
    extends ColumnWizardOperationDisplayState<ColumnWizardAddOperationResult> {
  String compareToValue = '';
  String valueTrue = ColumnWizardToBinaryOperation.defaultValueTrue;
  String valueFalse = ColumnWizardToBinaryOperation.defaultValueFalse;

  @override
  String defaultColumnName() {
    return 'binary';
  }

  @override
  ColumnWizardOperation? collect() {
    if (newColumnNames.isNotEmpty) {
      return ColumnWizardToBinaryOperation(newColumnNames, compareToValue, valueTrue, valueFalse);
    } else {
      return null;
    }
  }

  @override
  List<Widget> buildParameterSelections() {
    return [
      Flexible(
        child: TextFormField(
          initialValue: compareToValue,
          decoration: const InputDecoration(labelText: 'Compare to value:'),
          onChanged: (String? value) {
            setState(() {
              compareToValue = value ?? '';
            });
          },
        ),
      ),
      Flexible(
        child: TextFormField(
          initialValue: valueTrue,
          decoration: const InputDecoration(labelText: 'Value if match'),
          onChanged: (String? value) {
            setState(() {
              valueTrue = value ?? ColumnWizardToBinaryOperation.defaultValueTrue;
            });
          },
        ),
      ),
      Flexible(
        child: TextFormField(
          initialValue: valueFalse,
          decoration: const InputDecoration(labelText: 'Value if no match'),
          onChanged: (String? value) {
            setState(() {
              valueFalse = value ?? ColumnWizardToBinaryOperation.defaultValueFalse;
            });
          },
        ),
      ),
    ];
  }
}

class ColumnWizardRemoveMissingOperationDisplay
    extends ColumnWizardOperationDisplay<ColumnWizardRemoveOperationResult> {
  const ColumnWizardRemoveMissingOperationDisplay({
    required super.selectedColumnNames,
    required super.onCalculateCallback,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _ColumnWizardRemoveMissingOperationDisplayState();
}

class _ColumnWizardRemoveMissingOperationDisplayState
    extends ColumnWizardOperationDisplayState<ColumnWizardRemoveOperationResult> {
  @override
  String defaultColumnName() {
    return '';
  }

  @override
  ColumnWizardOperation? collect() {
    return ColumnWizardRemoveMissingOperation(newColumnNames);
  }

  @override
  List<Widget> buildParameterSelections() {
    return [];
  }
}

class ColumnWizardRemoveOutliersOperationDisplay
    extends ColumnWizardOperationDisplay<ColumnWizardRemoveOperationResult> {
  const ColumnWizardRemoveOutliersOperationDisplay({
    required super.selectedColumnNames,
    required super.onCalculateCallback,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _ColumnWizardRemoveOutliersOperationDisplayState();
}

class _ColumnWizardRemoveOutliersOperationDisplayState
    extends ColumnWizardOperationDisplayState<ColumnWizardRemoveOperationResult> {
  ColumnWizardOutlierRemovalMethod? _selectedMethod;

  @override
  String defaultColumnName() {
    return '';
  }

  @override
  ColumnWizardOperation? collect() {
    if (_selectedMethod != null) {
      return ColumnWizardRemoveOutliersOperation(newColumnNames, _selectedMethod!);
    }
    return null;
  }

  @override
  List<Widget> buildParameterSelections() {
    return [
      Flexible(
        child: BiocentralDropdownMenu(
          dropdownMenuEntries: ColumnWizardOutlierRemovalMethod.values
              .map((method) => DropdownMenuEntry(value: method, label: method.name))
              .toList(),
          label: const Text('Select method'),
          onSelected: (ColumnWizardOutlierRemovalMethod? method) {
            setState(() {
              _selectedMethod = method;
            });
          },
        ),
      ),
    ];
  }
}

class ColumnWizardClampOperationDisplay extends ColumnWizardOperationDisplay<ColumnWizardRemoveOperationResult> {
  const ColumnWizardClampOperationDisplay({
    required super.selectedColumnNames,
    required super.onCalculateCallback,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _ColumnWizardClampOperationDisplayState();
}

class _ColumnWizardClampOperationDisplayState
    extends ColumnWizardOperationDisplayState<ColumnWizardRemoveOperationResult> {
  double? low;
  double? high;

  @override
  String defaultColumnName() {
    return '';
  }

  @override
  ColumnWizardOperation? collect() {
    if (low != null || high != null) {
      return ColumnWizardClampOperation(newColumnNames, low, high);
    }
    return null;
  }

  @override
  List<Widget> buildParameterSelections() {
    return [
      Flexible(
        child: TextFormField(
          initialValue: '0.0',
          decoration: const InputDecoration(
            labelText: 'Lower value:',
            helperText: 'Remove all values strictly lower than this.',
          ),
          onChanged: (String? value) {
            setState(() {
              low = double.tryParse(value ?? '');
            });
          },
        ),
      ),
      Flexible(
        child: TextFormField(
          initialValue: '0.0',
          decoration: const InputDecoration(
            labelText: 'Upper value:',
            helperText: 'Remove all values strictly higher than this.',
          ),
          onChanged: (String? value) {
            setState(() {
              high = double.tryParse(value ?? '');
            });
          },
        ),
      ),
    ];
  }
}

class ColumnWizardCalculateLengthOperationDisplay extends ColumnWizardOperationDisplay<ColumnWizardAddOperationResult> {
  const ColumnWizardCalculateLengthOperationDisplay({
    required super.selectedColumnNames,
    required super.onCalculateCallback,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _ColumnWizardCalculateLengthOperationDisplayState();
}

class _ColumnWizardCalculateLengthOperationDisplayState
    extends ColumnWizardOperationDisplayState<ColumnWizardAddOperationResult> {
  @override
  String defaultColumnName() {
    return 'length';
  }

  @override
  ColumnWizardOperation? collect() {
    if (newColumnNames.isNotEmpty) {
      return ColumnWizardCalculateLengthOperation(newColumnNames);
    } else {
      return null;
    }
  }

  @override
  List<Widget> buildParameterSelections() {
    return [];
  }
}
