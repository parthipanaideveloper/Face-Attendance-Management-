import 'dart:convert';
import 'package:staff_attendance_app/database/db_helper.dart';

class PayrollService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Calculates the suggested payroll for a specific staff member for a given month.
  /// [monthPrefix] should be in format 'yyyy-MM', e.g., '2023-10'
  /// Returns a Map with all the calculated deduction details, allowing the Admin to override.
  Future<Map<String, dynamic>> calculateSuggestedPayroll(String registerNo, String monthPrefix, int totalWorkingDaysInMonth) async {
    // 1. Fetch Staff Details
    final staff = await _dbHelper.getStaffByRegisterNo(registerNo);
    if (staff == null) {
      throw Exception("Staff not found");
    }

    double baseSalary = 0.0;
    if (staff['salary'] != null) {
       baseSalary = double.tryParse(staff['salary'].toString()) ?? 0.0;
    }

    // 2. Fetch Attendance for the month
    final attendanceRecords = await _dbHelper.getAttendanceByMonth(monthPrefix);
    final staffAttendance = attendanceRecords.where((record) => record['register_no'] == registerNo).toList();

    int daysPresent = staffAttendance.length;
    int daysAbsent = totalWorkingDaysInMonth - daysPresent;
    if (daysAbsent < 0) daysAbsent = 0;

    // 3. Leave Quota Logic (1 SL, 1 EL per month)
    int remainingAbsences = daysAbsent;
    int slUsed = 0;
    int elUsed = 0;

    // Use Sick Leave (Max 1)
    if (remainingAbsences > 0) {
      slUsed = 1;
      remainingAbsences -= 1;
    }

    // Use Earned Leave (Max 1)
    if (remainingAbsences > 0) {
      elUsed = 1;
      remainingAbsences -= 1;
    }

    // Remaining absences become LOP
    int lopDays = remainingAbsences;
    
    double perDaySalary = totalWorkingDaysInMonth > 0 ? (baseSalary / totalWorkingDaysInMonth) : 0.0;
    double suggestedLopDeduction = lopDays * perDaySalary;

    // 4. Dynamic Advances Logic
    var advances = staff['dynamic_advances'];
    double totalAdvanceDeduction = 0.0;
    List<Map<String, dynamic>> advanceDeductionsDetails = [];

    if (advances != null && advances is List) {
      for (var advance in advances) {
        if (advance != null && advance is Map) {
          double balance = double.tryParse(advance['balance'].toString()) ?? 0.0;
          String targetMonth = advance['target_month']?.toString() ?? advance['start_month']?.toString() ?? '2000-01'; // Fallback for old data
          
          // Deduct full balance if we reached the target month
          if (balance > 0 && monthPrefix.compareTo(targetMonth) >= 0) {
            double deductionAmount = balance; // Take full balance
            
            totalAdvanceDeduction += deductionAmount;
            advanceDeductionsDetails.add({
              "id": advance['id'],
              "suggested_deduction": deductionAmount,
              "remaining_balance_before": balance,
            });
          }
        }
      }
    }

    double suggestedNetSalary = baseSalary - suggestedLopDeduction - totalAdvanceDeduction;

    // Return the calculated data so the Admin UI can review and override it
    return {
      "register_no": registerNo,
      "name": staff['name'],
      "month": monthPrefix,
      "base_salary": baseSalary,
      "total_working_days": totalWorkingDaysInMonth,
      "days_present": daysPresent,
      "days_absent": daysAbsent,
      "sl_used": slUsed,
      "el_used": elUsed,
      "suggested_lop_days": lopDays,
      "suggested_lop_deduction": suggestedLopDeduction,
      "advance_deductions": advanceDeductionsDetails,
      "total_advance_deduction": totalAdvanceDeduction,
      "suggested_net_salary": suggestedNetSalary,
    };
  }

  /// Called by the Admin when they confirm the final payroll (after applying overrides).
  /// This updates the advance balances in the database safely.
  Future<void> finalizePayroll(String registerNo, List<Map<String, dynamic>> appliedAdvanceDeductions) async {
    final staff = await _dbHelper.getStaffByRegisterNo(registerNo);
    if (staff == null) return;

    var advancesData = staff['dynamic_advances'];
    if (advancesData == null || advancesData is! List) return;
    
    List<dynamic> advances = advancesData;
    bool updated = false;

    // Update balances based on the Admin's final applied deductions
    for (var applied in appliedAdvanceDeductions) {
      for (var i = 0; i < advances.length; i++) {
        if (advances[i]['id'] == applied['id']) {
          double currentBalance = double.tryParse(advances[i]['balance'].toString()) ?? 0.0;
          double deduction = double.tryParse(applied['deducted_amount'].toString()) ?? 0.0;
          
          double newBalance = currentBalance - deduction;
          if (newBalance < 0) newBalance = 0.0;
          
          advances[i]['balance'] = newBalance;
          updated = true;
          break;
        }
      }
    }

    // Save back to local DB (which can then sync to Firebase)
    if (updated) {
      staff['dynamic_advances'] = advances;
      await _dbHelper.updateStaff(staff);
    }
  }
}
