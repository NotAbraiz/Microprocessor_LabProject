import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/class_service.dart';
import '../services/student_service.dart';

class ManageStudentsScreen extends StatefulWidget {
  final String classId;
  final String className;

  const ManageStudentsScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Set<String> _selectedStudents = {};
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final classService = Provider.of<ClassService>(context);
    final studentService = Provider.of<StudentService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Students - ${widget.className}"),
      ),
      floatingActionButton: _selectedStudents.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _addSelectedStudents(classService),
              label: Text("Add ${_selectedStudents.length}"),
              icon: const Icon(Icons.add),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: "Search Students",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: studentService.getStudentsStream(),
                    builder: (context, studentSnapshot) {
                      if (!studentSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return StreamBuilder<DocumentSnapshot>(
                        stream: classService.getClassStream(widget.classId),
                        builder: (context, classSnapshot) {
                          if (!classSnapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final classData = classSnapshot.data!.data()
                              as Map<String, dynamic>;
                          final List<dynamic> classStudentIds =
                              classData['student_ids'] ?? [];

                          final students = studentSnapshot.data!.docs;
                          final searchQuery =
                              _searchController.text.toLowerCase();

                          final filteredStudents = students.where((doc) {
                            final student = doc.data() as Map<String, dynamic>;
                            final name =
                                student['name'].toString().toLowerCase();
                            final rollNo =
                                student['roll_no'].toString().toLowerCase();
                            final studentId = student['finger_id'].toString();
                            return name.contains(searchQuery) ||
                                rollNo.contains(searchQuery) ||
                                studentId.contains(searchQuery);
                          }).toList();

                          return ListView.builder(
                            itemCount: filteredStudents.length,
                            itemBuilder: (context, index) {
                              final doc = filteredStudents[index];
                              final student =
                                  doc.data() as Map<String, dynamic>;
                              final studentId = student['finger_id'].toString();
                              final isInClass =
                                  classStudentIds.contains(studentId);

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 4.0,
                                ),
                                child: CheckboxListTile(
                                  title: Text(student['name']),
                                  subtitle: Text(
                                      "Roll: ${student['roll_no']} | ID: $studentId"),
                                  secondary: CircleAvatar(
                                    child: Text(studentId),
                                  ),
                                  value: isInClass ||
                                      _selectedStudents.contains(studentId),
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedStudents.add(studentId);
                                      } else {
                                        _selectedStudents.remove(studentId);
                                      }
                                    });
                                  },
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                ),
                              );
                            },
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

  Future<void> _addSelectedStudents(ClassService service) async {
    setState(() => _isLoading = true);

    try {
      await service.addStudentsToClass(
        widget.classId,
        _selectedStudents.toList(),
      );

      setState(() {
        _selectedStudents.clear();
        _isLoading = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Added ${_selectedStudents.length} student(s) to class"),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to add students: $e")),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
