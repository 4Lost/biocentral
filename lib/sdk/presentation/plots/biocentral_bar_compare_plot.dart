import 'dart:math' as math;
import 'dart:math';

import 'package:biocentral/sdk/util/constants.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class BiocentralBarComparePlotData {
  // (Name, Mean, Error)
  final List<List<(String, double, double?)>> _data;

  BiocentralBarComparePlotData.withoutErrors(List<Map<String, double>> data)
      : _data = [data[0].entries.map((entry) => (entry.key, entry.value, null)).toList(), data[1].entries.map((entry) => (entry.key, entry.value, null)).toList()];

  BiocentralBarComparePlotData.withErrors(this._data);

  BiocentralBarComparePlotData sorted() {
    final List<List<(String, double, double?)>> sortedData = [];
    sortedData.add(_data[0].sorted((a, b) => b.$2.compareTo(a.$2)));
    sortedData.add(_data[1].sorted((a, b) => b.$2.compareTo(a.$2)));
    return BiocentralBarComparePlotData.withErrors(sortedData);
  }

  double maxY() {
    return [_data[0].map((item) => item.$2).reduce(math.max), _data[1].map((item) => item.$2).reduce(math.max)].max;
  }

  List<int> get length => [_data[0].length, _data[1].length];

  List<(String, double, double?)> operator [](int index) => [_data[0][index], _data[1][index]];

  Iterable<(int, List<(String, double, double?)?>)> indexed() {
    return [for (int i = 0; i < numberBins; i++) (i, [i < _data[0].length ? _data[0][i] : null, i < _data[1].length ? _data[1][i] : null])];
  }

  int get numberBins => max(_data[0].length, _data[1].length);
}

class _TooltipData {
  final Offset position;
  final String firstLabel;
  final String secondLabel;
  final double firstValue;
  final double secondValue;
  final double? firstErrorMargin;
  final double? secondErrorMargin;

  _TooltipData(this.position, this.firstLabel, this.secondLabel, this.firstValue, this.secondValue, this.firstErrorMargin, this.secondErrorMargin);

  String getTooltipText() {
    String text = '$firstLabel - $secondLabel\n'
        'Value: ${firstValue.toStringAsFixed(Constants.maxDoublePrecision)} - ${secondValue.toStringAsFixed(Constants.maxDoublePrecision)}';
    if (firstErrorMargin != null && secondErrorMargin != null) {
      text += '\nError: ±${firstErrorMargin?.toStringAsFixed(Constants.maxDoublePrecision)} - ±${secondErrorMargin?.toStringAsFixed(Constants.maxDoublePrecision)}';
    } else if (firstErrorMargin != null) {
      text += '\nError: ±${firstErrorMargin?.toStringAsFixed(Constants.maxDoublePrecision)} - N/A';
    } else if (secondErrorMargin != null) {
      text += '\nError: N/A - ±${secondErrorMargin?.toStringAsFixed(Constants.maxDoublePrecision)}';
    }
    return text;
  }
}

class BiocentralBarComparePlot extends StatefulWidget {
  final BiocentralBarComparePlotData data;
  final String xAxisLabel;
  final String yAxisLabel;
  final int maxLabelLength;

  BiocentralBarComparePlot({
    required BiocentralBarComparePlotData data,
    super.key,
    this.xAxisLabel = '',
    this.yAxisLabel = '',
    this.maxLabelLength = 6,
  }) : data = data.sorted();

  @override
  State<BiocentralBarComparePlot> createState() => _BiocentralBarComparePlotState();
}

class _BiocentralBarComparePlotState extends State<BiocentralBarComparePlot> {
  _TooltipData? tooltipData;

