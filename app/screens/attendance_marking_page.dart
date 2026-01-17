import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/attendance_service.dart';
import '../services/class_service.dart';

class AttendanceMarkingPage extends StatefulWidget {
  const AttendanceMarkingPage({super.key});

  @override
  State<AttendanceMarkingPage> createState() => _AttendanceMarkingPageState();
}

class _AttendanceMarkingPageState extends State<AttendanceMarkingPage> {
  String? _selectedClassId;
  String? _selectedClassName;
  String? _selectedSection;
  bool _isLoading = false;
  final Map<String, Map<String, dynamic>> _presentStudents = {};
  final Map<String, Map<String, dynamic>> _absentStudents = {};
  bool _scanInProgress = false;

  @override
  void dispose() {
    // Clean up any listeners
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attendanceService = Provider.of<AttendanceService>(context);
    final classService = Provider.of<ClassService>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          attendanceService.isActive
              ? "Attendance - ${attendanceService.currentClassName}"
              : "Attendance Marking",
        ),
      ),
      body: Column(
        children: [
          // Status indicator
          if (attendanceService.isActive)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    theme.colorScheme.tertiary.withOpacity(0.9),
                    theme.colorScheme.tertiary,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.fingerprint,
                      color: theme.colorScheme.tertiary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Session Active",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "Scanning for ${attendanceService.currentClassName}",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _stopAttendance(attendanceService),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: theme.colorScheme.error,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.error,
                            ),
                          )
                        : const Text("End Session"),
                  ),
                ],
              ),
            ),

          // Class selection section
          if (!attendanceService.isActive)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.class_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Select Class",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      StreamBuilder<QuerySnapshot>(
                        stream: classService.getClassesStream(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Center(
                                child: CircularProgressIndicator(
                              color: theme.colorScheme.primary,
                            ));
                          }

                          final classes = snapshot.data!.docs;
                          final groupedClasses =
                              <String, List<Map<String, dynamic>>>{};

                          // Group classes by name
                          for (final doc in classes) {
                            final classData =
                                doc.data() as Map<String, dynamic>;
                            final className = classData['name'];

                            if (!groupedClasses.containsKey(className)) {
                              groupedClasses[className] = [];
                            }
                            groupedClasses[className]!.add({
                              'id': doc.id,
                              'data': classData,
                            });
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Select Class/Section",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 120,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: groupedClasses.length,
                                  itemBuilder: (context, index) {
                                    final className =
                                        groupedClasses.keys.elementAt(index);
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: _ClassOptionCard(
                                        className: className,
                                        isSelected:
                                            _selectedClassName == className,
                                        sectionCount:
                                            groupedClasses[className]!.length,
                                        onTap: () {
                                          setState(() {
                                            _selectedClassName = className;
                                            _selectedClassId = null;
                                            _selectedSection = null;
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (_selectedClassName != null) ...[
                                const SizedBox(height: 20),
                                Text(
                                  "Select Section",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: groupedClasses[_selectedClassName]!
                                      .map((sectionData) {
                                    final classData = sectionData['data'];
                                    final section = classData['section'];
                                    final isSelected =
                                        _selectedSection == section;

                                    return ChoiceChip(
                                      label: Text(
                                        "Section $section",
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedSection = section;
                                            _selectedClassId =
                                                sectionData['id'];
                                          } else {
                                            _selectedSection = null;
                                            _selectedClassId = null;
                                          }
                                        });
                                      },
                                      selectedColor: theme.colorScheme.primary,
                                      backgroundColor:
                                          theme.colorScheme.surfaceVariant,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                              const SizedBox(height: 24),
                              Center(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _selectedClassId == null || _isLoading
                                          ? null
                                          : () => _startAttendance(
                                              attendanceService, classService),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text("Start Attendance Session"),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    minimumSize: const Size(200, 50),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Live attendance display (when active)
          if (attendanceService.isActive)
            Expanded(
              child: Column(
                children: [
                  // Attendance panels
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Present Students Panel
                          Expanded(
                            child: _AttendancePanel(
                              title: "Present Students",
                              studentCount: _presentStudents.length,
                              emptyMessage: "No students marked present yet",
                              color: theme.colorScheme.tertiary,
                              students: _presentStudents,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Pending Students Panel
                          Expanded(
                            child: _AttendancePanel(
                              title: "Pending Students",
                              studentCount: _absentStudents.length,
                              emptyMessage: "All students are present",
                              color: theme.colorScheme.secondary,
                              students: _absentStudents,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _startAttendance(
      AttendanceService service, ClassService classService) async {
    if (_selectedClassId == null ||
        _selectedClassName == null ||
        _selectedSection == null) return;

    setState(() => _isLoading = true);

    try {
      // Create full class name with section
      final fullClassName = '$_selectedClassName - Section $_selectedSection';

      // Get class details to populate absent students list
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(_selectedClassId!)
          .get();

      // Clear existing data
      _presentStudents.clear();
      _absentStudents.clear();

      if (classDoc.exists) {
        final classData = classDoc.data() as Map<String, dynamic>;
        final studentIds = List<String>.from(classData['student_ids'] ?? []);

        // Get student details for each ID
        for (final studentId in studentIds) {
          // Validate student ID
          if (studentId.isEmpty || studentId.toLowerCase() == "none") {
            continue;
          }

          try {
            final studentDoc = await FirebaseFirestore.instance
                .collection('students')
                .doc(studentId)
                .get();

            if (studentDoc.exists) {
              final studentData = studentDoc.data() as Map<String, dynamic>;
              _absentStudents[studentId] = {
                'name': studentData['name'] ?? 'Unknown',
                'roll_no': studentData['roll_no'] ?? 'Unknown',
              };
            }
          } catch (e) {
            print("Error loading student $studentId: $e");
          }
        }
      }

      // Start attendance session with full class name including section
      await service.startAttendance(_selectedClassId!, fullClassName);

      // Start listening for scans using the new method
      service.startListeningForScans((fingerId, status, data) async {
        // Show dialog for each scan
        await _showScanDialog(fingerId, status, data);
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Attendance started for $fullClassName"),
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
            content: Text("Failed to start attendance: $e"),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showScanDialog(
      String fingerId, String status, Map<String, dynamic> data) async {
    // Prevent multiple dialogs
    if (_scanInProgress) return;
    _scanInProgress = true;

    // Determine dialog content
    Color dialogColor;
    IconData dialogIcon;
    String dialogTitle;
    String dialogMessage;
    int autoCloseDuration = 2000; // Default 2 seconds

    switch (status) {
      case "Success":
        dialogColor = Theme.of(context).colorScheme.tertiary;
        dialogIcon = Icons.check_circle;
        dialogTitle = "Attendance Marked";
        dialogMessage = "${data['name']}\n${data['roll_no']}";
        autoCloseDuration = 1500; // 1.5 seconds for success

        // Move student from absent to present if fingerId is valid
        if (fingerId.isNotEmpty && _absentStudents.containsKey(fingerId)) {
          setState(() {
            _presentStudents[fingerId] = _absentStudents[fingerId]!;
            _absentStudents.remove(fingerId);
          });
        }
        break;
      case "Not_Found":
        dialogColor = Colors.orange;
        dialogIcon = Icons.error_outline;
        dialogTitle = "Fingerprint Not Found";
        dialogMessage = "No matching fingerprint in database";
        autoCloseDuration = 2000; // 2 seconds
        break;
      case "Not_in_Class":
        dialogColor = Theme.of(context).colorScheme.error;
        dialogIcon = Icons.block;
        dialogTitle = "Not in Class";
        // Check if we have the student data
        if (data['finger_id']?.isNotEmpty == true) {
          final fingerIdFromData = data['finger_id'] as String;
          // Student exists but not in this class - remove from absent list if present
          if (_absentStudents.containsKey(fingerIdFromData)) {
            setState(() {
              _absentStudents.remove(fingerIdFromData);
            });
            dialogMessage = "Student ${data['finger_id']} removed from list";
          } else {
            dialogMessage = "Student not enrolled in this class";
          }
        } else {
          dialogMessage = "Student not enrolled in this class";
        }
        autoCloseDuration = 2000; // 2 seconds
        break;
      case "error":
        dialogColor = Colors.grey;
        dialogIcon = Icons.error;
        dialogTitle = "Error";
        dialogMessage = data['error']?.toString() ?? "An error occurred";
        autoCloseDuration = 2500; // 2.5 seconds for errors
        break;
      default:
        dialogColor = Colors.blue;
        dialogIcon = Icons.hourglass_empty;
        dialogTitle = "Processing...";
        dialogMessage = "Verifying fingerprint";
        autoCloseDuration = 1000; // 1 second for processing
    }

    // Show dialog
    if (context.mounted) {
      Completer<void> dialogCompleter = Completer<void>();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: dialogColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    dialogIcon,
                    size: 40,
                    color: dialogColor,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  dialogTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  dialogMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
                ),
                if (status == "pending") ...[
                  const SizedBox(height: 16),
                  CircularProgressIndicator(
                    color: dialogColor,
                    strokeWidth: 2,
                  ),
                ],
              ],
            ),
          ),
        ),
      ).then((_) {
        dialogCompleter.complete();
      });

      // Auto-close after specified duration
      Future.delayed(Duration(milliseconds: autoCloseDuration), () {
        if (context.mounted &&
            Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        dialogCompleter.complete();
      });

      // Wait for dialog to close (either by timer or user)
      await dialogCompleter.future;
    }

    // Reset scan progress
    _scanInProgress = false;
  }

  Future<void> _stopAttendance(AttendanceService service) async {
    setState(() => _isLoading = true);

    try {
      await service.stopAttendance();

      // Clear student lists
      setState(() {
        _presentStudents.clear();
        _absentStudents.clear();
        _scanInProgress = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Attendance session saved successfully"),
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
            content: Text("Failed to stop attendance: $e"),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
        _selectedClassId = null;
        _selectedClassName = null;
        _selectedSection = null;
      });
    }
  }
}

class _ClassOptionCard extends StatelessWidget {
  final String className;
  final bool isSelected;
  final int sectionCount;
  final VoidCallback onTap;

  const _ClassOptionCard({
    required this.className,
    required this.isSelected,
    required this.sectionCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.1)
              : theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.6),
              size: 24,
            ),
            const SizedBox(height: 12),
            Text(
              className,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              "$sectionCount section${sectionCount == 1 ? '' : 's'}",
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendancePanel extends StatelessWidget {
  final String title;
  final int studentCount;
  final String emptyMessage;
  final Color color;
  final Map<String, Map<String, dynamic>> students;

  const _AttendancePanel({
    required this.title,
    required this.studentCount,
    required this.emptyMessage,
    required this.color,
    required this.students,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    studentCount.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: students.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            title.contains("Present")
                                ? Icons.people_outline
                                : Icons.person_outline,
                            size: 64,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            emptyMessage,
                            style: TextStyle(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.5),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final studentId = students.keys.elementAt(index);
                        final student = students[studentId]!;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: color.withOpacity(0.1),
                              child: Icon(
                                title.contains("Present")
                                    ? Icons.check_circle_outline
                                    : Icons.person_outline,
                                color: color,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              student['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              "Roll: ${student['roll_no']}",
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.7),
                              ),
                            ),
                            trailing: Text(
                              "ID: $studentId",
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
