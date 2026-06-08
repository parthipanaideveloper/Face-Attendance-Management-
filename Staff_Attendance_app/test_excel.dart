import 'package:excel/excel.dart';

void main() {
  var excel = Excel.createExcel();
  var sheet = excel['Sheet1'];
  
  var cellStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('#FF0000'),
    fontFamily: getFontFamily(FontFamily.Calibri),
  );
  
  var cell = sheet.cell(CellIndex.indexByString("A1"));
  cell.value = TextCellValue("Hello");
  cell.cellStyle = cellStyle;
  
  print("Success");
}
