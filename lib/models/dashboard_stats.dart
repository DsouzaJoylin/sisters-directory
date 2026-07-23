/// Aggregated stats for the admin dashboard's stat cards,
/// age distribution chart, and community distribution chart.
/// Typically computed on the fly from the 'sisters' collection
/// by DashboardService rather than stored directly in Firestore.
class DashboardStats {
  final int totalSisters;
  final int pendingProfiles;
  final int approvedProfiles;
  final int rejectedProfiles;
  final int newThisMonth;
  final Map<String, int> communityDistribution; // community name -> count
  final Map<String, int> ageDistribution; // age bracket label -> count

  const DashboardStats({
    required this.totalSisters,
    required this.pendingProfiles,
    required this.approvedProfiles,
    required this.rejectedProfiles,
    required this.newThisMonth,
    required this.communityDistribution,
    required this.ageDistribution,
  });

  /// Empty stats — useful as a loading/fallback state before
  /// the first Firestore snapshot resolves.
  factory DashboardStats.empty() {
    return const DashboardStats(
      totalSisters: 0,
      pendingProfiles: 0,
      approvedProfiles: 0,
      rejectedProfiles: 0,
      newThisMonth: 0,
      communityDistribution: {},
      ageDistribution: {},
    );
  }

  /// Standard age brackets used by AgeDistributionCard.
  static const List<String> ageBrackets = [
    '0-17',
    '18-30',
    '31-45',
    '46-60',
    '60+',
  ];

  /// Buckets a raw age into one of [ageBrackets].
  static String bracketForAge(int age) {
    if (age <= 17) return '0-17';
    if (age <= 30) return '18-30';
    if (age <= 45) return '31-45';
    if (age <= 60) return '46-60';
    return '60+';
  }
}