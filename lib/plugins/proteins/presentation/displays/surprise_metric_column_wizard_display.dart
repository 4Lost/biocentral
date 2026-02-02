import 'package:biocentral/plugins/proteins/model/surprise_metric_column_wizard.dart';
import 'package:biocentral/sdk/biocentral_sdk.dart';
import 'package:flutter/material.dart';

class SurpriseMetricColumnWizardDisplay extends StatefulWidget {
  final SurpriseMetricColumnWizard columnWizard;

  const SurpriseMetricColumnWizardDisplay({required this.columnWizard, super.key});

  @override
  State<SurpriseMetricColumnWizardDisplay> createState() => _SurpriseMetricColumnWizardDisplayState();
}

class _SurpriseMetricColumnWizardDisplayState extends State<SurpriseMetricColumnWizardDisplay> {
  String sequence = '';
  String filter = '';
  final Map<int, FixedColumnWidth> columnWidth = const {0: FixedColumnWidth(190), 1: FixedColumnWidth(190)};

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Table(
          columnWidths: columnWidth,
          children: [
            TableRow(children: [
              const Text('Extremly surprising:'), Text(widget.columnWizard.getAmount('extremly surprising').toString()),
            ]),
            TableRow(children: [
              const Text('Highly surprising:'), Text(widget.columnWizard.getAmount('highly surprising').toString()),
            ]),
            TableRow(children: [
              const Text('Surprising:'), Text(widget.columnWizard.getAmount('surprising').toString()),
            ]),
            TableRow(children: [
              const Text('Slightly surprising:'), Text(widget.columnWizard.getAmount('slightly surprising').toString()),
            ]),
            TableRow(children: [
              const Text('Ordinary:'), Text(widget.columnWizard.getAmount('ordinary').toString()),
            ]),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Protein selection'),
        Row(children: [
          Expanded(child: BiocentralDropdownMenu<String>(
            dropdownMenuEntries: widget.columnWizard.getSequencesWithFilter(filter)
              .map((key) => DropdownMenuEntry(value: key, label: key))
              .toList(),
            label: const Text('Select protein..'),
            initialSelection: sequence,
            onSelected: (String? value) {
              if (value == sequence) {
                return;
              }
              setState(() => sequence = value ?? '');
            },
          ),),
          const SizedBox(width: 16),
          Expanded(child: BiocentralDropdownMenu<String>(
            dropdownMenuEntries: widget.columnWizard.getFilterKeys()
              .map((key) => DropdownMenuEntry(value: key, label: key))
              .toList(),
            label: const Text('Select filter..'),
            initialSelection: filter,
            onSelected: (String? value)  {
              if (value == filter) {
                return;
              }
              setState(() => filter = value ?? '');
            },
          ),),
        ],),
        const SizedBox(height: 16),
        buildStats(),
      ],
    );
  }

  Widget buildStats() {
    if (sequence == '') return const Text('Please select a Sequence. You can select a suprise metric class to filter the options.');

    final SurpriseMetric surpriseMetric = widget.columnWizard.getForSequence(sequence);
    if (surpriseMetric.surpriseClass == 'notFound') return Text('The sequence ${surpriseMetric.sequenceId} seems to be invalid. Please select a valid sequence.');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Surprise metric values for the sequence ${surpriseMetric.sequenceId}.'),
        const SizedBox(height: 8),
        Table(
          columnWidths: columnWidth,
          children: [
            TableRow(children: [
              const Text('Surprise class:'), Text(surpriseMetric.surpriseClass),
            ]),
            TableRow(children: [
              const Text('Surprise factor:'), Text(surpriseMetric.factor.toStringAsFixed(3)),
            ]),
          ],
        ),
        const SizedBox(height: 16),
        const Text('The surprise factor is the average of the surprise factors of each feature. These surprise factors are calculated with this formula: |mean - value| / standard deviation'),
        const SizedBox(height: 8),
        Table(
          columnWidths: columnWidth,
          children: [
            TableRow(children: [
              const Text('Length factor:'), Text(surpriseMetric.length.toStringAsFixed(3)),
            ]),
            TableRow(children: [
              const Text('Alpha helix factor:'), Text(surpriseMetric.alphaHelix.toStringAsFixed(3)),
            ]),
            TableRow(children: [
              const Text('Beta sheet factor:'), Text(surpriseMetric.betaSheet.toStringAsFixed(3)),
            ]),
            TableRow(children: [
              const Text('Coil factor:'), Text(surpriseMetric.coil.toStringAsFixed(3)),
            ]),
            TableRow(children: [
              const Text('Free energy factor:'), Text(surpriseMetric.freeEnergy.toStringAsFixed(3)),
            ]),
            TableRow(children: [
              const Text('Hydrophobicity factor:'), Text(surpriseMetric.hydrophobicity.toStringAsFixed(3)),
            ]),
            TableRow(children: [
              const Text('Mutability factor:'), Text(surpriseMetric.mutability.toStringAsFixed(3)),
            ]),
            TableRow(children: [
              const Text('Stability factor:'), Text(surpriseMetric.stability.toStringAsFixed(3)),
            ]),
            TableRow(children: [
              const Text('Volume factor:'), Text(surpriseMetric.volume.toStringAsFixed(3)),
            ]),
          ],
        ),
      ],
    );
  }
}
