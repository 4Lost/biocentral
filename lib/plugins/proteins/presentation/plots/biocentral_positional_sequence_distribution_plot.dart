import 'dart:math' as math;
import 'package:biocentral/sdk/data/biocentral_background_data.dart';
import 'package:flutter/material.dart';

class BiocentralPositionalSequenceDistributionPlot extends StatefulWidget {
  final List<Map<int, Map<String, double>>> distributions;
  final bool showSecond;

  const BiocentralPositionalSequenceDistributionPlot({
    required this.distributions,
    super.key,
    this.showSecond = true,
  });

  @override
  State<BiocentralPositionalSequenceDistributionPlot> createState() =>
      _PositionalDistributionPlotState();
}

class _PositionalDistributionPlotState extends State<BiocentralPositionalSequenceDistributionPlot> {
  late List<Map<int, Map<String, double>>> _distributions;
  int _startIndex = 0; // starting index of visible positions
  static const int pageSize = 50;

  @override
  void initState() {
    _distributions = List.from(widget.distributions);
    if (widget.distributions.length < 2) _loadData();
    super.initState();
  }

  Future<void> _loadData() async {
    final data = await BiocentralBackgroundData.getAAPositionalSequenceDistribution(widget.distributions[0].keys);
    setState(() {
      _distributions.add(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    final int nPositions = _distributions[0].keys.length;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _PositionalDistributionPainter(
                  _distributions,
                  widget.showSecond,
                  _startIndex,
                  pageSize,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PositionalDistributionPainter extends CustomPainter {
  final List<Map<int, Map<String, double>>> data;
  final bool showSecond;
  final TextStyle plotTextStyle = const TextStyle(color: Colors.black, fontSize: 16);
  final int startIndex;
  final int pageSize;

  _PositionalDistributionPainter(this.data, this.showSecond, this.startIndex, this.pageSize);

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
    const double rightPadding = 160;
    const double bottomPadding = 60;

    final Offset plotOffset = const Offset(leftPadding, topPadding);
    final Size plotSize = Size(
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );

    final int nPositions = data[0].keys.length;
    final int endIndex = (startIndex + pageSize).clamp(0, nPositions);
    final int visibleCount = endIndex - startIndex; 
    final int barGroups = data.length;
    final double groupWidth = plotSize.width / visibleCount;
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
    final int labelStep = (pageSize / 10).ceil().clamp(1, pageSize);

    // Bars
    for (int pos = startIndex; pos < endIndex; pos++) {
      final double groupX = plotOffset.dx + (pos - startIndex) * groupWidth;

      if (data[0][pos] != null) {
        _drawStackedBar(canvas, groupX, plotOffset.dy + plotSize.height,
            barWidth, plotSize.height, data[0][pos]!.map((k, v) => MapEntry(k, v.toDouble())));
      }

      if (showSecond && data.length == 2 && data[1][pos] != null) {
        final double barX = groupX + barWidth;
        /*--
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
        --*/
        final Paint linePaint = Paint()..color = Colors.white..strokeWidth = 4;
        canvas.drawLine(Offset(barX, plotOffset.dy), Offset(barX, plotOffset.dy + plotSize.height), linePaint);
        _drawStackedBar(canvas, barX, plotOffset.dy + plotSize.height, barWidth, plotSize.height, data[1][pos]!);
      }

      // Only draw 10 labels
      if ((pos % labelStep) == 0 || pos == pageSize - 1) {
        final tp = TextPainter(
          text: TextSpan(text: '${startIndex + pos + 1}', style: plotTextStyle),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(groupX + groupWidth / 2 - tp.width / 2, plotOffset.dy + plotSize.height + 5));
      }
    }
    
    // Labels
    final xLabelPainter = TextPainter(
      text: TextSpan(text: 'Position', style: plotTextStyle),
      textDirection: TextDirection.ltr,
    );
    xLabelPainter.layout();
    xLabelPainter.paint(canvas, Offset(size.width / 2, size.height - xLabelPainter.height - 20));

    final yLabelPainter = TextPainter(
      text: TextSpan(text: 'Percentage', style: plotTextStyle),
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
    final double legendX = size.width - 150;
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
