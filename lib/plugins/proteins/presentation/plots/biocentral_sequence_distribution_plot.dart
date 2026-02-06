import 'dart:math' as math;

import 'package:biocentral/sdk/data/biocentral_background_data.dart';
import 'package:flutter/material.dart';

class BiocentralSequenceDistributionPlot extends StatefulWidget {
  final List<Map<String, double>> distributions;
  final bool showSecond;

  const BiocentralSequenceDistributionPlot({
    required this.distributions,
    super.key,
    this.showSecond = true,
  });

  @override
  State<BiocentralSequenceDistributionPlot> createState() =>
      _GeneralDistributionPlotState();
}

class _GeneralDistributionPlotState extends State<BiocentralSequenceDistributionPlot> {
  late List<Map<String, double>> _distributions;

  @override
  void initState() {
    _distributions = List.from(widget.distributions);
    super.initState();
    if (_distributions.length < 2) _loadData();
  }

  Future<void> _loadData() async {
    final data = await BiocentralBackgroundData.getAASequenceDistribution();
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
          painter: _GeneralDistributionPainter(
            _distributions,
            widget.showSecond,
          ),
        );
      },
    );
  }
}

class _GeneralDistributionPainter extends CustomPainter {
  final List<Map<String, double>> data;
  final bool showSecond;
  final TextStyle plotTextStyle = const TextStyle(color: Colors.black, fontSize: 12);

  _GeneralDistributionPainter(this.data, this.showSecond);

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

    final sortedKeys = data[0].keys.toList()..sort((a, b) => data[0][b]!.compareTo(data[0][a]!));
    final int nBars = sortedKeys.length;
    final int barGroups = showSecond ? 2 : 1;
    final double groupWidth = plotSize.width / nBars;
    final double barWidth = groupWidth / (barGroups + 0.5);

    final Paint borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Axes
    canvas.drawLine(
      Offset(plotOffset.dx, plotOffset.dy + plotSize.height),
      Offset(plotOffset.dx + plotSize.width, plotOffset.dy + plotSize.height),
      borderPaint,
    );
    canvas.drawLine(
      Offset(plotOffset.dx, plotOffset.dy),
      Offset(plotOffset.dx, plotOffset.dy + plotSize.height),
      borderPaint,
    );

    // Y-axis ticks (0–100%)
    double maxValue = 0;
    for (var dist in data) {
      final double total = dist.values.fold(0.0, (a, b) => a + b);
      for (var val in dist.values) {
        final double percent = (val / total) * 100;
        if (percent > maxValue) maxValue = percent;
      }
    }
    const int yTicks = 5;
    for (int i = 0; i <= yTicks; i++) {
      final double value = i * maxValue / yTicks;
      final double y = plotOffset.dy + plotSize.height * (1 - value / maxValue);
      canvas.drawLine(
        Offset(plotOffset.dx - 5, y),
        Offset(plotOffset.dx, y),
        borderPaint,
      );

      final tp = TextPainter(
        text: TextSpan(text: '${value.toInt()}%', style: plotTextStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
          canvas, Offset(plotOffset.dx - tp.width - 8, y - tp.height / 2));
    }

    // Normalize input distribution to 100%
    final double totalData = data[0].values.fold(0.0, (a, b) => a + b);
    final Map<String, double> normData = {
      for (var k in data[0].keys) k: (data[0][k]! / totalData) * 100
    };

    Map<String, double>? normSecond;
    if (barGroups == 2) {
      final double totalSnd = data[1].values.fold(0.0, (a, b) => a + b);
      normSecond = {
        for (var k in data[1].keys)
          k: (data[1][k]! / totalSnd) * 100
      };
    }

    // Bars
    for (int i = 0; i < sortedKeys.length; i++) {
      final aa = sortedKeys[i];
      final double groupX = plotOffset.dx + i * groupWidth;

      if (normData.containsKey(aa)) {
        _drawBar(canvas, groupX, plotOffset.dy + plotSize.height, barWidth,
            plotSize.height, normData[aa]!, Colors.blue, maxValue);
      }

      if (normSecond != null &&
          normSecond.containsKey(aa)) {
        final double barX = groupX + barWidth;
        _drawBar(canvas, barX, plotOffset.dy + plotSize.height, barWidth,
            plotSize.height, normSecond[aa]!, Colors.pink, maxValue);
      }

      // X-axis label
      final tp = TextPainter(
        text: TextSpan(text: aa, style: plotTextStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
          canvas,
          Offset(groupX + groupWidth / 2 - tp.width / 2,
              plotOffset.dy + plotSize.height + 5));
    }

    drawLegend(canvas, size, plotOffset);
  }

  void _drawBar(Canvas canvas, double barX, double yBottom, double barWidth,
      double totalHeight, double perc, Color color, double maxValue, ) {
    final double h = perc / maxValue * totalHeight;
    final rect = Rect.fromLTWH(barX, yBottom - h, barWidth, h);
    final paint = Paint()..color = color;
    canvas.drawRect(rect, paint);
  }

  void drawLegend(Canvas canvas, Size size, Offset plotOffset) {
    final double legendX = size.width - 130;
    double legendY = 50;
    const double boxSize = 12;
    const double spacing = 6;

    final entries = [
      {'label': 'Distribution', 'color': Colors.blue}, // %TODO : better names
      if (showSecond && data.length == 2) {'label': 'Compare Data', 'color': Colors.pink},
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

    final xLabelPainter = TextPainter(
      text: TextSpan(text: 'Amino Acid', style: plotTextStyle), // Position for Pos
      textDirection: TextDirection.ltr,
    );
    xLabelPainter.layout();
    xLabelPainter.paint(canvas, Offset(size.width / 2, size.height - xLabelPainter.height - 20));

    final yLabelPainter = TextPainter(
      text: TextSpan(text: 'Percentage', style: plotTextStyle),
      textDirection: TextDirection.ltr,
    );
    yLabelPainter.layout();
    canvas.translate(0, size.height / 2 + yLabelPainter.width / 2);
    canvas.rotate(-math.pi / 2);
    yLabelPainter.paint(canvas, Offset(0, plotOffset.dx / 4 - 10));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
