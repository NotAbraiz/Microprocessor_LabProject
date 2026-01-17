import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class StudentService with ChangeNotifier {
  final DatabaseReference _rtdb =
      FirebaseDatabase.instance.ref("FingerScanner1");
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isEnrolling = false;
  bool _handledResult = false;
  String _message = "";
  StreamSubscription? _resultSubscription;
  StreamSubscription? _deleteSubscription;

  VoidCallback? onEnrollmentSuccess;

  bool get isEnrolling => _isEnrolling;
  String get message => _message;

  // Make Firestore accessible for editing
  FirebaseFirestore get firestore => _firestore;

  // ---------------- ENROLLMENT ----------------

  Future<void> startEnrollment(String name, String rollNo) async {
    _isEnrolling = true;
    _handledResult = false;
    _message = "Waiting for scanner...";
    notifyListeners();

    try {
      await _rtdb.child("Command").set({
        "Data": {
          "Name": name,
          "Roll_No": rollNo,
        },
        "Type": "enroll",
        "Cancelled": false,
        "Result": "none",
        "Status": "pending",
      });

      _resultSubscription =
          _rtdb.child("Enrollment_Result").onValue.listen((event) async {
        if (event.snapshot.value == null || _handledResult) return;

        _handledResult = true;
        _resultSubscription?.cancel();

        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        final status = data['Status'];
        final type = data['Type'];
        final fingerId = data['ID']?.toString() ?? "";

        if (status == "Success" && type == "New") {
          await _saveToFirestore(name, rollNo, fingerId);
          await _cleanupRTDB();

          _finishEnrollment("Student enrolled successfully!");
          onEnrollmentSuccess?.call();
        } else if (type == "duplicate") {
          await _cleanupRTDB();
          _finishEnrollment("Error: Fingerprint already exists.");
          onEnrollmentSuccess?.call();
        } else {
          await _cleanupRTDB();
          _finishEnrollment("Enrollment failed.");
          onEnrollmentSuccess?.call();
        }
      });
    } catch (e) {
      _finishEnrollment("System Error: $e");
      onEnrollmentSuccess?.call();
    }
  }

  Future<void> cancelEnrollment() async {
    await _rtdb.child("Command/Cancelled").set(true);
    await _cleanupRTDB();
    _finishEnrollment("Enrollment Cancelled");
  }

  // ---------------- DELETION ----------------

  Future<bool> startDeletion(String fingerId) async {
    try {
      // Send delete command to ESP32
      await _rtdb.child("Command").set({
        "Data": {
          "ID": int.parse(fingerId),
        },
        "Type": "delete",
        "Cancelled": false,
        "Result": "none",
        "Status": "pending",
      });

      Completer<bool> completer = Completer<bool>();
      bool handled = false;

      // Listen for deletion result
      _deleteSubscription =
          _rtdb.child("Deletion_Result").onValue.listen((event) async {
        if (event.snapshot.value == null || handled) return;

        handled = true;
        _deleteSubscription?.cancel();

        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final status = data['Status'];

        // Clean up Firebase RTDB
        await _rtdb.child("Deletion_Result").remove();
        await _resetCommand();

        if (status == "Success") {
          // Delete from Firestore only if ESP deletion was successful
          await _firestore.collection("students").doc(fingerId).delete();
          completer.complete(true);
        } else {
          completer.complete(false);
        }
      });

      // Timeout after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        if (!completer.isCompleted) {
          _deleteSubscription?.cancel();
          _resetCommand();
          completer.complete(false);
        }
      });

      return await completer.future;
    } catch (e) {
      print("Deletion error: $e");
      return false;
    }
  }

  // ---------------- CLEANUP ----------------

  Future<void> _cleanupRTDB() async {
    await _rtdb.child("Enrollment_Result").remove();
  }

  Future<void> _resetCommand() async {
    await _rtdb.child("Command").set({
      "Data": {},
      "Type": "none",
      "Cancelled": false,
      "Result": "none",
      "Status": "idle",
    });
  }

  void _finishEnrollment(String msg) {
    _message = msg;
    _isEnrolling = false;
    notifyListeners();
  }

  // ---------------- FIRESTORE ----------------

  Future<void> _saveToFirestore(
      String name, String rollNo, String fingerId) async {
    await _firestore.collection("students").doc(fingerId).set({
      "name": name,
      "roll_no": rollNo,
      "finger_id": fingerId,
      "enrolled_at": FieldValue.serverTimestamp(),
      "updated_at": FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getStudentsStream() {
    return _firestore.collection("students").snapshots();
  }

  @override
  void dispose() {
    _resultSubscription?.cancel();
    _deleteSubscription?.cancel();
    super.dispose();
  }
}
