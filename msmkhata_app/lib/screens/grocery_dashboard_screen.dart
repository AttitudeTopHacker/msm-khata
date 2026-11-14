import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/grocery_item.dart';
import '../services/grocery_pdf_service.dart';
import '../services/grocery_service.dart';
import '../widgets/sync_status_badge.dart';
import '../widgets/unified_progress_modal.dart';
import 'store_ledger_screen.dart';

class GroceryDashboardScreen extends StatefulWidget {
  const GroceryDashboardScreen({super.key});

  @override
  State<GroceryDashboardScreen> createState() => _GroceryDashboardScreenState();
}

class _GroceryDashboardScreenState extends State<GroceryDashboardScreen> {
  List<GroceryStore> _stores = [];
  bool _isLoading = true;
  String _filter = 'ALL'; // 'ALL', 'PENDING', 'SETTLED'

  @override
  void initState() {
    super.initState();
    GroceryService.dataVersion.addListener(_onDataChanged);
    _loadStores();
  }

  void _onDataChanged() {
    if (mounted) {
      setState(() {
        _stores = List.from(GroceryService.cachedStores);
      });
    }
  }

  @override
  void dispose() {
    GroceryService.dataVersion.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> _loadStores() async {
    setState(() => _isLoading = true);
    try {
      final list = await GroceryService.fetchStores();
      if (mounted) {
        setState(() {
          _stores = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateStoreDialog() {
    final nameCtrl = TextEditingController();
    String category = 'Grocery';
    final notesCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Color(0xFF4F46E5), width: 1.2),
            ),
            title: const Row(
              children: [
                Icon(Icons.storefront_rounded, color: Color(0xFF818CF8), size: 24),
                SizedBox(width: 10),
                Text(
                  'Add New Dukan / Store',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dukan / Store Name *', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Sharma Kirana Store, Gupta Medicos',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Store Category', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Grocery', 'Vegetables', 'Medical', 'General'].map((cat) {
                      final isSelected = category == cat;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: const Color(0xFF4F46E5),
                        backgroundColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        side: BorderSide(color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF334155)),
                        onSelected: (_) => setDialogState(() => category = cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  const Text('Optional Notes / Landmark', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Near main chowk, contact details',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter store name.'), backgroundColor: Color(0xFFEF4444)),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        try {
                          final store = await GroceryService.createStore(
                            name: name,
                            category: category,
                            notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                          );
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            _loadStores();
                            // Navigate directly into newly created store
                            Navigator.push(
                              this.context,
                              MaterialPageRoute(builder: (_) => StoreLedgerScreen(store: store)),
                            ).then((_) => _loadStores());
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e'), backgroundColor: const Color(0xFFEF4444)),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Create & Open', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmAndDeleteStore(GroceryStore store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delete Store Account?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you certain you wish to delete "${store.storeName}" and all associated credit/payment records? This action cannot be reversed.',
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await GroceryService.deleteStore(store.id);
      _loadStores();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Store "${store.storeName}" removed.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final stats = GroceryService.computeStats(_stores);

    final filteredStores = _stores.where((s) {
      if (_filter == 'PENDING') return s.pendingBalance > 0;
      if (_filter == 'SETTLED') return s.isSettled;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grocery & Dukan Khata',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              'Independent Store Ledger • Grocery, Sabzi & Medicine',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (_stores.isNotEmpty)
            IconButton(
              tooltip: 'Print / Export All Stores PDF',
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF10B981), size: 22),
              onPressed: () {
                UnifiedProgressModal.show(
                  context: context,
                  title: 'Exporting PDF Statement',
                  subtitle: 'All Stores Summary',
                  icon: Icons.storefront_rounded,
                  iconColor: const Color(0xFF10B981),
                  task: (progress) async {
                    progress.update(status: 'Analyzing store accounts...');
                    final bytes = await GroceryPdfService.generateAllStoresSummaryPdfBytes(
                      stores: _stores,
                      stats: stats,
                    );
                    progress.update(status: 'Launching Print & Save Preview...');
                    await Printing.layoutPdf(
                      onLayout: (format) async => bytes,
                      name: 'DukanKhata_AllStores_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
                    );
                  },
                );
              },
            ),
          ValueListenableBuilder<bool>(
            valueListenable: GroceryService.isSyncing,
            builder: (context, syncing, _) {
              return SyncStatusBadge(
                isSyncing: syncing,
                onSync: _loadStores,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : RefreshIndicator(
              color: const Color(0xFF4F46E5),
              backgroundColor: const Color(0xFF1E293B),
              onRefresh: _loadStores,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Summary Cards
                    _buildOverviewMetrics(stats, currency),
                    const SizedBox(height: 20),

                    // Add Dukan Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _showCreateStoreDialog,
                        icon: const Icon(Icons.add_business_rounded, size: 20),
                        label: const Text('Add New Dukan / Store Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                    if (_stores.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.5), width: 1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            UnifiedProgressModal.show(
                              context: context,
                              title: 'Exporting PDF Statement',
                              subtitle: 'All Stores Summary',
                              icon: Icons.storefront_rounded,
                              iconColor: const Color(0xFF10B981),
                              task: (progress) async {
                                progress.update(status: 'Analyzing store accounts...');
                                final bytes = await GroceryPdfService.generateAllStoresSummaryPdfBytes(
                                  stores: _stores,
                                  stats: stats,
                                );
                                progress.update(status: 'Launching Print & Save Preview...');
                                await Printing.layoutPdf(
                                  onLayout: (format) async => bytes,
                                  name: 'DukanKhata_AllStores_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
                                );
                              },
                            );
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
                          label: const Text('Print / Save All Stores Summary PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),

                    // Filter Chips: All vs Baaki vs Chukta
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'My Dukan Accounts',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            _buildFilterChip('All', 'ALL', _stores.length),
                            const SizedBox(width: 6),
                            _buildFilterChip('Baaki', 'PENDING', stats.pendingStoresCount),
                            const SizedBox(width: 6),
                            _buildFilterChip('Chukta', 'SETTLED', stats.settledStoresCount),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Store Cards List
                    if (filteredStores.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.store_rounded, color: Color(0xFF64748B), size: 48),
                            const SizedBox(height: 12),
                            Text(
                              _stores.isEmpty
                                  ? 'No Dukan accounts created yet.'
                                  : 'No stores match the selected filter.',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Tap "Add New Dukan" to start tracking grocery, vegetables, or medical dues.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredStores.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final store = filteredStores[index];
                          return _buildStoreCard(store, currency);
                        },
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF334155)),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewMetrics(GroceryOverviewStats stats, NumberFormat currency) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.4), width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Net Pending to Stores', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(stats.netPending),
                    style: TextStyle(
                      color: stats.netPending > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF4F46E5), width: 0.8),
                ),
                child: Text(
                  '${stats.totalStores} Dukaane',
                  style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Udhaar Liya', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                    const SizedBox(height: 3),
                    Text(
                      currency.format(stats.totalUdhaar),
                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Chukaya (Diya)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                    const SizedBox(height: 3),
                    Text(
                      currency.format(stats.totalChukaya),
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreCard(GroceryStore store, NumberFormat currency) {
    final isSettled = store.isSettled;
    IconData catIcon = Icons.storefront_rounded;
    Color catColor = const Color(0xFF38BDF8);

    if (store.category == 'Vegetables') {
      catIcon = Icons.eco_rounded;
      catColor = const Color(0xFF10B981);
    } else if (store.category == 'Medical') {
      catIcon = Icons.medical_services_rounded;
      catColor = const Color(0xFFEC4899);
    } else if (store.category == 'Grocery') {
      catIcon = Icons.local_grocery_store_rounded;
      catColor = const Color(0xFFF59E0B);
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StoreLedgerScreen(store: store)),
        ).then((_) => _loadStores());
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSettled ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFF334155),
            width: 1.1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(catIcon, color: catColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.storeName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${store.category} • ${store.entriesCount} entries',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSettled ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSettled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    isSettled ? 'Hisaab Chukta ✅' : '₹${currency.format(store.pendingBalance)} Baaki',
                    style: TextStyle(
                      color: isSettled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Udhaar: ${currency.format(store.totalUdhaar)}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
                    const SizedBox(width: 12),
                    Text('Chukaya: ${currency.format(store.totalChukaya)}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Delete Store Account',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 16),
                      ),
                      onPressed: () => _confirmAndDeleteStore(store),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 13),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

