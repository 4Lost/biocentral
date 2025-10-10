import 'package:biocentral/plugins/proteins/model/sequence_column_wizard.dart';
import 'package:biocentral/plugins/proteins/presentation/plots/biocentral_AA_kde_plot.dart';
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
  //late Future<Map<int, Map<String, int>>> _sequencePosDistributionFuture;

  @override
  void initState() {
    super.initState();
    //_sequencePosDistributionFuture = widget.columnWizard.positionalSequenceDistribution();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, double>>(
      future: widget.columnWizard.sequenceDistribution(),
      builder: (context, seqDistSnapshot) {
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
              buildLengthCompositionPlot(),
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
              buildCompositionPlot(seqDistSnapshot),
              /*const Text('Positional Protein Distribution\n'),
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
              FutureBuilder<Widget>(
                key: ValueKey('pos-$protDistCompare'),
                future: buildPositionalCompositionPlot(),
                builder: (context, snapshot) {
                  if(snapshot.hasData && snapshot.data != null) {
                    return snapshot.data!;
                  }
                  return const CircularProgressIndicator();
                },
              ),*/
            ],
          );
        });
        return const CircularProgressIndicator();
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

  Widget buildLengthCompositionPlot() {
    return SizedBox(
      width: 2000,
      height: 500,
      child: BiocentralAAKDEPlot(focus: lenDistCompare,),
    );
  }

  Widget buildCompositionPlot(AsyncSnapshot<Map<String, double>> snapshot) {
    if(snapshot.hasData && snapshot.data != null) {
        return SizedBox(
        width: 2000,
        height: 500,
        child: BiocentralSequenceDistributionPlot(distribution: snapshot.data!, showBackground: protDistCompare,),
      );
    }
      return const CircularProgressIndicator();
    
  }

  Future<Widget> buildPositionalCompositionPlot() async {
    return SizedBox(
      width: 2000,
      height: 500,
      child: BiocentralPositionalSequenceDistributionPlot(positionalDist: await widget.columnWizard.positionalSequenceDistribution(), showBackground: protDistCompare,),
    );
  }
}
