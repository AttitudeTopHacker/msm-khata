import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/stats.dart';
import '../models/transaction.dart';
import 'auth_service.dart';

/// Professional A4 PDF & Print Statement Generation Service
class PdfExportService {
  /// Generate and open standard A4 PDF Print / Save dialog
  static Future<void> printOrSaveA4Statement({
    required DashboardStats stats,
    required List<TransactionItem> transactions,
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontSemiBold = await PdfGoogleFonts.interSemiBold();

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);
    final userName = AuthService.displayName.isNotEmpty ? AuthService.displayName : 'Authorized Ledger User';
    final userEmail = AuthService.email.isNotEmpty ? AuthService.email : 'Cloud Account';
    final generatedOn = DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now());

    // Calculate totals
    final totalGiven = stats.totalReceivable;
    final totalTaken = stats.totalPayable;
    final totalIncome = stats.totalIncome;
    final totalExpense = stats.totalExpense;
    final netBalance = stats.netLenDenPosition;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
        header: (context) => _buildPdfHeader(
          userName: userName,
          userEmail: userEmail,
          generatedOn: generatedOn,
          fontBold: fontBold,
          fontSemiBold: fontSemiBold,
        ),
        footer: (context) => _buildPdfFooter(context, font),
        build: (context) => [
          pw.SizedBox(height: 12),

          // 1. Executive Financial Summary (KPI Box)
          _buildSummaryKpiBox(
            totalGiven: totalGiven,
            totalTaken: totalTaken,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            netBalance: netBalance,
            currency: currency,
            fontBold: fontBold,
            fontSemiBold: fontSemiBold,
          ),

          pw.SizedBox(height: 16),

          // 2. Category & Trade Breakdown (if available)
          if (stats.categoryBreakdown.isNotEmpty) ...[
            _buildCategoryBreakdownSection(
              stats.categoryBreakdown,
              currency,
              fontBold,
            ),
            pw.SizedBox(height: 16),
          ],

          // 3. Detailed Transaction Ledger
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'DETAILED TRANSACTION LEDGER ENTRIES',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 10,
                  color: PdfColors.blueGrey800,
                  letterSpacing: 0.8,
                ),
              ),
              pw.Text(
                'Total Entries: ${transactions.length}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.blueGrey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),

          _buildTransactionsTable(
            transactions,
            currency,
            fontBold,
          ),
        ],
      ),
    );

    // Trigger A4 Print / Save PDF Dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'MsmKhata_Ledger_Statement_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _buildPdfHeader({
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
                    width: 22,
                    height: 22,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.indigo700,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'M',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 13,
                        font: fontBold,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'MSMKHATA',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 16,
                      color: PdfColors.indigo900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'ORG : msm.movin 2022 • Personal & Agricultural Trade Statement',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.blueGrey600,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                userName,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 11,
                  color: PdfColors.blueGrey900,
                ),
              ),
              pw.Text(
                userEmail,
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.blueGrey600,
                ),
              ),
              pw.Text(
                'Generated: $generatedOn',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.blueGrey500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryKpiBox({
    required double totalGiven,
    required double totalTaken,
    required double totalIncome,
    required double totalExpense,
    required double netBalance,
    required NumberFormat currency,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
  }) {
    final isPositive = netBalance >= 0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildKpiColumn('Total Lent (Receivable)', currency.format(totalGiven), PdfColors.teal700, fontBold),
          _buildKpiDivider(),
          _buildKpiColumn('Total Borrowed (Payable)', currency.format(totalTaken), PdfColors.red700, fontBold),
          _buildKpiDivider(),
          _buildKpiColumn('Total Income', currency.format(totalIncome), PdfColors.blue700, fontBold),
          _buildKpiDivider(),
          _buildKpiColumn('Total Expenses', currency.format(totalExpense), PdfColors.amber800, fontBold),
          _buildKpiDivider(),
          _buildKpiColumn(
            'Net Position',
            currency.format(netBalance),
            isPositive ? PdfColors.teal800 : PdfColors.red800,
            fontBold,
            highlight: true,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildKpiColumn(
    String label,
    String value,
    PdfColor color,
    pw.Font fontBold, {
    bool highlight = false,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.blueGrey700),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: highlight ? 12 : 10.5,
            font: fontBold,
            color: color,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildKpiDivider() {
    return pw.Container(
      width: 1,
      height: 24,
      color: PdfColors.blueGrey200,
    );
  }

  static pw.Widget _buildCategoryBreakdownSection(
    List<CategoryBreakdown> categories,
    NumberFormat currency,
    pw.Font fontBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.blueGrey100, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SPENDING & TRADE CATEGORY BREAKDOWN',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 9,
              color: PdfColors.blueGrey800,
              letterSpacing: 0.6,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 12,
            runSpacing: 6,
            children: categories.map((c) {
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      c.categoryName,
                      style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.blueGrey900),
                    ),
                    pw.SizedBox(width: 4),
                    pw.Text(
                      currency.format(c.totalAmount),
                      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.indigo800),
                    ),
                    pw.SizedBox(width: 3),
                    pw.Text(
                      '(${c.percentage.toStringAsFixed(1)}%)',
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.blueGrey500),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTransactionsTable(
    List<TransactionItem> transactions,
    NumberFormat currency,
    pw.Font fontBold,
  ) {
    final headers = ['Date', 'Contact / Tag', 'Type', 'Mode', 'Status', 'Amount'];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.4),
        1: pw.FlexColumnWidth(2.5),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.1),
        4: pw.FlexColumnWidth(1.1),
        5: pw.FlexColumnWidth(1.6),
      },
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.indigo900),
          children: headers.map((h) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Text(
                h,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 8.5,
                  color: PdfColors.white,
                ),
                textAlign: h == 'Amount' ? pw.TextAlign.right : pw.TextAlign.left,
              ),
            );
          }).toList(),
        ),

        // Data Rows
        ...transactions.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isEven = index % 2 == 0;

          final isGiven = item.type == 'GIVEN';
          final isTaken = item.type == 'TAKEN';
          final isIncome = item.type == 'INCOME';

          final typeLabel = isGiven
              ? 'Lent'
              : isTaken
                  ? 'Borrowed'
                  : isIncome
                      ? 'Income'
                      : 'Expense';

          final amountColor = isGiven
              ? PdfColors.teal800
              : isTaken
                  ? PdfColors.red800
                  : isIncome
                      ? PdfColors.blue800
                      : PdfColors.amber900;

          String dateFormatted = '';
          if (item.transactionDate != null && item.transactionDate!.isNotEmpty) {
            try {
              dateFormatted = DateFormat('dd MMM yyyy').format(DateTime.parse(item.transactionDate!));
            } catch (_) {
              dateFormatted = item.transactionDate!.substring(0, 10);
            }
          }

          final contactOrTag = item.personName ?? item.categoryName ?? item.type;
          final notesPart = item.notes?.isNotEmpty == true ? ' (${item.notes})' : '';

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : PdfColors.grey50,
            ),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
                child: pw.Text(dateFormatted, style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey800)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
                child: pw.Text(
                  '$contactOrTag$notesPart',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey900),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
                child: pw.Text(
                  typeLabel,
                  style: pw.TextStyle(
                    fontSize: 8,
                    font: fontBold,
                    color: amountColor,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
                child: pw.Text(item.paymentMode, style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey700)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
                child: pw.Text(
                  item.isSettled ? 'Settled' : 'Pending',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    color: item.isSettled ? PdfColors.teal700 : PdfColors.amber800,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
                child: pw.Text(
                  currency.format(item.amount),
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    font: fontBold,
                    color: amountColor,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context context, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.blueGrey200, width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'ORG : msm.movin 2022 • Computer-Generated Certified Ledger Statement • Confidential',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.blueGrey500),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.blueGrey600),
          ),
        ],
      ),
    );
  }

  /// Generate CSV String for Google Sheets / Microsoft Excel
  static String generateCsvData({
    required List<TransactionItem> transactions,
  }) {
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('Transaction ID,Date,Type,Contact/Party,Category,Payment Mode,Amount,Is Settled,Due Date,Notes');

    for (final t in transactions) {
      final date = t.transactionDate ?? '';
      final type = t.type;
      final contact = (t.personName ?? '').replaceAll(',', ' ');
      final category = (t.categoryName ?? '').replaceAll(',', ' ');
      final mode = t.paymentMode;
      final amount = t.amount;
      final settled = t.isSettled ? 'YES' : 'NO';
      final dueDate = t.dueDate ?? '';
      final notes = (t.notes ?? '').replaceAll(',', ' ').replaceAll('\n', ' ');

      buffer.writeln('${t.id},$date,$type,$contact,$category,$mode,$amount,$settled,$dueDate,"$notes"');
    }

    return buffer.toString();
  }
}
