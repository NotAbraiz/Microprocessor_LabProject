import 'dart:io';
import 'dart:html' as html; // For web support
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class ExportService {
  // Export monthly attendance to Excel
  Future<void> exportMonthlyAttendanceToExcel({
    required String className,
    required String section,
    required String monthYear,
    required Map<String, List<Map<String, dynamic>>> monthlyRecords,
  }) async {
    try {
      print('🚀 Starting Excel export for $className - $section - $monthYear');
      print('📊 Records count: ${monthlyRecords.length}');

      // Check for storage permission on mobile
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission denied');
        }
      }

      // Create Excel workbook
      final excel = Excel.createExcel();
      final Sheet sheetObject = excel['Attendance Report'];
      var sheet = sheetObject;

      // Add headers
      _createExcelHeader(sheet, className, section, monthYear);

      // Add data rows
      int rowIndex = 7; // Start after header rows

      // Sort dates
      final sortedDates = monthlyRecords.keys.toList()
        ..sort((a, b) {
          try {
            final dateA = DateFormat('dd MMM yyyy').parse(a);
            final dateB = DateFormat('dd MMM yyyy').parse(b);
            return dateA.compareTo(dateB);
          } catch (e) {
            print('Date parsing error: $e');
            return a.compareTo(b);
          }
        });

      print('📅 Sorted dates: $sortedDates');

      for (final date in sortedDates) {
        final dayRecords = monthlyRecords[date]!;
        print('📝 Processing date $date with ${dayRecords.length} records');

        // Sort records by time
        dayRecords.sort((a, b) {
          final timeA = (a['data']['start_time'] as Timestamp).toDate();
          final timeB = (b['data']['start_time'] as Timestamp).toDate();
          return timeA.compareTo(timeB);
        });

        for (final record in dayRecords) {
          final data = record['data'];
          final startTime = (data['start_time'] as Timestamp).toDate();
          final endTime = (data['end_time'] as Timestamp).toDate();
          final students =
              List<Map<String, dynamic>>.from(data['students'] ?? []);

          print(
              '⏰ Session: ${DateFormat('hh:mm a').format(startTime)} - ${DateFormat('hh:mm a').format(endTime)}');
          print('👥 Total students in session: ${students.length}');

          // Group students by status
          final presentStudents =
              students.where((s) => s['status'] == 'Present').toList();
          final absentStudents =
              students.where((s) => s['status'] == 'Absent').toList();
          final otherStudents = students
              .where((s) => s['status'] != 'Present' && s['status'] != 'Absent')
              .toList();

          // Add session header
          _addSessionHeader(sheet, rowIndex, date, startTime, endTime,
              presentStudents.length, students.length);
          rowIndex++;

          // Add column headers for students
          _addStudentColumnHeaders(sheet, rowIndex);
          rowIndex++;

          // Add present students
          rowIndex = _addStudentList(
              sheet, rowIndex, 'Present Students', presentStudents, 'Present');

          // Add absent students
          rowIndex = _addStudentList(
              sheet, rowIndex, 'Absent Students', absentStudents, 'Absent');

          // Add other status students
          if (otherStudents.isNotEmpty) {
            rowIndex = _addStudentList(
                sheet, rowIndex, 'Other Status', otherStudents, 'Other');
          }

          // Add empty row between sessions
          rowIndex++;
        }
      }

      // Save the file
      final fileName =
          'Attendance_${_sanitizeFileName(className)}_${_sanitizeFileName(section)}_${_sanitizeFileName(monthYear)}.xlsx';

      print('💾 Exporting file: $fileName');

      if (kIsWeb) {
        // On web, show download prompt
        await _downloadExcelWebWithFeedback(
            excel, fileName, className, section, monthYear);
      } else {
        final filePath = await _saveExcelFile(excel, fileName);
        await _openOrShareFile(filePath, fileName);
      }

      print('✅ Excel export completed successfully');
    } catch (e) {
      print('❌ Error exporting to Excel: $e');
      rethrow;
    }
  }

  Future<void> _downloadExcelWebWithFeedback(Excel excel, String fileName,
      String className, String section, String monthYear) async {
    try {
      print('🌐 Starting web download...');

      final fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      // Show download information
      print('📋 File Information:');
      print('   - File Name: $fileName');
      print('   - Class: $className');
      print('   - Section: $section');
      print('   - Month: $monthYear');
      print('   - Size: ${(fileBytes.length / 1024).toStringAsFixed(2)} KB');
      print(
          '   - Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
      print('');
      print(
          '📢 The file should download to your browser\'s default download folder.');
      print(
          '💡 Tip: Check your browser\'s downloads section (Ctrl+J on most browsers)');

      // Create download
      final blob = html.Blob([fileBytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);

      // Clean up
      html.Url.revokeObjectUrl(url);

      print('✅ Download initiated. Check your browser downloads.');
    } catch (e) {
      print('❌ Web download error: $e');
      rethrow;
    }
  }

  String _sanitizeFileName(String name) {
    // Remove invalid characters for file names
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  void _createExcelHeader(
      Sheet sheet, String className, String section, String monthYear) {
    try {
      // Title - A1
      final titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = 'ATTENDANCE REPORT';

      // Merge title cells A1-E1
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('E1'));

      // Class info - A2
      final classCell = sheet.cell(CellIndex.indexByString('A2'));
      classCell.value = 'Class: $className';
      sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('E2'));

      // Section - A3
      final sectionCell = sheet.cell(CellIndex.indexByString('A3'));
      sectionCell.value = 'Section: $section';
      sheet.merge(CellIndex.indexByString('A3'), CellIndex.indexByString('E3'));

      // Month - A4
      final monthCell = sheet.cell(CellIndex.indexByString('A4'));
      monthCell.value = 'Month: $monthYear';
      sheet.merge(CellIndex.indexByString('A4'), CellIndex.indexByString('E4'));

      // Export date - A5
      final exportDateCell = sheet.cell(CellIndex.indexByString('A5'));
      exportDateCell.value =
          'Exported on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}';
      sheet.merge(CellIndex.indexByString('A5'), CellIndex.indexByString('E5'));

      // Empty row - A6
      final emptyCell = sheet.cell(CellIndex.indexByString('A6'));
      emptyCell.value = '';
      sheet.merge(CellIndex.indexByString('A6'), CellIndex.indexByString('E6'));
    } catch (e) {
      print('❌ Error creating Excel header: $e');
    }
  }

  void _addSessionHeader(Sheet sheet, int rowIndex, String date,
      DateTime startTime, DateTime endTime, int presentCount, int totalCount) {
    try {
      final startCell =
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex);
      final endCell =
          CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex);

      // Merge cells for session header
      sheet.merge(startCell, endCell);

      final sessionCell = sheet.cell(startCell);
      sessionCell.value =
          'Date: $date | Time: ${DateFormat('hh:mm a').format(startTime)} - ${DateFormat('hh:mm a').format(endTime)} | Present: $presentCount/$totalCount';
    } catch (e) {
      print('❌ Error adding session header: $e');
    }
  }

  void _addStudentColumnHeaders(Sheet sheet, int rowIndex) {
    try {
      final headers = [
        'Roll No',
        'Name',
        'Fingerprint ID',
        'Status',
        'Remarks'
      ];
      for (int i = 0; i < headers.length; i++) {
        final cellIndex =
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex);
        final cell = sheet.cell(cellIndex);
        cell.value = headers[i];
      }
    } catch (e) {
      print('❌ Error adding column headers: $e');
    }
  }

  int _addStudentList(Sheet sheet, int rowIndex, String category,
      List<Map<String, dynamic>> students, String statusType) {
    try {
      // Add category header if there are students
      if (students.isNotEmpty) {
        final startCell =
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex);
        final endCell =
            CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex);

        // Merge cells for category header
        sheet.merge(startCell, endCell);

        final categoryCell = sheet.cell(startCell);
        categoryCell.value = category;
        rowIndex++;
      }

      // Add student data
      for (final student in students) {
        final rollNo = student['roll_no']?.toString() ?? 'N/A';
        final name = student['name']?.toString() ?? 'Unknown';
        final fingerId = student['finger_id']?.toString() ?? '';
        final status = student['status']?.toString() ?? '';

        final data = [rollNo, name, fingerId, status, ''];

        for (int i = 0; i < data.length; i++) {
          final cellIndex =
              CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex);
          final cell = sheet.cell(cellIndex);
          cell.value = data[i];
        }

        rowIndex++;
      }

      // Add empty row after the list
      rowIndex++;
    } catch (e) {
      print('❌ Error adding student list: $e');
    }

    return rowIndex;
  }

  Future<String> _saveExcelFile(Excel excel, String fileName) async {
    try {
      // Get directory
      Directory directory;

      if (Platform.isAndroid) {
        directory = (await getExternalStorageDirectory()) ??
            await getApplicationDocumentsDirectory();
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
      }

      final filePath = '${directory.path}/$fileName';

      print('💾 Saving file to: $filePath');

      // Save Excel file
      final fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file bytes');
      }

      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      print('✅ File saved successfully: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Error saving Excel file: $e');
      rethrow;
    }
  }

  Future<void> _openOrShareFile(String filePath, String fileName) async {
    try {
      final file = File(filePath);

      if (await file.exists()) {
        print('📂 File exists, opening/sharing...');

        if (Platform.isAndroid || Platform.isIOS) {
          // Share the file
          await Share.shareXFiles([XFile(filePath)],
              text: 'Attendance Report: $fileName');
          print('✅ File shared successfully');
        } else {
          // Open the file on desktop
          final result = await OpenFile.open(filePath);
          print('📄 Open file result: $result');
        }
      } else {
        throw Exception('File not found: $filePath');
      }
    } catch (e) {
      print('❌ Error opening/sharing file: $e');
      rethrow;
    }
  }

  Future<void> _downloadExcelWeb(Excel excel, String fileName) async {
    try {
      print('🌐 Starting web download...');

      final fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file for web');
      }

      // Create a blob and download link for web
      final blob = html.Blob([fileBytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);

      html.Url.revokeObjectUrl(url);

      print('✅ Web download initiated for: $fileName');
    } catch (e) {
      print('❌ Web download error: $e');
      rethrow;
    }
  }

  // Simple test method to verify Excel generation
  Future<void> testExcelGeneration() async {
    try {
      print('🧪 Testing Excel generation...');

      // Create a simple Excel file
      final excel = Excel.createExcel();
      final sheet = excel['Test'];

      // Add some test data
      final cellA1 = sheet.cell(CellIndex.indexByString('A1'));
      cellA1.value = 'Test Excel Export';

      final cellA2 = sheet.cell(CellIndex.indexByString('A2'));
      cellA2.value = 'Generated successfully!';

      final cellA3 = sheet.cell(CellIndex.indexByString('A3'));
      cellA3.value =
          'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}';

      final cellB1 = sheet.cell(CellIndex.indexByString('B1'));
      cellB1.value = 'Column B';

      final cellC1 = sheet.cell(CellIndex.indexByString('C1'));
      cellC1.value = 'Column C';

      // Merge cells
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('C1'));

      final fileName =
          'test_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      print('📁 Test file name: $fileName');

      if (kIsWeb) {
        await _downloadExcelWeb(excel, fileName);
      } else {
        final filePath = await _saveExcelFile(excel, fileName);
        await _openOrShareFile(filePath, fileName);
      }

      print('✅ Test Excel generation completed successfully');
    } catch (e) {
      print('❌ Test Excel generation failed: $e');
      rethrow;
    }
  }
}
