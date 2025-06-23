import 'package:biocentral/sdk/model/column_wizard_abstract.dart';
import 'package:biocentral/sdk/presentation/plots/biocentral_bar_plot.dart';
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
                  return Text("ERROR"); // TODO Better error message
                }
                final resultTextWidgets = distributionResults
                    .map((distributionMap) => Text(distributionMap['dist_type'] + ": " + distributionMap["p_value"].toString()))
                    .toList();
                return Row(
                  children: [
                    Column(
                      children: resultTextWidgets,
                    ),
                    Column(children: [
                      SizedBox(
                        width: SizeConfig.safeBlockHorizontal(context) * 5,
                      ),
                      Builder(
                        builder: (context) {
                          final data = (widget.columnWizard as NumericStats).numericValues.toList();
                          return SizedBox(
                            width: SizeConfig.screenWidth(context) * 0.4,
                            height: SizeConfig.screenHeight(context) * 0.3,
                            child: BiocentralQQPlot(data: data),
                          );
                        },
                      ),
                    ]),
                  ],
                );
              }
              return const CircularProgressIndicator();
            }),
        // textFuture('Normal:', columnWizard.testDistribution('normal')),
        //textFuture('T:', columnWizard.testDistribution('t')),
        //textFuture('Log-Norm:', columnWizard.testDistribution('log_norm')),
        //textFuture('Chi2:', columnWizard.testDistribution('chi2')),
        //textFuture('Gamma:', columnWizard.testDistribution('gamma')),
        //textFuture('Beta:', columnWizard.testDistribution('beta')),
        //textFuture('Weibull:', columnWizard.testDistribution('weibull')),
        //textFuture('Exponential:', columnWizard.testDistribution('exponental')),
        //textFuture('Uniform:', columnWizard.testDistribution('uniform')),
        //textFuture('Bernoulli:', columnWizard.testDistribution('bernoulli')),
        //textFuture('Binomial:', columnWizard.testDistribution('binomial')),
        //textFuture('Geometric:', columnWizard.testDistribution('geometric')),
        //textFuture('Poisson:', columnWizard.testDistribution('poisson')),
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
}
