import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/grocery_item.dart';
import 'auth_service.dart';
import 'grocery_service.dart';

class GroceryPdfService {
  /// Generate and open standard A4 PDF Print / Save dialog for a specific store ledger
  static Future<void> printStoreStatement({
    required GroceryStore store,
    required List<GroceryEntry> entries,
  }) async {
    final doc = pw.Document();
    pw.Font font;
    pw.Font fontBold;
    pw.Font fontSemiBold;
    try {
      font = await PdfGoogleFonts.interRegular();
      fontBold = await PdfGoogleFonts.interBold();
      fontSemiBold = await PdfGoogleFonts.interSemiBold();
    } catch (_) {
      // Offline fallback: Use standard built-in PDF Type 1 fonts
      font = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
      fontSemiBold = pw.Font.helveticaBold();
    }

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);
    final userName = AuthService.displayName.isNotEmpty ? AuthService.displayName : 'Authorized Ledger User';
    final userEmail = AuthService.email.isNotEmpty ? AuthService.email : 'Cloud Account';
    final generatedOn = DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now());

    final isSettled = store.isSettled;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
        header: (context) => _buildHeader(
          store: store,
          userName: userName,
          userEmail: userEmail,
          generatedOn: generatedOn,
          fontBold: fontBold,
          fontSemiBold: fontSemiBold,
        ),
        footer: (context) => _buildFooter(context, font),
        build: (context) => [
          pw.SizedBox(height: 12),

          // 1. Store Balance Summary Box
          _buildStoreKpiBox(
            store: store,
            currency: currency,
            isSettled: isSettled,
            fontBold: fontBold,
            fontSemiBold: fontSemiBold,
          ),
          pw.SizedBox(height: 16),

          // 2. Entries Section Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'DETAILED STORE LEDGER ENTRIES (SAMAN UDHAAR & CHUKAYA)',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 10,
                  color: PdfColors.blueGrey800,
                  letterSpacing: 0.8,
                ),
              ),
              pw.Text(
                'Total Records: ${entries.length}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.blueGrey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),

          // 3. Entries Table
          _buildEntriesTable(entries, currency, fontBold),
        ],
      ),
    );

    final cleanName = store.storeName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'DukanKhata_${cleanName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  /// Generate and open standard A4 PDF Print / Save dialog for All Stores Summary
  static Future<void> printAllStoresSummary({
    required List<GroceryStore> stores,
    required GroceryOverviewStats stats,
  }) async {
    final doc = pw.Document();
    pw.Font font;
    pw.Font fontBold;
    try {
      font = await PdfGoogleFonts.interRegular();
      fontBold = await PdfGoogleFonts.interBold();
    } catch (_) {
      // Offline fallback: Use standard built-in PDF Type 1 fonts
      font = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);
    final userName = AuthService.displayName.isNotEmpty ? AuthService.displayName : 'Authorized Ledger User';
    final userEmail = AuthService.email.isNotEmpty ? AuthService.email : 'Cloud Account';
    final generatedOn = DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey200, width: 1.2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('GROCERY & DUKAN KHATA SUMMARY', style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.blue800)),
                  pw.Text('Independent Store Ledger Directory', style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey600)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(userName, style: pw.TextStyle(font: fontBold, fontSize: 11)),
                  pw.Text(userEmail, style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600)),
                  pw.Text(generatedOn, style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey400)),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => _buildFooter(context, font),
        build: (context) => [
          pw.SizedBox(height: 12),

          // Overview KPI
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.blueGrey200),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildKpiItem('Total Dukaane', '${stats.totalStores}', PdfColors.blueGrey800, fontBold),
                _buildKpiItem('Total Udhaar Liya', currency.format(stats.totalUdhaar), PdfColors.orange800, fontBold),
                _buildKpiItem('Total Chukaya', currency.format(stats.totalChukaya), PdfColors.green800, fontBold),
                _buildKpiItem('Net Pending Dues', currency.format(stats.netPending), PdfColors.red800, fontBold),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          pw.Text('ALL STORE ACCOUNTS BREAKDOWN', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blueGrey800)),
          pw.SizedBox(height: 6),

          pw.TableHelper.fromTextArray(
            headers: ['Store Name', 'Category', 'Total Udhaar', 'Total Chukaya', 'Pending Due', 'Status'],
            data: stores.map((s) => [
              s.storeName,
              s.category,
              currency.format(s.totalUdhaar),
              currency.format(s.totalChukaya),
              currency.format(s.pendingBalance),
              s.isSettled ? 'Hisaab Chukta' : 'Baaki',
            ]).toList(),
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'DukanKhata_AllStores_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _buildKpiItem(String title, String val, PdfColor color, pw.Font fontBold) {
    return pw.Column(
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.blueGrey600)),
        pw.SizedBox(height: 3),
        pw.Text(val, style: pw.TextStyle(font: fontBold, fontSize: 12, color: color)),
      ],
    );
  }

  static pw.Widget _buildHeader({
    required GroceryStore store,
    required String userName,
    required String userEmail,
    required String generatedOn,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blueGrey200, width: 1.2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 20,
                    height: 20,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green700,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text('D', style: pw.TextStyle(color: PdfColors.white, font: fontBold, fontSize: 12)),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    store.storeName.toUpperCase(),
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 15,
                      color: PdfColors.blueGrey900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Dukan Khata & Store Ledger (${store.category} Store)',
                style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.blueGrey600),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(userName, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blueGrey900)),
              pw.Text(userEmail, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.blueGrey600)),
              pw.Text('Date: $generatedOn', style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey400)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStoreKpiBox({
    required GroceryStore store,
    required NumberFormat currency,
    required bool isSettled,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('TOTAL UDHAAR LIYA', style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey600)),
              pw.SizedBox(height: 2),
              pw.Text(
                currency.format(store.totalUdhaar),
                style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.orange800),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('TOTAL CHUKAYA (PAID)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey600)),
              pw.SizedBox(height: 2),
              pw.Text(
                currency.format(store.totalChukaya),
                style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.green800),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('NET PENDING BALANCE', style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey600)),
              pw.SizedBox(height: 2),
              pw.Text(
                currency.format(store.pendingBalance),
                style: pw.TextStyle(font: fontBold, fontSize: 14, color: isSettled ? PdfColors.green800 : PdfColors.red800),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(
              color: isSettled ? PdfColors.green100 : PdfColors.orange100,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: isSettled ? PdfColors.green700 : PdfColors.orange700, width: 0.8),
            ),
            child: pw.Text(
              isSettled ? 'HISAAB CHUKTA' : 'BAAKI HAI',
              style: pw.TextStyle(font: fontBold, fontSize: 9, color: isSettled ? PdfColors.green900 : PdfColors.orange900),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildEntriesTable(
    List<GroceryEntry> entries,
    NumberFormat currency,
    pw.Font fontBold,
  ) {
    if (entries.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        alignment: pw.Alignment.center,
        child: pw.Text('No entries recorded in this store ledger.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey500)),
      );
    }

    return pw.TableHelper.fromTextArray(
      headers: ['S.No.', 'Date & Time', 'Type', 'Kya Saman / Remarks', 'Amount (Rs.)'],
      data: entries.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final item = entry.value;
        final isUdhaar = item.isUdhaar;

        return [
          '$index',
          DateFormat('dd MMM yyyy, hh:mm a').format(item.entryDate),
          isUdhaar ? 'Udhaar Saman' : 'Paise Chukaye',
          item.itemsDescription,
          currency.format(item.amount),
        ];
      }).toList(),
      headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.Font font) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey200, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'MsmKhata — Dedicated Grocery & General Dukan Khata Statement',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey500),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey500),
          ),
        ],
      ),
    );
  }
}

