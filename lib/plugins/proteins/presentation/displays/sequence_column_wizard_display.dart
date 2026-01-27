import 'package:biocentral/plugins/proteins/model/sequence_column_wizard.dart';
import 'package:biocentral/plugins/proteins/presentation/plots/biocentral_length_distribution_plot.dart';
import 'package:biocentral/plugins/proteins/presentation/plots/biocentral_scale_plot.dart';
import 'package:biocentral/plugins/proteins/presentation/plots/biocentral_sequence_distribution_plot.dart';
import 'package:biocentral/plugins/proteins/presentation/plots/biocentral_positional_sequence_distribution_plot.dart';
import 'package:biocentral/sdk/biocentral_sdk.dart';
import 'package:biocentral/sdk/util/point.dart';
import 'package:flutter/material.dart';

class SequenceColumnWizardDisplay extends StatefulWidget {
  final SequenceColumnWizard columnWizard;

  const SequenceColumnWizardDisplay({required this.columnWizard, super.key});

  @override
  State<SequenceColumnWizardDisplay> createState() => _SequenceColumnWizardDisplayState();
}

class _SequenceColumnWizardDisplayState extends State<SequenceColumnWizardDisplay> {
  List<bool> compareValues = [false, false, false, false, false, false, false, false, false, false, false];
  List<String> compareColumns = ['', ''];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return widget.columnWizard.compare ? buildCompare(context) : buildSingle(context);
  }

  Widget buildSingle(BuildContext context) {
    return FutureBuilder<DistributionStats>(
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
            toggleCompareButton(1),
            buildLengthCompositionPlot([snapshot.data!.lenKdePoints], [snapshot.data!.lenStats]),
            const Text('Protein Distribution\n'),
            toggleCompareButton(2),
            buildCompositionPlot([snapshot.data!.seqDistribution]),
            const Text('Positional Protein Distribution\n'),
            toggleCompareButton(3),
            buildPositionalCompositionPlot([snapshot.data!.posSeqDistribution]),
            const Text('Hydrophobicity\n'),
            toggleCompareButton(4),
            buildScalePlot('hydrophobicity', [snapshot.data!.getScaleStats('hydrophobicity')], 4),
            const Text('Free Energy\n'),
            const Text('Stability\n'),
            const Text('Volume\n'),
            const Text('Alpha Helix\n'),
            const Text('Beta Sheet\n'),
            const Text('Coil\n'),
            const Text('Mutability\n'),
          ],
        );
      }
    );
  }

  Widget buildCompare(BuildContext context) {
    return FutureBuilder<List<DistributionStats>>(
      key: ValueKey('${compareColumns[0]}-${compareColumns[1]}'),
      future: (widget.columnWizard as SequenceCompareColumnWizard).distributionByKeys(compareColumns[0], compareColumns[1]),
      builder: (context, snapshot) {
        if (compareColumns[0] == '' || compareColumns[1] == '') return compareSelection((widget.columnWizard as SequenceCompareColumnWizard).getKeys());
        if (!snapshot.hasData) return const CircularProgressIndicator();
        compareValues = [true, true, true];
        final bool notEnoughData = snapshot.data![0].lenKdePoints.length > 1;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            compareSelection((widget.columnWizard as SequenceCompareColumnWizard).getKeys()),
            buildCompareSequenceStats(compareColumns[0], compareColumns[1]),
            SizedBox(
              width: SizeConfig.safeBlockHorizontal(context) * 5,
            ),
            if (notEnoughData) const Text('Length Distribution\n'),
            if (notEnoughData) buildLengthCompositionPlot([snapshot.data![0].lenKdePoints, snapshot.data![1].lenKdePoints], [snapshot.data![0].lenStats, snapshot.data![1].lenStats]),
            const Text('Protein Distribution\n'),
            buildCompositionPlot([snapshot.data![0].seqDistribution, snapshot.data![1].seqDistribution]),
            const Text('Positional Protein Distribution\n'),
            buildPositionalCompositionPlot([snapshot.data![0].posSeqDistribution, snapshot.data![1].posSeqDistribution]),
            const Text('Hydrophobicity\n'),
            //buildScalePlot('hydrophobicity', [snapshot.data![0].getScaleStats('hydrophobicity'), snapshot.data![1].getScaleStats('hydrophobicity')]),
            const Text('Free Energy\n'),
            const Text('Stability\n'),
            const Text('Volume\n'),
            const Text('Alpha Helix\n'),
            const Text('Beta Sheet\n'),
            const Text('Coil\n'),
            const Text('Mutability\n'),
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
                    child: textFuture(' ', Future.value((widget.columnWizard as SequenceCompareColumnWizard).valueMap[first]!.values.firstOrNull.runtimeType,)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
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
    if (!keys.contains(compareColumns[0])) compareColumns[0] = '';
    if (!keys.contains(compareColumns[1])) compareColumns[1] = '';

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
            onSelected: (String? value) {
              if (value == compareColumns[0] || compareColumns[1] == '' || value == '') {
                compareColumns = [value ?? '', compareColumns[1]];
                return;
              }
              setState(() => compareColumns = [value ?? '', compareColumns[1]]);
            },
          ),),
          const SizedBox(width: 16),
          Expanded(child: BiocentralDropdownMenu<String>(
            dropdownMenuEntries: keys
              .map((key) => DropdownMenuEntry(value: key, label: key))
              .toList(),
            label: const Text('Select second..'),
            initialSelection: compareColumns[1],
            onSelected: (String? value)  {
              if (value == compareColumns[1] || compareColumns[0] == '' || value == '') {
                compareColumns = [compareColumns[0], value ?? ''];
                return;
              }
              setState(() => compareColumns = [compareColumns[0], value ?? '']);
            },
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
  
  Widget toggleCompareButton(int index) {
    return SizedBox(
      height: SizeConfig.safeBlockHorizontal(context) * 3,
      width: SizeConfig.safeBlockHorizontal(context) * 8,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor, textStyle: Theme.of(context).textTheme.labelMedium,
        ),
        onPressed: () => setState(() {
          compareValues[index - 1] = !compareValues[index - 1];
        }),
        child: const Text('Toggle Comparison', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget buildLengthCompositionPlot(List<List<Point>> lenDist, List<Map<String, double>> lenStats) {
    return SizedBox(
      key: Key('1-${compareColumns[0]}-${compareColumns[1]}'),
      width: 2000,
      height: 500,
      child: BiocentralLengthDistributionPlot(distributions: lenDist, stats: lenStats, showSecond: compareValues[0],),
    );
  }

  Widget buildCompositionPlot(List<Map<String, double>> data) {
    return SizedBox(
      key: Key('2-${compareColumns[0]}-${compareColumns[1]}'),
      width: 2000,
      height: 500,
      child: BiocentralSequenceDistributionPlot(distributions: data, showSecond: compareValues[1],),
    );
  }

  Widget buildPositionalCompositionPlot(List<Map<int, Map<String, double>>> data) {
    return SizedBox(
      key: Key('3-${compareColumns[0]}-${compareColumns[1]}'),
      width: 2000,
      height: 500,
      child: BiocentralPositionalSequenceDistributionPlot(distributions: data, showSecond: compareValues[2],),
    );
  }

  Widget buildScalePlot(String feature, List<PointScaleStats> data, int compareIndex) {
    return SizedBox(
      key: Key('4-$feature-${compareColumns[0]}-${compareColumns[1]}'),
      width: 2000,
      height: 500,
      child: BiocentralScalePlot(scaleStats: data, showSecond: compareValues[compareIndex - 1], feature: feature,),
    );
  }
}