  @override
  Widget build(BuildContext context) {
    if (widget.data.length.min < 1) return const Text('Not enough data to display bar plot.');

    return LayoutBuilder(
      builder: (context, constraints) {
        return MouseRegion(
          onHover: (event) {
            // Update tooltip data based on mouse position
            final RenderBox box = context.findRenderObject() as RenderBox;
            final localPosition = box.globalToLocal(event.position);
            final tooltipInfo = _getTooltipData(localPosition, constraints.maxWidth, constraints.maxHeight);
            setState(() {
              tooltipData = tooltipInfo;
            });
          },
          onExit: (event) {
            setState(() {
              tooltipData = null;
            });
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _BarComparePlotPainter(
                  widget.data,
                  widget.xAxisLabel,
                  widget.yAxisLabel,
                  widget.maxLabelLength,
                  tooltipData,
                ),
              ),
              if (tooltipData != null)
                Positioned(
                  left: tooltipData!.position.dx,
                  top: tooltipData!.position.dy - 40, // Offset above the cursor
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tooltipData?.getTooltipText() ?? '',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  _TooltipData? _getTooltipData(Offset localPosition, double width, double height) {
    const double padding = 60;
    final plotWidth = width - padding * 2;
    final barWidth = plotWidth / widget.data.numberBins;

    // Check if we're within the plot area
    if (localPosition.dx < padding ||
        localPosition.dx > width - padding ||
        localPosition.dy < padding ||
        localPosition.dy > height - padding) {
      return null;
    }

    // Calculate which bar we're hovering over
    final barIndex = ((localPosition.dx - padding) / barWidth).floor();
    if (barIndex >= 0 && barIndex < widget.data.numberBins) {
      final data = widget.data[barIndex];
      return _TooltipData(
        localPosition,
        data[0].$1,
        data[1].$1,
        data[0].$2,
        data[1].$2,
        data[0].$3,
        data[1].$3,
      );
    }
    return null;
  }
}

class _BarComparePlotPainter extends CustomPainter {
  final BiocentralBarComparePlotData data;
  final String xAxisLabel;
  final String yAxisLabel;
  final int maxLabelLength;

  final _TooltipData? tooltipData;

  final TextStyle plotTextStyle = const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold);

  _BarComparePlotPainter(this.data, this.xAxisLabel, this.yAxisLabel, this.maxLabelLength, this.tooltipData);

  @override
  void paint(Canvas canvas, Size size) {
    const double padding = 30;
    final Size plotSize = Size(size.width - padding * 2, size.height - padding * 2);
    final Offset plotOffset = const Offset(padding, padding);

    final Paint axesPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Calculate max Y value
    final double maxY = data.maxY();

    final double barWidth = plotSize.width / data.numberBins;

    _drawAxes(canvas, size, padding, axesPaint);

    _drawBars(canvas, plotOffset, plotSize, maxY, barWidth);

    _drawXAxisLabels(canvas, size, plotOffset, barWidth, padding);

    _drawYAxisLabels(canvas, plotSize, plotOffset, maxY, padding, axesPaint);

    _drawAxesLabels(canvas, size, padding);
  }

  void _drawBars(Canvas canvas, Offset plotOffset, Size plotSize, double maxY, double barWidth) {
    // Error bars paint
    final Paint errorBarPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5;
    final Paint errorCompareBarPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5;

    for (final dataPoint in data.indexed()) {
      if (dataPoint.$2[0] != null) {
        _drawBar(dataPoint, 0, canvas, plotOffset, plotSize, maxY, barWidth, errorBarPaint, false);
      }
      if (dataPoint.$2[1] != null) {
        _drawBar(dataPoint, 1, canvas, plotOffset, plotSize, maxY, barWidth, errorCompareBarPaint, true);
      }
    }
  }

  void _drawBar((int, List<(String, double, double?)?>) dataPoint, int index, Canvas canvas, Offset plotOffset, Size plotSize, double maxY, double barWidth, Paint errorBarPaint, bool isCompare) {
    final int i = dataPoint.$1;
    final double value = dataPoint.$2[index]!.$2;
    final double barHeight = (value / maxY) * plotSize.height;
    final Rect rect = Rect.fromLTWH(
      plotOffset.dx + i * barWidth + (isCompare ? barWidth * 0.4 : 0),
      plotOffset.dy + plotSize.height - barHeight,
      barWidth * 0.4, // Leave some space between bars
      barHeight,
    );

    // Change color if this bar is being hovered
    final bool isHovered = tooltipData != null && (index == 0 ? tooltipData!.firstLabel : tooltipData!.secondLabel) == data[i][index].$1;
    final color = isCompare ? (isHovered ? Colors.pink.shade300 : Colors.pink) : (isHovered ? Colors.blue.shade300 : Colors.blue);
    canvas.drawRect(rect, Paint()..color = color);

    final errorMargin = dataPoint.$2[index]!.$3;
    if (errorMargin != null) {
      // Draw error bars
      final double barCenterX = plotOffset.dx + i * barWidth + (barWidth * 0.2) + (isCompare ? barWidth * 0.4 : 0);
      final double barTopY = plotOffset.dy + plotSize.height - barHeight;
      final double errorBarHeight = (errorMargin / maxY) * plotSize.height;

      // Vertical line
      canvas.drawLine(
        Offset(barCenterX, barTopY - errorBarHeight),
        Offset(barCenterX, barTopY + errorBarHeight),
        errorBarPaint,
      );

      // Top horizontal line
      canvas.drawLine(
        Offset(barCenterX - 2, barTopY - errorBarHeight),
        Offset(barCenterX + 2, barTopY - errorBarHeight),
        errorBarPaint,
      );

      // Bottom horizontal line
      canvas.drawLine(
        Offset(barCenterX - 2, barTopY + errorBarHeight),
        Offset(barCenterX + 2, barTopY + errorBarHeight),
        errorBarPaint,
      );
    }
  }

  void _drawAxes(Canvas canvas, Size size, double padding, Paint axesPaint) {
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      axesPaint,
    );
    canvas.drawLine(Offset(padding, padding), Offset(padding, size.height - padding), axesPaint);
  }

  void _drawXAxisLabels(Canvas canvas, Size size, Offset plotOffset, double barWidth, double padding) {
    // First, calculate the maximum width of all labels
    double maxLabelWidth = 0;
    final List<TextPainter> textPainters = [];
    final List<TextPainter> compareTextPainters = [];

    for (int i = 0; i < data.numberBins; i++) {
      if (i < data[0].length) {
        String label = data[0][i].$1;
        final int originalLabelLength = label.length;
        label = label.substring(0, min(label.length, maxLabelLength));
        if (originalLabelLength > maxLabelLength) {
          label = label.replaceRange(label.length - 2, label.length, '..');
        }

        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: plotTextStyle,
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainters.add(textPainter);
        maxLabelWidth = max(maxLabelWidth, textPainter.width);
      }
      if (i < data[1].length) {
        String label = data[1][i].$1;
        final int originalLabelLength = label.length;
        label = label.substring(0, min(label.length, maxLabelLength));
        if (originalLabelLength > maxLabelLength) {
          label = label.replaceRange(label.length - 2, label.length, '..');
        }

        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: plotTextStyle,
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        compareTextPainters.add(textPainter);
        maxLabelWidth = max(maxLabelWidth, textPainter.width);
      }
    }

    // Calculate if rotated labels would go beyond the bottom margin
    final rotatedHeight = maxLabelWidth * sin(math.pi / 4); // Height when rotated 45 degrees
    final availableVerticalSpace = size.height - (size.height - padding + 5);
    final wouldOvershoot = rotatedHeight > availableVerticalSpace;

    // Determine rotation angle
    double rotationAngle = 0;
    if (wouldOvershoot) {
      // Use smaller rotation angle if would overshoot
      rotationAngle = 0.05;
    } else {
      rotationAngle = math.pi / 4; // 45 degrees
    }

    // Draw labels with appropriate rotation
    for (int i = 0; i < data.numberBins; i++) {
      if (i < data[0].length) {
        final textPainter = textPainters[i];
        canvas.save();

        // Rotated placement
        canvas.translate(
          plotOffset.dx + (i + 0.2) * barWidth,
          size.height - padding + 2,
        );
        canvas.rotate(rotationAngle);
        textPainter.paint(canvas, const Offset(0, 0));

        canvas.restore();
      }
      if (i < data[1].length) {
        final textPainter = compareTextPainters[i];
        canvas.save();

        // Rotated placement
        canvas.translate(
          plotOffset.dx + (i + 0.6) * barWidth,
          size.height - padding + 2,
        );
        canvas.rotate(rotationAngle);
        textPainter.paint(canvas, const Offset(0, 0));

        canvas.restore();
      }
    }
  }

  void _drawYAxisLabels(Canvas canvas, Size plotSize, Offset plotOffset, double maxY, double padding, Paint axesPaint) {
    // Draw y-axis labels
    final int yTickCount = min(data.numberBins, 5);
    for (int i = 0; i <= yTickCount; i++) {
      final double y = plotOffset.dy + plotSize.height * (1 - i / yTickCount);
      final double labelValue = maxY * (i / yTickCount);
      canvas.drawLine(Offset(padding - 5, y), Offset(padding, y), axesPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: labelValue.toStringAsFixed(Constants.maxDoublePrecision),
          style: plotTextStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(padding - 10 - textPainter.width, y - textPainter.height / 2));
    }
  }

  void _drawAxesLabels(Canvas canvas, Size size, double padding) {
    // Add axis labels
    final xLabelPainter = TextPainter(
      text: TextSpan(text: xAxisLabel, style: plotTextStyle),
      textDirection: TextDirection.ltr,
    );
    xLabelPainter.layout();
    xLabelPainter.paint(canvas, Offset(size.width - padding, size.height - padding));

    final yLabelPainter = TextPainter(
      text: TextSpan(text: yAxisLabel, style: plotTextStyle),
      textDirection: TextDirection.ltr,
    );
    yLabelPainter.layout();
    canvas.save();
    canvas.translate(-padding, size.height / 2 + yLabelPainter.width / 2);
    canvas.rotate(-math.pi / 2);
    yLabelPainter.paint(canvas, Offset(0, -padding / 4));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is _BarComparePlotPainter) {
      return oldDelegate.tooltipData != tooltipData;
    }
    return false;
  }
}
