import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/dashboard_stats.dart';
import '../../../services/dashboard_service.dart';
import '../../../utils/app_colors.dart';
import 'dashboard_card.dart';

/// Bar chart showing sister counts per age bracket, built with
/// fl_chart's BarChart for proper axis labels, tooltips, and
/// animation instead of hand-rolled Container bars.
class AgeDistributionCard extends StatelessWidget {
  const AgeDistributionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Age Distribution',
      child: StreamBuilder<DashboardStats>(
        stream: DashboardService.instance.streamDashboardStats(),
        builder: (context, snapshot) {
          final stats = snapshot.data ?? DashboardStats.empty();
          final distribution = stats.ageDistribution;

          if (stats.totalSisters == 0) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No data yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          final brackets = DashboardStats.ageBrackets;
          final maxCount = distribution.values.isEmpty
              ? 1
              : distribution.values.reduce((a, b) => a > b ? a : b);

          // maxCount is an int, so (maxCount / 4) is already a double —
          // no clamp()/ceilToDouble() chaining needed. That chain doesn't
          // compile: num.clamp() returns num, and num has no
          // ceilToDouble() method (only double does). Compute the
          // interval directly and floor it at 1 so the grid never has a
          // zero-width step.
          final rawInterval = maxCount / 4;
          final horizontalInterval = rawInterval < 1 ? 1.0 : rawInterval.ceilToDouble();

          return SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: (maxCount + (maxCount * 0.2)).ceilToDouble(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primaryDark,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${brackets[group.x.toInt()]}\n${rod.toY.toInt()} sisters',
                        const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= brackets.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            brackets[index],
                            style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: horizontalInterval,
                  getDrawingHorizontalLine: (value) => FlLine(color: AppColors.divider, strokeWidth: 1),
                ),
                barGroups: List.generate(brackets.length, (index) {
                  final count = distribution[brackets[index]] ?? 0;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: count.toDouble(),
                        color: AppColors.primary,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }
}