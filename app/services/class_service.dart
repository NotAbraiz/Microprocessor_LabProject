import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ClassService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new class
  Future<void> createClass(String name, String section) async {
    try {
      await _firestore.collection('classes').add({
        'name': name,
        'section': section,
        'student_ids': [],
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create class: $e');
    }
  }

  // Update an existing class
  Future<void> updateClass(String classId, String name, String section) async {
    try {
      await _firestore.collection('classes').doc(classId).update({
        'name': name,
        'section': section,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update class: $e');
    }
  }

  // Delete a class
  Future<void> deleteClass(String classId) async {
    try {
      await _firestore.collection('classes').doc(classId).delete();
    } catch (e) {
      throw Exception('Failed to delete class: $e');
    }
  }

  // Add students to a class
  Future<void> addStudentsToClass(
      String classId, List<String> studentIds) async {
    try {
      final classRef = _firestore.collection('classes').doc(classId);

      await _firestore.runTransaction((transaction) async {
        final classDoc = await transaction.get(classRef);
        final currentData = classDoc.data() as Map<String, dynamic>;
        final currentStudentIds =
            List<String>.from(currentData['student_ids'] ?? []);

        // Add only new students
        final updatedStudentIds = [...currentStudentIds];
        for (final studentId in studentIds) {
          if (!updatedStudentIds.contains(studentId)) {
            updatedStudentIds.add(studentId);
          }
        }

        transaction.update(classRef, {
          'student_ids': updatedStudentIds,
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('Failed to add students to class: $e');
    }
  }

  // Remove students from a class
  Future<void> removeStudentsFromClass(
      String classId, List<String> studentIds) async {
    try {
      final classRef = _firestore.collection('classes').doc(classId);

      await _firestore.runTransaction((transaction) async {
        final classDoc = await transaction.get(classRef);
        final currentData = classDoc.data() as Map<String, dynamic>;
        final currentStudentIds =
            List<String>.from(currentData['student_ids'] ?? []);

        // Remove specified students
        final updatedStudentIds =
            currentStudentIds.where((id) => !studentIds.contains(id)).toList();

        transaction.update(classRef, {
          'student_ids': updatedStudentIds,
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('Failed to remove students from class: $e');
    }
  }

  // Get stream of all classes
  Stream<QuerySnapshot> getClassesStream() {
    return _firestore
        .collection('classes')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  // Get stream of a specific class
  Stream<DocumentSnapshot> getClassStream(String classId) {
    return _firestore.collection('classes').doc(classId).snapshots();
  }

  // Get class by ID
  Future<DocumentSnapshot> getClass(String classId) async {
    return await _firestore.collection('classes').doc(classId).get();
  }
}
