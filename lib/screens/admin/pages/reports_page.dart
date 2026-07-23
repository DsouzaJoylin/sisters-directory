import 'package:flutter/material.dart';

import '../../../models/dashboard_stats.dart';
import '../../../models/sister_model.dart';
import '../../../services/dashboard_service.dart';
import '../../../services/firestore_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_constants.dart';
import '../widgets/dashboard_card.dart';

/// Summary reporting page: high-level stats plus breakdowns by
/// status, community, and age bracket. No PDF/CSV export wired
/// up yet (would need an added package like `pdf` or `csv`) —
/// flagged below as a natural next step.
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.largePadding),
      child: StreamBuilder<DashboardStats>(
        stream: DashboardService.instance.streamDashboardStats(),
        builder: (context, statsSnapshot) {
          final stats = statsSnapshot.data ?? DashboardStats.empty();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, stats),
              const SizedBox(height: 20),
              _buildSummaryGrid(stats),
              const SizedBox(height: 20),
              _buildStatusBreakdown(stats),
              const SizedBox(height: 20),
              _buildCommunityBreakdown(stats),
              const SizedBox(height: 20),
              _buildFullDirectoryTable(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DashboardStats stats) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'A snapshot of your community directory.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Export coming soon — add the "pdf" or "csv" package to enable this.'),
              ),
            );
          },
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Export'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildSummaryGrid(DashboardStats stats) {
    final items = [
      ('Total Sisters', '${stats.totalSisters}', Icons.groups_outlined, AppColors.primary),
      ('Approved', '${stats.approvedProfiles}', Icons.check_circle_outline, AppColors.success),
      ('Pending', '${stats.pendingProfiles}', Icons.hourglass_empty_outlined, AppColors.pending),
      ('Rejected', '${stats.rejectedProfiles}', Icons.cancel_outlined, AppColors.error),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        return GridView.count(
          crossAxisCount: isWide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: items
              .map((item) => DashboardCard(
                    child: Row(
                      children: [
                        Icon(item.$3, color: item.$4, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.$2,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text(item.$1,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildStatusBreakdown(DashboardStats stats) {
    final total = stats.totalSisters == 0 ? 1 : stats.totalSisters;
    final rows = [
      ('Approved', stats.approvedProfiles, AppColors.approved),
      ('Pending', stats.pendingProfiles, AppColors.pending),
      ('Rejected', stats.rejectedProfiles, AppColors.rejected),
    ];

    return DashboardCard(
      title: 'Status Breakdown',
      child: Column(
        children: rows.map((row) {
          final percent = (row.$2 / total * 100).toStringAsFixed(0);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 90, child: Text(row.$1, style: const TextStyle(fontSize: 13))),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      children: [
                        Container(
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        Container(
                          height: 14,
                          width: constraints.maxWidth * (row.$2 / total),
                          decoration: BoxDecoration(
                            color: row.$3,
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 60,
                  child: Text('${row.$2} ($percent%)',
                      textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCommunityBreakdown(DashboardStats stats) {
    final entries = stats.communityDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return DashboardCard(
      title: 'Sisters per Community',
      child: entries.isEmpty
          ? const Text('No community data yet.', style: TextStyle(color: AppColors.textSecondary))
          : Column(
              children: entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                            Text('${e.value}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
    );
  }

  Widget _buildFullDirectoryTable() {
    return DashboardCard(
      title: 'Full Directory',
      child: StreamBuilder<List<SisterModel>>(
        stream: FirestoreService.instance.streamAllSisters(),
        builder: (context, snapshot) {
          final sisters = snapshot.data ?? [];

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            );
          }

          if (sisters.isEmpty) {
            return const Text('No sisters in the directory yet.',
                style: TextStyle(color: AppColors.textSecondary));
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Community')),
                DataColumn(label: Text('Age')),
                DataColumn(label: Text('Status')),
              ],
              rows: sisters
                  .map((s) => DataRow(cells: [
                        DataCell(Text(s.fullName)),
                        DataCell(Text(s.community)),
                        DataCell(Text('${s.age}')),
                        DataCell(Text(s.status[0].toUpperCase() + s.status.substring(1))),
                      ]))
                  .toList(),
            ),
          );
        },
      ),
    );
  }
}