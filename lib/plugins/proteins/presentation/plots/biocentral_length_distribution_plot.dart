import 'dart:math' as math;
import 'package:biocentral/sdk/data/biocentral_background_data.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class BiocentralLengthDistributionPlot extends StatefulWidget {
  final List<List<double>> distributions;
  final List<Map<String, double>> stats;
  final double bandwidth;
  final bool showSecond;

  const BiocentralLengthDistributionPlot({
    required this.distributions,
    required this.stats,
    super.key,
    this.bandwidth = 20,
    this.showSecond = true,
  });

  @override
  State<StatefulWidget> createState() => _BiocentralLengthDistributionPlotState();
}

class _BiocentralLengthDistributionPlotState extends State<BiocentralLengthDistributionPlot> {
  late List<List<double>> _distributions;
  late List<Map<String, double>> _stats;

  @override
  void initState() {
    _distributions = List.from(widget.distributions);
    _stats = List.from(widget.stats);
    if (_distributions.length < 2) _loadData();
    super.initState();
  }

  Future<void> _loadData() async {
    final dist = await BiocentralBackgroundData.getAALengthDistribution();
    final stats = await BiocentralBackgroundData.getAALengthStats();
    setState(() {
      _distributions.add(dist);
      _stats.add(stats);
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
            _stats,
            widget.bandwidth,
            widget.showSecond,
          ),
        );
      },
    );
  }
}

class _LengthDistributionPainter extends CustomPainter {
  final List<List<double>> distributions;
  final List<Map<String, double>> stats;
  final double bandwidth;
  final bool showSecond;
  final TextStyle plotTextStyle = const TextStyle(color: Colors.black, fontSize: 12);

  _LengthDistributionPainter(this.distributions, this.stats, this.bandwidth, this.showSecond);

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

    final List<_Point> kdePoints = getKdePlotPoints(distributions[0], stats[0], plotOffset);
    List<_Point> bgKdePoints = [];
    if (showSecond && distributions.length == 2) {
      bgKdePoints = getKdePlotPoints(distributions[1], stats[1], plotOffset);
    }

    Offset range = Offset(kdePoints[0].x, kdePoints[kdePoints.length - 1].x);
    if (showSecond && distributions.length == 2) {
      range = Offset(
        math.min(range.dx, bgKdePoints[0].x),
        math.max(range.dy, bgKdePoints[bgKdePoints.length - 1].x),
      );
    }
    // Find global max density across all datasets
    double maxDensity = 0.0;
    maxDensity = math.max(maxDensity, kdePoints.map((p) => p.y).reduce(math.max));
    if (showSecond && distributions.length == 2) {
      maxDensity = math.max(maxDensity, bgKdePoints.map((p) => p.y).reduce(math.max));
    }

    drawKdePlot(canvas, kdePoints, range, plotSize, plotOffset, maxDensity, false);
    highlightMeanAndStdDev(canvas, plotSize, plotOffset, range.dx, range.dy, stats[0]['mean']!, stats[0]['std_dev']!, false);
    if (showSecond && distributions.length == 2) {
      drawKdePlot(canvas, bgKdePoints, range, plotSize, plotOffset, maxDensity, true);
      highlightMeanAndStdDev(canvas, plotSize, plotOffset, range.dx, range.dy, stats[1]['mean']!, stats[1]['std_dev']!, true);
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

  List<_Point> getKdePlotPoints(List<double> data, Map<String, double> stats, Offset plotOffset) {
    // Calculate metrics
    final double range = stats['max']! - stats['min']!;

    // Compute KDE
    final List<_Point> kdePoints = [];
    for (int i = 0; i <= 100; i++) {
      final double x = stats['min']! + (i / 100) * range;
      double y = plotOffset.dy;
      for (final value in data) {
        y += math.exp(-math.pow(x - value, 2) / (2 * bandwidth * bandwidth));
      }
      y /= data.length * bandwidth * math.sqrt(2 * math.pi);
      kdePoints.add(_Point(x, y));
    }

    // Normalize KDE
    final double sumKDE = kdePoints.map((p) => p.y).sum;
    final List<_Point> normalizedKDE = kdePoints.map((p) => _Point(p.x, p.y / sumKDE)).toList();
    return normalizedKDE;
  }

  void drawKdePlot(Canvas canvas, List<_Point> kdePoints, Offset range, Size plotSize, Offset plotOffset, double maxDensity, bool isCompare) {
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
      final _Point point = kdePoints[i];
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
    final double leftStdDevX = plotOffset.dx + (mean - stdDev - minValue) / (maxValue - minValue) * plotSize.width;
    final double rightStdDevX = plotOffset.dx + (mean + stdDev - minValue) / (maxValue - minValue) * plotSize.width;

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
      {'label': 'Distribution', 'color': Colors.blue}, // %TODO : better names
      {'label': 'Distribution Stats', 'color': Colors.green}, // %TODO : better names
      if (showSecond && distributions.length == 2) {'label': 'Compare Data', 'color': Colors.pink},
      if (showSecond && distributions.length == 2) {'label': 'Compare Data Stats', 'color': Colors.purple},
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
