import 'package:biomark/screens/attendance_marking_page.dart';
import 'package:biomark/screens/attendance_records_page.dart';
import 'package:biomark/screens/classes_page.dart';
import 'package:biomark/screens/students_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/hardware_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const StudentsPage(),
    const ClassesPage(),
    const AttendanceMarkingPage(),
    const AttendanceRecordsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final hardwareStatus = context.watch<HardwareService>().status;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            leading: Column(
              children: [
                const Icon(Icons.fingerprint, size: 40, color: Colors.blue),
                const SizedBox(height: 10),
                // Status Indicator
                CircleAvatar(
                  radius: 8,
                  backgroundColor:
                      hardwareStatus == "online" ? Colors.green : Colors.red,
                ),
                Text(
                  hardwareStatus.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
              ],
            ),
            destinations: const [
              NavigationRailDestination(
                  icon: Icon(Icons.people), label: Text('Students')),
              NavigationRailDestination(
                  icon: Icon(Icons.class_), label: Text('Classes')),
              NavigationRailDestination(
                  icon: Icon(Icons.how_to_reg), label: Text('Attendance')),
              NavigationRailDestination(
                  icon: Icon(Icons.history), label: Text('Records')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}
