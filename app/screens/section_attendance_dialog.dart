import 'package:biomark/services/export_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'session_details_dialog.dart';
import 'package:intl/intl.dart';

class SectionAttendanceDialog extends StatefulWidget {
  final String className;
  final String section;
  final List<Map<String, dynamic>> records;

  const SectionAttendanceDialog({
    super.key,
    required this.className,
    required this.section,
    required this.records,
  });

  @override
  State<SectionAttendanceDialog> createState() =>
      _SectionAttendanceDialogState();
}

class _SectionAttendanceDialogState extends State<SectionAttendanceDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, List<Map<String, dynamic>>> _monthlyRecords = {};
  final Map<String, List<Map<String, dynamic>>> _dailyRecords = {};
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _groupRecordsByMonth();
    _tabController = TabController(
      length: _monthlyRecords.keys.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _groupRecordsByMonth() {
    _monthlyRecords.clear();

    for (final record in widget.records) {
      final data = record['data'];
      final startTime = (data['start_time'] as Timestamp).toDate();
      final monthYear = DateFormat('MMMM yyyy').format(startTime);

      if (!_monthlyRecords.containsKey(monthYear)) {
        _monthlyRecords[monthYear] = [];
      }

      _monthlyRecords[monthYear]!.add(record);
    }

    // Sort months in descending order (newest first)
    final sortedMonths = _monthlyRecords.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('MMMM yyyy').parse(a);
        final dateB = DateFormat('MMMM yyyy').parse(b);
        return dateB.compareTo(dateA);
      });

    // Reorder the map
    final sortedMap = <String, List<Map<String, dynamic>>>{};
    for (final month in sortedMonths) {
      sortedMap[month] = _monthlyRecords[month]!;
    }

    _monthlyRecords.clear();
    _monthlyRecords.addAll(sortedMap);
  }

  void _groupRecordsByDay(String monthYear) {
    _dailyRecords.clear();
    final monthRecords = _monthlyRecords[monthYear] ?? [];

    for (final record in monthRecords) {
      final data = record['data'];
      final startTime = (data['start_time'] as Timestamp).toDate();
      final dateKey = DateFormat('dd MMM yyyy').format(startTime);

      if (!_dailyRecords.containsKey(dateKey)) {
        _dailyRecords[dateKey] = [];
      }

      _dailyRecords[dateKey]!.add(record);
    }

    // Sort dates in descending order (newest first)
    final sortedDates = _dailyRecords.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('dd MMM yyyy').parse(a);
        final dateB = DateFormat('dd MMM yyyy').parse(b);
        return dateB.compareTo(dateA);
      });

    // Reorder the map
    final sortedMap = <String, List<Map<String, dynamic>>>{};
    for (final date in sortedDates) {
      sortedMap[date] = _dailyRecords[date]!;
    }

    _dailyRecords.clear();
    _dailyRecords.addAll(sortedMap);

    // Select first date by default
    if (_dailyRecords.isNotEmpty) {}
  }

  Color _withCustomOpacity(Color color, double opacity) {
    return Color.fromRGBO(color.red, color.green, color.blue, opacity);
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = _monthlyRecords.keys.isNotEmpty
        ? _monthlyRecords.keys.elementAt(_tabController.index)
        : '';

    if (currentMonth.isNotEmpty && _dailyRecords.isEmpty) {
      _groupRecordsByDay(currentMonth);
    }

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 600,
          maxHeight: 700,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.className,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Section ${widget.section}",
                          style: TextStyle(
                            fontSize: 14,
                            color: _withCustomOpacity(
                              Theme.of(context).colorScheme.onSurface,
                              0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: _withCustomOpacity(
                        Theme.of(context).colorScheme.onSurface,
                        0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Month Tabs
            if (_monthlyRecords.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: _withCustomOpacity(
                    Theme.of(context).colorScheme.onSurface,
                    0.7,
                  ),
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorWeight: 3,
                  tabs: _monthlyRecords.keys
                      .map((month) => Tab(text: month))
                      .toList(),
                  onTap: (index) {
                    final month = _monthlyRecords.keys.elementAt(index);
                    _groupRecordsByDay(month);
                    setState(() {});
                  },
                ),
              ),

            // Compact Statistics with Export button
            if (currentMonth.isNotEmpty && _dailyRecords.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Total Students
                            _CompactStatItem(
                              value: _calculateTotalStudents(currentMonth)
                                  .toString(),
                              label: "Students",
                              icon: Icons.people_outline,
                              context: context,
                            ),

                            // Vertical Divider
                            Container(
                              width: 1,
                              height: 40,
                              color: Theme.of(context).dividerColor,
                            ),

                            // Attendance Days
                            _CompactStatItem(
                              value: _calculateTotalAttendanceDays(currentMonth)
                                  .toString(),
                              label: "Days",
                              icon: Icons.event_note_outlined,
                              context: context,
                            ),

                            // Vertical Divider
                            Container(
                              width: 1,
                              height: 40,
                              color: Theme.of(context).dividerColor,
                            ),

                            // Total Sessions (for reference)
                            _CompactStatItem(
                              value: _monthlyRecords[currentMonth]!
                                  .length
                                  .toString(),
                              label: "Sessions",
                              icon: Icons.schedule_outlined,
                              context: context,
                            ),

                            // Vertical Divider
                            Container(
                              width: 1,
                              height: 40,
                              color: Theme.of(context).dividerColor,
                            ),

                            // Export Button
                            ElevatedButton.icon(
                              onPressed: _isExporting
                                  ? null
                                  : () => _exportToExcel(currentMonth),
                              icon: _isExporting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.download, size: 18),
                              label: _isExporting
                                  ? const Text("Exporting...")
                                  : const Text("Export"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.tertiary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Month: $currentMonth",
                          style: TextStyle(
                            fontSize: 12,
                            color: _withCustomOpacity(
                              Theme.of(context).colorScheme.onSurface,
                              0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Date-wise Attendance
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Daily Attendance",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            "${_dailyRecords.length} day${_dailyRecords.length == 1 ? '' : 's'}",
                            style: TextStyle(
                              fontSize: 12,
                              color: _withCustomOpacity(
                                Theme.of(context).colorScheme.onSurface,
                                0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _dailyRecords.isEmpty
                          ? Center(
                              child: Text(
                                "No attendance records for this month",
                                style: TextStyle(
                                  color: _withCustomOpacity(
                                    Theme.of(context).colorScheme.onSurface,
                                    0.5,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _dailyRecords.keys.length,
                              itemBuilder: (context, index) {
                                final date =
                                    _dailyRecords.keys.elementAt(index);
                                final dayRecords = _dailyRecords[date]!;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    title: Text(
                                      date,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "${dayRecords.length} session${dayRecords.length == 1 ? '' : 's'}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _withCustomOpacity(
                                          Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                          0.7,
                                        ),
                                      ),
                                    ),
                                    children: dayRecords.map((record) {
                                      final data = record['data'];
                                      final startTime =
                                          (data['start_time'] as Timestamp)
                                              .toDate();
                                      final endTime =
                                          (data['end_time'] as Timestamp)
                                              .toDate();
                                      final students =
                                          List<Map<String, dynamic>>.from(
                                              data['students'] ?? []);
                                      final presentCount = students
                                          .where(
                                              (s) => s['status'] == 'Present')
                                          .length;

                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 6,
                                        ),
                                        dense: true,
                                        leading: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondary
                                              .withAlpha(25),
                                          child: Icon(
                                            Icons.schedule,
                                            size: 16,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                          ),
                                        ),
                                        title: Text(
                                          "${DateFormat('hh:mm a').format(startTime)} - ${DateFormat('hh:mm a').format(endTime)}",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                        ),
                                        subtitle: Text(
                                          "$presentCount/${students.length} present",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .tertiary,
                                          ),
                                        ),
                                        trailing: Icon(
                                          Icons.chevron_right,
                                          size: 18,
                                          color: _withCustomOpacity(
                                            Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                            0.5,
                                          ),
                                        ),
                                        onTap: () {
                                          _showSessionDialog(
                                              record['id'], data);
                                        },
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // Close Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Close"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateTotalStudents(String monthYear) {
    final monthRecords = _monthlyRecords[monthYear] ?? [];
    final allStudents = <String>{};

    for (final record in monthRecords) {
      final students =
          List<Map<String, dynamic>>.from(record['data']['students'] ?? []);
      for (final student in students) {
        final fingerId = student['finger_id']?.toString();
        if (fingerId != null && fingerId.isNotEmpty) {
          allStudents.add(fingerId);
        }
      }
    }

    return allStudents.length;
  }

  int _calculateTotalAttendanceDays(String monthYear) {
    // Count unique dates when attendance was taken
    final monthRecords = _monthlyRecords[monthYear] ?? [];
    final uniqueDates = <String>{};

    for (final record in monthRecords) {
      final data = record['data'];
      final startTime = (data['start_time'] as Timestamp).toDate();
      final dateKey = DateFormat('yyyy-MM-dd').format(startTime);
      uniqueDates.add(dateKey);
    }

    return uniqueDates.length;
  }

  void _showSessionDialog(String recordId, Map<String, dynamic> data) {
    final className = widget.className;
    final section = widget.section;

    showDialog(
      context: context,
      builder: (context) => SessionDetailsDialog(
        sessionId: recordId,
        sessionData: data,
        className: className,
        section: section,
      ),
    );
  }

  void _exportToExcel(String monthYear) async {
    setState(() => _isExporting = true);

    try {
      final exportService = Provider.of<ExportService>(context, listen: false);
      final monthRecords = _monthlyRecords[monthYear] ?? [];

      // Create monthly records map for the specific month
      final Map<String, List<Map<String, dynamic>>> monthlyData = {
        monthYear: monthRecords,
      };

      await exportService.exportMonthlyAttendanceToExcel(
        className: widget.className,
        section: widget.section,
        monthYear: monthYear,
        monthlyRecords: monthlyData,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Attendance data exported for $monthYear"),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to export: ${e.toString()}"),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (context.mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}

class _CompactStatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final BuildContext context;

  const _CompactStatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.context,
  });

  Color _withCustomOpacity(Color color, double opacity) {
    return Color.fromRGBO(color.red, color.green, color.blue, opacity);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: _withCustomOpacity(
              Theme.of(context).colorScheme.onSurface,
              0.6,
            ),
          ),
        ),
      ],
    );
  }
}
