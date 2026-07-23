import 'package:flutter/material.dart';

import 'age_distribution_card.dart';
import 'community_distribution_card.dart';
import 'mini_calendar_card.dart';

/// Lays out the bottom row of the dashboard: age distribution,
/// community distribution, and the mini calendar side by side
/// on wide screens, stacked on narrow ones.
class BottomRowCards extends StatelessWidget {
  const BottomRowCards({super.key});

  static const double _stackBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _stackBreakpoint;

        final cards = const [
          Expanded(child: AgeDistributionCard()),
          SizedBox(width: 16, height: 16),
          Expanded(child: CommunityDistributionCard()),
          SizedBox(width: 16, height: 16),
          Expanded(child: MiniCalendarCard()),
        ];

        return isWide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: cards)
            : Column(children: cards);
      },
    );
  }
}