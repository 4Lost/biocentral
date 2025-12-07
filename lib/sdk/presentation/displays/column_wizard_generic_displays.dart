import 'package:biocentral/sdk/model/column_wizard_abstract.dart';
import 'package:biocentral/sdk/presentation/displays/column_wizard_generic_discrete_displays.dart';
import 'package:biocentral/sdk/presentation/displays/column_wizard_generic_not_discrete_displays.dart';
import 'package:flutter/material.dart';

class ColumnWizardGenericDisplay extends StatefulWidget {
  final ColumnWizard columnWizard;

  const ColumnWizardGenericDisplay({required this.columnWizard, super.key});

  @override
  State<StatefulWidget> createState() => _ColumnWizardGenericDisplayState();
}

class _ColumnWizardGenericDisplayState extends State<ColumnWizardGenericDisplay> {
  Future<bool> handleAsDiscrete = Future.value(false);

  @override
  void initState() {
    super.initState();
    handleAsDiscrete = widget.columnWizard.handleAsDiscrete();
  }

  /*
  @override
  void didUpdateWidget(ColumnWizardGenericDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.columnWizard != widget.columnWizard) {
      handleAsDiscrete = widget.columnWizard.handleAsDiscrete();
    }
  }*/

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: handleAsDiscrete,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) return const CircularProgressIndicator();

        return snapshot.data! ? ColumnWizardGenericDiscreteDisplay(columnWizard: widget.columnWizard,) : ColumnWizardGenericNotDiscreteDisplay(columnWizard: widget.columnWizard,);
      },
    );
  }
}
