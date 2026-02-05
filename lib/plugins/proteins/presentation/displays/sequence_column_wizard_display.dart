import 'package:biocentral/plugins/proteins/model/sequence_column_wizard.dart';
import 'package:biocentral/plugins/proteins/presentation/plots/biocentral_length_distribution_plot.dart';
import 'package:biocentral/plugins/proteins/presentation/plots/biocentral_scale_plot.dart';
import 'package:biocentral/plugins/proteins/presentation/plots/biocentral_sequence_distribution_plot.dart';
import 'package:biocentral/plugins/proteins/presentation/plots/biocentral_positional_sequence_distribution_plot.dart';
import 'package:biocentral/sdk/biocentral_sdk.dart';
import 'package:biocentral/sdk/util/point.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:widgets_to_image/widgets_to_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html show Blob, AnchorElement, Url;

class SequenceColumnWizardDisplay extends StatefulWidget {
  final SequenceColumnWizard columnWizard;

  const SequenceColumnWizardDisplay({required this.columnWizard, super.key});

  @override
  State<SequenceColumnWizardDisplay> createState() => _SequenceColumnWizardDisplayState();
}

class _SequenceColumnWizardDisplayState extends State<SequenceColumnWizardDisplay> {
  List<bool> compareValues = [true, true, true, true, true, true, true, true, true, true, true, true];
  List<String> compareColumns = ['', ''];
  List<Widget> widgets = [];
  List<WidgetsToImageController> controllers = [];
  List<String> widgetNames = [
    'kde_length',
    'bar_AA_distribution',
    'bar_pos_AA_distribution',
    'kde_alpha-helix',
    'kde_beta-sheet',
    'kde_coil',
    'kde_freeEnergy',
    'kde_hydrophobicity',
    'kde_mutability',
    'kde_stability',
    'kde_volume',
  ];

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

