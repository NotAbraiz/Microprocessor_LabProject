import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SessionDetailsDialog extends StatefulWidget {
  final String sessionId;
  final Map<String, dynamic> sessionData;
  final String className;
  final String section;

  const SessionDetailsDialog({
    super.key,
    required this.sessionId,
    required this.sessionData,
    required this.className,
    required this.section,
  });

  @override
  State<SessionDetailsDialog> createState() => _SessionDetailsDialogState();
}

class _SessionDetailsDialogState extends State<SessionDetailsDialog> {
  List<Map<String, dynamic>> _presentStudents = [];
  List<Map<String, dynamic>> _absentStudents = [];
  List<Map<String, dynamic>> _otherStatusStudents = [];
  bool _isLoading = true;
  int _totalClassStudents = 0;

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    try {
      // Get all students from this class
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .where('name', isEqualTo: widget.className)
          .where('section', isEqualTo: widget.section)
          .get();

      if (classDoc.docs.isNotEmpty) {
        final classData = classDoc.docs.first.data();
        final classStudentIds =
            List<String>.from(classData['student_ids'] ?? []);
        _totalClassStudents = classStudentIds.length;

        // Get session students
        final sessionStudents = List<Map<String, dynamic>>.from(
            widget.sessionData['students'] ?? []);

        // Separate students by status
        final presentStudents = <Map<String, dynamic>>[];
        final absentStudents = <Map<String, dynamic>>[];
        final otherStatusStudents = <Map<String, dynamic>>[];

        // Get enrolled students details
        final enrolledStudents = <String, Map<String, dynamic>>{};

        for (final studentId in classStudentIds) {
          if (studentId.isNotEmpty && studentId.toLowerCase() != "none") {
            try {
              final studentDoc = await FirebaseFirestore.instance
                  .collection('students')
                  .doc(studentId)
                  .get();

              if (studentDoc.exists) {
                enrolledStudents[studentId] = {
                  'finger_id': studentId,
                  'name': studentDoc.data()!['name'] ?? 'Unknown',
                  'roll_no': studentDoc.data()!['roll_no'] ?? 'Unknown',
                  'enrolled_at': studentDoc.data()!['enrolled_at'],
                  'status': 'Absent', // Default status
                };
              }
            } catch (e) {
              print("Error loading student $studentId: $e");
            }
          }
        }

        // Update status based on session attendance
        for (final sessionStudent in sessionStudents) {
          final fingerId = sessionStudent['finger_id']?.toString() ?? '';
          final status = sessionStudent['status']?.toString() ?? '';

          if (fingerId.isNotEmpty && enrolledStudents.containsKey(fingerId)) {
            if (status == 'Present') {
              enrolledStudents[fingerId]!['status'] = 'Present';
              enrolledStudents[fingerId]!['timestamp'] =
                  sessionStudent['timestamp'];
            }
            // Ignore 'Not Found' and 'Not in Class' statuses
          }
        }

        // Separate into present and absent lists
        for (final student in enrolledStudents.values) {
          if (student['status'] == 'Present') {
            presentStudents.add(student);
          } else {
            absentStudents.add(student);
          }
        }

        // Add other status students (Not Found, Not in Class, etc.)
        for (final sessionStudent in sessionStudents) {
          final status = sessionStudent['status']?.toString() ?? '';
          if (status != 'Present' &&
              status != 'Absent' &&
              !status.toLowerCase().contains('not found') &&
              !status.toLowerCase().contains('not in class')) {
            otherStatusStudents.add(sessionStudent);
          }
        }

        // Sort by roll number
        presentStudents.sort((a, b) {
          final rollA = a['roll_no']?.toString() ?? '';
          final rollB = b['roll_no']?.toString() ?? '';
          return rollA.compareTo(rollB);
        });

        absentStudents.sort((a, b) {
          final rollA = a['roll_no']?.toString() ?? '';
          final rollB = b['roll_no']?.toString() ?? '';
          return rollA.compareTo(rollB);
        });

        setState(() {
          _presentStudents = presentStudents;
          _absentStudents = absentStudents;
          _otherStatusStudents = otherStatusStudents;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading session data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _withCustomOpacity(Color color, double opacity) {
    return Color.fromRGBO(color.red, color.green, color.blue, opacity);
  }

  @override
  Widget build(BuildContext context) {
    final startTime = (widget.sessionData['start_time'] as Timestamp).toDate();
    final endTime = (widget.sessionData['end_time'] as Timestamp).toDate();
    final duration = endTime.difference(startTime);
    final dateFormat = DateFormat('dd MMM yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 700,
          maxHeight: 800,
        ),
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            : Column(
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
                                "${widget.className} - Section ${widget.section}",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "${dateFormat.format(startTime)}, ${timeFormat.format(startTime)} - ${timeFormat.format(endTime)}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _withCustomOpacity(
                                    Theme.of(context).colorScheme.onSurface,
                                    0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Duration: ${duration.inMinutes} minutes",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _withCustomOpacity(
                                    Theme.of(context).colorScheme.onSurface,
                                    0.6,
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

                  // Statistics Card (only Total, Present, Absent)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatCard(
                              title: "Total",
                              value: _totalClassStudents.toString(),
                              color: Theme.of(context).colorScheme.primary,
                              icon: Icons.people_outline,
                            ),
                            _StatCard(
                              title: "Present",
                              value: _presentStudents.length.toString(),
                              color: Theme.of(context).colorScheme.tertiary,
                              icon: Icons.check_circle_outline,
                            ),
                            _StatCard(
                              title: "Absent",
                              value: _absentStudents.length.toString(),
                              color: Theme.of(context).colorScheme.error,
                              icon: Icons.person_off_outlined,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tabs for Present/Absent/Other
                  Expanded(
                    child: DefaultTabController(
                      length: _otherStatusStudents.isEmpty ? 2 : 3,
                      child: Column(
                        children: [
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
                              labelColor: Theme.of(context).colorScheme.primary,
                              unselectedLabelColor: _withCustomOpacity(
                                Theme.of(context).colorScheme.onSurface,
                                0.7,
                              ),
                              indicatorColor:
                                  Theme.of(context).colorScheme.primary,
                              indicatorWeight: 3,
                              tabs: [
                                Tab(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                          "Present (${_presentStudents.length})"),
                                    ],
                                  ),
                                ),
                                Tab(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person_off, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                          "Absent (${_absentStudents.length})"),
                                    ],
                                  ),
                                ),
                                if (_otherStatusStudents.isNotEmpty)
                                  Tab(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.info, size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                            "Other (${_otherStatusStudents.length})"),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // Present Students Tab
                                _buildStudentsList(
                                  _presentStudents,
                                  Theme.of(context).colorScheme.tertiary,
                                  "No students were present for this session",
                                ),

                                // Absent Students Tab
                                _buildStudentsList(
                                  _absentStudents,
                                  Theme.of(context).colorScheme.error,
                                  "All students were present for this session",
                                ),

                                // Other Status Tab (if exists)
                                if (_otherStatusStudents.isNotEmpty)
                                  _buildOtherStatusList(_otherStatusStudents),
                              ],
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

  Widget _buildStudentsList(
    List<Map<String, dynamic>> students,
    Color statusColor,
    String emptyMessage,
  ) {
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: _withCustomOpacity(
                Theme.of(context).colorScheme.onSurface,
                0.3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: _withCustomOpacity(
                  Theme.of(context).colorScheme.onSurface,
                  0.5,
                ),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final enrolledAt = student['enrolled_at'] as Timestamp?;
        final enrolledDate = enrolledAt != null
            ? DateFormat('dd MMM yyyy').format(enrolledAt.toDate())
            : 'Unknown';

        final rollNo = student['roll_no']?.toString() ?? 'N/A';
        final name = student['name']?.toString() ?? 'Unknown';
        final fingerId = student['finger_id']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            leading: CircleAvatar(
              backgroundColor: statusColor.withAlpha(25),
              child: Text(
                fingerId, // Display full roll number
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: statusColor.withAlpha(50),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    rollNo,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  "Fingerprint ID: $fingerId",
                  style: TextStyle(
                    fontSize: 11,
                    color: _withCustomOpacity(
                      Theme.of(context).colorScheme.onSurface,
                      0.7,
                    ),
                  ),
                ),
                Text(
                  "Enrolled: $enrolledDate",
                  style: TextStyle(
                    fontSize: 11,
                    color: _withCustomOpacity(
                      Theme.of(context).colorScheme.onSurface,
                      0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOtherStatusList(List<Map<String, dynamic>> otherStudents) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: otherStudents.length,
      itemBuilder: (context, index) {
        final student = otherStudents[index];
        final status = student['status']?.toString() ?? 'Unknown';
        final fingerId = student['finger_id']?.toString() ?? '';
        final name = student['name']?.toString() ?? 'Unknown';
        final rollNo = student['roll_no']?.toString() ?? 'N/A';

        Color statusColor;
        IconData statusIcon;

        if (status.toLowerCase().contains('not found')) {
          statusColor = Colors.grey;
          statusIcon = Icons.search_off;
        } else if (status.toLowerCase().contains('not in class')) {
          statusColor = Colors.orange;
          statusIcon = Icons.block;
        } else {
          statusColor = Colors.blue;
          statusIcon = Icons.info;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: _withCustomOpacity(statusColor, 0.05),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            leading: CircleAvatar(
              backgroundColor: statusColor.withAlpha(25),
              child: Icon(
                statusIcon,
                size: 18,
                color: statusColor,
              ),
            ),
            title: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  "Roll: $rollNo | ID: $fingerId",
                  style: TextStyle(
                    fontSize: 11,
                    color: _withCustomOpacity(
                      Theme.of(context).colorScheme.onSurface,
                      0.7,
                    ),
                  ),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: statusColor.withAlpha(50),
                  width: 1,
                ),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 22,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: Color.fromRGBO(
              Theme.of(context).colorScheme.onSurface.red,
              Theme.of(context).colorScheme.onSurface.green,
              Theme.of(context).colorScheme.onSurface.blue,
              0.7,
            ),
          ),
        ),
      ],
    );
  }
}
