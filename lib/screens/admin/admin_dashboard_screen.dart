import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';
import 'pages/admin_add_sister_screen.dart';
import 'pages/dashboard_page.dart';
import 'pages/manage_sisters_page.dart';
import 'pages/reports_page.dart';
import 'pages/settings_page.dart';
import 'widgets/admin_header.dart';
import 'widgets/admin_sidebar.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminPage _selectedPage = AdminPage.dashboard;

  // Below this width we treat the device as "mobile" and use a Drawer
  // instead of a permanent side-by-side sidebar.
  static const double _mobileBreakpoint = 700;

  static const Map<AdminPage, String> _titles = {
    AdminPage.dashboard: 'Dashboard',
    AdminPage.manageSisters: 'Manage Sisters',
    AdminPage.addSister: 'Add Sister',
    AdminPage.reports: 'Reports',
    AdminPage.settings: 'Settings',
  };

  Widget _buildPage() {
    switch (_selectedPage) {
      case AdminPage.dashboard:
        return DashboardPage(
          onNavigateToManageSisters: () =>
              setState(() => _selectedPage = AdminPage.manageSisters),
          onNavigateToAddSister: () =>
              setState(() => _selectedPage = AdminPage.addSister),
          onNavigateToReports: () =>
              setState(() => _selectedPage = AdminPage.reports),
        );
      case AdminPage.manageSisters:
        return const ManageSistersPage();
      case AdminPage.addSister:
        return const AdminAddSisterScreen();
      case AdminPage.reports:
        return const ReportsPage();
      case AdminPage.settings:
        return const SettingsPage();
    }
  }

  void _onPageSelected(AdminPage page, {bool isMobile = false}) {
    setState(() => _selectedPage = page);
    if (isMobile) {
      Navigator.of(context).pop(); // close the drawer
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < _mobileBreakpoint;

    if (isMobile) {
      // MOBILE LAYOUT: sidebar lives in a Drawer, content gets full width.
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_titles[_selectedPage]!),
          backgroundColor: AppColors.background,
        ),
        drawer: Drawer(
          child: AdminSidebar(
            selectedPage: _selectedPage,
            onPageSelected: (page) =>
                _onPageSelected(page, isMobile: true),
          ),
        ),
        body: _buildPage(),
      );
    }

    // DESKTOP / TABLET LAYOUT: permanent side-by-side sidebar.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          AdminSidebar(
            selectedPage: _selectedPage,
            onPageSelected: (page) => _onPageSelected(page),
          ),
          Expanded(
            child: Column(
              children: [
                AdminHeader(title: _titles[_selectedPage]!),
                Expanded(child: _buildPage()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}