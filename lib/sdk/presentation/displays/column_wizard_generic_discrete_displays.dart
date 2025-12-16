import 'package:biocentral/sdk/model/column_wizard_abstract.dart';
import 'package:biocentral/sdk/presentation/plots/biocentral_bar_compare_plot.dart';
import 'package:biocentral/sdk/presentation/plots/biocentral_bar_plot.dart';
import 'package:biocentral/sdk/presentation/widgets/biocentral_drop_down_menu.dart';
import 'package:biocentral/sdk/util/constants.dart';
import 'package:biocentral/sdk/util/size_config.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class ColumnWizardGenericDiscreteDisplay extends StatefulWidget {
  final ColumnWizard columnWizard;

  const ColumnWizardGenericDiscreteDisplay({required this.columnWizard, super.key});

  @override
  State<StatefulWidget> createState() => _ColumnWizardGenericDiscreteDisplayState();
}

class _ColumnWizardGenericDiscreteDisplayState extends State<ColumnWizardGenericDiscreteDisplay> {
  List<String> compareColumns = ['', ''];
  CarouselController carouselController = CarouselController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return widget.columnWizard.compare ? buildCompare(context) : buildSingle(context);
  }

  Widget buildSingle(BuildContext context) {
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
  }

  Widget buildCompare(BuildContext context) {
    if (compareColumns[0] == '' || compareColumns[1] == '') return compareSelection((widget.columnWizard as CounterCompareStats).getKeys());

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        compareSelection((widget.columnWizard as CounterCompareStats).getKeys()),
        descriptiveStatisticsCounterStatsCompare(),
        SizedBox(
          width: SizeConfig.safeBlockHorizontal(context) * 5,
        ),
        barDistributionPlotCompare(),
      ],
    );
  }

  Widget descriptiveStatisticsCounterStats() {
    final CounterStats columnWizard = widget.columnWizard as CounterStats;
    return FutureBuilder<Map<String, int>>(
      future: columnWizard.getCounts(), // Cached
      builder: (context, snapshot) {
        final List<Widget> classCounts = [];
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty && snapshot.data!.keys.length <= 20) {
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

  Widget descriptiveStatisticsCounterStatsCompare() {
    final CounterCompareStats columnWizard = widget.columnWizard as CounterCompareStats;
    return FutureBuilder<List<Map<String, int>>>(
      key: ValueKey('stats-${compareColumns.join('-')}-'),
      future: columnWizard.getCountsOfKeys(compareColumns[0], compareColumns[1]), // Cached
      builder: (context, snapshot) {
        final List<Widget> classCounts = [];
        final List<Widget> firstCounts = [];
        final List<Widget> secondCounts = [];

        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          firstCounts.addAll(
            snapshot.data![0].entries
                .sorted((e1, e2) => e1.value.compareTo(e2.value))
                .reversed
                .map((entry) => Text('${entry.key}: ${entry.value}')),
          );
          secondCounts.addAll(
            snapshot.data![1].entries
                .sorted((e1, e2) => e1.value.compareTo(e2.value))
                .reversed
                .map((entry) => Text('${entry.key}: ${entry.value}')),
          );

          classCounts.add(const Text('Class counts:'));
          classCounts.add(Row(children: [
            const Text('First Column:\n'),
            Column(children: firstCounts,),
            const SizedBox(width: 20),
            const Text('Second Column:\n'),
            Column(children: secondCounts,),
          ],),);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Descriptive Statistics:\n'),
            Row(children: [
              textFuture('Number values:', columnWizard.lengthOfKey(compareColumns[0])),
              textFuture(' - ', columnWizard.lengthOfKey(compareColumns[1])),
            ],),
            Row(children: [
              textFuture('Number different classes:', columnWizard.getCountsOfKey(compareColumns[0]).then((counts) => counts.keys.length)),
              textFuture(' - ', columnWizard.getCountsOfKey(compareColumns[1]).then((counts) => counts.keys.length)),
            ],),
            Row(children: [
              textFuture('Number missing values:', columnWizard.numberMissingOfKey(compareColumns[0])),
              textFuture(' - ', columnWizard.numberMissingOfKey(compareColumns[1])),
            ],),
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

  Widget barDistributionPlotCompare() {
    return Flexible(
      child: FutureBuilder<BiocentralBarComparePlotData>(
        future: (widget.columnWizard as CounterCompareStats).getBarPlotsData(compareColumns[0], compareColumns[1]), // TODO add compare
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            final BiocentralBarComparePlotData barPlotData = snapshot.data!;
            final BiocentralBarComparePlot barComparePlot = BiocentralBarComparePlot(
                data: barPlotData,
                xAxisLabel: 'Categories',
                yAxisLabel: 'Frequency',
              );
            // Todo add index for shown window

            return SizedBox(
              width: SizeConfig.screenWidth(context) * 0.4,
              height: SizeConfig.screenHeight(context) * 0.3,
              child: barComparePlot,
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

    return Text(maxDist['p_value'] as double > 0.5
      ? 'The distribution seems to be ${maxDist['dist_type']} distributed.'
      : 'The distribution does not fullfill the properties of any tested distribution. But it is the closest to a ${distributionResults.elementAt(0)['dist_type']} distributed.');
  }

  Widget getMostLiklyCompare(List<List<Map<String, dynamic>>> distributionResults) {
    final Map<String, dynamic> maxDistFirst = distributionResults[0].reduce((a, b) => a['p_value'] > b['p_value'] ? a : b);
    final Map<String, dynamic> maxDistSecond = distributionResults[1].reduce((a, b) => a['p_value'] > b['p_value'] ? a : b);

    if (maxDistFirst['p_value'] as double > 0.5 && maxDistSecond['p_value'] as double > 0.5) {
      return Text('The first distribution seems to be ${maxDistFirst['dist_type']} distributed and the second distribution seems to be ${maxDistSecond['dist_type']} distributed.');
    } else if (maxDistFirst['p_value'] as double > 0.5) {
      return Text('The first distribution seems to be ${maxDistFirst['dist_type']} distributed. The second distribution does not fullfill the properties of any tested distribution. But it is the closest to a ${distributionResults[1].elementAt(0)['dist_type']} distributed.');
    } else if (maxDistSecond['p_value'] as double > 0.5) {
      return Text('The second distribution seems to be ${maxDistSecond['dist_type']} distributed. The first distribution does not fullfill the properties of any tested distribution. But it is the closest to a ${distributionResults[0].elementAt(0)['dist_type']} distributed.');
    } else {
      return Text('Both distributions do not fullfill the properties of any tested distribution. But the first is the closest to a ${distributionResults[0].elementAt(0)['dist_type']} distributed and the second is the closest to a ${distributionResults[1].elementAt(0)['dist_type']} distributed.');
    }
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
            onSelected: (String? value) => WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => compareColumns = [value ?? '', compareColumns[1]],),),
          ),),
          const SizedBox(width: 16),
          Expanded(child: BiocentralDropdownMenu<String>(
            dropdownMenuEntries: keys
              .map((key) => DropdownMenuEntry(value: key, label: key))
              .toList(),
            label: const Text('Select second..'),
            initialSelection: compareColumns[1],
            onSelected: (String? value) => WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => compareColumns = [compareColumns[0], value ?? ''],),),
          ),),
        ],),
        const Text('Please select which Data you want to compare.'),
      ],
    );
  }
}
