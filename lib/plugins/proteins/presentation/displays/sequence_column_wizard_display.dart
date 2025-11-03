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
  int index = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (true) {//widget.columnWizard.subsectionSelected()) {
      return buildMultiple(context);
    } else {
      return buildSingle(context);
    }
  }

  Widget buildSingle(BuildContext context) {
    return FutureBuilder<({
      Map<String, Map<String, double>> lenDistribution,
      Map<String, double> seqDistribution,
      Map<int, Map<String, int>> posSeqDistribution,
    })>(
      future: widget.columnWizard.distribution(),
      builder: (context, snapshot) {
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
            snapshot.hasData ? buildLengthCompositionPlot(snapshot.data!.lenDistribution) : const CircularProgressIndicator(),
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
            snapshot.hasData ? buildCompositionPlot(snapshot.data!.seqDistribution) : const CircularProgressIndicator(),
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
            snapshot.hasData ? buildPositionalCompositionPlot(snapshot.data!.posSeqDistribution) : const CircularProgressIndicator(),
          ],
        );
      }
    );
  }

  Widget buildMultiple(BuildContext context) {
    return FutureBuilder<List<({
      Map<String, Map<String, double>> lenDistribution,
      Map<String, double> seqDistribution,
      Map<int, Map<String, int>> posSeqDistribution,
    })>>(
      future: widget.columnWizard.distributionByColumn(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }
        final isFirst = index == 0;
        final isLast = index == widget.columnWizard.getColumnAmount('test') - 1;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_left),
                  color: isFirst ? Colors.grey : Colors.blue,
                  onPressed: isFirst ? null : () => setState(() => index--),
                ),
                Text('${index + 1}/${snapshot.data!.length}'),
                IconButton(
                  icon: const Icon(Icons.arrow_right),
                  color: isLast ? Colors.grey : Colors.blue,
                  onPressed: isLast ? null : () => setState(() => index++),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: buildMultipleSub(snapshot.data![index]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
        
  Widget buildMultipleSub(({
      Map<String, Map<String, double>> lenDistribution,
      Map<String, double> seqDistribution,
      Map<int, Map<String, int>> posSeqDistribution,
    }) data) {
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
        buildLengthCompositionPlot(data.lenDistribution),
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
        buildCompositionPlot(data.seqDistribution),
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
        buildPositionalCompositionPlot(data.posSeqDistribution),
      ],
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
                    padding: EdgeInsets.symmetric(vertical: 4.0),
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
                    padding: EdgeInsets.symmetric(vertical: 4.0),
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
                    padding: EdgeInsets.symmetric(vertical: 4.0),
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

  // TODO Merge with other column wizard function
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

  Widget buildLengthCompositionPlot(Map<String, Map<String, double>> data) {
    return SizedBox(
      width: 2000,
      height: 500,
      child: BiocentralLengthDistributionPlot(distribution: data, showBackground: lenDistCompare,),
    );
  }

  Widget buildCompositionPlot(Map<String, double> data) {
    return SizedBox(
      width: 2000,
      height: 500,
      child: BiocentralSequenceDistributionPlot(distribution: data, showBackground: protDistCompare,),
    );
  }

  Widget buildPositionalCompositionPlot(Map<int, Map<String, int>> data) {
    return SizedBox(
      width: 2000,
      height: 500,
      child: BiocentralPositionalSequenceDistributionPlot(distribution: data, showBackground: posProtDistCompare,),
    );
  }
}