import 'dart:math' as math;
import 'package:biocentral/plugins/proteins/model/sequence_column_wizard.dart';
import 'package:biocentral/sdk/data/biocentral_background_data.dart';
import 'package:biocentral/sdk/util/point.dart';
import 'package:flutter/material.dart';

class BiocentralScalePlot extends StatefulWidget {
  final List<PointScaleStats> scaleStats;
  final String feature;
  final double bandwidth;
  final bool showSecond;

  const BiocentralScalePlot({
    required this.scaleStats,
    required this.feature,
    super.key,
    this.bandwidth = 20,
    this.showSecond = true,
  });

  @override
  State<StatefulWidget> createState() => _BiocentralScalePlotState();
}

class _BiocentralScalePlotState extends State<BiocentralScalePlot> {
  late List<PointScaleStats> _scaleStats;

  @override
  void initState() {
    _scaleStats = List.from(widget.scaleStats);
    if (_scaleStats.length < 2) _loadData();
    super.initState();
  }

  Future<void> _loadData() async {
    final data = await BiocentralBackgroundData.getScale(widget.feature);
    setState(() {
      _scaleStats.add(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _ScalePainter(
            _scaleStats,
            widget.bandwidth,
            widget.showSecond,
          ),
        );
      },
    );
  }
}

class _ScalePainter extends CustomPainter {
  final List<PointScaleStats> scaleStats;
  final double bandwidth;
  final bool showSecond;
  final TextStyle plotTextStyle = const TextStyle(color: Colors.black, fontSize: 12);

  _ScalePainter(this.scaleStats, this.bandwidth, this.showSecond);

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

    Offset range = Offset(scaleStats[0].values[0].x, scaleStats[0].values[scaleStats[0].values.length - 1].x);
    if (showSecond && scaleStats.length == 2) {
      range = Offset(
        math.min(range.dx, scaleStats[1].values[0].x),
        math.max(range.dy, scaleStats[1].values[scaleStats[0].values.length - 1].x),
      );
    }
    // Find global max density across all datasets
    double maxDensity = 0.0;
    maxDensity = math.max(maxDensity, scaleStats[0].values.map((p) => p.y).reduce(math.max));
    if (showSecond && scaleStats.length == 2) {
      maxDensity = math.max(maxDensity, scaleStats[1].values.map((p) => p.y).reduce(math.max));
    }

