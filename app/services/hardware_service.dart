import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class HardwareService with ChangeNotifier {
  // This uses the databaseURL defined in your FirebaseOptions
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref("FingerScanner1");

  String _status = "offline";
  int _lastSeen = 0;
  Timer? _timer;

  String get status => _status;

  HardwareService() {
    _initListener();
    _startWatchdog();
  }

  void _initListener() {
    // 1. Listen to the heartbeat from the ESP32
    _dbRef.child("Last_Seen").onValue.listen((event) {
      if (event.snapshot.value != null) {
        _lastSeen = int.tryParse(event.snapshot.value.toString()) ?? 0;
        _checkAndUpdateStatus();
      }
    }, onError: (error) => print("Firebase Error: $error"));

    // 2. Listen to the status to update the UI reactively
    _dbRef.child("Status").onValue.listen((event) {
      if (event.snapshot.value != null) {
        _status = event.snapshot.value.toString();
        notifyListeners();
      }
    });
  }

  void _startWatchdog() {
    // Run every 5 seconds to check if hardware went silent
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkAndUpdateStatus();
    });
  }

  void _checkAndUpdateStatus() {
    if (_lastSeen == 0) return;

    // Unix timestamp in seconds
    final int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int difference = currentTime - _lastSeen;

    // Rule: > 20 seconds = offline
    String calculatedStatus = (difference > 30) ? "offline" : "online";

    if (calculatedStatus != _status) {
      _dbRef.child("Status").set(calculatedStatus);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