        widgets = [
          buildLengthCompositionPlot([snapshot.data!.lenKdePoints], [snapshot.data!.lenStats]),
          buildCompositionPlot([snapshot.data!.seqDistribution]),
          buildPositionalCompositionPlot([snapshot.data!.posSeqDistribution]),
          buildScalePlot('alphaHelix', [snapshot.data!.getScaleStats('alphaHelix')], 8),
          buildScalePlot('betaSheet', [snapshot.data!.getScaleStats('betaSheet')], 9),
          buildScalePlot('coil', [snapshot.data!.getScaleStats('coil')], 10),
          buildScalePlot('freeEnergy', [snapshot.data!.getScaleStats('freeEnergy')], 5),
          buildScalePlot('hydrophobicity', [snapshot.data!.getScaleStats('hydrophobicity')], 4),
          buildScalePlot('mutability', [snapshot.data!.getScaleStats('mutability')], 11),
          buildScalePlot('stability', [snapshot.data!.getScaleStats('stability')], 6),
          buildScalePlot('volume', [snapshot.data!.getScaleStats('volume')], 7),
        ];
        controllers.addAll(widgets.map((_) => WidgetsToImageController()));

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildSequenceStats(),
            SizedBox(
              width: SizeConfig.safeBlockHorizontal(context) * 5,
            ),
            WidgetsToImage(
              controller: controllers[0],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Length Distribution\n', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  widgets[0],
                ],
              ),
            ),
            toggleCompareButton(1),
            WidgetsToImage(
              controller: controllers[1],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Protein Distribution\n', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  widgets[1],
                ],
              ),
            ),
            toggleCompareButton(2),
            WidgetsToImage(
              controller: controllers[2],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Positional Protein Distribution\n', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  widgets[2],
                ],
              ),
            ),
            toggleCompareButton(3),
            WidgetsToImage(
              controller: controllers[3],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Alpha Helix\n', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  widgets[3],
                ],
              ),
            ),
            toggleCompareButton(4),
            WidgetsToImage(
              controller: controllers[4],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Beta Sheet\n', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  widgets[4],
                ],
              ),
            ),
            toggleCompareButton(5),
            WidgetsToImage(
              controller: controllers[5],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Coil\n', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  widgets[5],
                ],
              ),
            ),
            toggleCompareButton(6),
            WidgetsToImage(
              controller: controllers[6],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Free Energy\n', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  widgets[6],
                ],
              ),
            ),
            toggleCompareButton(7),
            WidgetsToImage(
              controller: controllers[7],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Hydrophobicity\n', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  widgets[7],
                ],
              ),
            ),
            toggleCompareButton(8),
            WidgetsToImage(
              controller: controllers[8],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Mutability\n', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  widgets[8],
                ],
              ),
            ),
            toggleCompareButton(9),
            WidgetsToImage(
              controller: controllers[9],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Stability\n', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  widgets[9],
                ],
              ),
            ),
            toggleCompareButton(10),
            WidgetsToImage(
              controller: controllers[10],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Volume\n', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  widgets[10],
                ],
              ),
            ),
            toggleCompareButton(11),
            FloatingActionButton(
              onPressed: saveAllToImages,
              child: Icon(Icons.save),
            ),
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

        widgets = [
          buildLengthCompositionPlot([snapshot.data![0].lenKdePoints, snapshot.data![1].lenKdePoints], [snapshot.data![0].lenStats, snapshot.data![1].lenStats]),
          buildCompositionPlot([snapshot.data![0].seqDistribution, snapshot.data![1].seqDistribution]),
          buildPositionalCompositionPlot([snapshot.data![0].posSeqDistribution, snapshot.data![1].posSeqDistribution]),
          buildScalePlot('alphaHelix', [snapshot.data![0].getScaleStats('alphaHelix'), snapshot.data![1].getScaleStats('alphaHelix')], 12),
          buildScalePlot('betaSheet', [snapshot.data![0].getScaleStats('betaSheet'), snapshot.data![1].getScaleStats('betaSheet')], 12),
          buildScalePlot('coil', [snapshot.data![0].getScaleStats('coil'), snapshot.data![1].getScaleStats('coil')], 12),
          buildScalePlot('freeEnergy', [snapshot.data![0].getScaleStats('freeEnergy'), snapshot.data![1].getScaleStats('freeEnergy')], 12),
          buildScalePlot('hydrophobicity', [snapshot.data![0].getScaleStats('hydrophobicity'), snapshot.data![1].getScaleStats('hydrophobicity')], 12),
          buildScalePlot('mutability', [snapshot.data![0].getScaleStats('mutability'), snapshot.data![1].getScaleStats('mutability')], 12),
          buildScalePlot('stability', [snapshot.data![0].getScaleStats('stability'), snapshot.data![1].getScaleStats('stability')], 12),
          buildScalePlot('volume', [snapshot.data![0].getScaleStats('volume'), snapshot.data![1].getScaleStats('volume')], 12),
        ];
        controllers.addAll(widgets.map((_) => WidgetsToImageController()));

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildCompareSequenceStats(compareColumns[0], compareColumns[1]),
            WidgetsToImage(
              controller: controllers[0],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Length Distribution\n'),
                  widgets[0],
                ],
              ),
            ),
            WidgetsToImage(
              controller: controllers[1],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Protein Distribution\n'),
                  widgets[1],
                ],
              ),
            ),
            WidgetsToImage(
              controller: controllers[2],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Positional Protein Distribution\n'),
                  widgets[2],
                ],
              ),
            ),
            WidgetsToImage(
              controller: controllers[3],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Alpha Helix\n'),
                  widgets[3],
                ],
              ),
            ),
            WidgetsToImage(
              controller: controllers[4],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Beta Sheet\n'),
                  widgets[4],
                ],
              ),
            ),
            WidgetsToImage(
              controller: controllers[5],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Coil\n'),
                  widgets[5],
                ],
              ),
            ),
            WidgetsToImage(
              controller: controllers[6],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Free Energie\n'),
                  widgets[6],
                ],
              ),
            ),
            WidgetsToImage(
              controller: controllers[7],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Hydrophobicity\n'),
                  widgets[7],
                ],
              ),
            ),
            WidgetsToImage(
              controller: controllers[8],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Mutability\n'),
                  widgets[8],
                ],
              ),
            ),
            WidgetsToImage(
              controller: controllers[9],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Stability\n'),
                  widgets[9],
                ],
              ),
            ),
            WidgetsToImage(
              controller: controllers[10],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Volume\n'),
                  widgets[10],
                ],
              ),
            ),
            FloatingActionButton(
              onPressed: saveAllToImages,
              child: Icon(Icons.save),
            ),
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
      height: 800,
      child: BiocentralLengthDistributionPlot(distributions: lenDist, stats: lenStats, showSecond: compareValues[0],),
    );
  }

  Widget buildCompositionPlot(List<Map<String, double>> data) {
    return SizedBox(
      key: Key('2-${compareColumns[0]}-${compareColumns[1]}'),
      width: 2000,
      height: 800,
      child: BiocentralSequenceDistributionPlot(distributions: data, showSecond: compareValues[1],),
    );
  }

  Widget buildPositionalCompositionPlot(List<Map<int, Map<String, double>>> data) {
    return SizedBox(
      key: Key('3-${compareColumns[0]}-${compareColumns[1]}'),
      width: 2000,
      height: 800,
      child: BiocentralPositionalSequenceDistributionPlot(distributions: data, showSecond: compareValues[2],),
    );
  }

  Widget buildScalePlot(String feature, List<PointScaleStats> data, int compareIndex) {
    return SizedBox(
      key: Key('4-$feature-${compareColumns[0]}-${compareColumns[1]}'),
      width: 2000,
      height: 800,
      child: BiocentralScalePlot(scaleStats: data, showSecond: compareValues[compareIndex - 1], feature: feature,),
    );
  }

  Future<void> saveAllToImages() async {
    for (int i = 0; i < controllers.length; i++) {
      try {
        final Uint8List? bytes = await controllers[i].capturePng(pixelRatio: 2.0);
        if (bytes != null) {
          if (kIsWeb) {
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.AnchorElement(href: url)
            ..setAttribute('download', '${widgetNames[i]}.png')
            ..click();
          html.Url.revokeObjectUrl(url);
        } else {
          final file = File('${widgetNames[i]}.png');
          await file.writeAsBytes(bytes);
        }
        }
      } catch (e) {
        print('Failed to capture widget $i: $e');
      }
    }
  }
}
