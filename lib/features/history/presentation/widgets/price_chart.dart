import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/models/price_history_item.dart';

class PriceChart extends StatelessWidget {
  final List<PriceTrendPoint> trendPoints;

  const PriceChart({super.key, required this.trendPoints});

  String _formatDate(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agt',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (trendPoints.isEmpty) {
      return Container(
        height: 172,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          'Belum cukup data untuk grafik tren',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      );
    }

    // Sort trendPoints by date to plot correctly
    final sortedPoints = List<PriceTrendPoint>.from(trendPoints)
      ..sort((a, b) => a.date.compareTo(b.date));

    final spots = <FlSpot>[];
    double minX = 0.0;
    double maxX = 0.0;
    final Map<int, String> bottomTitleMap = {};

    if (sortedPoints.length == 1) {
      spots.add(FlSpot(0.0, sortedPoints[0].price));
      minX = -1.0;
      maxX = 1.0;
      bottomTitleMap[0] = _formatDate(sortedPoints[0].date);
    } else {
      for (int i = 0; i < sortedPoints.length; i++) {
        spots.add(FlSpot(i.toDouble(), sortedPoints[i].price));
      }
      minX = 0.0;
      maxX = (sortedPoints.length - 1).toDouble();

      if (sortedPoints.length <= 4) {
        for (int i = 0; i < sortedPoints.length; i++) {
          bottomTitleMap[i] = _formatDate(sortedPoints[i].date);
        }
      } else {
        bottomTitleMap[0] = _formatDate(sortedPoints[0].date);
        bottomTitleMap[sortedPoints.length ~/ 2] = _formatDate(
          sortedPoints[sortedPoints.length ~/ 2].date,
        );
        bottomTitleMap[sortedPoints.length - 1] = _formatDate(
          sortedPoints[sortedPoints.length - 1].date,
        );
      }
    }

    final double lastX = sortedPoints.length == 1 ? 0.0 : maxX;

    final String semanticsLabel = sortedPoints.length == 1
        ? 'Grafik tren harga untuk satu data poin pada ${_formatDate(sortedPoints[0].date)} dengan harga ${formatRp(sortedPoints[0].price)}'
        : 'Grafik tren harga dari ${_formatDate(sortedPoints[0].date)} hingga ${_formatDate(sortedPoints.last.date)}. '
          'Harga terendah ${formatRp(sortedPoints.map((e) => e.price).reduce((a, b) => a < b ? a : b))}, '
          'dan harga tertinggi ${formatRp(sortedPoints.map((e) => e.price).reduce((a, b) => a > b ? a : b))}.';

    return Semantics(
      label: semanticsLabel,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                        strokeWidth: 1,
                        dashArray: [3, 4],
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final valIndex = value.toInt();
                          final dateStr = bottomTitleMap[valIndex];
                          if (dateStr == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: minX,
                  maxX: maxX,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, barData) {
                          if (sortedPoints.length == 1) return true;
                          return spot.x == lastX;
                        },
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            color: const Color(0xFF059669),
                            strokeColor: Colors.white,
                            strokeWidth: 2.5,
                            radius: 5,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF059669).withValues(alpha: 0.16),
                            const Color(0xFF059669).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: isDark
                          ? const Color(0xFF0F172A)
                          : Colors.white,
                      tooltipBorder: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          if (sortedPoints.length == 1) {
                            final point = sortedPoints[0];
                            return LineTooltipItem(
                              '${_formatDate(point.date)}\n${formatRp(point.price)}',
                              TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            );
                          }
                          final spotIndex = spot.x.toInt();
                          if (spotIndex < 0 || spotIndex >= sortedPoints.length) {
                            return null;
                          }
                          final point = sortedPoints[spotIndex];
                          return LineTooltipItem(
                            '${_formatDate(point.date)}\n${formatRp(point.price)}',
                            TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          );
                        }).whereType<LineTooltipItem>().toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
