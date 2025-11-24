import 'package:biocentral/plugins/proteins/model/sequence_column_wizard.dart';
import 'package:biocentral/plugins/proteins/presentation/plots/biocentral_length_distribution_plot.dart';
import 'package:biocentral/plugins/proteins/presentation/plots/biocentral_sequence_distribution_plot.dart';
import 'package:biocentral/plugins/proteins/presentation/plots/biocentral_positional_sequence_distribution_plot.dart';
import 'package:biocentral/sdk/biocentral_sdk.dart';
import 'package:flutter/material.dart';

class SequenceColumnWizardDisplay extends StatefulWidget {
  final SequenceColumnWizard columnWizard;

  const SequenceColumnWizardDisplay({required this.columnWizard, super.key});

  @override
  State<SequenceColumnWizardDisplay> createState() => _SequenceColumnWizardDisplayState();
}

class _SequenceColumnWizardDisplayState extends State<SequenceColumnWizardDisplay> {
  bool lenDistCompare = false;
  bool protDistCompare = false;
  bool posProtDistCompare = false;
  List<String> compareColumns = ['', ''];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return widget.columnWizard is SequenceCompareColumnWizard ? buildCompare(context) : buildSingle(context) ;
  }

  Widget buildSingle(BuildContext context) {
    return FutureBuilder<({
      Map<String, Map<String, double>> lenDistribution,
      Map<String, double> seqDistribution,
      Map<int, Map<String, double>> posSeqDistribution,
    })>(
      future: (widget.columnWizard as SequenceNormalColumnWizard).distribution(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildSequenceStats(),
            SizedBox(
              width: SizeConfig.safeBlockHorizontal(context) * 5,
            ),
            const Text('Length Distribution\n'),
            SizedBox(
              height: SizeConfig.safeBlockHorizontal(context) * 3,
              width: SizeConfig.safeBlockHorizontal(context) * 8,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor, textStyle: Theme.of(context).textTheme.labelMedium,
                ),
                onPressed: () => setState(() {
                  lenDistCompare = !lenDistCompare;
                }),
                child: const Text('Toggle Comparison', style: TextStyle(color: Colors.white)),
              ),
            ),
            buildLengthCompositionPlot([snapshot.data!.lenDistribution]),
            const Text('Protein Distribution\n'),
            SizedBox(
              height: SizeConfig.safeBlockHorizontal(context) * 3,
              width: SizeConfig.safeBlockHorizontal(context) * 8,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor, textStyle: Theme.of(context).textTheme.labelMedium,
                ),
                onPressed: () => setState(() {
                  protDistCompare = !protDistCompare;
                }),
                child: const Text('Toggle Comparison', style: TextStyle(color: Colors.white)),
              ),
            ),
            buildCompositionPlot([snapshot.data!.seqDistribution]),
            const Text('Positional Protein Distribution\n'),
            SizedBox(
              height: SizeConfig.safeBlockHorizontal(context) * 3,
              width: SizeConfig.safeBlockHorizontal(context) * 8,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor, textStyle: Theme.of(context).textTheme.labelMedium,
                ),
                onPressed: () => setState(() {
                  posProtDistCompare = !posProtDistCompare;
                }),
                child: const Text('Toggle Comparison', style: TextStyle(color: Colors.white)),
              ),
            ),
            buildPositionalCompositionPlot([snapshot.data!.posSeqDistribution]),
          ],
        );
      }
    );
  }

  Widget buildCompare(BuildContext context) {
    return FutureBuilder<Map<String, ({
      Map<String, Map<String, double>> lenDistribution,
      Map<String, double> seqDistribution,
      Map<int, Map<String, double>> posSeqDistribution,
    })>>(
      future: (widget.columnWizard as SequenceCompareColumnWizard).distribution(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        if (compareColumns[0] == '' || compareColumns[1] == '') return compareSelection(snapshot.data!.keys);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Compare selection:'),
            compareSelection(snapshot.data!.keys),
            buildCompareSequenceStats(compareColumns[0], compareColumns[1]),
            SizedBox(
              width: SizeConfig.safeBlockHorizontal(context) * 5,
            ),
            const Text('Length Distribution\n'),
            buildLengthCompositionPlot([snapshot.data![compareColumns[0]]!.lenDistribution, snapshot.data![compareColumns[1]]!.lenDistribution]),
            const Text('Protein Distribution\n'),
            buildCompositionPlot([snapshot.data![compareColumns[0]]!.seqDistribution, snapshot.data![compareColumns[1]]!.seqDistribution]),
            const Text('Positional Protein Distribution\n'),
            buildPositionalCompositionPlot([snapshot.data![compareColumns[0]]!.posSeqDistribution, snapshot.data![compareColumns[1]]!.posSeqDistribution]),
          ],
        );
      }
    );
  }

  Widget buildSequenceStats() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center, // center horizontally
      children: [
        const Text('Descriptive Statistics\n'),
        Center(
          child: Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  const Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text('Number values:', textAlign: TextAlign.left),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: textFuture(' ', widget.columnWizard.length()),
                  ),
                ],
              ),
              TableRow(
                children: [
                  const Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text('Sequence Type:', textAlign: TextAlign.left),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: textFuture(
                      ' ',
                      Future.value(
                        widget.columnWizard.valueMap.values.firstOrNull?.runtimeType ?? 'Unknown',
                      ),
                    ),
                  ),
                ],
              ),
              TableRow(
                children: [
                  const Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text('Number missing values:', textAlign: TextAlign.left),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: textFuture(' ', widget.columnWizard.numberMissing()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildCompareSequenceStats(String first, String second) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center, // center horizontally
      children: [
        const Text('Descriptive Statistics\n'),
        Center(
          child: Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  const Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text('Number values:', textAlign: TextAlign.left),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: textFuture(' ', (widget.columnWizard as SequenceCompareColumnWizard).lengthOfKey(first)),
                  ),
                  const Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(' - ', textAlign: TextAlign.left),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: textFuture(' ', (widget.columnWizard as SequenceCompareColumnWizard).lengthOfKey(second)),
                  ),
                ],
              ),
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: Text('Sequence Type:', textAlign: TextAlign.left),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: textFuture(' ', Future.value((widget.columnWizard as SequenceCompareColumnWizard).valueMap[first]!.values.firstOrNull.runtimeType ?? 'Unknown',)),
                  ),
                  const Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(' - ', textAlign: TextAlign.left),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: textFuture(' ', Future.value((widget.columnWizard as SequenceCompareColumnWizard).valueMap[second]!.values.firstOrNull?.runtimeType ?? 'Unknown',)),
                  ),
                ],
              ),
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: Text('Number missing values:', textAlign: TextAlign.left),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: textFuture(' ', (widget.columnWizard as SequenceCompareColumnWizard).numberMissingOfKey(first)),
                  ),
                  const Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(' - ', textAlign: TextAlign.left),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: textFuture(' ', (widget.columnWizard as SequenceCompareColumnWizard).numberMissingOfKey(second)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget compareSelection(Iterable<String> keys) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Compare selection:'),
        Row(children: [
          Expanded(child: BiocentralDropdownMenu<String>(
            dropdownMenuEntries: keys
              .map((key) => DropdownMenuEntry(value: key, label: key))
              .toList(),
            label: const Text('Select first..'),
            initialSelection: compareColumns[0],
            onSelected: (String? value) => WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => compareColumns[0] = value ?? '')),
          ),),
          const SizedBox(width: 16),
          Expanded(child: BiocentralDropdownMenu<String>(
            dropdownMenuEntries: keys
              .map((key) => DropdownMenuEntry(value: key, label: key))
              .toList(),
            label: const Text('Select second..'),
            initialSelection: compareColumns[1],
            onSelected: (String? value) => WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => compareColumns[1] = value ?? '')),
          ),),
        ],),
        const Text('Please select which Data you want to compare.'),
      ],
    );
  }

  Widget textFuture(String text, Future future) {
    return FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          String valueString = snapshot.data.toString();
          final double? parsedDouble = double.tryParse(valueString);
          if (parsedDouble != null) {
            valueString = parsedDouble.toStringAsPrecision(Constants.maxDoublePrecision);
          }
          return Row(
            children: [
              Text('$text '),
              Text(valueString),
            ],
          );
        }
        return Row(children: [Text('$text '), const CircularProgressIndicator()]);
      },
    );
  }

  Widget buildLengthCompositionPlot(List<Map<String, Map<String, double>>> data) {
    return SizedBox(
      width: 2000,
      height: 500,
      child: BiocentralLengthDistributionPlot(distributions: data, showSecond: lenDistCompare,),
    );
  }

  Widget buildCompositionPlot(List<Map<String, double>> data) {
    return SizedBox(
      width: 2000,
      height: 500,
      child: BiocentralSequenceDistributionPlot(distributions: data, showSecond: protDistCompare,),
    );
  }

  Widget buildPositionalCompositionPlot(List<Map<int, Map<String, double>>> data) {
    return SizedBox(
      width: 2000,
      height: 500,
      child: BiocentralPositionalSequenceDistributionPlot(distributions: data, showSecond: posProtDistCompare,),
    );
  }
}
