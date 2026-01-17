import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/class_service.dart';
import '../services/student_service.dart';

class ClassesPage extends StatefulWidget {
  const ClassesPage({super.key});

  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  final _classNameController = TextEditingController();
  final _searchController = TextEditingController();
  final Map<String, List<Map<String, dynamic>>> _groupedClasses = {};

  @override
  Widget build(BuildContext context) {
    final classService = Provider.of<ClassService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Classes"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateClassDialog(classService),
        label: const Text("Create Class"),
        icon: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: "Search classes...",
                prefixIcon:
                    Icon(Icons.search, color: Theme.of(context).hintColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: classService.getClassesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.class_outlined,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No classes created yet",
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Tap the + button to create your first class",
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final classes = snapshot.data!.docs;
                final searchQuery = _searchController.text.toLowerCase();

                // Group classes by name (ignoring section for grouping)
                _groupedClasses.clear();
                for (final doc in classes) {
                  final classData = doc.data() as Map<String, dynamic>;
                  final className = classData['name'].toString();
                  final section = classData['section'].toString();

                  if (searchQuery.isNotEmpty) {
                    if (!className.toLowerCase().contains(searchQuery) &&
                        !section.toLowerCase().contains(searchQuery)) {
                      continue;
                    }
                  }

                  if (!_groupedClasses.containsKey(className)) {
                    _groupedClasses[className] = [];
                  }
                  _groupedClasses[className]!.add({
                    'id': doc.id,
                    'data': classData,
                  });
                }

                if (_groupedClasses.isEmpty) {
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
                          "No classes found",
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final sortedClassNames = _groupedClasses.keys.toList()..sort();

                return ListView.builder(
                  itemCount: sortedClassNames.length,
                  padding: const EdgeInsets.only(bottom: 80),
                  itemBuilder: (context, classIndex) {
                    final className = sortedClassNames[classIndex];
                    final sections = _groupedClasses[className]!;

                    // Sort sections alphabetically
                    sections.sort((a, b) {
                      final sectionA = a['data']['section'].toString();
                      final sectionB = b['data']['section'].toString();
                      return sectionA.compareTo(sectionB);
                    });

                    // Find the next section letter
                    String nextSectionLetter = _getNextSectionLetter(sections);

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Class Header with Edit and Add buttons
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      className,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                    ),
                                    onPressed: () => _showEditClassNameDialog(
                                      classService,
                                      className,
                                      sections,
                                    ),
                                    tooltip: "Edit Class Name",
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.add,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    onPressed: () => _addNewSection(
                                      classService,
                                      className,
                                      nextSectionLetter,
                                    ),
                                    tooltip: "Add Section $nextSectionLetter",
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
                            ...sections.map((sectionData) {
                              final classData = sectionData['data'];
                              final classId = sectionData['id'];
                              final section = classData['section'].toString();
                              final studentCount =
                                  (classData['student_ids'] as List<dynamic>?)
                                          ?.length ??
                                      0;

                              return InkWell(
                                onTap: () => _showManageStudentsDialog(
                                  classService,
                                  classId,
                                  '$className - Section $section',
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: classIndex ==
                                                    sortedClassNames.length -
                                                        1 &&
                                                sections.last == sectionData
                                            ? BorderSide.none
                                            : BorderSide(
                                                color: Theme.of(context)
                                                    .dividerColor,
                                                width: 1,
                                              ),
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 0),
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
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
                                                  .primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        "Section $section",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "$studentCount students",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.7),
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                          size: 20,
                                        ),
                                        onPressed: () =>
                                            _showDeleteSectionDialog(
                                          classService,
                                          classId,
                                          '$className - Section $section',
                                        ),
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

  String _getNextSectionLetter(List<Map<String, dynamic>> sections) {
    if (sections.isEmpty) return 'A';

    // Get all section letters and find the next one
    final existingSections = sections
        .map((s) => s['data']['section'].toString())
        .where((section) =>
            section.length == 1 &&
            section.codeUnitAt(0) >= 65 &&
            section.codeUnitAt(0) <= 90)
        .toList();

    if (existingSections.isEmpty) return 'A';

    // Sort sections alphabetically
    existingSections.sort();

    // Find the next letter in sequence
    for (int i = 0; i < existingSections.length; i++) {
      final currentChar = existingSections[i].codeUnitAt(0);
      final expectedChar = 65 + i; // 65 is 'A'

      if (currentChar > expectedChar) {
        return String.fromCharCode(expectedChar);
      }
    }

    // If all letters from A are used, return the next one
    return String.fromCharCode(65 + existingSections.length);
  }

  Future<void> _addNewSection(
    ClassService service,
    String className,
    String sectionLetter,
  ) async {
    try {
      await service.createClass(className, sectionLetter);
      _showSnackBar("Section $sectionLetter added to $className", false);
    } catch (e) {
      _showSnackBar("Failed to add section: $e", true);
    }
  }

  void _showCreateClassDialog(ClassService service) {
    _classNameController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Create New Class",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _classNameController,
              decoration: InputDecoration(
                labelText: "Class Name*",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                hintText: "e.g., Electrical Engineering, Computer Science",
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Section 'A' will be created automatically",
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final className = _classNameController.text.trim();

              if (className.isEmpty) {
                _showSnackBar("Class name is required", true);
                return;
              }

              try {
                // Create class with default section 'A'
                await service.createClass(className, 'A');
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSnackBar(
                      "Class '$className' created with Section A", false);
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSnackBar("Failed to create class: $e", true);
                }
              }
            },
            child: const Text("Create Class"),
          ),
        ],
      ),
    );
  }

