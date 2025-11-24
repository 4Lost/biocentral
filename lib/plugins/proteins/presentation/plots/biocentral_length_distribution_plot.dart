import 'dart:math' as math;
import 'package:biocentral/sdk/data/biocentral_background_data.dart';
import 'package:flutter/material.dart';

class BiocentralLengthDistributionPlot extends StatefulWidget {
  final List<Map<String, Map<String, double>>> distributions;
  final bool showSecond;

  const BiocentralLengthDistributionPlot({
    required this.distributions,
    super.key,
    this.showSecond = true,
  });

  @override
  State<StatefulWidget> createState() => _BiocentralLengthDistributionPlotState();
}

class _BiocentralLengthDistributionPlotState extends State<BiocentralLengthDistributionPlot> {
  late List<Map<String, Map<String, double>>> _distributions;

  @override
  void initState() {
    _distributions = List.from(widget.distributions);
    if (_distributions.length < 2) _loadData();
    super.initState();
  }

  Future<void> _loadData() async {
    final data = await BiocentralBackgroundData.getAALengthDistribution();
    setState(() {
      _distributions.add(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _LengthDistributionPainter(
            _distributions,
            widget.showSecond,
          ),
        );
      },
    );
  }
}

class _LengthDistributionPainter extends CustomPainter {
  final List<Map<String, Map<String, double>>> data;
  final bool showSecond;
  final TextStyle plotTextStyle = const TextStyle(color: Colors.black, fontSize: 12);

  _LengthDistributionPainter(this.data, this.showSecond);

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPadding = 60;
    const double topPadding = 40;
    const double rightPadding = 150;
    const double bottomPadding = 60;

    final Offset plotOffset = const Offset(leftPadding, topPadding);
    final Size plotSize = Size(
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );

    // Extract KDE points
    final Map<String, double> kdeData = data[0]['length_kde']!;
    final List<_Point> kdePoints = kdeData.entries.map((entry) => _Point(double.parse(entry.key), entry.value)).toList();
    kdePoints.sort((a, b) => a.x.compareTo(b.x));

    final double leftCutoff = kdePoints.firstWhere((p) => p.y > 0.0, orElse: () => kdePoints.first).x;
    final double rightCutoff = kdePoints.lastWhere((p) => p.y > 0.0, orElse: () => kdePoints.last).x;

    // Draw KDE curve (already normalized)
    final Paint kdePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Path kdePath = Path();
    bool first = true;
    for (int i = 0; i < kdePoints.length; i++) {
      final _Point point = kdePoints[i];
      if (point.x < leftCutoff || point.x > rightCutoff) {
        continue;
      }
      final double x = plotOffset.dx + (point.x - leftCutoff) / (rightCutoff - leftCutoff) * plotSize.width;
      final double y = plotOffset.dy + plotSize.height * (1 - point.y);
      if (first) {
        kdePath.moveTo(x, y);
        first = false;
      } else {
        kdePath.lineTo(x, y);
      }
    }
    canvas.drawPath(kdePath, kdePaint);

    final Map<String, double> stats = data[0]['length_stats']!;
    highlightMeanAndStdDev(canvas, plotSize, plotOffset, stats, leftCutoff, rightCutoff, false);

    if (showSecond && data.length == 2) {
      // Draw background KDE
      final Map<String, double> bgKdeData = data[1]['length_kde']!;
      print(bgKdeData);
      final List<_Point> bgKdePoints = bgKdeData.entries.map((entry) => _Point(double.parse(entry.key), entry.value)).toList();

      final Paint bgKdePaint = Paint()
        ..color = Colors.pink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final Path bgKdePath = Path();
      bool bgFirst = true;
      for (int i = 0; i < bgKdePoints.length; i++) {
        final _Point point = bgKdePoints[i];
        if (point.x < leftCutoff || point.x > rightCutoff) {
          continue;
        }
        final double x = plotOffset.dx + (point.x - leftCutoff) / (rightCutoff - leftCutoff) * plotSize.width;
        final double y = plotOffset.dy + plotSize.height * (1 - point.y);
        if (bgFirst) {
          bgKdePath.moveTo(x, y);
          bgFirst = false;
        } else {
          bgKdePath.lineTo(x, y);
        }
      }
      canvas.drawPath(bgKdePath, bgKdePaint);

      final Map<String, double> bgStats = data[1]['length_stats']!;
      highlightMeanAndStdDev(canvas, plotSize, plotOffset, bgStats, leftCutoff, rightCutoff, true);
    }

