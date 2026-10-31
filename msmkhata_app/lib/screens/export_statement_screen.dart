import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/account.dart';
import '../models/stats.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/account_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/msm_shimmer_text.dart';

/// Interactive Export Statement & A4 PDF Print Screen
class ExportStatementScreen extends StatefulWidget {
  const ExportStatementScreen({super.key});

  @override
  State<ExportStatementScreen> createState() => _ExportStatementScreenState();
}

class _ExportStatementScreenState extends State<ExportStatementScreen> {
  bool _isLoading = true;
  DashboardStats? _stats;
  List<TransactionItem> _transactions = [];
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final activeAccount = AccountService.activeAccountNotifier.value;
      final s = await ApiService.getDashboardStats(accountId: activeAccount.id);
      final txs = await ApiService.getTransactions(accountId: activeAccount.id);
      if (mounted) {
        setState(() {
          _stats = s;
          _transactions = txs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load statement data: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _handleDownloadPythonPdf() async {
    final activeAccount = AccountService.activeAccountNotifier.value;
    setState(() => _isGeneratingPdf = true);
    try {
      final pdfBytes = await ApiService.fetchPdfReport(
        accountId: activeAccount.id,
        accountName: activeAccount.name,
      );
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'msmkhata_${activeAccount.name}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading Python PDF: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }



  Future<void> _handlePrintPdf() async {
    if (_stats == null) return;
    setState(() => _isGeneratingPdf = true);
    try {
      await PdfExportService.printOrSaveA4Statement(
        stats: _stats!,
        transactions: _transactions,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  void _handleViewCsv() {
    final csv = PdfExportService.generateCsvData(transactions: _transactions);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.table_chart_rounded, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 8),
            Text('CSV Ledger Sheet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 300,
          child: SingleChildScrollView(
            child: SelectableText(
              csv,
              style: const TextStyle(color: Color(0xFFC7D2FE), fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CSV content ready for Excel / Google Sheets'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Export & A4 Print Sheet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF818CF8)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.print_rounded, color: Color(0xFF818CF8), size: 24),
                                    ),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Financial Statement (A4)',
                                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        MsmShimmerText(
                                          text: 'ORG : msm.movin 2022',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                                  ),
                                  child: const Text(
                                    'A4 Ready',
                                    style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Generate a certified, clean A4 statement document containing executive financial summary, Mandi trade breakdown, and detailed transaction entries suitable for printing, archiving, or PDF export.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // A4 Sheet Preview Mock Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF312E81),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'MSMKHATA STATEMENT',
                                      style: TextStyle(color: Color(0xFF1E1B4B), fontWeight: FontWeight.w900, fontSize: 15),
                                    ),
                                  ],
                                ),
                                Text(
                                  DateFormat('dd MMM yyyy').format(DateTime.now()),
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                ),
                              ],
                            ),
                            const Divider(color: Color(0xFFE2E8F0), height: 24, thickness: 1),

                            // KPI Grid
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildPreviewStat('Total Lent', currency.format(_stats?.totalReceivable ?? 0), const Color(0xFF047857)),
                                  _buildPreviewStat('Total Borrowed', currency.format(_stats?.totalPayable ?? 0), const Color(0xFFB91C1C)),
                                  _buildPreviewStat('Total Income', currency.format(_stats?.totalIncome ?? 0), const Color(0xFF1D4ED8)),
                                  _buildPreviewStat('Net Position', currency.format(_stats?.netLenDenPosition ?? 0), const Color(0xFF4338CA)),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),
                            Text(
                              'Statement Data: ${_transactions.length} Transactions Recorded',
                              style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Standard Paper Size: ISO 216 A4 (210 × 297 mm) • Margins: 28pt • Font: Inter Vector Typography',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 1. Primary Button: Python Professional PDF with Charts
                      SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                            shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                          ),
                          onPressed: _isGeneratingPdf ? null : _handleDownloadPythonPdf,
                          icon: _isGeneratingPdf
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.analytics_rounded, size: 22),
                          label: Text(
                            _isGeneratingPdf ? 'Generating PDF with Charts...' : 'Download Full Audit PDF (With Charts)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                        ),
                      ),



                      // 3. Instant Local Print / Save
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF334155), width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _handlePrintPdf,
                              icon: const Icon(Icons.print_rounded, color: Color(0xFF818CF8), size: 18),
                              label: const Text(
                                'Local A4 Print',
                                style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF334155), width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _handleViewCsv,
                              icon: const Icon(Icons.code_rounded, color: Color(0xFF10B981), size: 18),
                              label: const Text(
                                'View Raw CSV',
                                style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPreviewStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
