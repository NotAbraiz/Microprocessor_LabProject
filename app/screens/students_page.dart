import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/student_service.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final _nameController = TextEditingController();
  final _rollController = TextEditingController();
  final _searchController = TextEditingController();
  final _editNameController = TextEditingController();
  final _editRollController = TextEditingController();

  bool _showResult = false;
  String _resultMessage = "";
  String _validationError = "";

  // Regular expression for roll number validation
  // Format 1: 2023-EE-351 (4 digits year, 2-3 letters department, 1-4 digits roll)
  // Format 2: 22R2023-EE-351 (2 digits fail year + R + 4 digits admission year)
  static final RegExp rollNumberRegex = RegExp(
    r'^(\d{4}|(\d{2}R\d{4}))-[A-Z]{2,3}-\d{1,4}$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _rollController.addListener(_validateRollNumber);
    _editRollController.addListener(_validateEditRollNumber);
  }

  void _onSearchChanged() {
    setState(() {});
  }

  void _validateRollNumber() {
    final rollNo = _rollController.text.trim();

    if (rollNo.isEmpty) {
      setState(() => _validationError = "");
      return;
    }

    if (!rollNumberRegex.hasMatch(rollNo)) {
      // Provide helpful error message
      if (!rollNo.contains('-')) {
        setState(
            () => _validationError = "Format: YYYY-DEPT-RN or YYRYEAR-DEPT-RN");
      } else if (rollNo.split('-').length < 3) {
        setState(() => _validationError = "Need 3 parts separated by '-'");
      } else {
        setState(
            () => _validationError = "Invalid format. Example: 2023-EE-351");
      }
    } else {
      setState(() => _validationError = "");
    }
  }

  void _validateEditRollNumber() {
    final rollNo = _editRollController.text.trim();

    if (rollNo.isEmpty) {
      return;
    }

    if (!rollNumberRegex.hasMatch(rollNo)) {
      // Don't interfere with typing
      // Just show error in dialog if needed
    }
  }

  bool _validateRollNumberFinal(String rollNo) {
    return rollNumberRegex.hasMatch(rollNo);
  }

  void _showEditStudentDialog(
      StudentService service, Map<String, dynamic> student) {
    _editNameController.text = student['name'];
    _editRollController.text = student['roll_no'];
    String editValidationError = "";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                "Edit Student",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _editNameController,
                      decoration: InputDecoration(
                        labelText: "Full Name",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _editRollController,
                      decoration: InputDecoration(
                        labelText: "Roll Number",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: "Format: 2023-EE-351 or 22R2023-EE-351",
                        errorText: editValidationError.isNotEmpty
                            ? editValidationError
                            : null,
                      ),
                      onChanged: (value) {
                        // Real-time validation without interfering
                        if (value.isNotEmpty &&
                            !_validateRollNumberFinal(value)) {
                          // Show error but don't interfere with typing
                          setState(() {
                            editValidationError = "Invalid format";
                          });
                        } else {
                          setState(() => editValidationError = "");
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Format: YYYY-DEPT-RN or YYRYEAR-DEPT-RN",
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                    final newName = _editNameController.text.trim();
                    final newRoll = _editRollController.text.trim();

                    if (newName.isEmpty) {
                      setState(
                          () => editValidationError = "Name cannot be empty");
                      return;
                    }

                    if (!_validateRollNumberFinal(newRoll)) {
                      setState(() =>
                          editValidationError = "Invalid roll number format.\n"
                              "Use: 2023-EE-351 or 22R2023-EE-351");
                      return;
                    }

                    try {
                      // Update student in Firestore using the public getter
                      await service.firestore
                          .collection('students')
                          .doc(student['finger_id'])
                          .update({
                        'name': newName,
                        'roll_no': newRoll,
                        'updated_at': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                "Student ${student['name']} updated successfully"),
                            backgroundColor:
                                Theme.of(context).colorScheme.tertiary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Failed to update student: $e"),
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text("Save Changes"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showEnrollDialog(StudentService service) {
    _showResult = false;
    _resultMessage = "";
    _validationError = "";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Consumer<StudentService>(
        builder: (context, svc, _) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                _showResult ? "Enrollment Result" : "Enroll New Student",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_showResult && !svc.isEnrolling) ...[
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: "Full Name",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _rollController,
                        decoration: InputDecoration(
                          labelText: "Roll Number",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          hintText: "Format: 2023-EE-351 or 22R2023-EE-351",
                          errorText: _validationError.isNotEmpty
                              ? _validationError
                              : null,
                        ),
                        // REMOVED onChanged handler that was causing issues
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "Examples: 2023-EE-351, 2023-CS-101, 22R2023-EE-351",
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_rollController.text.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _validateRollNumberFinal(
                                    _rollController.text.trim())
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _validateRollNumberFinal(
                                      _rollController.text.trim())
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _validateRollNumberFinal(
                                        _rollController.text.trim())
                                    ? Icons.check_circle
                                    : Icons.info,
                                color: _validateRollNumberFinal(
                                        _rollController.text.trim())
                                    ? Colors.green
                                    : Colors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _validateRollNumberFinal(
                                          _rollController.text.trim())
                                      ? "✓ Valid format"
                                      : "Enter in format: YYYY-DEPT-RN",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ] else if (svc.isEnrolling) ...[
                      Column(
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Place your finger on the scanner...",
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ] else if (_showResult) ...[
                      Icon(
                        _resultMessage.contains("successfully")
                            ? Icons.check_circle
                            : Icons.error,
                        color: _resultMessage.contains("successfully")
                            ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(context).colorScheme.error,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _resultMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                if (!svc.isEnrolling && !_showResult)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _clearFields();
                    },
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                if (!_showResult && !svc.isEnrolling)
                  ElevatedButton(
                    onPressed: () async {
                      final name = _nameController.text.trim();
                      final rollNo = _rollController.text.trim();

                      if (name.isEmpty) {
                        _showValidationError("Name cannot be empty");
                        return;
                      }

                      if (!_validateRollNumberFinal(rollNo)) {
                        _showValidationError(
                          "Invalid roll number format.\n"
                          "Examples:\n"
                          "• 2023-EE-351\n"
                          "• 2023-CS-101\n"
                          "• 22R2023-EE-351 (for repeaters)\n"
                          "Where EE/CS is department code (2-3 letters)",
                        );
                        return;
                      }

                      // Set up callback to handle completion
                      svc.onEnrollmentSuccess = () {
                        setState(() {
                          _showResult = true;
                          _resultMessage = svc.message;
                        });
                      };

                      await svc.startEnrollment(name, rollNo);
                    },
                    child: const Text("Start Scanning"),
                  ),
                if (svc.isEnrolling)
                  TextButton(
                    onPressed: () {
                      svc.cancelEnrollment();
                    },
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                if (_showResult)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _clearFields();
                    },
                    child: const Text("Close"),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _clearFields() {
    _nameController.clear();
    _rollController.clear();
    _editNameController.clear();
    _editRollController.clear();
    _showResult = false;
    _resultMessage = "";
    _validationError = "";
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<StudentService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Database"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEnrollDialog(service),
        label: const Text("Enroll"),
        icon: const Icon(Icons.fingerprint),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by name or roll number...",
                prefixIcon:
                    Icon(Icons.search, color: Theme.of(context).hintColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: service.getStudentsStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                final allStudents = docs.map((doc) {
                  final student = doc.data() as Map<String, dynamic>;
                  return {
                    'id': doc.id,
                    'name': student['name'] ?? '',
                    'roll_no': student['roll_no'] ?? '',
                    'finger_id': student['finger_id'] ?? '',
                    'enrolled_at': student['enrolled_at'],
                  };
                }).toList();

                // Sort by finger_id in increasing order (convert to int for proper sorting)
                allStudents.sort((a, b) {
                  final fingerIdA = int.tryParse(a['finger_id'] ?? '0') ?? 0;
                  final fingerIdB = int.tryParse(b['finger_id'] ?? '0') ?? 0;
                  return fingerIdA.compareTo(fingerIdB);
                });

                // Filter students based on search query
                final searchQuery = _searchController.text.toLowerCase();
                final filteredStudents = searchQuery.isEmpty
                    ? allStudents
                    : allStudents.where((student) {
                        final name = student['name'].toString().toLowerCase();
                        final rollNo =
                            student['roll_no'].toString().toLowerCase();
                        return name.contains(searchQuery) ||
                            rollNo.contains(searchQuery);
                      }).toList();

                if (filteredStudents.isEmpty) {
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
                              ? "No students enrolled yet"
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
                  itemCount: filteredStudents.length,
                  padding: const EdgeInsets.only(bottom: 80),
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];

                    // Parse roll number for better display
                    final rollNo = student['roll_no'];
                    String department = '';
                    String roll = '';

                    if (rollNo.contains('-')) {
                      final parts = rollNo.split('-');
                      if (parts.length >= 3) {
                        // year = parts[0]; // Not used, so removed
                        department = parts[1];
                        roll = parts[2];
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 6.0,
                      ),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                student['finger_id'].toString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            student['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text("Roll: ${student['roll_no']}"),
                              if (department.isNotEmpty && roll.isNotEmpty)
                                Text(
                                  "Dept: $department | No: $roll",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                                onPressed: () =>
                                    _showEditStudentDialog(service, student),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Theme.of(context).colorScheme.error,
                                  size: 20,
                                ),
                                onPressed: () => _showDeleteDialog(service,
                                    student['finger_id'], student['name']),
                              ),
                            ],
                          ),
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

  void _showDeleteDialog(StudentService service, String fingerId, String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Delete Student",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          "Are you sure you want to delete $name (ID: $fingerId)?",
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
              Navigator.pop(context);
              await _initiateDeletion(service, fingerId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> _initiateDeletion(
      StudentService service, String fingerId) async {
    // Show processing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Deleting Student",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Deleting fingerprint ID: $fingerId...",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );

    // Start deletion process
    final success = await service.startDeletion(fingerId);

    // Close processing dialog
    if (context.mounted) Navigator.pop(context);

    // Show result
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            success ? "Success" : "Failed",
            style: TextStyle(
              color: success
                  ? Theme.of(context).colorScheme.tertiary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
          content: Text(
            success
                ? "Fingerprint deleted successfully"
                : "Deletion failed or timed out",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "OK",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _rollController.removeListener(_validateRollNumber);
    _editRollController.removeListener(_validateEditRollNumber);
    _nameController.dispose();
    _rollController.dispose();
    _editNameController.dispose();
    _editRollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
