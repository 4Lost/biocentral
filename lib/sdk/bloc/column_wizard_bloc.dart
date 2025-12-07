import 'package:biocentral/sdk/biocentral_sdk.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class ColumnWizardEvent {}

final class ColumnWizardLoadEvent extends ColumnWizardEvent {}

final class ColumnWizardSelectColumnEvent extends ColumnWizardEvent {
  List<String> selectedColumns = [''];

  ColumnWizardSelectColumnEvent(this.selectedColumns);
}

final class ColumnWizardSelectOperationEvent extends ColumnWizardEvent {
  final ColumnOperationType selectedOperationType;

  ColumnWizardSelectOperationEvent(this.selectedOperationType);
}

final class ColumnWizardCalculateEvent extends ColumnWizardEvent {
  final ColumnWizardOperation columnWizardOperation;

  ColumnWizardCalculateEvent(this.columnWizardOperation);
}

@immutable
final class ColumnWizardBlocState extends Equatable {
  final Map<String, Map<String, dynamic>> columns;

  final Map<String, ColumnWizard>? columnWizards;
  final Widget Function(ColumnWizard)? customBuildFunction;
  final String selectedColumns;
  final ColumnOperationType? selectedOperationType;

  final ColumnWizardBlocStatus status;

  const ColumnWizardBlocState(
    this.columns,
    this.columnWizards,
    this.customBuildFunction,
    this.selectedColumns,
    this.selectedOperationType,
    this.status,
  );

  const ColumnWizardBlocState.initial()
      : columns = const {},
        customBuildFunction = null,
        columnWizards = null,
        selectedColumns = '',
        selectedOperationType = null,
        status = ColumnWizardBlocStatus.initial;

  ColumnWizard? get columnWizard => columnWizards?[selectedColumns];

  @override
  List<Object?> get props =>
      [columns, columnWizards, customBuildFunction, selectedColumns, selectedOperationType, status];

  ColumnWizardBlocState copyWith({Map<String, dynamic>? copyMap}) {
    return ColumnWizardBlocState(
      copyMapExtractor(copyMap, 'columns', columns),
      copyMapExtractor(copyMap, 'columnWizards', columnWizards),
      copyMapExtractor(copyMap, 'customBuildFunction', customBuildFunction),
      copyMapExtractor(copyMap, 'selectedColumn', selectedColumns),
      copyMapExtractor(copyMap, 'selectedOperationType', selectedOperationType),
      copyMapExtractor(copyMap, 'status', status),
    );
  }
}

enum ColumnWizardBlocStatus { initial, loading, loaded, selected }

class ColumnWizardBloc extends Bloc<ColumnWizardEvent, ColumnWizardBlocState> {
  final BiocentralDatabase _biocentralDatabase;
  final BiocentralColumnWizardRepository _columnWizardRepository;

  ColumnWizardBloc(this._biocentralDatabase, this._columnWizardRepository)
      : super(const ColumnWizardBlocState.initial()) {
    on<ColumnWizardLoadEvent>((event, emit) async {
      emit(const ColumnWizardBlocState.initial().copyWith(copyMap: {'status': ColumnWizardBlocStatus.loading}));
      final Map<String, Map<String, dynamic>> columns = _biocentralDatabase.getColumns();
      emit(state.copyWith(copyMap: {'columns': columns, 'status': ColumnWizardBlocStatus.loaded}));
    });
    on<ColumnWizardSelectColumnEvent>((event, emit) async {
      if (event.selectedColumns.length == 1 && event.selectedColumns.first == '') return;

      final Map<String, ColumnWizard> columnWizards = state.columnWizards ?? {};
      Widget Function(ColumnWizard)? customBuildFunction;
      final String selectionKey = event.selectedColumns.where((x) => x.isNotEmpty).join('|');

      ColumnWizard? columnWizard = columnWizards[selectionKey];
      if (columnWizard == null) {
        columnWizard = await _columnWizardRepository.getColumnWizardForColumn(
          columnNames: event.selectedColumns,
          valueMap: getValueMap(event),
        );
        columnWizards[selectionKey] = columnWizard;
      }
      customBuildFunction = _columnWizardRepository.getCustomBuildFunctionForColumnWizard(columnWizard);

      emit(
        state.copyWith(
          copyMap: {
            'selectedColumn': selectionKey,
            'columnWizards': columnWizards,
            'customBuildFunction': customBuildFunction,
            'status': ColumnWizardBlocStatus.selected,
          },
        ),
      );
    });
    on<ColumnWizardSelectOperationEvent>((event, emit) async {
      emit(
        state.copyWith(
          copyMap: {'selectedOperationType': event.selectedOperationType, 'status': ColumnWizardBlocStatus.selected},
        ),
      );
    });
  }
  
  Map<String, dynamic> getValueMap(ColumnWizardSelectColumnEvent event) {
    if (event.selectedColumns.length < 2 || event.selectedColumns[1] == '') return state.columns[event.selectedColumns[0]] ?? {};

    final Map<String, Map<String, dynamic>> result = {};

final columns = event.selectedColumns;
if (columns.isEmpty) return result;

final String valueColumn = columns.first;
final List<String> groupingColumns = columns.sublist(1);
final Map<String, dynamic>? primaryMap = state.columns[valueColumn];
if (primaryMap == null) return result;

for (final entry in primaryMap.entries) {
  final String rowKey = entry.key;
  final dynamic value = entry.value;

  final parts = <String>[];
  for (final col in groupingColumns) {
    if (col != '') {
      final dynamic colValue = state.columns[col]?[rowKey];
      parts.add('$col=${colValue.toString()}');
    }
  }

  final String mapKey = parts.join('&');

  result.putIfAbsent(mapKey, () => {});
  result[mapKey]![rowKey] = value;
}

    return result;
  }
}
