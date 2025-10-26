import 'package:biocentral/sdk/data/biocentral_background_data.dart';
import 'package:flutter/material.dart';

class BiocentralSequenceDistributionPlot extends StatefulWidget {
  final Map<String, double> distribution;
  final bool showBackground;

  const BiocentralSequenceDistributionPlot({
    required this.distribution,
    super.key,
    this.showBackground = false,
  });

  @override
  State<BiocentralSequenceDistributionPlot> createState() =>
      _GeneralDistributionPlotState();
}

class _GeneralDistributionPlotState
    extends State<BiocentralSequenceDistributionPlot> {
  Map<String, double>? backgroundDist;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data =
        await BiocentralBackgroundData.getAASequenceDistribution();
    setState(() {
      backgroundDist = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showBackground && backgroundDist == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _GeneralDistributionPainter(
            widget.distribution,
            widget.showBackground ? backgroundDist : null,
          ),
        );
      },
    );
  }
}

class _GeneralDistributionPainter extends CustomPainter {
  final Map<String, double> data;
  final Map<String, double>? backgroundDist;
  final TextStyle plotTextStyle =
      const TextStyle(color: Colors.black, fontSize: 12);

  _GeneralDistributionPainter(this.data, this.backgroundDist);

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPadding = 60;
    const double topPadding = 40;
    const double rightPadding = 150; // leave space for legend
    const double bottomPadding = 60;

    final Offset plotOffset = const Offset(leftPadding, topPadding);
    final Size plotSize = Size(
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );

    final sortedKeys = data.keys.toList()..sort((a, b) => data[b]!.compareTo(data[a]!));
    final int nBars = sortedKeys.length;
    final int barGroups = backgroundDist == null ? 1 : 2;
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
    const int yTicks = 5;
    for (int i = 0; i <= yTicks; i++) {
      final double percent = i * 100 / yTicks;
      final double y = plotOffset.dy + plotSize.height * (1 - percent / 100);
      canvas.drawLine(
        Offset(plotOffset.dx - 5, y),
        Offset(plotOffset.dx, y),
        borderPaint,
      );

      final tp = TextPainter(
        text: TextSpan(text: '${percent.toInt()}%', style: plotTextStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
          canvas, Offset(plotOffset.dx - tp.width - 8, y - tp.height / 2));
    }

    // Normalize input distribution to 100%
    final double totalData = data.values.fold(0.0, (a, b) => a + b);
    final Map<String, double> normData = {
      for (var k in data.keys) k: (data[k]! / totalData) * 100
    };

    Map<String, double>? normBackground;
    if (backgroundDist != null) {
      final double totalBg = backgroundDist!.values.fold(0.0, (a, b) => a + b);
      normBackground = {
        for (var k in backgroundDist!.keys)
          k: (backgroundDist![k]! / totalBg) * 100
      };
    }

    // Bars
    for (int i = 0; i < sortedKeys.length; i++) {
      final aa = sortedKeys[i];
      final double groupX = plotOffset.dx + i * groupWidth;

      if (normData.containsKey(aa)) {
        _drawBar(canvas, groupX, plotOffset.dy + plotSize.height, barWidth,
            plotSize.height, normData[aa]!, Colors.blue);
      }

      if (normBackground != null &&
          normBackground.containsKey(aa)) {
        final double barX = groupX + barWidth;
        _drawBar(canvas, barX, plotOffset.dy + plotSize.height, barWidth,
            plotSize.height, normBackground[aa]!, Colors.pink);
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

    drawLegend(canvas, size);
  }

  void _drawBar(Canvas canvas, double barX, double yBottom, double barWidth,
      double totalHeight, double perc, Color color) {
    final double h = perc / 100 * totalHeight;
    final rect = Rect.fromLTWH(barX, yBottom - h, barWidth, h);
    final paint = Paint()..color = color;
    canvas.drawRect(rect, paint);
  }

  void drawLegend(Canvas canvas, Size size) {
    final double legendX = size.width - 130;
    double legendY = 50;
    const double boxSize = 12;
    const double spacing = 6;

    final entries = [
      {'label': 'Distribution', 'color': Colors.blue}, // %TODO : better names
      if (backgroundDist != null) {'label': 'Background Data', 'color': Colors.pink},
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
