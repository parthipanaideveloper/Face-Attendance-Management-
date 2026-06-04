import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ExportUtils {
  static Future<void> exportCSV(BuildContext context, String titleStr, List<Map<String, dynamic>> records, String type) async {
    String csv = "Date,Name,RegNo,Dept,InTime,OutTime,Status,Hours,Net Salary\n";
    for (var r in records) {
      double hours = 0;
      if (r['in_time'] != null && r['out_time'] != null && r['out_time'].toString().isNotEmpty) {
        try {
          final inFormat = DateFormat("hh:mm a").parse(r['in_time']);
          final outFormat = DateFormat("hh:mm a").parse(r['out_time']);
          hours = outFormat.difference(inFormat).inMinutes / 60.0;
          if (hours < 0) hours += 24;
        } catch (e) {}
      }

      double baseSalary = (r['salary'] as num?)?.toDouble() ?? 0.0;
      double lop = (r['lop_amount'] as num?)?.toDouble() ?? 0.0;
      double netSalary = 0.0;
      if (type == 'Monthly') {
        netSalary = baseSalary - lop;
      } else {
        netSalary = (r['status'] == 'Present' || r['status'] == 'Late Entry') ? (baseSalary / 30.0) : 0.0;
      }

      csv += "${r['date']},${r['name']},${r['register_no']},${r['dept']},${r['in_time']},${r['out_time'] ?? '--:--:--'},${r['status']},${hours.toStringAsFixed(2)},\$${netSalary.toStringAsFixed(2)}\n";
    }
    final directory = await getTemporaryDirectory();
    final file = File("${directory.path}/report_$titleStr.csv");
    await file.writeAsString(csv);
    Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], text: 'Attendance Report CSV');
  }

  static Future<void> exportExcel(BuildContext context, String titleStr, List<Map<String, dynamic>> records, String type) async {
    var excel = xl.Excel.createExcel();
    xl.Sheet sheetObject = excel['Attendance Report'];
    excel.setDefaultSheet('Attendance Report');

    sheetObject.appendRow([
      xl.TextCellValue('Date'), xl.TextCellValue('Name'), xl.TextCellValue('RegNo'),
      xl.TextCellValue('Dept'), xl.TextCellValue('InTime'), xl.TextCellValue('OutTime'),
      xl.TextCellValue('Status'), xl.TextCellValue('Hours'), xl.TextCellValue('Net Salary')
    ]);

    for (var r in records) {
      double hours = 0;
      if (r['in_time'] != null && r['out_time'] != null && r['out_time'].toString().isNotEmpty) {
        try {
          final inFormat = DateFormat("hh:mm a").parse(r['in_time']);
          final outFormat = DateFormat("hh:mm a").parse(r['out_time']);
          hours = outFormat.difference(inFormat).inMinutes / 60.0;
          if (hours < 0) hours += 24;
        } catch (e) {}
      }

      double baseSalary = (r['salary'] as num?)?.toDouble() ?? 0.0;
      double lop = (r['lop_amount'] as num?)?.toDouble() ?? 0.0;
      double netSalary = 0.0;
      if (type == 'Monthly') {
        netSalary = baseSalary - lop;
      } else {
        netSalary = (r['status'] == 'Present' || r['status'] == 'Late Entry') ? (baseSalary / 30.0) : 0.0;
      }

      sheetObject.appendRow([
        xl.TextCellValue(r['date'].toString()), xl.TextCellValue(r['name'].toString()),
        xl.TextCellValue(r['register_no'].toString()), xl.TextCellValue(r['dept'].toString()),
        xl.TextCellValue(r['in_time'].toString()), xl.TextCellValue((r['out_time'] ?? '--:--:--').toString()),
        xl.TextCellValue(r['status'].toString()), xl.TextCellValue(hours.toStringAsFixed(2)),
        xl.TextCellValue('₹${netSalary.toStringAsFixed(2)}')
      ]);
    }

    final directory = await getTemporaryDirectory();
    final file = File("${directory.path}/report_$titleStr.xlsx");
    await file.writeAsBytes(excel.encode()!);
    Share.shareXFiles([XFile(file.path)], text: 'Attendance Report Excel');
  }

  static Future<void> exportPDF(BuildContext context, String titleStr, List<Map<String, dynamic>> records, String type) async {
    final pdf = pw.Document();

    final ByteData logoBytes = await rootBundle.load('assets/St-Marys-school-logo.webp');
    final Uint8List logoData = logoBytes.buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Image(logoImage, width: 50, height: 50),
                  pw.SizedBox(width: 15),
                  pw.Text("St. Marrys School Attendance - $titleStr", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                ]
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Date', 'Name', 'RegNo', 'In', 'Out', 'Hrs', 'Net Salary'],
              data: records.map((r) {
                double hours = 0;
                if (r['in_time'] != null && r['out_time'] != null && r['out_time'].toString().isNotEmpty) {
                  try {
                    final inFormat = DateFormat("hh:mm a").parse(r['in_time']);
                    final outFormat = DateFormat("hh:mm a").parse(r['out_time']);
                    hours = outFormat.difference(inFormat).inMinutes / 60.0;
                    if (hours < 0) hours += 24;
                  } catch (e) {}
                }

                double baseSalary = (r['salary'] as num?)?.toDouble() ?? 0.0;
                double lop = (r['lop_amount'] as num?)?.toDouble() ?? 0.0;
                double netSalary = 0.0;
                if (type == 'Monthly') {
                  netSalary = baseSalary - lop;
                } else {
                  netSalary = (r['status'] == 'Present' || r['status'] == 'Late Entry') ? (baseSalary / 30.0) : 0.0;
                }

                return [r['date'], r['name'], r['register_no'], r['in_time'], r['out_time'] ?? '--:--:--', hours.toStringAsFixed(1), 'Rs. ${netSalary.toStringAsFixed(2)}'];
              }).toList(),
            ),
          ];
        },
      ),
    );

    final directory = await getTemporaryDirectory();
    final file = File("${directory.path}/report_$titleStr.pdf");
    await file.writeAsBytes(await pdf.save());
    Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')], text: 'Attendance Report PDF');
  }

  static void showExportDialog(BuildContext context, String defaultType, Future<List<Map<String, dynamic>>> Function(String type, String dateStr) fetchRecords) {
    final now = DateTime.now();
    final monthStr = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    showDialog(
      context: context,
      builder: (ctx) {
        String _selectedReportType = defaultType;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text("Export & Share", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Choose the type of report:", style: TextStyle(color: Colors.black87)),
                  DropdownButton<String>(
                    value: _selectedReportType,
                    isExpanded: true,
                    items: ['Daily', 'Monthly'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _selectedReportType = v!),
                  ),
                  const SizedBox(height: 10),
                  const Text("Select format to export:", style: TextStyle(color: Colors.black87)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final records = await fetchRecords(_selectedReportType, _selectedReportType == 'Daily' ? todayStr : monthStr);
                    ExportUtils.exportCSV(context, _selectedReportType == 'Daily' ? todayStr : monthStr, records, _selectedReportType);
                  },
                  child: const Text("CSV"),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final records = await fetchRecords(_selectedReportType, _selectedReportType == 'Daily' ? todayStr : monthStr);
                    ExportUtils.exportExcel(context, _selectedReportType == 'Daily' ? todayStr : monthStr, records, _selectedReportType);
                  },
                  child: const Text("Excel (XLSX)"),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final records = await fetchRecords(_selectedReportType, _selectedReportType == 'Daily' ? todayStr : monthStr);
                    ExportUtils.exportPDF(context, _selectedReportType == 'Daily' ? todayStr : monthStr, records, _selectedReportType);
                  },
                  child: const Text("PDF Document"),
                ),
              ],
            );
          }
        );
      }
    );
  }
}
