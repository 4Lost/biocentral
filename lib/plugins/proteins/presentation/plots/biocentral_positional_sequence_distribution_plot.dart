import 'package:biocentral/sdk/data/biocentral_background_data.dart';
import 'package:flutter/material.dart';

class BiocentralPositionalSequenceDistributionPlot extends StatefulWidget {
  final Map<int, Map<String, int>> distribution;
  final bool showBackground;

  const BiocentralPositionalSequenceDistributionPlot({
    required this.distribution,
    super.key,
    this.showBackground = false,
  });

  @override
  State<BiocentralPositionalSequenceDistributionPlot> createState() =>
      _PositionalDistributionPlotState();
}

class _PositionalDistributionPlotState
    extends State<BiocentralPositionalSequenceDistributionPlot> {
  Map<int, Map<String, double>>? backgroundDist;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data =
        await BiocentralBackgroundData.getAAPositionalSequenceDistribution(widget.distribution.keys);
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
          painter: _PositionalDistributionPainter(
            widget.distribution,
            widget.showBackground ? backgroundDist : null,
          ),
        );
      },
    );
  }
}

class _PositionalDistributionPainter extends CustomPainter {
  final Map<int, Map<String, int>> data;
  final Map<int, Map<String, double>>? backgroundDist;
  final TextStyle plotTextStyle =
      const TextStyle(color: Colors.black, fontSize: 12);

  _PositionalDistributionPainter(
      this.data, this.backgroundDist);

  static final Map<String, Color> aminoColors = {
    'A': Colors.blue,
    'C': Colors.green,
    'D': Colors.red,
    'E': Colors.orange,
    'F': Colors.purple,
    'G': Colors.brown,
    'H': Colors.pink,
    'I': Colors.teal,
    'K': Colors.indigo,
    'L': Colors.cyan,
    'M': Colors.lime,
    'N': Colors.amber,
    'P': Colors.deepPurple,
    'Q': Colors.deepOrange,
    'R': Colors.lightBlue,
    'S': Colors.lightGreen,
    'T': Colors.yellow,
    'V': Colors.blueGrey,
    'W': Colors.grey,
    'Y': Colors.black,
  };

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

    final int nPositions = data.keys.length;
    final int barGroups = backgroundDist == null ? 1 : 2;
    final double groupWidth = plotSize.width / nPositions;
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

    // Y-axis ticks
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

    // X-axis labels step
    final int labelStep = (nPositions / 10).ceil().clamp(1, nPositions);

    // Bars
    for (int pos = 0; pos < nPositions; pos++) {
      final double groupX = plotOffset.dx + pos * groupWidth;

      final dist = data[pos];
      if (dist != null) {
        _drawStackedBar(canvas, groupX, plotOffset.dy + plotSize.height,
            barWidth, plotSize.height, dist.map((k, v) => MapEntry(k, v.toDouble())),);
      }

      if (backgroundDist != null && backgroundDist![pos] != null) {
        final double barX = groupX + barWidth;
        _drawStackedBar(canvas, barX, plotOffset.dy + plotSize.height,
            barWidth, plotSize.height, backgroundDist![pos]!);
      }

      // Only draw 10 labels
      if ((pos % labelStep) == 0 || pos == nPositions - 1) {
        final tp = TextPainter(
          text: TextSpan(text: '${pos + 1}', style: plotTextStyle),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(
            canvas,
            Offset(groupX + groupWidth / 2 - tp.width / 2,
                plotOffset.dy + plotSize.height + 5));
      }
    }

    drawLegend(canvas, size);
  }

  void _drawStackedBar(Canvas canvas, double barX, double yBottom,
      double barWidth, double totalHeight, Map<String, double> dist) {
    final double sum = dist.values.fold(0.0, (a, b) => a + b);
    final Map<String, double> normalized =
        sum == 0 ? dist : dist.map((k, v) => MapEntry(k, (v / sum) * 100));

    final letters = normalized.keys.toList()..sort();
    for (final aa in letters) {
      final double perc = normalized[aa]!;
      final double h = perc / 100 * totalHeight;

      final rect = Rect.fromLTWH(barX, yBottom - h, barWidth, h);
      final paint = Paint()..color = aminoColors[aa] ?? Colors.grey;
      canvas.drawRect(rect, paint);
      yBottom -= h;
    }
  }

  void drawLegend(Canvas canvas, Size size) {
    final double legendX = size.width - 140;
    double legendY = 40;
    const double boxSize = 12;
    const double spacing = 4;

    final sortedKeys = aminoColors.keys.toList()..sort();
    for (final aa in sortedKeys) {
      final paint = Paint()..color = aminoColors[aa]!;
      canvas.drawRect(Rect.fromLTWH(legendX, legendY, boxSize, boxSize), paint);

      final tp = TextPainter(
        text: TextSpan(text: aa, style: plotTextStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(legendX + boxSize + spacing, legendY - 2));

      legendY += boxSize + spacing;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