  void _showEditClassNameDialog(
    ClassService service,
    String currentName,
    List<Map<String, dynamic>> sections,
  ) {
    _classNameController.text = currentName;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Edit Class Name",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _classNameController,
              decoration: InputDecoration(
                labelText: "New Class Name*",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "All ${sections.length} section(s) will be updated",
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = _classNameController.text.trim();

              if (newName.isEmpty) {
                _showSnackBar("Class name is required", true);
                return;
              }

              if (newName == currentName) {
                Navigator.pop(context);
                return;
              }

              try {
                // Update all sections with the new class name
                for (final sectionData in sections) {
                  final classId = sectionData['id'];
                  final section = sectionData['data']['section'].toString();
                  await service.updateClass(classId, newName, section);
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  _showSnackBar("Class name updated to '$newName'", false);
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSnackBar("Failed to update class name: $e", true);
                }
              }
            },
            child: const Text("Update Name"),
          ),
        ],
      ),
    );
  }

  void _showDeleteSectionDialog(
    ClassService service,
    String classId,
    String className,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Delete Section",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          "Are you sure you want to delete '$className'?\n\nThis will also remove all enrolled students from this section.",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await service.deleteClass(classId);
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSnackBar("Section deleted successfully", false);
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSnackBar("Failed to delete section: $e", true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text("Delete Section"),
          ),
        ],
      ),
    );
  }

  void _showManageStudentsDialog(
    ClassService service,
    String classId,
    String className,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
          child: _ManageStudentsDialogContent(
            classId: classId,
            className: className,
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.tertiary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

// _ManageStudentsDialogContent class remains the same as before
// Only changed the class name display in the dialog title
class _ManageStudentsDialogContent extends StatefulWidget {
  final String classId;
  final String className;

  const _ManageStudentsDialogContent({
    required this.classId,
    required this.className,
  });

  @override
  State<_ManageStudentsDialogContent> createState() =>
      _ManageStudentsDialogContentState();
}

class _ManageStudentsDialogContentState
    extends State<_ManageStudentsDialogContent>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  Set<String> _selectedEnrolled = {};
  Set<String> _selectedNotEnrolled = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classService = Provider.of<ClassService>(context);
    final studentService = Provider.of<StudentService>(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.className,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Enrolled"),
            Tab(text: "Not Enrolled"),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() {}),
            decoration: InputDecoration(
              hintText: "Search students...",
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildEnrolledStudentsList(classService, studentService),
              _buildNotEnrolledStudentsList(classService, studentService),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _selectedEnrolled.isNotEmpty
                    ? () => _removeSelectedStudents(classService)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: Text(
                  "Remove (${_selectedEnrolled.length})",
                ),
              ),
              ElevatedButton(
                onPressed: _selectedNotEnrolled.isNotEmpty
                    ? () => _addSelectedStudents(classService)
                    : null,
                child: Text(
                  "Add (${_selectedNotEnrolled.length})",
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnrolledStudentsList(
      ClassService classService, StudentService studentService) {
    return StreamBuilder<DocumentSnapshot>(
      stream: classService.getClassStream(widget.classId),
      builder: (context, classSnapshot) {
        if (!classSnapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }

        final classData = classSnapshot.data!.data() as Map<String, dynamic>;
        final List<dynamic> classStudentIds = classData['student_ids'] ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: studentService.getStudentsStream(),
          builder: (context, studentSnapshot) {
            if (!studentSnapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            }

            final students = studentSnapshot.data!.docs;
            final searchQuery = _searchController.text.toLowerCase();

            final enrolledStudents = students.where((doc) {
              final student = doc.data() as Map<String, dynamic>;
              final studentId = student['finger_id'].toString();
              if (!classStudentIds.contains(studentId)) return false;

              final name = student['name'].toString().toLowerCase();
              final rollNo = student['roll_no'].toString().toLowerCase();
              return name.contains(searchQuery) ||
                  rollNo.contains(searchQuery) ||
                  studentId.contains(searchQuery);
            }).toList();

            if (enrolledStudents.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      searchQuery.isEmpty
                          ? "No students enrolled in this class"
                          : "No enrolled students found",
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: enrolledStudents.length,
              itemBuilder: (context, index) {
                final doc = enrolledStudents[index];
                final student = doc.data() as Map<String, dynamic>;
                final studentId = student['finger_id'].toString();

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
                  color: Theme.of(context).colorScheme.surface,
                  child: CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: Text(
                      student['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      "Roll: ${student['roll_no']} | ID: $studentId",
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                    ),
                    secondary: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      child: Text(
                        studentId,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    value: _selectedEnrolled.contains(studentId),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedEnrolled.add(studentId);
                        } else {
                          _selectedEnrolled.remove(studentId);
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNotEnrolledStudentsList(
      ClassService classService, StudentService studentService) {
    return StreamBuilder<DocumentSnapshot>(
      stream: classService.getClassStream(widget.classId),
      builder: (context, classSnapshot) {
        if (!classSnapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }

        final classData = classSnapshot.data!.data() as Map<String, dynamic>;
        final List<dynamic> classStudentIds = classData['student_ids'] ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: studentService.getStudentsStream(),
          builder: (context, studentSnapshot) {
            if (!studentSnapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            }

            final students = studentSnapshot.data!.docs;
            final searchQuery = _searchController.text.toLowerCase();

            final notEnrolledStudents = students.where((doc) {
              final student = doc.data() as Map<String, dynamic>;
              final studentId = student['finger_id'].toString();
              if (classStudentIds.contains(studentId)) return false;

              final name = student['name'].toString().toLowerCase();
              final rollNo = student['roll_no'].toString().toLowerCase();
              return name.contains(searchQuery) ||
                  rollNo.contains(searchQuery) ||
                  studentId.contains(searchQuery);
            }).toList();

            if (notEnrolledStudents.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_disabled,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      searchQuery.isEmpty
                          ? "All students are enrolled in this class"
                          : "No students found",
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: notEnrolledStudents.length,
              itemBuilder: (context, index) {
                final doc = notEnrolledStudents[index];
                final student = doc.data() as Map<String, dynamic>;
                final studentId = student['finger_id'].toString();

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
                  color: Theme.of(context).colorScheme.surface,
                  child: CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: Text(
                      student['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      "Roll: ${student['roll_no']} | ID: $studentId",
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                    ),
                    secondary: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withOpacity(0.1),
                      child: Text(
                        studentId,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                    value: _selectedNotEnrolled.contains(studentId),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedNotEnrolled.add(studentId);
                        } else {
                          _selectedNotEnrolled.remove(studentId);
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _addSelectedStudents(ClassService service) async {
    try {
      await service.addStudentsToClass(
        widget.classId,
        _selectedNotEnrolled.toList(),
      );

      setState(() {
        _selectedNotEnrolled.clear();
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Added ${_selectedNotEnrolled.length} student(s) to class"),
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
            content: Text("Failed to add students: $e"),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _removeSelectedStudents(ClassService service) async {
    try {
      await service.removeStudentsFromClass(
        widget.classId,
        _selectedEnrolled.toList(),
      );

      setState(() {
        _selectedEnrolled.clear();
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Removed ${_selectedEnrolled.length} student(s) from class"),
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
            content: Text("Failed to remove students: $e"),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}
