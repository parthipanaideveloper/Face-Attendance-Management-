import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staff_attendance_app/core/providers/db_provider.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:staff_attendance_app/core/widgets/footer_widget.dart';
import 'package:staff_attendance_app/services/payroll_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as xl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:math';

class LopManagementScreen extends ConsumerStatefulWidget {
  const LopManagementScreen({super.key});

  @override
  ConsumerState<LopManagementScreen> createState() => _LopManagementScreenState();
}

class _LopManagementScreenState extends ConsumerState<LopManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _staffList = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    final db = ref.read(databaseProvider);
    final staff = await db.getAllStaffs();
    if (mounted) {
      setState(() {
        _staffList = staff;
        _isLoading = false;
      });
    }
  }

  xl.ExcelColor _getRowColor(Map<String, dynamic> staff) {
    String reg = staff['register_no']?.toString().toUpperCase() ?? '';
    String dept = staff['dept']?.toString().toLowerCase() ?? '';
    
    if (reg.startsWith('SMSOA')) return xl.ExcelColor.fromHexString('#FFF2CC'); // Yellowish
    if (reg.startsWith('SMSAD')) return xl.ExcelColor.fromHexString('#D9EAD3'); // Greenish
    if (reg.startsWith('SMSAO')) return xl.ExcelColor.fromHexString('#C9DAF8'); // Blueish
    if (reg.startsWith('SMSTM')) return xl.ExcelColor.fromHexString('#FCE5CD'); // Orangish
    if (reg.startsWith('SMSNS')) return xl.ExcelColor.fromHexString('#EAD1DC'); // Pinkish
    
    if (dept.contains('teaching') && !dept.contains('non')) return xl.ExcelColor.fromHexString('#D0E0E3'); // Light Teal
    if (dept.contains('non teaching') || dept.contains('non-teaching')) return xl.ExcelColor.fromHexString('#E6B8AF'); // Light Red
    
    return xl.ExcelColor.fromHexString('#FFFFFF'); // Default white
  }

  double _calculateTotalAdvanceBalance(Map<String, dynamic> staff) {
    var advances = staff['dynamic_advances'];
    if (advances == null || advances is! List) return 0.0;

    double total = 0.0;
    for (var advance in advances) {
      if (advance != null && advance is Map) {
        total += double.tryParse(advance['balance'].toString()) ?? 0.0;
      }
    }
    return total;
  }

  double _calculateCurrentMonthAdvanceDeduction(Map<String, dynamic> staff) {
    var advances = staff['dynamic_advances'];
    if (advances == null || advances is! List) return 0.0;

    double totalAdvanceDeduction = 0.0;
    String currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

    for (var advance in advances) {
      if (advance != null && advance is Map) {
        double balance = double.tryParse(advance['balance'].toString()) ?? 0.0;
        String targetMonth = advance['target_month']?.toString() ?? advance['start_month']?.toString() ?? '2000-01';
        
        if (balance > 0 && currentMonth.compareTo(targetMonth) >= 0) {
          totalAdvanceDeduction += balance; // Take full balance
        }
      }
    }
    return totalAdvanceDeduction;
  }

  Future<void> _exportData(String format) async {
    final records = List<Map<String, dynamic>>.from(_staffList);
    records.sort((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
    if (records.isEmpty) return;

    final directory = await getTemporaryDirectory();
    final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    if (format == 'CSV') {
      String csv = "Name,ID,Dept,Mobile,Zone,Gender,Designation,Salary,LOP,SL,EL,Full Advance,Adv Deducted,Final Pay\n";
      for (var s in records) {
        final double sal = double.tryParse(s['salary']?.toString() ?? '0') ?? 0.0;
        final double lop = double.tryParse(s['lop_amount']?.toString() ?? '0') ?? 0.0;
        final int sl = s['sick_leave'] != null ? int.tryParse(s['sick_leave'].toString()) ?? 0 : 0;
        final int el = s['earned_leave'] != null ? int.tryParse(s['earned_leave'].toString()) ?? 0 : 0;
        
        double totalAdvanceBalance = _calculateTotalAdvanceBalance(s);
        double totalAdvanceDeducted = _calculateCurrentMonthAdvanceDeduction(s);
        final double finalPay = sal - lop - totalAdvanceDeducted;
        
        String regNo = s['register_no']?.toString() ?? '';
        String zoneText = s['zone']?.toString() ?? '';
        if (regNo.startsWith('SMSNS')) zoneText = '-';

        csv += "${s['name']},$regNo,${s['dept']},${s['mobile_no']},$zoneText,${s['gender']},${s['designation']},$sal,$lop,$sl,$el,$totalAdvanceBalance,$totalAdvanceDeducted,$finalPay\n";
      }
      final file = File("${directory.path}/Payroll_$timestamp.csv");
      await file.writeAsString(csv);
      Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], text: 'Payroll Report CSV');
    } else if (format == 'Excel') {
      var excel = xl.Excel.createExcel();
      xl.Sheet sheet = excel['Payroll Report'];
      excel.setDefaultSheet('Payroll Report');
      
      var headerStyle = xl.CellStyle(
        backgroundColorHex: xl.ExcelColor.fromHexString('#4F81BD'),
        fontFamily: xl.getFontFamily(xl.FontFamily.Calibri),
        fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
        bold: true,
      );

      List<String> headers = ['Name', 'ID', 'Dept', 'Mobile', 'Zone', 'Gender', 'Designation', 'Salary', 'LOP', 'SL', 'EL', 'Full Advance', 'Adv Deducted', 'Final Pay'];
      for (int i = 0; i < headers.length; i++) {
        var cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      int rowIdx = 1;
      for (var s in records) {
        final double sal = double.tryParse(s['salary']?.toString() ?? '0') ?? 0.0;
        final double lop = double.tryParse(s['lop_amount']?.toString() ?? '0') ?? 0.0;
        final int sl = s['sick_leave'] != null ? int.tryParse(s['sick_leave'].toString()) ?? 0 : 0;
        final int el = s['earned_leave'] != null ? int.tryParse(s['earned_leave'].toString()) ?? 0 : 0;
        
        double totalAdvanceBalance = _calculateTotalAdvanceBalance(s);
        double totalAdvanceDeducted = _calculateCurrentMonthAdvanceDeduction(s);
        final double finalPay = sal - lop - totalAdvanceDeducted;

        xl.ExcelColor rowColor = _getRowColor(s);
        var rowStyle = xl.CellStyle(
          backgroundColorHex: rowColor,
          fontFamily: xl.getFontFamily(xl.FontFamily.Calibri),
        );

        String regNo = s['register_no']?.toString() ?? '';
        String zoneText = s['zone']?.toString() ?? '';
        if (regNo.startsWith('SMSNS')) zoneText = '-';

        List<xl.CellValue> values = [
          xl.TextCellValue(s['name']?.toString() ?? ''),
          xl.TextCellValue(regNo),
          xl.TextCellValue(s['dept']?.toString() ?? ''),
          xl.TextCellValue(s['mobile_no']?.toString() ?? ''),
          xl.TextCellValue(zoneText),
          xl.TextCellValue(s['gender']?.toString() ?? ''),
          xl.TextCellValue(s['designation']?.toString() ?? ''),
          xl.DoubleCellValue(sal),
          xl.DoubleCellValue(lop),
          xl.IntCellValue(sl),
          xl.IntCellValue(el),
          xl.DoubleCellValue(totalAdvanceBalance),
          xl.DoubleCellValue(totalAdvanceDeducted),
          xl.DoubleCellValue(finalPay),
        ];

        for (int c = 0; c < values.length; c++) {
          var cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx));
          cell.value = values[c];
          cell.cellStyle = rowStyle;
        }
        rowIdx++;
      }
      final file = File("${directory.path}/Payroll_$timestamp.xlsx");
      await file.writeAsBytes(excel.encode()!);
      Share.shareXFiles([XFile(file.path)], text: 'Payroll Report Excel');
    } else if (format == 'PDF') {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              pw.Text("Payroll Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
                headerHeight: 25,
                cellHeight: 25,
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
                cellStyle: const pw.TextStyle(fontSize: 7),
                headers: ['Name', 'ID', 'Dept', 'Zone', 'Salary', 'LOP', 'SL', 'EL', 'Full Adv', 'Deducted', 'Final Pay'],
                data: records.map((s) {
                  final double sal = double.tryParse(s['salary']?.toString() ?? '0') ?? 0.0;
                  final double lop = double.tryParse(s['lop_amount']?.toString() ?? '0') ?? 0.0;
                  final int sl = s['sick_leave'] != null ? int.tryParse(s['sick_leave'].toString()) ?? 0 : 0;
                  final int el = s['earned_leave'] != null ? int.tryParse(s['earned_leave'].toString()) ?? 0 : 0;
                  
                  double totalAdvanceBalance = _calculateTotalAdvanceBalance(s);
                  double totalAdvanceDeducted = _calculateCurrentMonthAdvanceDeduction(s);
                  final double finalPay = sal - lop - totalAdvanceDeducted;
                  
                  String regNo = s['register_no']?.toString() ?? '';
                  String zoneText = s['zone']?.toString() ?? '';
                  if (regNo.startsWith('SMSNS')) zoneText = '-';

                  return [
                    s['name']?.toString() ?? '', regNo, s['dept']?.toString() ?? '', zoneText,
                    sal.toString(), lop.toString(), sl.toString(), el.toString(),
                    totalAdvanceBalance.toString(), totalAdvanceDeducted.toString(), finalPay.toString()
                  ];
                }).toList(),
              )
            ];
          }
        )
      );
      final file = File("${directory.path}/Payroll_$timestamp.pdf");
      await file.writeAsBytes(await pdf.save());
      Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')], text: 'Payroll Report PDF');
    }
  }

  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("Export Payroll Data", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text("Export as Excel"),
              onTap: () { Navigator.pop(ctx); _exportData('Excel'); },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text("Export as PDF"),
              onTap: () { Navigator.pop(ctx); _exportData('PDF'); },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt, color: Colors.blue),
              title: const Text("Export as CSV"),
              onTap: () { Navigator.pop(ctx); _exportData('CSV'); },
            ),
          ],
        ),
      )
    );
  }

  void _showManageAdvancesDialog(Map<String, dynamic> staff) {
    final TextEditingController amountCtrl = TextEditingController();
    
    // Default to CURRENT month so deductions apply immediately
    DateTime now = DateTime.now();
    final TextEditingController targetMonthCtrl = TextEditingController(text: DateFormat('yyyy-MM').format(now));

    List<dynamic> advances = staff['dynamic_advances'] ?? [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("Manage Dynamic Advances", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Current Active Advances:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 5),
                  if (advances.isEmpty) const Text("No active advances.", style: TextStyle(color: Colors.black54)),
                  for (var adv in advances)
                    if ((double.tryParse(adv['balance'].toString()) ?? 0.0) > 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Total: ₹${adv['total_amount']} | Bal: ₹${adv['balance']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                            Text("Deduct In: ${adv['target_month'] ?? adv['start_month']}", style: const TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                  const Divider(height: 30),
                  const Text("Issue New Advance:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(labelText: "Advance Amount (₹)", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: targetMonthCtrl,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(labelText: "Deduction Month (yyyy-MM)", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, minimumSize: const Size(double.infinity, 36)),
                    onPressed: () async {
                      double amount = double.tryParse(amountCtrl.text) ?? 0.0;
                      if (amount > 0) {
                        Map<String, dynamic> newAdv = {
                          "id": DateTime.now().millisecondsSinceEpoch.toString(),
                          "total_amount": amount,
                          "balance": amount,
                          "target_month": targetMonthCtrl.text.trim(),
                        };
                        
                        advances.add(newAdv);
                        staff['dynamic_advances'] = advances;
                        
                        final db = ref.read(databaseProvider);
                        await db.updateStaff(staff);
                        
                        setDialogState(() {
                          amountCtrl.clear();
                        });
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Advance Issued successfully!"), backgroundColor: AppTheme.accentEmerald));
                          _loadStaff(); // refresh table behind
                        }
                      }
                    },
                    child: const Text("Issue Advance", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
          ],
        ),
      ),
    );
  }

  void _showUpdateSalaryDialog(Map<String, dynamic> staff) {
    final TextEditingController salaryCtrl = TextEditingController(text: (staff['salary'] ?? '0').toString());
    final TextEditingController lopCtrl = TextEditingController(text: (staff['lop_amount'] ?? '0').toString());
    final TextEditingController slCtrl = TextEditingController(text: (staff['sick_leave'] ?? '0').toString());
    final TextEditingController elCtrl = TextEditingController(text: (staff['earned_leave'] ?? '0').toString());
    bool isCalculating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Update Salary & LOP", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            if (isCalculating) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Name: ${staff['name']}", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                Text("Reg No: ${staff['register_no']}", style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                  label: const Text("Auto-Calculate LOP (1 SL, 1 EL)", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, minimumSize: const Size(double.infinity, 36)),
                  onPressed: () async {
                    setDialogState(() => isCalculating = true);
                    try {
                      final payrollService = PayrollService();
                      String monthPrefix = DateFormat('yyyy-MM').format(DateTime.now());
                      var report = await payrollService.calculateSuggestedPayroll(staff['register_no'], monthPrefix, 30);
                      
                      setDialogState(() {
                        lopCtrl.text = report['suggested_lop_deduction'].toString();
                        slCtrl.text = report['sl_used'].toString();
                        elCtrl.text = report['el_used'].toString();
                      });
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("Auto-Applied: ${report['suggested_lop_days']} LOP days. (${report['sl_used']} SL used, ${report['el_used']} EL used.)"),
                          backgroundColor: Colors.blueAccent,
                        ));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error calculating: $e")));
                      }
                    } finally {
                      setDialogState(() => isCalculating = false);
                    }
                  },
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: salaryCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(labelText: "Monthly Salary (₹)", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: lopCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(labelText: "Manual LOP Deduction (₹)", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: slCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.black), decoration: const InputDecoration(labelText: "Sick Leave (Days)", border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: elCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.black), decoration: const InputDecoration(labelText: "Earned Leave (Days)", border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
                  label: const Text("Manage Dynamic Advances", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, minimumSize: const Size(double.infinity, 45)),
                  onPressed: () {
                     Navigator.pop(ctx);
                     _showManageAdvancesDialog(staff);
                  },
                )
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
            onPressed: () async {
              double newSalary = double.tryParse(salaryCtrl.text) ?? 0.0;
              double newLop = double.tryParse(lopCtrl.text) ?? 0.0;
              int sl = int.tryParse(slCtrl.text) ?? 0;
              int el = int.tryParse(elCtrl.text) ?? 0;

              final db = ref.read(databaseProvider);
              await db.updateStaff({
                'register_no': staff['register_no'],
                'salary': newSalary,
                'lop_amount': newLop,
                'sick_leave': sl,
                'earned_leave': el,
              });

              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Salary & LOP Updated!"), backgroundColor: AppTheme.accentEmerald));
                _loadStaff();
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredStaff = _staffList.where((s) {
      final text = "${s['name']} ${s['register_no']} ${s['dept']}".toLowerCase();
      return text.contains(_searchQuery.toLowerCase());
    }).toList();
    filteredStaff.sort((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));

    return Scaffold(
      backgroundColor: Colors.grey[50], // White Theme
      appBar: AppBar(
        title: const Text("Manage LOP & Salary", style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.cardColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Export Options",
            onPressed: _showExportOptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: "Search Employee...",
                      hintStyle: const TextStyle(color: Colors.black54),
                      prefixIcon: const Icon(Icons.search, color: Colors.black54),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.blueGrey[900]), // Dark Highlight Color
                        dataRowMinHeight: 48,
                        dataRowMaxHeight: 48,
                        columns: const [
                          DataColumn(label: Text("Name", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text("ID", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text("Dept", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text("Mobile", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text("Zone", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text("Gender", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text("Designation", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text("Salary", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text("LOP", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text("Full Advance", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text("Adv Deducted", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text("SL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text("EL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text("Final Pay", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text("Action", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                        ],
                        rows: filteredStaff.map((staff) {
                          final double sal = double.tryParse(staff['salary']?.toString() ?? '0') ?? 0.0;
                          final double lop = double.tryParse(staff['lop_amount']?.toString() ?? '0') ?? 0.0;
                          final int sl = staff['sick_leave'] != null ? int.tryParse(staff['sick_leave'].toString()) ?? 0 : 0;
                          final int el = staff['earned_leave'] != null ? int.tryParse(staff['earned_leave'].toString()) ?? 0 : 0;
                          
                          double totalAdvanceBalance = _calculateTotalAdvanceBalance(staff);
                          double totalAdvanceDeducted = _calculateCurrentMonthAdvanceDeduction(staff);
                          final double finalPay = sal - lop - totalAdvanceDeducted;
                          
                          String regNo = staff['register_no'] ?? '';
                          String zoneText = staff['zone'] ?? '';
                          if (regNo.startsWith('SMSNS')) {
                            zoneText = '-';
                          }

                          return DataRow(cells: [
                            DataCell(Text(staff['name'] ?? '', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(regNo, style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(staff['dept'] ?? '', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(staff['mobile_no'] ?? '', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(zoneText, style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(staff['gender'] ?? '', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(staff['designation'] ?? '', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text("₹$sal", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                            DataCell(Text("₹$lop", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                            DataCell(Text("₹${totalAdvanceBalance.toStringAsFixed(2)}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                            DataCell(Text("₹${totalAdvanceDeducted.toStringAsFixed(2)}", style: const TextStyle(color: Colors.deepOrangeAccent, fontWeight: FontWeight.bold))),
                            DataCell(Text("$sl", style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold))),
                            DataCell(Text("$el", style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold))),
                            DataCell(Text("₹${finalPay.toStringAsFixed(2)}", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.edit, color: AppTheme.accentCyan),
                                tooltip: "Edit",
                                onPressed: () => _showUpdateSalaryDialog(staff),
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const AppFooter(isDark: false),
              ],
            ),
    );
  }
}
