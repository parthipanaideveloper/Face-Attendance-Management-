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
  static Future<void> exportCSV(BuildContext context, String titleStr, List<Map<String, dynamic>> records, String type, {bool includeSalary = true}) async {
    String csv = includeSalary 
        ? "Date,Name,RegNo,Dept,InTime,OutTime,Status,Hrs,Net Salary\n"
        : "Date,Name,RegNo,Dept,InTime,OutTime,Status,Hrs\n";

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

      String row = "${r['date']},${r['name']},${r['register_no']},${r['dept']},${r['in_time'] ?? ''},${r['out_time'] ?? '--:--:--'},${r['status']},${hours.toStringAsFixed(2)}";
      
      if (includeSalary) {
        double baseSalary = (r['salary'] as num?)?.toDouble() ?? 0.0;
        double lop = (r['lop_amount'] as num?)?.toDouble() ?? 0.0;
        double netSalary = 0.0;
        if (type == 'Monthly') {
          netSalary = baseSalary - lop;
        } else {
          netSalary = (r['status'] == 'Present' || r['status'] == 'Late Entry') ? (baseSalary / 30.0) : 0.0;
        }
        row += ",Rs. ${netSalary.toStringAsFixed(2)}";
      }

      csv += "$row\n";
    }
    final directory = await getTemporaryDirectory();
    final file = File("${directory.path}/report_$titleStr.csv");
    await file.writeAsString(csv);
    Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], text: 'Attendance Report CSV');
  }

  static Future<void> exportExcel(BuildContext context, String titleStr, List<Map<String, dynamic>> records, String type, {bool includeSalary = true}) async {
    var excel = xl.Excel.createExcel();
    xl.Sheet sheetObject = excel['Attendance Report'];
    excel.setDefaultSheet('Attendance Report');

    List<xl.CellValue> headers = [
      xl.TextCellValue('Date'), xl.TextCellValue('Name'), xl.TextCellValue('RegNo'),
      xl.TextCellValue('Dept'), xl.TextCellValue('InTime'), xl.TextCellValue('OutTime'),
      xl.TextCellValue('Status'), xl.TextCellValue('Hrs')
    ];
    if (includeSalary) {
      headers.add(xl.TextCellValue('Net Salary'));
    }
    sheetObject.appendRow(headers);

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

      List<xl.CellValue> rowData = [
        xl.TextCellValue(r['date']?.toString() ?? ''), xl.TextCellValue(r['name']?.toString() ?? ''),
        xl.TextCellValue(r['register_no']?.toString() ?? ''), xl.TextCellValue(r['dept']?.toString() ?? ''),
        xl.TextCellValue(r['in_time']?.toString() ?? ''), xl.TextCellValue((r['out_time'] ?? '--:--:--').toString()),
        xl.TextCellValue(r['status']?.toString() ?? ''), xl.TextCellValue(hours.toStringAsFixed(2))
      ];

      if (includeSalary) {
        double baseSalary = (r['salary'] as num?)?.toDouble() ?? 0.0;
        double lop = (r['lop_amount'] as num?)?.toDouble() ?? 0.0;
        double netSalary = 0.0;
        if (type == 'Monthly') {
          netSalary = baseSalary - lop;
        } else {
          netSalary = (r['status'] == 'Present' || r['status'] == 'Late Entry') ? (baseSalary / 30.0) : 0.0;
        }
        rowData.add(xl.TextCellValue('Rs. ${netSalary.toStringAsFixed(2)}'));
      }

      sheetObject.appendRow(rowData);
    }

    final directory = await getTemporaryDirectory();
    final file = File("${directory.path}/report_$titleStr.xlsx");
    await file.writeAsBytes(excel.encode()!);
    Share.shareXFiles([XFile(file.path)], text: 'Attendance Report Excel');
  }

  static Future<void> exportPDF(BuildContext context, String titleStr, List<Map<String, dynamic>> records, String type, {bool includeSalary = true}) async {
    final pdf = pw.Document();

    final ByteData logoBytes = await rootBundle.load('assets/St-Marys-school-logo.webp');
    final Uint8List logoData = logoBytes.buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context context) {
          return [
            pw.Container(
              margin: const pw.EdgeInsets.all(20),
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey, width: 2),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Image(logoImage, width: 50, height: 50),
                        pw.SizedBox(width: 15),
                        pw.Text("St. Marys School Attendance - $titleStr", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                      ]
                  ),
                  pw.SizedBox(height: 20),
                  pw.TableHelper.fromTextArray(
                    context: context,
                    headers: includeSalary 
                        ? ['Date', 'Name', 'RegNo', 'Dept', 'In', 'Out', 'Status', 'Hrs', 'Net Salary']
                        : ['Date', 'Name', 'RegNo', 'Dept', 'In', 'Out', 'Status', 'Hrs'],
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

                      List<String> rowData = [r['date'] ?? '', r['name'] ?? '', r['register_no'] ?? '', r['dept'] ?? '', r['in_time'] ?? '', r['out_time'] ?? '--:--:--', r['status'] ?? '', hours.toStringAsFixed(1)];
                      
                      if (includeSalary) {
                        double baseSalary = (r['salary'] as num?)?.toDouble() ?? 0.0;
                        double lop = (r['lop_amount'] as num?)?.toDouble() ?? 0.0;
                        double netSalary = 0.0;
                        if (type == 'Monthly') {
                          netSalary = baseSalary - lop;
                        } else {
                          netSalary = (r['status'] == 'Present' || r['status'] == 'Late Entry') ? (baseSalary / 30.0) : 0.0;
                        }
                        rowData.add('Rs. ${netSalary.toStringAsFixed(2)}');
                      }
                      return rowData;
                    }).toList(),
                  ),
                ]
              )
            )
          ];
        },
      ),
    );

    final directory = await getTemporaryDirectory();
    final file = File("${directory.path}/report_$titleStr.pdf");
    await file.writeAsBytes(await pdf.save());
    Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')], text: 'Attendance Report PDF');
  }

  static void showExportDialog(BuildContext context, String defaultType, Future<List<Map<String, dynamic>>> Function(String type, String dateStr) fetchRecords, {bool includeSalary = true}) {
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) {
        String _selectedReportType = defaultType;
        return StatefulBuilder(
          builder: (context, setState) {
            String displayDate = _selectedReportType == 'Daily' 
                ? DateFormat('dd MMM yyyy').format(selectedDate)
                : DateFormat('MMMM yyyy').format(selectedDate);
                
            String queryDateStr = _selectedReportType == 'Daily' 
                ? DateFormat('yyyy-MM-dd').format(selectedDate) 
                : DateFormat('yyyy-MM').format(selectedDate);

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Selected: $displayDate", style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: const Text("Change Date"),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text("Select format to export:", style: TextStyle(color: Colors.black87)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final records = await fetchRecords(_selectedReportType, queryDateStr);
                    ExportUtils.exportCSV(context, queryDateStr, records, _selectedReportType, includeSalary: includeSalary);
                  },
                  child: const Text("CSV"),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final records = await fetchRecords(_selectedReportType, queryDateStr);
                    ExportUtils.exportExcel(context, queryDateStr, records, _selectedReportType, includeSalary: includeSalary);
                  },
                  child: const Text("Excel (XLSX)"),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final records = await fetchRecords(_selectedReportType, queryDateStr);
                    ExportUtils.exportPDF(context, queryDateStr, records, _selectedReportType, includeSalary: includeSalary);
                  },
                  child: const Text("PDF"),
                ),
              ],
            );
          }
        );
      }
    );
  }
}
