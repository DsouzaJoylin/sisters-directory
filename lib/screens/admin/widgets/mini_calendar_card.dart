import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../utils/app_colors.dart';
import 'dashboard_card.dart';

/// Compact month calendar for the admin dashboard, built on the
/// `table_calendar` package. Purely presentational for now — no
/// event markers wired in yet (would need a dedicated 'events'
/// Firestore collection, which isn't in the current project scope).
class MiniCalendarCard extends StatefulWidget {
  const MiniCalendarCard({super.key});

  @override
  State<MiniCalendarCard> createState() => _MiniCalendarCardState();
}

class _MiniCalendarCardState extends State<MiniCalendarCard> {
  final DateTime _today = DateTime.now();
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = _today;
    _selectedDay = _today;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TableCalendar(
        firstDay: DateTime(_today.year - 5, 1, 1),
        lastDay: DateTime(_today.year + 5, 12, 31),
        focusedDay: _focusedDay,
        currentDay: _today,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        calendarFormat: CalendarFormat.month,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, size: 20, color: AppColors.textSecondary),
          rightChevronIcon: Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          weekendStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
          weekendTextStyle: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
          todayDecoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(color: Colors.white, fontSize: 12.5),
          selectedDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
          markerDecoration: const BoxDecoration(
            color: AppColors.secondary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}