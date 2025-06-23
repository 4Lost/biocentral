import 'dart:math' as math;

import 'package:biocentral/sdk/biocentral_sdk.dart';
import 'package:biocentral/sdk/data/biocentral_python_companion.dart';
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';

class BiocentralTestDistributionPlot extends StatelessWidget {
  final List<double> data;
  final ColumnWizard columnWizard;

  const BiocentralTestDistributionPlot({
    required this.data, required this.columnWizard, super.key
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _CIPainter(data, columnWizard),
        );
      },
    );
  }
}

class _CIPainter extends CustomPainter {
  final List<double> data;
  final ColumnWizard columnWizard;
  final TextStyle plotTextStyle = const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold);

  _CIPainter(this.data, this.columnWizard);

  @override
  void paint(Canvas canvas, Size size) async {
    const double padding = 60;

    final Size plotSize = Size(size.width - padding, size.height - padding);
    final Offset plotOffset = const Offset(padding, 0);

    // Calculate metrics
      final Map<String, dynamic> dist = await (columnWizard as NumericStats).getMostLikelyResult();






    // Calculate Confidence Intervals
    data.sort();
    // final List<double> confidenceLevels = [0.5, 0.6, 0.7, 0.8, 0.9, 0.975];
    // getConfidenceIntervals(data, confidenceLevels, mean, stdDev);
    final List<_Point> qqPoints = getQQPoints(data, dist);

    // Min & Max
    double min = math.min(qqPoints.map((p) => p.x).reduce(math.min),qqPoints.map((p) => p.y).reduce(math.min));
    double max = math.max(qqPoints.map((p) => p.x).reduce(math.max),qqPoints.map((p) => p.y).reduce(math.max));

    // Scale of the Canvas
    final Offset shownArea = Offset(((min - 5)/10).floor() * 10, ((max + 5)/10).ceil() * 10);

    // Draw Points
    final Paint qqPaint = Paint()
      ..color = Colors.orange.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    for (_Point point in qqPoints){
      final double scaledX = (point.x - shownArea.dx)/(shownArea.dy - shownArea.dx)*(size.width - padding);
      final double scaledY = (point.y - shownArea.dx)/(shownArea.dy - shownArea.dx)*(size.height - padding);
      canvas.drawCircle(Offset(padding + scaledX, size.height - padding - scaledY), 0.1, qqPaint);
    }
    // Draw diagonal
    final Paint diagonalPaint = Paint()
      ..color = Colors.purple
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw normal line
    canvas.drawLine(Offset(plotOffset.dx, size.height - padding), Offset(size.width, 0), diagonalPaint);

    // Draw legend
    drawLegend(canvas, size);

    // Draw axes
    final Paint axesPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(Offset(padding, plotSize.height), Offset(size.width, plotSize.height), axesPaint);
    canvas.drawLine(const Offset(padding, 0), Offset(padding, plotSize.height), axesPaint);

    final double range = shownArea.dy - shownArea.dx;

    // Draw x-axis annotations
    final int xTickCount = 5;
    for (int i = 0; i <= xTickCount; i++) {
      final double value = shownArea.dx + (i / xTickCount) * range;
      final double x = plotOffset.dx + (i / xTickCount) * plotSize.width;
      canvas.drawLine(Offset(x, plotSize.height), Offset(x, plotSize.height + 5), axesPaint);

      final textPainter = TextPainter(
        text: TextSpan(text: value.toStringAsFixed(1), style: plotTextStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, plotSize.height + 7));
    }

    // Draw y-axis annotations
    final int yTickCount = 5;
    for (int i = 0; i <= yTickCount; i++) {
      final double value = shownArea.dy - (i / xTickCount) * range;
      final double y = plotSize.height * (i / yTickCount);
      canvas.drawLine(Offset(padding - 5, y), Offset(padding, y), axesPaint);

      final textPainter = TextPainter(
        text: TextSpan(text: value.toStringAsFixed(1), style: plotTextStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(padding - 10 - textPainter.width, y - textPainter.height / 2));
    }

    // Add labels
    final xLabelPainter = TextPainter(
      text: TextSpan(text: 'Normal theoretical quantiles', style: plotTextStyle),
      textDirection: TextDirection.ltr,
    );
    xLabelPainter.layout();
    xLabelPainter.paint(canvas, Offset(size.width / 2 - xLabelPainter.width / 2, size.height - xLabelPainter.height));

    final yLabelPainter = TextPainter(
      text: TextSpan(text: 'Empirical quantiles', style: plotTextStyle),
      textDirection: TextDirection.ltr,
    );
    yLabelPainter.layout();
    canvas.save();
    canvas.translate(0, size.height / 2 + yLabelPainter.width / 2);
    canvas.rotate(-math.pi / 2);
    yLabelPainter.paint(canvas, const Offset(0, -padding / 4));
    canvas.restore();
  }
  
  List<_Point> getQQPoints(List<double> data, Map<String, dynamic> dist) {
    final List<_Point> points = [];
    switch('normal') {
    //switch(dist['dist_type']) {
      case 'normal':
        // Calculate metrics
        final double mean = data.reduce((a, b) => a + b) / data.length;
        final double stdDev = math.sqrt(data.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / (data.length - 1));
        // Calculate empirical quantiles with Van der Waerden
        final List<double> quantiles = [];
        for (int index = 1; index <= data.length; index++) {
          quantiles.add(index/(data.length + 1));
        }
        // Calculate theoretical values using the Abramowitz and Stegun Approximation: mu + sigma sign(p - 0.5)sqrt(- ln(1 - x/1 + x))/2)
        for (int index = 0; index < data.length; index++) {
        points.add(_Point(data.elementAt(index), mean + stdDev * ((quantiles.elementAt(index) - 0.5).abs() * math.sqrt(-2 * math.log(1 - quantiles.elementAt(index))))));
        }
      case 't':
      case 'lognorm':
      case 'chi2':
      case 'gamma':
      case 'beta':
      case 'weibull':
      case 'exponental':
      case 'uniform':
      case 'bernoulli':
      case 'binomial':
      case 'geometric':
      case 'poisson':
      default:
    }
    return points;
  }

  void drawLegend(Canvas canvas, Size size) {
    final double legendX = size.width - 100;
    final double legendY = 100;
    final double itemHeight = 20;

    // KDE legend item
    canvas.drawLine(
        Offset(legendX, legendY),
        Offset(legendX + 30, legendY),
        Paint()..color = Colors.orange..strokeWidth = 2,
    );
    final kdePainter = TextPainter(
      text: TextSpan(text: 'Quantiles comparison', style: plotTextStyle),
      textDirection: TextDirection.ltr,
    );
    kdePainter.layout();
    kdePainter.paint(canvas, Offset(legendX + 35, legendY - 6));

    // Normal distribution legend item
    canvas.drawLine(
        Offset(legendX, legendY + itemHeight),
        Offset(legendX + 30, legendY + itemHeight),
        Paint()..color = Colors.purple..strokeWidth = 2,
    );
    final normalPainter = TextPainter(
      text: TextSpan(text: 'Middle line', style: plotTextStyle),
      textDirection: TextDirection.ltr,
    );
    normalPainter.layout();
    normalPainter.paint(canvas, Offset(legendX + 35, legendY + itemHeight - 6));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Point {
  final double x;
  final double y;

  _Point(this.x, this.y);
}
