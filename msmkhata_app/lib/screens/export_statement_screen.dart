import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/account.dart';
import '../models/stats.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/account_service.dart';
import '../services/sync_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/msm_shimmer_text.dart';
import '../widgets/unified_progress_modal.dart';

/// Interactive Export Statement & A4 PDF Print Screen
class ExportStatementScreen extends StatefulWidget {
  final AccountBook? account;

  const ExportStatementScreen({super.key, this.account});

  @override
  State<ExportStatementScreen> createState() => _ExportStatementScreenState();
}

class _ExportStatementScreenState extends State<ExportStatementScreen> {
  bool _isLoading = true;
  DashboardStats? _stats;
  List<TransactionItem> _transactions = [];
  String? _activeAction; // 'full_pdf', 'full_print', 'fast_pdf', 'fast_print'

  AccountBook get _effectiveAccount => widget.account ?? AccountService.activeAccountNotifier.value;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final activeAccount = _effectiveAccount;

    DashboardStats? s = SyncService.cachedStats;
    List<TransactionItem> txs = SyncService.cachedTransactions
        .where((t) => t.accountId == activeAccount.id)
        .toList();

    try {
      final freshStats = await ApiService.getDashboardStats(accountId: activeAccount.id);
      final freshTxs = await ApiService.getTransactions(accountId: activeAccount.id);
      s = freshStats;
      txs = freshTxs;
    } catch (_) {
      s ??= DashboardStats(
        netAccountBalance: 0,
        totalMoneyIn: 0,
        totalMoneyOut: 0,
        totalReceivable: 0,
        totalPayable: 0,
        netLenDenPosition: 0,
        totalIncome: 0,
        totalExpense: 0,
        netSavings: 0,
        peopleToReceiveCount: 0,
        peopleToPayCount: 0,
        totalTransactionsCount: txs.length,
        categoryBreakdown: const [],
        topDebtors: const [],
        topCreditors: const [],
        monthlyTrends: const [],
      );
    }

