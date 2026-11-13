import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/routine_entry.dart';
import 'auth_service.dart';

/// Professional A4 PDF Generator and Print Service for Daily Routine & Work Diary
class RoutinePdfService {
  /// Generate and open standard A4 PDF Print / Save dialog for Daily Routine entries
  static Future<void> printRoutineStatement({
    required List<RoutineEntry> entries,
    String filterLabel = 'All Dates',
    String categoryLabel = 'All Categories',
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
      font = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
      fontSemiBold = pw.Font.helveticaBold();
    }

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);
    final userName = AuthService.displayName.isNotEmpty ? AuthService.displayName : 'Authorized Ledger User';
    final userEmail = AuthService.email.isNotEmpty ? AuthService.email : 'Local Encrypted Mode';
    final generatedOn = DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now());

    // Calculate totals
    final totalCount = entries.length;
    final totalHours = entries.fold<double>(0.0, (sum, e) => sum + (e.hoursSpent ?? 0.0));
    final totalExpense = entries.fold<double>(0.0, (sum, e) => sum + (e.expense ?? 0.0));
    final completedCount = entries.where((e) => e.isCompleted).length;
    final pendingCount = totalCount - completedCount;

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
          filterLabel: filterLabel,
          categoryLabel: categoryLabel,
          fontBold: fontBold,
          fontSemiBold: fontSemiBold,
        ),
        footer: (context) => _buildPdfFooter(context, font),
        build: (context) => [
          pw.SizedBox(height: 12),

          // 1. Executive Summary KPI Box
          _buildSummaryKpiBox(
            totalCount: totalCount,
            totalHours: totalHours,
            totalExpense: totalExpense,
            completedCount: completedCount,
            pendingCount: pendingCount,
            currency: currency,
            fontBold: fontBold,
            fontSemiBold: fontSemiBold,
          ),
          pw.SizedBox(height: 16),

          // 2. Entries Section Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'WORK LOG ENTRIES (ROZANA KAAM RECORD)',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                  letterSpacing: 0.5,
                ),
              ),
              pw.Text(
                'Total: $totalCount items',
                style: pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.Divider(color: PdfColors.grey300, thickness: 0.8),
          pw.SizedBox(height: 6),

          // 3. Entries Table
          if (entries.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 24),
              alignment: pw.Alignment.center,
              child: pw.Text(
                'Is filter ke liye koi kaam / routine entry darj nahi hai.',
                style: pw.TextStyle(color: PdfColors.grey600, fontSize: 11),
              ),
            )
          else
            _buildEntriesTable(
              entries: entries,
              currency: currency,
              fontBold: fontBold,
              fontSemiBold: fontSemiBold,
            ),
        ],
      ),
    );

    final cleanDate = DateFormat('yyyyMMdd').format(DateTime.now());
    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'MsmKhata_DailyRoutine_${cleanDate}.pdf',
    );
  }

  /// Official Header with MsmKhata Branding & Filters
  static pw.Widget _buildPdfHeader({
    required String userName,
    required String userEmail,
    required String generatedOn,
    required String filterLabel,
    required String categoryLabel,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey200, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left: Branding
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 22,
                    height: 22,
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF0F172A),
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'M',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'MsmKhata',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'DAILY ROUTINE & WORK DIARY STATEMENT',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF4F46E5),
                  letterSpacing: 0.8,
                ),
              ),
              pw.Text(
                'ORG : msm.movin 2022 • Cloud Ledger System',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
              ),
            ],
          ),

          // Right: Meta Information & Filter Badges
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                userName,
                style: pw.TextStyle(font: fontBold, fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                userEmail,
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Date: $generatedOn',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF1F5F9),
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  'Filter: $filterLabel  |  Category: $categoryLabel',
                  style: pw.TextStyle(
                    font: fontSemiBold,
                    fontSize: 7.5,
                    color: const PdfColor.fromInt(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// KPI Summary Box
  static pw.Widget _buildSummaryKpiBox({
    required int totalCount,
    required double totalHours,
    required double totalExpense,
    required int completedCount,
    required int pendingCount,
    required NumberFormat currency,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildKpiCell('TOTAL ENTRIES', '$totalCount Kaam', const PdfColor.fromInt(0xFF4F46E5), fontBold),
          _buildKpiDivider(),
          _buildKpiCell('HOURS LOGGED', '${totalHours.toStringAsFixed(1)} hrs', const PdfColor.fromInt(0xFF0284C7), fontBold),
          _buildKpiDivider(),
          _buildKpiCell('TOTAL EXPENSE', currency.format(totalExpense), const PdfColor.fromInt(0xFFD97706), fontBold),
          _buildKpiDivider(),
          _buildKpiCell('COMPLETED / PENDING', '$completedCount done  •  $pendingCount pend', const PdfColor.fromInt(0xFF16A34A), fontBold),
        ],
      ),
    );
  }

  static pw.Widget _buildKpiCell(String label, String value, PdfColor valueColor, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600, letterSpacing: 0.3),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildKpiDivider() {
    return pw.Container(
      width: 1,
      height: 22,
      color: const PdfColor.fromInt(0xFFCBD5E1),
    );
  }

  /// Table Listing Routine Entries
  static pw.Widget _buildEntriesTable({
    required List<RoutineEntry> entries,
    required NumberFormat currency,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.6),
      columnWidths: const {
        0: pw.FixedColumnWidth(26), // Index
        1: pw.FixedColumnWidth(75), // Date & Time
        2: pw.FlexColumnWidth(3),   // Kaam Title & Remarks
        3: pw.FlexColumnWidth(1.8), // Category
        4: pw.FixedColumnWidth(55), // Hours
        5: pw.FixedColumnWidth(65), // Expense
        6: pw.FixedColumnWidth(60), // Status
      },
      children: [
        // Table Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F172A)),
          children: [
            _buildTableHeaderCell('#', fontBold),
            _buildTableHeaderCell('DATE & TIME', fontBold),
            _buildTableHeaderCell('WORK TITLE & REMARKS', fontBold),
            _buildTableHeaderCell('CATEGORY', fontBold),
            _buildTableHeaderCell('HOURS', fontBold, align: pw.TextAlign.right),
            _buildTableHeaderCell('EXPENSE', fontBold, align: pw.TextAlign.right),
            _buildTableHeaderCell('STATUS', fontBold, align: pw.TextAlign.center),
          ],
        ),

        // Table Rows
        ...entries.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final item = entry.value;
          final isEven = idx % 2 == 0;
          final rowBg = isEven ? const PdfColor.fromInt(0xFFF8FAFC) : PdfColors.white;

          final dateStr = DateFormat('dd MMM yyyy').format(item.date);
          final timeStr = item.time != null && item.time!.isNotEmpty ? item.time! : '';

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: rowBg),
            children: [
              // Index
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                alignment: pw.Alignment.center,
                child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ),

              // Date & Time
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(dateStr, style: pw.TextStyle(font: fontSemiBold, fontSize: 8)),
                    if (timeStr.isNotEmpty)
                      pw.Text(timeStr, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                  ],
                ),
              ),

              // Title & Remarks
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item.title,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 8.5,
                        color: const PdfColor.fromInt(0xFF0F172A),
                      ),
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        item.notes!,
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                      ),
                    ],
                  ],
                ),
              ),

              // Category
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                child: pw.Text(
                  item.categoryName,
                  style: pw.TextStyle(
                    font: fontSemiBold,
                    fontSize: 8,
                    color: const PdfColor.fromInt(0xFF4F46E5),
                  ),
                ),
              ),

              // Hours
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  item.hoursSpent != null && item.hoursSpent! > 0 ? '${item.hoursSpent} hrs' : '—',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                ),
              ),

              // Expense
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  item.expense != null && item.expense! > 0 ? currency.format(item.expense) : '—',
                  style: pw.TextStyle(
                    font: item.expense != null && item.expense! > 0 ? fontBold : null,
                    fontSize: 8,
                    color: item.expense != null && item.expense! > 0 ? const PdfColor.fromInt(0xFFB45309) : PdfColors.grey600,
                  ),
                ),
              ),

              // Status
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                alignment: pw.Alignment.center,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: item.isCompleted ? const PdfColor.fromInt(0xFFDCFCE7) : const PdfColor.fromInt(0xFFFEE2E2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Text(
                    item.isCompleted ? 'Done' : 'Pending',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: item.isCompleted ? const PdfColor.fromInt(0xFF15803D) : const PdfColor.fromInt(0xFFB91C1C),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(String text, pw.Font fontBold, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      alignment: align == pw.TextAlign.right
          ? pw.Alignment.centerRight
          : (align == pw.TextAlign.center ? pw.Alignment.center : pw.Alignment.centerLeft),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: fontBold,
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  /// Document Footer
  static pw.Widget _buildPdfFooter(pw.Context context, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey100, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated via MsmKhata Daily Routine • ORG : msm.movin 2022',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }
}

