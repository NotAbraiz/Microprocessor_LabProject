import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';
import 'section_attendance_dialog.dart';

class AttendanceRecordsPage extends StatefulWidget {
  const AttendanceRecordsPage({super.key});

  @override
  State<AttendanceRecordsPage> createState() => _AttendanceRecordsPageState();
}

class _AttendanceRecordsPageState extends State<AttendanceRecordsPage> {
  final TextEditingController _searchController = TextEditingController();
  DateTime? _selectedDate;
  final Map<String, Map<String, List<Map<String, dynamic>>>> _groupedRecords =
      {};

  @override
  Widget build(BuildContext context) {
    final attendanceService = Provider.of<AttendanceService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Records"),
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Filter Records",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: "Search by class name...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        ),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 20,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _selectedDate == null
                                        ? "Filter by date"
                                        : DateFormat('dd/MM/yyyy')
                                            .format(_selectedDate!),
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_selectedDate != null)
                                    IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        size: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                      ),
                                      onPressed: () {
                                        setState(() => _selectedDate = null);
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Records List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: attendanceService.getAttendanceRecordsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_outlined,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No attendance records",
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Start an attendance session to create records",
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final records = snapshot.data!.docs;
                final searchQuery = _searchController.text.toLowerCase();

                // Group records by class name, then by section
                _groupedRecords.clear();
                for (final doc in records) {
                  final data = doc.data() as Map<String, dynamic>;
                  final className = data['class_name']?.toString() ?? 'Unknown';
                  final section = data['section']?.toString() ?? 'No Section';

                  // Apply filters
                  if (searchQuery.isNotEmpty &&
                      !className.toLowerCase().contains(searchQuery)) {
                    continue;
                  }

                  if (_selectedDate != null) {
                    final recordDate =
                        (data['created_at'] as Timestamp).toDate();
                    if (DateFormat('yyyy-MM-dd').format(recordDate) !=
                        DateFormat('yyyy-MM-dd').format(_selectedDate!)) {
                      continue;
                    }
                  }

                  // Initialize class group if not exists
                  if (!_groupedRecords.containsKey(className)) {
                    _groupedRecords[className] = {};
                  }

                  // Initialize section group if not exists
                  if (!_groupedRecords[className]!.containsKey(section)) {
                    _groupedRecords[className]![section] = [];
                  }

                  _groupedRecords[className]![section]!.add({
                    'id': doc.id,
                    'data': data,
                  });
                }

                if (_groupedRecords.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No records found",
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Try adjusting your search or filters",
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Sort class names alphabetically
                final sortedClassNames = _groupedRecords.keys.toList()
                  ..sort((a, b) => a.compareTo(b));

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: sortedClassNames.length,
                  itemBuilder: (context, classIndex) {
                    final className = sortedClassNames[classIndex];
                    final sections = _groupedRecords[className]!;

                    // Sort section names
                    final sortedSections = sections.keys.toList()
                      ..sort((a, b) => a.compareTo(b));

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Class Header
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.school_outlined,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          className,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          "${sections.length} section${sections.length == 1 ? '' : 's'}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Divider
                            Divider(
                              color: Theme.of(context).dividerColor,
                              height: 1,
                            ),

                            // Sections List
                            ...sortedSections.map((section) {
                              final sectionRecords = sections[section]!;
                              // Sort records by date (newest first)
                              sectionRecords.sort((a, b) {
                                final dateA =
                                    (a['data']['created_at'] as Timestamp)
                                        .toDate();
                                final dateB =
                                    (b['data']['created_at'] as Timestamp)
                                        .toDate();
                                return dateB.compareTo(dateA);
                              });

                              return InkWell(
                                onTap: () => _showSectionDialog(
                                  className,
                                  section,
                                  sectionRecords,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: classIndex ==
                                                    sortedClassNames.length -
                                                        1 &&
                                                sortedSections.last == section
                                            ? BorderSide.none
                                            : BorderSide(
                                                color: Theme.of(context)
                                                    .dividerColor,
                                                width: 1,
                                              ),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .secondary
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: Text(
                                                section,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .secondary,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Section $section",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                ),
                                                Text(
                                                  "${sectionRecords.length} session${sectionRecords.length == 1 ? '' : 's'}",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.6),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showSectionDialog(
    String className,
    String section,
    List<Map<String, dynamic>> records,
  ) {
    showDialog(
      context: context,
      builder: (context) => SectionAttendanceDialog(
        className: className,
        section: section,
        records: records,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
