import 'package:biocentral/sdk/model/column_wizard_abstract.dart';
import 'package:biocentral/sdk/presentation/plots/biocentral_histogram_kde_plot.dart';
import 'package:biocentral/sdk/presentation/plots/biocentral_q_q_plot.dart';
import 'package:biocentral/sdk/presentation/widgets/biocentral_drop_down_menu.dart';
import 'package:biocentral/sdk/util/constants.dart';
import 'package:biocentral/sdk/util/size_config.dart';
import 'package:flutter/material.dart';

class ColumnWizardGenericNotDiscreteDisplay extends StatefulWidget {
  final ColumnWizard columnWizard;

  const ColumnWizardGenericNotDiscreteDisplay({required this.columnWizard, super.key});

  @override
  State<StatefulWidget> createState() => _ColumnWizardGenericNotDiscreteDisplayState();
}

class _ColumnWizardGenericNotDiscreteDisplayState extends State<ColumnWizardGenericNotDiscreteDisplay> {
  Future<bool> handleAsDiscrete = Future.value(false);
  int _focusWindow = 0;
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
        distributionNumericStats(),
      ],
    );
  }

  Widget buildCompare(BuildContext context) {
    if (compareColumns[0] == '' || compareColumns[1] == '') return compareSelection((widget.columnWizard as NumericCompareStats).getKeys());

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        compareSelection((widget.columnWizard as NumericCompareStats).getKeys()),
        distributionNumericStatsCompare(),
      ],
    );
  }

  Widget distributionNumericStats() {
    final NumericStats columnWizard = widget.columnWizard as NumericStats;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Distribution Statistics:\n'),
        FutureBuilder<List<Map<String, dynamic>>?>(
            future: columnWizard.getDistributions(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              if (snapshot.data == null) return const Text('Loading of the distribution data failed.');
              
              final List<Map<String, dynamic>> distributionResults = snapshot.data!;

              distributionResults.sort((a, b) {
                final aValue = a['p_value'] as double;
                final bValue = b['p_value'] as double;
                return aValue.compareTo(bValue);
              });
              final List<TableRow> resultTextRows = distributionResults
                  .map((distributionMap) => TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text('${distributionMap['dist_type']}:'),
                      ),
                      const SizedBox(width: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          '  ${(distributionMap['p_value'] as double) < 0.005 ? (0.0).toString() : distributionMap['p_value'].toString()}',
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),).toList();
              final SizedBox recommentionDist = SizedBox(
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

  Widget distributionNumericStatsCompare() {
    final NumericCompareStats columnWizard = widget.columnWizard as NumericCompareStats;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Distribution Statistics:\n'),
        FutureBuilder<List<List<Map<String, dynamic>>>?>(
            future: columnWizard.getDistributions(compareColumns[0], compareColumns[1]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              if (snapshot.data == null) return const Text('Loading of the distribution data failed.');
              
              final List<List<Map<String, dynamic>>> distributionResults = snapshot.data!;

              final List<TableRow> resultTextRows = distributionResults
                  .map((distributionMap) => TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text('${distributionMap[0]['dist_type']}:'),
                      ),
                      const SizedBox(width: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          (distributionMap[0]['p_value'] as double) < 0.005 ? (0.0).toString() : distributionMap[0]['p_value'].toString(),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          ' - ${(distributionMap[1]['p_value'] as double) < 0.005 ? (0.0).toString() : distributionMap[1]['p_value'].toString()}',
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),).toList();
              final SizedBox recommentionDist = SizedBox(
                width: SizeConfig.screenHeight(context) * 0.5,
                child: getMostLiklyCompare(distributionResults),
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
                  children: [ // TODO add compare plots
                    BiocentralHistogramKDEPlot(data: columnWizard.numericValues(compareColumns[0]).toList(), focus: _focusWindow == 0 ? true : false),
                    BiocentralQQPlot(data: columnWizard.numericValues(compareColumns[0]).toList(), focus: _focusWindow == 1 ? true : false),
                  ],
                ),
              ),
            ),
          ],
        ), 
      ],
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
