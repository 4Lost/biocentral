import 'dart:math' as math;

import 'package:flutter/material.dart';

class BiocentralQQPlot extends StatelessWidget {
  final List<double> data;

  const BiocentralQQPlot({
    required this.data, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _QQPainter(data),
        );
      },
    );
  }
}

class _QQPainter extends CustomPainter {
  final List<double> data;
  final TextStyle plotTextStyle = const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold);

  _QQPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    const double padding = 60;

    final Size plotSize = Size(size.width - padding, size.height - padding);
    final Offset plotOffset = const Offset(padding, 0);

    // Calculate metrics
    final double mean = data.reduce((a, b) => a + b) / data.length;
    final double stdDev = math.sqrt(data.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / (data.length - 1));

    // Calculate Points
    data.sort();
    final List<_Point> qqPoints = getQQPoints(data, mean, stdDev);

    // Min & Max
    final double min = math.min(qqPoints.map((p) => p.x).reduce(math.min),qqPoints.map((p) => p.y).reduce(math.min));
    final double max = math.max(qqPoints.map((p) => p.x).reduce(math.max),qqPoints.map((p) => p.y).reduce(math.max));

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

  List<_Point> getQQPoints(List<double> data, double mean, double stdDev) {
    final List<_Point> points = [];

    // Calculate empirical quantiles with Van der Waerden
    final List<double> quantiles = [];
    for (int index = 1; index <= data.length; index++) {
      quantiles.add(index/(data.length + 1));
    }
    // Calculate theoretical values using the Abramowitz and Stegun Approximation: mu + sigma sign(p - 0.5)sqrt(- ln(1 - x/1 + x))/2)
    for (int index = 0; index < data.length; index++) {
    //points.add(_Point(data.elementAt(index), mean + stdDev * (quantiles.elementAt(index) - 0.5).abs() * math.sqrt(-2 * math.log(1 - quantiles.elementAt(index)))));
    points.add(_Point(data.elementAt(index), inverseNormalCDF(quantiles.elementAt(index), mean: mean, stdDev: stdDev)));
    }
    return points;
  }
  // Acklam inverse normal approximation
  double inverseNormalCDF(double p, {double mean = 0.0, double stdDev = 1.0}) {
    if (p <= 0.0 || p >= 1.0) {
      throw ArgumentError('The probability p must be between 0 and 1 (exclusive)');
    }

    // Constants for approximation
    const a1 = -39.6968302866538;
    const a2 = 220.946098424521;
    const a3 = -275.928510446969;
    const a4 = 138.357751867269;
    const a5 = -30.6647980661472;
    const a6 = 2.50662827745924;

    const b1 = -54.4760987982241;
    const b2 = 161.585836858041;
    const b3 = -155.698979859887;
    const b4 = 66.8013118877197;
    const b5 = -13.2806815528857;

    const c1 = -0.00778489400243029;
    const c2 = -0.322396458041136;
    const c3 = -2.40075827716184;
    const c4 = -2.54973253934373;
    const c5 = 4.37466414146497;
    const c6 = 2.93816398269878;

    const d1 = 0.00778469570904146;
    const d2 = 0.32246712907004;
    const d3 = 2.445134137143;
    const d4 = 3.75440866190742;

    // Define break-points
    const pLow = 0.02425;
    const pHigh = 1 - pLow;

    double q, r;
    double result;

    if (p < pLow) {
      q = math.sqrt(-2 * math.log(p));
      result = (((((c1 * q + c2) * q + c3) * q + c4) * q + c5) * q + c6) /
               ((((d1 * q + d2) * q + d3) * q + d4) * q + 1);
    } else if (p <= pHigh) {
      q = p - 0.5;
      r = q * q;
      result = (((((a1 * r + a2) * r + a3) * r + a4) * r + a5) * r + a6) * q /
               (((((b1 * r + b2) * r + b3) * r + b4) * r + b5) * r + 1);
    } else {
      q = math.sqrt(-2 * math.log(1 - p));
      result = -(((((c1 * q + c2) * q + c3) * q + c4) * q + c5) * q + c6) /
                ((((d1 * q + d2) * q + d3) * q + d4) * q + 1);
    }

    // Scale and shift to match the desired mean and standard deviation
    return mean + stdDev * result;
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
