import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class BiocentralAAKDEPlot extends StatefulWidget {
  final bool? focus;

  const BiocentralAAKDEPlot({
    super.key,
    this.focus,
  });

  @override
  State<StatefulWidget> createState() => _BiocentralAAKDEPlotState();
}

class _BiocentralAAKDEPlotState extends State<BiocentralAAKDEPlot> {
  Map<String, dynamic>? jsonData;

  @override
  void initState() {
    super.initState();
    _loadJson();
  }

  Future<void> _loadJson() async {
    final contents = await rootBundle.loadString('assets/background_dist/distribution_AA.json');
    final data = jsonDecode(contents);
    setState(() {
      jsonData = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (jsonData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _KDEPainter(jsonData!, widget.focus ?? true),
        );
      },
    );
  }
}

class _KDEPainter extends CustomPainter {
  final Map<String, dynamic> jsonData;
  final bool focus;
  final TextStyle plotTextStyle =
      const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold);

  _KDEPainter(this.jsonData, this.focus);

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPadding = 60;
    const double topPadding = 40;
    const double rightPadding = 40;
    const double bottomPadding = 60;

    final Offset plotOffset = const Offset(leftPadding, topPadding);
    final Size plotSize = Size(
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );

    // Extract stats from JSON
    final Map<String, dynamic> stats = jsonData['length_stats'];
    final double minValue = stats['min'].toDouble();
    final double maxValue = stats['max'].toDouble();
    final double mean = stats['mean'].toDouble();
    final double stdDev = stats['std_dev'].toDouble();

    // Extract KDE points
    final List<dynamic> kdeData = jsonData['length_kde'];
    final List<_Point> kdePoints =
        kdeData.map((p) => _Point((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList();

    // Draw KDE curve (already normalized)
    final Paint kdePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Path kdePath = Path();
    for (int i = 0; i < kdePoints.length; i++) {
      final _Point point = kdePoints[i];
      final double x = plotOffset.dx + (point.x - minValue) / (maxValue - minValue) * plotSize.width;
      final double y = plotOffset.dy + plotSize.height * (1 - point.y);
      if (i == 0) {
        kdePath.moveTo(x, y);
      } else {
        kdePath.lineTo(x, y);
      }
    }
    canvas.drawPath(kdePath, kdePaint);

    // Highlight Mean and Standard Deviation
    highlightMeanAndStdDev(canvas, plotSize, plotOffset, minValue, maxValue, mean, stdDev);

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

    if (focus) {
      // Draw x-axis ticks
      final int xTickCount = 5;
      for (int i = 0; i <= xTickCount; i++) {
        final double value = minValue + (i / xTickCount) * (maxValue - minValue);
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
    }
  }

  void highlightMeanAndStdDev(Canvas canvas, Size plotSize, Offset plotOffset,
      double minValue, double maxValue, double mean, double stdDev) {
    final Paint meanPaint = Paint()
      ..color = Colors.purple
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final double meanX = plotOffset.dx + (mean - minValue) / (maxValue - minValue) * plotSize.width;

    // Draw mean line
    canvas.drawLine(Offset(meanX, plotOffset.dy), Offset(meanX, plotOffset.dy + plotSize.height), meanPaint);

    // Draw std deviation range
    final double leftStdDevX =
        plotOffset.dx + (mean - stdDev - minValue) / (maxValue - minValue) * plotSize.width;
    final double rightStdDevX =
        plotOffset.dx + (mean + stdDev - minValue) / (maxValue - minValue) * plotSize.width;

    canvas.drawLine(Offset(leftStdDevX, plotOffset.dy + plotSize.height),
        Offset(rightStdDevX, plotOffset.dy + plotSize.height), meanPaint);

    if (focus) {
      // Labels
      final TextPainter meanPainter = TextPainter(
        text: TextSpan(text: 'Mean', style: plotTextStyle.copyWith(color: Colors.purple)),
        textDirection: TextDirection.ltr,
      );
      meanPainter.layout();
      meanPainter.paint(canvas, Offset(meanX - meanPainter.width / 2, plotOffset.dy - 15));

      final TextPainter stdDevPainter = TextPainter(
        text: TextSpan(text: '±1 StdDev', style: plotTextStyle.copyWith(color: Colors.purple)),
        textDirection: TextDirection.ltr,
      );
      stdDevPainter.layout();
      stdDevPainter.paint(canvas,
          Offset((leftStdDevX + rightStdDevX) / 2 - stdDevPainter.width / 2,
              plotOffset.dy + plotSize.height - 15));
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
