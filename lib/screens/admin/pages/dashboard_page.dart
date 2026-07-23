import 'package:flutter/material.dart';

import '../../../models/dashboard_stats.dart';
import '../../../services/dashboard_service.dart';
import '../../../utils/app_constants.dart';
import '../widgets/bottom_row_cards.dart';
import '../widgets/dashboard_footer.dart';
import '../widgets/pending_profiles_card.dart';
import '../widgets/quick_actions.dart';
import '../widgets/recent_activities_card.dart';
import '../widgets/search_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/upcoming_birthdays_card.dart';

import '../../user/view_profile_screen.dart';

/// The main admin landing page: stat cards up top, quick actions
/// and search, then activity/birthdays/pending-profiles, and
/// finally the distribution charts + calendar at the bottom.
///
/// [onNavigateToManageSisters], [onNavigateToAddSister], and
/// [onNavigateToReports] let QuickActions switch the sidebar's
/// selected page — wire these up from AdminDashboardScreen.
class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    this.onNavigateToManageSisters,
    this.onNavigateToAddSister,
    this.onNavigateToReports,
  });

  final VoidCallback? onNavigateToManageSisters;
  final VoidCallback? onNavigateToAddSister;
  final VoidCallback? onNavigateToReports;

  static const double _stackBreakpoint = 900;

  // Opens the tapped sister's profile. SearchCard's onSisterSelected
  // passes the Firestore doc id (uid) directly, so no SisterModel
  // construction is needed here.
  void _openSisterProfile(BuildContext context, String sisterId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(sisterId: sisterId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.largePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatCardsRow(),
          const SizedBox(height: 16),
          QuickActions(
            onAddSister: onNavigateToAddSister ?? () {},
            onManageSisters: onNavigateToManageSisters ?? () {},
            onViewReports: onNavigateToReports ?? () {},
          ),
          const SizedBox(height: 16),
          SearchCard(
            onSisterSelected: (sisterId) => _openSisterProfile(context, sisterId),
          ),
          const SizedBox(height: 16),
          _buildMiddleRow(),
          const SizedBox(height: 16),
          const BottomRowCards(),
          const DashboardFooter(),
        ],
      ),
    );
  }

  Widget _buildStatCardsRow() {
    return StreamBuilder<DashboardStats>(
      stream: DashboardService.instance.streamDashboardStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? DashboardStats.empty();

        final cards = [
          StatCard(
            label: 'Total Sisters',
            value: '${stats.totalSisters}',
            icon: Icons.groups_outlined,
          ),
          StatCard(
            label: 'Pending Profiles',
            value: '${stats.pendingProfiles}',
            icon: Icons.hourglass_empty_outlined,
            iconColor: Colors.orange,
          ),
          StatCard(
            label: 'Approved',
            value: '${stats.approvedProfiles}',
            icon: Icons.check_circle_outline,
            iconColor: Colors.green,
          ),
          StatCard(
            label: 'New This Month',
            value: '${stats.newThisMonth}',
            icon: Icons.trending_up,
            iconColor: Colors.blue,
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _stackBreakpoint;
            final crossAxisCount = isWide ? 4 : 2;

            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.2,
              children: cards,
            );
          },
        );
      },
    );
  }

  Widget _buildMiddleRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _stackBreakpoint;

        final cards = const [
          Expanded(child: RecentActivitiesCard()),
          SizedBox(width: 16, height: 16),
          Expanded(child: UpcomingBirthdaysCard()),
          SizedBox(width: 16, height: 16),
          Expanded(child: PendingProfilesCard()),
        ];

        return isWide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: cards)
            : Column(children: cards);
      },
    );
  }
}