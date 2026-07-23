import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_constants.dart';

/// Navigation destinations available in the admin sidebar.
/// Index order here must match the pages list built in
/// AdminDashboardScreen.
enum AdminPage { dashboard, manageSisters, addSister, reports, settings }

/// Left-hand navigation rail for the admin dashboard. Highlights
/// the currently selected page and notifies the parent via
/// [onPageSelected] when a different item is tapped.
class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.selectedPage,
    required this.onPageSelected,
  });

  final AdminPage selectedPage;
  final ValueChanged<AdminPage> onPageSelected;

  static const _items = [
    _SidebarItem(page: AdminPage.dashboard, icon: Icons.dashboard_outlined, label: 'Dashboard'),
    _SidebarItem(page: AdminPage.manageSisters, icon: Icons.groups_outlined, label: 'Manage Sisters'),
    _SidebarItem(page: AdminPage.addSister, icon: Icons.person_add_alt_outlined, label: 'Add Sister'),
    _SidebarItem(page: AdminPage.reports, icon: Icons.bar_chart_outlined, label: 'Reports'),
    _SidebarItem(page: AdminPage.settings, icon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.primaryDark,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBrand(),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _items
                    .map((item) => _buildNavTile(item))
                    .toList(),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            _buildSignOutTile(context),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Icon(Icons.diversity_3_rounded, color: Colors.white, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              AppConstants.appName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile(_SidebarItem item) {
    final isSelected = item.page == selectedPage;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onPageSelected(item.page),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
                const SizedBox(width: 14),
                Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => AuthService.instance.signOut(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.logout, size: 20, color: Colors.white70),
                SizedBox(width: 14),
                Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem {
  final AdminPage page;
  final IconData icon;
  final String label;

  const _SidebarItem({
    required this.page,
    required this.icon,
    required this.label,
  });
}