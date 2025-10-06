import 'package:biocentral/sdk/model/column_wizard_abstract.dart';
import 'package:biocentral/sdk/presentation/plots/biocentral_bar_plot.dart';
import 'package:biocentral/sdk/presentation/plots/biocentral_histogram_kde_plot.dart';
import 'package:biocentral/sdk/presentation/plots/biocentral_q_q_plot.dart';
import 'package:biocentral/sdk/util/constants.dart';
import 'package:biocentral/sdk/util/size_config.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class ColumnWizardGenericDisplay extends StatefulWidget {
  final ColumnWizard columnWizard;

  const ColumnWizardGenericDisplay({required this.columnWizard, super.key});

  @override
  State<StatefulWidget> createState() => _ColumnWizardGenericDisplayState();
}

class _ColumnWizardGenericDisplayState extends State<ColumnWizardGenericDisplay> {
  Future<bool> handleAsDiscrete = Future.value(false);
  int _focusWindow = 0;
  CarouselController carouselController = CarouselController();

  @override
  void initState() {
    super.initState();
    handleAsDiscrete = widget.columnWizard.handleAsDiscrete();
  }

  @override
  void didUpdateWidget(ColumnWizardGenericDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.columnWizard != widget.columnWizard) {
      handleAsDiscrete = widget.columnWizard.handleAsDiscrete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: handleAsDiscrete,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          if (snapshot.data == true) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                descriptiveStatisticsCounterStats(),
                SizedBox(
                  width: SizeConfig.safeBlockHorizontal(context) * 5,
                ),
                barDistributionPlot(),
              ],
            );
          } else {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                distributionNumericStats(),
              ],
            );
          }
        }
        return const CircularProgressIndicator();
      },
    );
  }

  Widget descriptiveStatisticsNumericStats() {
    final NumericStats columnWizard = widget.columnWizard as NumericStats;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Descriptive Statistics:\n'),
        textFuture('Number values:', columnWizard.length()),
        textFuture('Number missing values:', columnWizard.numberMissing()),
        textFuture('Max:', columnWizard.max()),
        textFuture('Min:', columnWizard.min()),
        textFuture('Mean:', columnWizard.mean()),
        textFuture('Median:', columnWizard.median()),
        textFuture('Mode:', columnWizard.mode()),
        textFuture('Standard deviation:', columnWizard.stdDev()),
      ],
    );
  }

  Widget distributionNumericStats() {
    final NumericStats columnWizard = widget.columnWizard as NumericStats;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Distribution Statistics:\n'),
        FutureBuilder(
            future: columnWizard.getDistributions(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final distributionResults = snapshot.data;
                if (distributionResults == null) {
                  return const Text('Loading of the distribution data failed.');
                }
                distributionResults.sort((a, b) {
                  final aValue = a['p_value'] as double;
                  final bValue = b['p_value'] as double;
                  return aValue.compareTo(bValue);
                });
                final resultTextRows = distributionResults
                    .map((distributionMap) => TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(distributionMap['dist_type'] + ':'),
                        ),
                        const SizedBox(width: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            '  ${distributionMap['p_value'] < 0.5 ? (0.0).toString() : distributionMap['p_value'].toString()}',
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),).toList();
                    final recommentionDist = SizedBox(
                      width: SizeConfig.screenHeight(context) * 0.5,
                      child: getMostLikly(distributionResults),
                    );
                return Column(
                  children: [
                    Table(
                      columnWidths: const {
                        0: IntrinsicColumnWidth(),
                        1: IntrinsicColumnWidth(),
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: resultTextRows,
                    ),
                    const SizedBox(height: 20),
                    recommentionDist,
                  ],
                );
              }
              return const CircularProgressIndicator();        
            },
          ),
          Column(children: [
            SizedBox(
              width: SizeConfig.safeBlockHorizontal(context) * 5,
            ),
            SizedBox(
              width: SizeConfig.screenWidth(context) * 0.7,
              height: SizeConfig.screenHeight(context) * 0.5,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 700),
                child: CarouselView(
                  controller: carouselController,
                  itemSnapping: true,
                  backgroundColor: Colors.transparent,
                  onTap: (value) { setState(() {
                    _focusWindow = value;
                    carouselController.animateToItem(value);
                  });},
                  itemExtent: SizeConfig.screenWidth(context) * 0.5,
                  children: [
                    //BiocentralPositionalDistributionPlot(focus: _focusWindow == 0 ? true : false),
                    //BiocentralAAKDEPlot(focus: _focusWindow == 0 ? true : false),
                    BiocentralHistogramKDEPlot(data: columnWizard.numericValues.toList(), focus: _focusWindow == 0 ? true : false),
                    BiocentralQQPlot(data: columnWizard.numericValues.toList(), focus: _focusWindow == 1 ? true : false),
                  ],
                ),
              ),
            ),
          ],
        ), 
      ],
    );
  }

  Widget descriptiveStatisticsCounterStats() {
    final CounterStats columnWizard = widget.columnWizard as CounterStats;
    return FutureBuilder<Map<String, int>>(
      future: columnWizard.getCounts(), // Cached
      builder: (context, snapshot) {
        final List<Widget> classCounts = [];
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          classCounts.add(const Text('Class counts:'));
          classCounts.addAll(
            snapshot.data!.entries
                .sorted((e1, e2) => e1.value.compareTo(e2.value))
                .reversed
                .map((entry) => Text('${entry.key}: ${entry.value}')),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Descriptive Statistics:\n'),
            textFuture('Number values:', columnWizard.length()),
            textFuture('Number different classes:', columnWizard.getCounts().then((counts) => counts.keys.length)),
            textFuture('Number missing values:', columnWizard.numberMissing()),
            ...classCounts,
          ],
        );
      },
    );
  }

  Widget textFuture(String text, Future<num> future) {
    return FutureBuilder<num>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          String valueString = '';
          if (snapshot.data.runtimeType == int) {
            valueString = snapshot.data.toString();
          } else {
            valueString = snapshot.data?.toStringAsPrecision(Constants.maxDoublePrecision) ?? '';
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

  Widget barDistributionPlot() {
    return Flexible(
      child: FutureBuilder<BiocentralBarPlotData>(
        future: widget.columnWizard.getBarPlotData(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            final BiocentralBarPlotData barPlotData = snapshot.data!;
            return SizedBox(
              width: SizeConfig.screenWidth(context) * 0.4,
              height: SizeConfig.screenHeight(context) * 0.3,
              child: BiocentralBarPlot(
                data: barPlotData,
                xAxisLabel: 'Categories',
                yAxisLabel: 'Frequency',
              ),
            );
          } else {
            return const CircularProgressIndicator();
          }
        },
      ),
    );
  }
  Widget getMostLikly(List<Map<String, dynamic>> distributionResults) {
    final Map<String, dynamic> maxDist = distributionResults.reduce((a, b) => a['p_value'] > b['p_value'] ? a : b);
    final String recommandation = ' ?? -- ?? ';

    return Text(maxDist['p_value'] as double > 0.5
      ? 'The distribution seems to be ${maxDist['dist_type']} distributed.'
      : 'The distribution does not fullfill the properties of any tested distribution. But it is the closest to a ${distributionResults.elementAt(0)['dist_type']} distributed. You can do ${recommandation} to transform to the distribution');
  }
}
