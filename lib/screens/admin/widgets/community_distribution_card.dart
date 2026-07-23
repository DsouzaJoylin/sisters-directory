import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/dashboard_stats.dart';
import '../../../services/dashboard_service.dart';
import '../../../utils/app_colors.dart';
import 'dashboard_card.dart';

/// Donut chart breaking down sisters by community/parish, with
/// a color-coded legend beneath it. Built with fl_chart's PieChart.
class CommunityDistributionCard extends StatefulWidget {
  const CommunityDistributionCard({super.key});

  @override
  State<CommunityDistributionCard> createState() => _CommunityDistributionCardState();
}

class _CommunityDistributionCardState extends State<CommunityDistributionCard> {
  int? _touchedIndex;

  static const List<Color> _palette = [
    AppColors.primary,
    AppColors.info,
    AppColors.secondaryDark,
    AppColors.success,
    AppColors.warning,
    AppColors.primaryLight,
  ];

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Community Distribution',
      child: StreamBuilder<DashboardStats>(
        stream: DashboardService.instance.streamDashboardStats(),
        builder: (context, snapshot) {
          final stats = snapshot.data ?? DashboardStats.empty();
          final entries = stats.communityDistribution.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          if (entries.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No community data yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          final topEntries = entries.take(6).toList();
          final total = topEntries.fold<int>(0, (sum, e) => sum + e.value);

          return Column(
            children: [
              SizedBox(
                height: 160,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response?.touchedSection == null) {
                            _touchedIndex = null;
                            return;
                          }
                          _touchedIndex = response!.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    sections: List.generate(topEntries.length, (index) {
                      final entry = topEntries[index];
                      final isTouched = index == _touchedIndex;
                      final percent = total == 0 ? 0.0 : entry.value / total * 100;

                      return PieChartSectionData(
                        value: entry.value.toDouble(),
                        color: _palette[index % _palette.length],
                        title: '${percent.toStringAsFixed(0)}%',
                        radius: isTouched ? 46 : 40,
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: List.generate(topEntries.length, (index) {
                  final entry = topEntries[index];
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _palette[index % _palette.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${entry.key} (${entry.value})',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary),
                      ),
                    ],
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}