    if (mounted) {
      setState(() {
        _stats = s;
        _transactions = txs;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDownloadPythonPdf({required String mode}) async {
    final activeAccount = _effectiveAccount;
    final modeLabel = mode == 'full' ? 'Full Analytics Review Report' : 'Fast Summary Statement';

    await UnifiedProgressModal.show(
      context: context,
      title: 'Exporting PDF Statement',
      subtitle: activeAccount.name,
      icon: Icons.picture_as_pdf_rounded,
      iconColor: const Color(0xFF6366F1),
      task: (progress) async {
        progress.update(status: 'Requesting $modeLabel from cloud engine...');
        Uint8List? pdfBytes;
        try {
          pdfBytes = await ApiService.fetchPdfReport(
            accountId: activeAccount.id,
            accountName: activeAccount.name,
            mode: mode,
          );
        } catch (_) {
          progress.update(status: 'Compiling local high-resolution statement...');
          if (_stats != null) {
            pdfBytes = await PdfExportService.generateA4PdfBytes(
              stats: _stats!,
              transactions: _transactions,
              isFastMode: mode == 'fast',
            );
          } else {
            rethrow;
          }
        }

        progress.update(status: 'Launching Print & Save Preview...');
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes!,
          name: 'msmkhata_${mode}_${activeAccount.name}.pdf',
        );
      },
    );
  }

  Future<void> _handlePrintPdf({required bool isFastMode}) async {
    if (_stats == null) return;
    final activeAccount = _effectiveAccount;
    final modeLabel = isFastMode ? 'Fast A4 Statement' : 'Full A4 Audit Report';

    await UnifiedProgressModal.show(
      context: context,
      title: 'Exporting PDF Statement',
      subtitle: activeAccount.name,
      icon: Icons.picture_as_pdf_rounded,
      iconColor: const Color(0xFF10B981),
      task: (progress) async {
        progress.update(status: 'Compiling ${activeAccount.name} transactions...');
        progress.update(status: 'Formatting $modeLabel layout...');
        final bytes = await PdfExportService.generateA4PdfBytes(
          stats: _stats!,
          transactions: _transactions,
          isFastMode: isFastMode,
        );

        progress.update(status: 'Launching Print & Save Preview...');
        final modePrefix = isFastMode ? 'Fast_Statement' : 'Full_Audit_Report';
        await Printing.layoutPdf(
          onLayout: (format) async => bytes,
          name: 'MsmKhata_${modePrefix}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
        );
      },
    );
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
        title: Text(
          'Export Statement • ${_effectiveAccount.name}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
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
                                      children: [
                                        Text(
                                          'Financial Statement • ${_effectiveAccount.name}',
                                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        const MsmShimmerText(
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
                                    Text(
                                      'MSMKHATA STATEMENT (${_effectiveAccount.name.toUpperCase()})',
                                      style: const TextStyle(color: Color(0xFF1E1B4B), fontWeight: FontWeight.w900, fontSize: 13),
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

                      // ==========================================
                      // 1. FULL REVIEW REPORT CARD (Comprehensive with Charts & Year-Wise Breakdown)
                      // ==========================================
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF4F46E5), width: 1.2),
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
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.analytics_rounded, color: Color(0xFF818CF8), size: 22),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Full Review Report',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(
                                          'Complete Financial & Analytics Audit',
                                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF818CF8), width: 0.8),
                                  ),
                                  child: const Text('AUDIT DOSSIER', style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Includes executive KPI dashboard, Har Saal Ka Hisaab (Year-wise benefit/loss audit), visual analytics graphs (Cashflow, Monthly trends, Category donut), Len-Den party balances, and complete itemized passbook ledger.',
                              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, height: 1.38),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4F46E5),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    onPressed: _activeAction != null ? null : () => _handleDownloadPythonPdf(mode: 'full'),
                                    icon: _activeAction == 'full_pdf'
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.picture_as_pdf_rounded, size: 20),
                                    label: Text(
                                      _activeAction == 'full_pdf' ? 'Generating Audit...' : 'Full Review PDF (With Charts)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF475569)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    onPressed: _activeAction != null ? null : () => _handlePrintPdf(isFastMode: false),
                                    icon: _activeAction == 'full_print'
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF818CF8)),
                                          )
                                        : const Icon(Icons.print_rounded, size: 18, color: Color(0xFF818CF8)),
                                    label: Text(
                                      _activeAction == 'full_print' ? 'Preparing...' : 'Full Print',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ==========================================
                      // 2. FAST REPORT CARD (Quick Single/Double Page Statement)
                      // ==========================================
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6), width: 1.2),
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
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 22),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Fast Report',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(
                                          'Quick 1-2 Page Statement',
                                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                                  ),
                                  child: const Text('INSTANT SHARE', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Instant, lightweight statement containing key performance indicators, Year snapshot, and recent 30 transactions. Perfect for rapid printing, WhatsApp sharing, or daily passbook receipts.',
                              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, height: 1.38),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF047857),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    onPressed: _activeAction != null ? null : () => _handleDownloadPythonPdf(mode: 'fast'),
                                    icon: _activeAction == 'fast_pdf'
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.flash_on_rounded, size: 20),
                                    label: Text(
                                      _activeAction == 'fast_pdf' ? 'Generating Fast...' : 'Fast Report PDF',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF475569)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    onPressed: _activeAction != null ? null : () => _handlePrintPdf(isFastMode: true),
                                    icon: _activeAction == 'fast_print'
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                                          )
                                        : const Icon(Icons.print_rounded, size: 18, color: Color(0xFF10B981)),
                                    label: Text(
                                      _activeAction == 'fast_print' ? 'Preparing...' : 'Quick Print',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 3. Raw CSV Export
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF334155), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _handleViewCsv,
                        icon: const Icon(Icons.code_rounded, color: Color(0xFF10B981), size: 18),
                        label: const Text(
                          'View Raw CSV (Excel / Google Sheets)',
                          style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
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
