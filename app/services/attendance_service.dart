import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class AttendanceService with ChangeNotifier {
  final DatabaseReference _rtdb =
      FirebaseDatabase.instance.ref("FingerScanner1");
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isActive = false;
  String _currentClassName = "";
  String _currentClassId = "";
  StreamSubscription<DatabaseEvent>? _attendanceSubscription;
  StreamSubscription<DatabaseEvent>? _scanListener;

  bool get isActive => _isActive;
  String get currentClassName => _currentClassName;

  // Start attendance for a class
  Future<void> startAttendance(String classId, String className) async {
    try {
      _currentClassId = classId;
      _currentClassName = className;

      // Extract section from className (assuming format: "ClassName - Section X")
      final sectionMatch = RegExp(r'Section\s+(\w+)$').firstMatch(className);
      final section = sectionMatch?.group(1) ?? '';

      // First, ensure Attendance_Record is clear
      await _rtdb.child("Attendance_Record").remove();

      final classNameOnly =
          className.replaceAll(RegExp(r'\s*-\s*Section\s+\w+$'), '').trim();
      // Set command to start attendance with section
      await _rtdb.child("Command").set({
        "Data": {
          "Class": classNameOnly,
          "Section": section, // Add section here
        },
        "Type": "attendance",
        "Cancelled": false,
        "Result": "none",
        "Status": "pending",
      });

      _isActive = true;
      notifyListeners();
    } catch (e) {
      throw Exception("Failed to start attendance: $e");
    }
  }

  void startListeningForScans(
      Function(String, String, Map<String, dynamic>) onScan) {
    // Cancel any existing listener
    _scanListener?.cancel();

    _scanListener = _rtdb
        .child("Attendance_Record/Students")
        .onChildAdded
        .listen((DatabaseEvent event) async {
      try {
        final studentEntry =
            event.snapshot.value as Map<dynamic, dynamic>? ?? {};
        final fingerId = studentEntry['ID']?.toString() ?? "";

        // If ESP32 already set status to "Not_Found", handle it immediately
        if (fingerId == "Not_Found" || fingerId.toLowerCase() == "not_found") {
          onScan(
              "", "Not_Found", {"error": "Fingerprint not found in scanner"});

          // Update the status in RTDB
          await _rtdb
              .child("Attendance_Record/Students/${event.snapshot.key}")
              .update({
            "Status": "Not_Found",
            "ID": "Not_Found",
            "Data": "none",
          });
          return;
        }

        // For valid finger IDs, process normally
        final result = await _processStudentAttendance(fingerId);

        // Update the status in RTDB for consistency
        await _updateStudentStatusInRTDB(
            event.snapshot.key, fingerId, result['status'], result['data']);

        // Call the callback with the result
        onScan(fingerId, result['status'], result['data']);
      } catch (e) {
        print("Error in scan listener: $e");
        onScan("", "error", {"error": e.toString()});
      }
    });
  }

  // Helper method to update student status in RTDB
  Future<void> _updateStudentStatusInRTDB(String? studentKey, String fingerId,
      String status, Map<String, dynamic> data) async {
    if (studentKey == null) return;

    final updateData = <String, dynamic>{
      "Status": status,
      "ID": fingerId,
    };

    if (status == "Success") {
      updateData["Data"] = {
        "name": data['name'] ?? 'Unknown',
        "roll_no": data['roll_no'] ?? 'Unknown',
        "finger_id": fingerId,
      };
    } else {
      updateData["Data"] = "none";
    }

    await _rtdb
        .child("Attendance_Record/Students/$studentKey")
        .update(updateData);
  }

// Process individual student attendance - Fixed version
  Future<Map<String, dynamic>> _processStudentAttendance(
      String fingerId) async {
    // Check if fingerId is "Not_Found" from ESP32
    if (fingerId == "Not_Found" || fingerId.toLowerCase() == "not_found") {
      return {
        'status': 'Not_Found',
        'data': {'error': 'Fingerprint not found in scanner database'},
      };
    }

    // Now validate if fingerId is a valid number/ID
    if (fingerId.isEmpty || !RegExp(r'^\d+$').hasMatch(fingerId)) {
      return {
        'status': 'Not_Found',
        'data': {'error': 'Invalid finger ID format'},
      };
    }

    try {
      // Get class details from Firestore
      final classDoc =
          await _firestore.collection('classes').doc(_currentClassId).get();
      if (!classDoc.exists) {
        return {
          'status': 'error',
          'data': {'error': 'Class not found'},
        };
      }

      final classData = classDoc.data() as Map<String, dynamic>;
      final studentIds = List<String>.from(classData['student_ids'] ?? []);

      // Check if student is in class
      if (!studentIds.contains(fingerId)) {
        return {
          'status': 'Not_in_Class',
          'data': {'finger_id': fingerId},
        };
      }

      // Get student details from Firestore
      final studentDoc =
          await _firestore.collection('students').doc(fingerId).get();
      if (!studentDoc.exists) {
        return {
          'status': 'Not_Found',
          'data': {'finger_id': fingerId},
        };
      }

      final studentData = studentDoc.data() as Map<String, dynamic>;

      return {
        'status': 'Success',
        'data': {
          'name': studentData['name'] ?? 'Unknown',
          'roll_no': studentData['roll_no'] ?? 'Unknown',
          'finger_id': fingerId,
        },
      };
    } catch (e) {
      print("Error processing student attendance: $e");
      return {
        'status': 'error',
        'data': {'error': e.toString()},
      };
    }
  }

  // Stop attendance session
  Future<void> stopAttendance() async {
    try {
      // Cancel scan listener first
      _scanListener?.cancel();
      _scanListener = null;

      // First, set cancelled flag to notify ESP32
      await _rtdb.child("Command/Cancelled").set(true);

      // Wait for ESP32 to process cancellation and update End_Time
      await _waitForEndTime();

      // Save attendance record to Firestore
      await _saveAttendanceToFirestore();

      // Clean up
      await _cleanupAttendance();

      _isActive = false;
      _currentClassName = "";
      _currentClassId = "";

      // Cancel any remaining subscription
      _attendanceSubscription?.cancel();
      _attendanceSubscription = null;

      notifyListeners();
    } catch (e) {
      throw Exception("Failed to stop attendance: $e");
    }
  }

  // Wait for ESP32 to update End_Time (maximum 10 seconds)
  Future<void> _waitForEndTime({int maxWaitSeconds = 10}) async {
    int attempts = 0;
    const int delayMs = 500;
    final int maxAttempts = maxWaitSeconds * 2; // 500ms * 20 = 10 seconds

    while (attempts < maxAttempts) {
      try {
        final snapshot = await _rtdb.child("Attendance_Record/End_Time").get();
        if (snapshot.exists && snapshot.value != null) {
          final endTime = snapshot.value;
          if (endTime is int && endTime > 0) {
            print("End_Time updated by ESP32: $endTime");
            return; // ESP32 has updated the end time
          }
        }
      } catch (e) {
        print("Error checking End_Time: $e");
      }

      await Future.delayed(const Duration(milliseconds: delayMs));
      attempts++;
    }

    print("Timeout waiting for ESP32 to update End_Time");

    // Set a default end time if ESP32 didn't respond
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _rtdb.child("Attendance_Record/End_Time").set(now);
  }

  // Save attendance to Firestore
  Future<void> _saveAttendanceToFirestore() async {
    try {
      // Get attendance record from RTDB
      final snapshot = await _rtdb.child("Attendance_Record").get();
      if (!snapshot.exists) {
        print("No attendance record found in RTDB");
        return;
      }

      final record = snapshot.value as Map<dynamic, dynamic>;
      final students = record['Students'] as Map<dynamic, dynamic>? ?? {};

      // Extract section from the class name
      final className = record['Class']?.toString() ?? "";
      final section = record['Section']?.toString() ?? "";

      final now = DateTime.now();

      // Process student data
      final List<Map<String, dynamic>> attendanceList = [];

      for (final key in students.keys) {
        final student = students[key] as Map<dynamic, dynamic>;
        final status = student['Status']?.toString() ?? "";
        final fingerId = student['ID']?.toString() ?? "";

        // Skip invalid entries
        if (fingerId.isEmpty ||
            fingerId == "Not_Found" ||
            fingerId.toLowerCase() == "none") {
          continue;
        }

        if (status == "Success") {
          final data = student['Data'] as Map<dynamic, dynamic>? ?? {};
          attendanceList.add({
            'name': data['name']?.toString() ?? 'Unknown',
            'roll_no': data['roll_no']?.toString() ?? 'Unknown',
            'finger_id': data['finger_id']?.toString() ?? fingerId,
            'status': 'Present',
            'timestamp': now,
          });
        } else if (status == "Not_in_Class") {
          attendanceList.add({
            'finger_id': fingerId,
            'status': 'Not in Class',
            'timestamp': now,
          });
        } else if (status == "Not_Found") {
          attendanceList.add({
            'finger_id': fingerId,
            'status': 'Not Found',
            'timestamp': now,
          });
        }
      }

      // Calculate start and end times
      DateTime startTime = now;
      DateTime endTime = now;

      if (record['Start_Time'] != null) {
        final startTimestamp = int.tryParse(record['Start_Time'].toString());
        if (startTimestamp != null && startTimestamp > 0) {
          startTime =
              DateTime.fromMillisecondsSinceEpoch(startTimestamp * 1000);
        }
      }

      if (record['End_Time'] != null) {
        final endTimestamp = int.tryParse(record['End_Time'].toString());
        if (endTimestamp != null && endTimestamp > 0) {
          endTime = DateTime.fromMillisecondsSinceEpoch(endTimestamp * 1000);
        }
      }

      // Save to Firestore with section
      await _firestore.collection('attendance_records').add({
        'class_id': _currentClassId,
        'class_name': className,
        'section': section, // Add section field
        'start_time': startTime,
        'end_time': endTime,
        'students': attendanceList,
        'total_students': attendanceList.length,
        'present_students':
            attendanceList.where((s) => s['status'] == 'Present').length,
        'created_at': FieldValue.serverTimestamp(),
      });

      print(
          "✅ Attendance saved to Firestore with ${attendanceList.length} students");
    } catch (e) {
      print("Error saving attendance to Firestore: $e");
      rethrow;
    }
  }

  // Clean up attendance data
  Future<void> _cleanupAttendance() async {
    try {
      // Clear command first
      await _rtdb.child("Command").set({
        "Data": {},
        "Type": "none",
        "Cancelled": false,
        "Result": "none",
        "Status": "idle",
      });

      // Wait a moment for ESP32 to reset
      await Future.delayed(const Duration(seconds: 1));

      // Clear attendance record
      await _rtdb.child("Attendance_Record").remove();

      print("✅ Attendance cleanup completed");
    } catch (e) {
      print("Error cleaning up attendance: $e");
    }
  }

  // Get attendance records stream
  Stream<QuerySnapshot> getAttendanceRecordsStream() {
    return _firestore
        .collection('attendance_records')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  // Get attendance record by ID
  Future<DocumentSnapshot> getAttendanceRecord(String recordId) async {
    return await _firestore
        .collection('attendance_records')
        .doc(recordId)
        .get();
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    _scanListener?.cancel();
    super.dispose();
  }
}