    // Draw axes
    final Paint axesPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
        Offset(plotOffset.dx, plotOffset.dy + plotSize.height),
        Offset(plotOffset.dx + plotSize.width, plotOffset.dy + plotSize.height),
        axesPaint);
    canvas.drawLine(
        Offset(plotOffset.dx, plotOffset.dy),
        Offset(plotOffset.dx, plotOffset.dy + plotSize.height),
        axesPaint);


    // Draw x-axis ticks
    final int xTickCount = 5;
    for (int i = 0; i <= xTickCount; i++) {
      final double value = leftCutoff + (i / xTickCount) * (rightCutoff - leftCutoff);
      final double x = plotOffset.dx + (i / xTickCount) * plotSize.width;
      canvas.drawLine(Offset(x, plotSize.height + plotOffset.dy),
          Offset(x, plotSize.height + plotOffset.dy + 5), axesPaint);

      final textPainter = TextPainter(
        text: TextSpan(text: value.toStringAsFixed(1), style: plotTextStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(x - textPainter.width / 2, plotSize.height + plotOffset.dy + 7));
    }

    // Draw y-axis ticks
    final int yTickCount = 5;
    for (int i = 0; i <= yTickCount; i++) {
      final double y = plotSize.height * (1 - i / yTickCount);
      canvas.drawLine(Offset(plotOffset.dx - 5, y + plotOffset.dy),
          Offset(plotOffset.dx, y + plotOffset.dy), axesPaint);

      final textPainter = TextPainter(
        text: TextSpan(text: (i / yTickCount).toStringAsFixed(1), style: plotTextStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(plotOffset.dx - 10 - textPainter.width, y - textPainter.height / 2 + plotOffset.dy));
    }

    // Labels
    final xLabelPainter = TextPainter(
      text: TextSpan(text: 'Value', style: plotTextStyle),
      textDirection: TextDirection.ltr,
    );
    xLabelPainter.layout();
    xLabelPainter.paint(canvas, Offset(size.width / 2, size.height - xLabelPainter.height - 20));

    final yLabelPainter = TextPainter(
      text: TextSpan(text: 'Density', style: plotTextStyle),
      textDirection: TextDirection.ltr,
    );
    yLabelPainter.layout();
    canvas.save();
    canvas.translate(0, size.height / 2 + yLabelPainter.width / 2);
    canvas.rotate(-math.pi / 2);
    yLabelPainter.paint(canvas, Offset(0, plotOffset.dx / 4 - 10));
    canvas.restore();

    drawLegend(canvas, size);
  }


  void highlightMeanAndStdDev(Canvas canvas, Size plotSize, Offset plotOffset, Map<String, double> stats, double leftCutoff, double rightCutoff, bool isBackground) {
    if (leftCutoff > stats['mean']! || stats['mean']! > rightCutoff) return;

    final Color color = !isBackground ? Colors.green : Colors.purple;

    final Paint meanPaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Mean
    final double meanX = plotOffset.dx + (stats['mean']! - leftCutoff) / (rightCutoff - leftCutoff) * plotSize.width;
    canvas.drawLine(Offset(meanX, plotOffset.dy), Offset(meanX, plotOffset.dy + plotSize.height), meanPaint);
    
    // std deviation range
    final double leftStdDevX = stats['mean']! - stats['std_dev']! < leftCutoff ? plotOffset.dx :
      plotOffset.dx + (stats['mean']! - stats['std_dev']! - leftCutoff) / (rightCutoff - leftCutoff) * plotSize.width;
    final double rightStdDevX = stats['mean']! + stats['std_dev']! > rightCutoff ? plotOffset.dy :
      plotOffset.dx + (stats['mean']! + stats['std_dev']! - leftCutoff) / (rightCutoff - leftCutoff) * plotSize.width;

    canvas.drawLine(Offset(leftStdDevX, plotOffset.dy + plotSize.height),
        Offset(rightStdDevX, plotOffset.dy + plotSize.height), meanPaint);

    // Labels
    final TextPainter meanPainter = TextPainter(
      text: TextSpan(text: 'Mean', style: plotTextStyle.copyWith(color: color)),
      textDirection: TextDirection.ltr,
    );
    meanPainter.layout();
    meanPainter.paint(canvas, Offset(meanX - meanPainter.width / 2, plotOffset.dy - 15));

    final TextPainter stdDevPainter = TextPainter(
      text: TextSpan(text: '±1 StdDev', style: plotTextStyle.copyWith(color: color)),
      textDirection: TextDirection.ltr,
    );
    stdDevPainter.layout();
    stdDevPainter.paint(canvas,
        Offset((leftStdDevX + rightStdDevX) / 2 - stdDevPainter.width / 2,
            plotOffset.dy + plotSize.height - 15));
  }

  void drawLegend(Canvas canvas, Size size) {
    final double legendX = size.width - 130;
    double legendY = 50;
    const double boxSize = 12;
    const double spacing = 6;

    final entries = [
      {'label': 'Distribution', 'color': Colors.blue}, // %TODO : better names
      {'label': 'Distribution Stats', 'color': Colors.green}, // %TODO : better names
      if (showSecond && data.length == 2) {'label': 'Compare Data', 'color': Colors.pink},
      if (showSecond && data.length == 2) {'label': 'Compare Data Stats', 'color': Colors.purple},
    ];

    for (final entry in entries) {
      final paint = Paint()..color = entry['color'] as Color;
      canvas.drawRect(Rect.fromLTWH(legendX, legendY, boxSize, boxSize), paint);

      final tp = TextPainter(
        text: TextSpan(text: entry['label'] as String, style: plotTextStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(legendX + boxSize + spacing, legendY - 2));

      legendY += boxSize + spacing + 4;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Point {
  final double x;
  final double y;
  _Point(this.x, this.y);
}