    drawKdePlot(canvas, scaleStats[0].values, range, plotSize, plotOffset, maxDensity, false);
    highlightMeanAndStdDev(canvas, plotSize, plotOffset, range.dx, range.dy, scaleStats[0].mean, scaleStats[0].stdDev, false);
    if (showSecond && scaleStats.length == 2) {
      drawKdePlot(canvas, scaleStats[1].values, range, plotSize, plotOffset, maxDensity, true);
      highlightMeanAndStdDev(canvas, plotSize, plotOffset, range.dx, range.dy, scaleStats[1].mean, scaleStats[1].stdDev, true);
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
      final double value = range.dx + (i / xTickCount) * (range.dy - range.dx); //TODO fix for two with cutoff
      final double x = plotOffset.dx + (i / xTickCount) * plotSize.width;
      canvas.drawLine(Offset(x, plotSize.height + plotOffset.dy),
          Offset(x, plotSize.height + plotOffset.dy + 5), axesPaint);

      final textPainter = TextPainter(
        text: TextSpan(text: value.toStringAsFixed(2), style: plotTextStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(x - textPainter.width / 2, plotSize.height + plotOffset.dy + 7));
    }

    // Draw y-axis ticks
    final int yTickCount = 5;
    for (int i = 0; i <= yTickCount; i++) {
      final double yValue = (i / yTickCount) * maxDensity;  // Scale ticks to maxDensity
      final double y = plotSize.height * (1 - i / yTickCount);
      // ... rest of tick drawing code unchanged
      final textPainter = TextPainter(
        text: TextSpan(text: yValue.toStringAsFixed(4), style: plotTextStyle),  // Show actual density values
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

  void drawKdePlot(Canvas canvas, List<Point> kdePoints, Offset range, Size plotSize, Offset plotOffset, double maxDensity, bool isCompare) {
    // Draw KDE curve (already normalized)
    final Paint kdePaint = Paint()
      ..color = isCompare ? Colors.pink : Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Path kdePath = Path();
    bool firstPoint = true;
    
    if (kdePoints[0].x != range.dx) {
      kdePath.moveTo(plotOffset.dx, plotOffset.dy + plotSize.height);
      kdePath.lineTo(plotOffset.dx + (kdePoints[0].x - range.dx) / (range.dy - range.dx) * plotSize.width, plotOffset.dy + plotSize.height);
    }
    for (int i = 0; i < kdePoints.length; i++) {
      final Point point = kdePoints[i];
      final double x = plotOffset.dx + (point.x - range.dx) / (range.dy - range.dx) * plotSize.width;
      final double y = plotOffset.dy + plotSize.height * (1 - point.y / maxDensity);
      if (firstPoint) {
        kdePath.moveTo(x, y);
        firstPoint = false;
      } else {
        kdePath.lineTo(x, y);
      }
    }
    if (kdePoints[kdePoints.length - 1].x != range.dy) {
      kdePath.lineTo(plotOffset.dx + (kdePoints[kdePoints.length - 1].x - range.dx) / (range.dy - range.dx) * plotSize.width, plotOffset.dy + plotSize.height);
      kdePath.lineTo(plotOffset.dx + plotSize.width, plotOffset.dy + plotSize.height);
    }

    canvas.drawPath(kdePath, kdePaint);
  }

  void highlightMeanAndStdDev(
      Canvas canvas, Size plotSize, Offset plotOffset, double minValue, double maxValue, double mean, double stdDev, bool isCompare,) {
    final Paint meanPaint = Paint()
      ..color = isCompare? Colors.purple : Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final double meanX = plotOffset.dx + (mean - minValue) / (maxValue - minValue) * (plotSize.width - plotOffset.dx);

    // Draw mean line
    canvas.drawLine(Offset(meanX, plotOffset.dy), Offset(meanX, plotOffset.dy + plotSize.height), meanPaint);

    // Draw standard deviation range
    final double clampedLeftValue = math.max(minValue, mean - stdDev);
    final double clampedRightValue = math.min(maxValue, mean + stdDev);
    final double leftStdDevX = plotOffset.dx + (clampedLeftValue - minValue) / (maxValue - minValue) * plotSize.width;
    final double rightStdDevX = plotOffset.dx + (clampedRightValue - minValue) / (maxValue - minValue) * plotSize.width;

    canvas.drawLine(Offset(leftStdDevX, plotOffset.dy + plotSize.height),
        Offset(rightStdDevX, plotOffset.dy + plotSize.height), meanPaint,);

    // Add labels
    final TextPainter meanPainter = TextPainter(
      text: TextSpan(text: 'Mean', style: plotTextStyle.copyWith(color: meanPaint.color)),
      textDirection: TextDirection.ltr,
    );
    meanPainter.layout();
    meanPainter.paint(canvas, Offset(meanX - meanPainter.width / 2, plotOffset.dy - 15));

    final TextPainter stdDevPainter = TextPainter(
      text: TextSpan(text: '±1 StdDev', style: plotTextStyle.copyWith(color: meanPaint.color)),
      textDirection: TextDirection.ltr,
    );
    stdDevPainter.layout();
    stdDevPainter.paint(canvas,
        Offset((leftStdDevX + rightStdDevX) / 2 - stdDevPainter.width / 2, plotOffset.dy + plotSize.height - 15),);
  }


  void drawLegend(Canvas canvas, Size size) {
    final double legendX = size.width - 130;
    double legendY = 50;
    const double boxSize = 12;
    const double spacing = 6;

    final entries = [
      {'label': 'Scale Values', 'color': Colors.blue}, // %TODO : better names
      {'label': 'Scale Stats', 'color': Colors.green}, // %TODO : better names
      if (showSecond && scaleStats.length == 2) {'label': 'Compare Scale', 'color': Colors.pink},
      if (showSecond && scaleStats.length == 2) {'label': 'Compare Scale Stats', 'color': Colors.purple},
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
