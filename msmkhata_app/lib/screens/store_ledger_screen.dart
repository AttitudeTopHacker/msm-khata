import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/grocery_item.dart';
import '../services/grocery_pdf_service.dart';
import '../services/grocery_service.dart';
import '../widgets/sync_status_badge.dart';

class StoreLedgerScreen extends StatefulWidget {
  final GroceryStore store;

  const StoreLedgerScreen({super.key, required this.store});

  @override
  State<StoreLedgerScreen> createState() => _StoreLedgerScreenState();
}

class _StoreLedgerScreenState extends State<StoreLedgerScreen> {
  late GroceryStore _store;
  List<GroceryEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _store = widget.store;
    GroceryService.dataVersion.addListener(_onDataChanged);
    _loadEntries();
  }

  void _onDataChanged() {
    if (mounted) {
      final cached = GroceryService.cachedEntriesByStore[_store.id];
      if (cached != null) {
        double udhaar = 0.0;
        double chukaya = 0.0;
        for (final e in cached) {
          if (e.isUdhaar) udhaar += e.amount;
          if (e.isChukaya) chukaya += e.amount;
        }
        setState(() {
          _entries = List.from(cached);
          _store.totalUdhaar = udhaar;
          _store.totalChukaya = chukaya;
          _store.entriesCount = cached.length;
        });
      }
    }
  }

  @override
  void dispose() {
    GroceryService.dataVersion.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    try {
      final list = await GroceryService.fetchEntries(_store.id);
      double udhaar = 0.0;
      double chukaya = 0.0;
      for (final e in list) {
        if (e.isUdhaar) udhaar += e.amount;
        if (e.isChukaya) chukaya += e.amount;
      }
      if (mounted) {
        setState(() {
          _entries = list;
          _store.totalUdhaar = udhaar;
          _store.totalChukaya = chukaya;
          _store.entriesCount = list.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEntrySheet(String entryType) {
    final isUdhaar = entryType == 'UDHAAR';
    final amountCtrl = TextEditingController();
    final itemCtrl = TextEditingController();
    DateTime entryDate = DateTime.now(); // Date by default set to today
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;

          return Container(
            padding: EdgeInsets.fromLTRB(22, 20, 22, bottomInset + 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Color(0xFF334155), width: 1.2)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF475569),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isUdhaar ? const Color(0xFFF59E0B).withOpacity(0.2) : const Color(0xFF10B981).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isUdhaar ? Icons.shopping_basket_rounded : Icons.payments_rounded,
                          color: isUdhaar ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isUdhaar ? 'Record Credit Taken (Udhaar Saman)' : 'Record Payment Made (Chukaya)',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Store: ${_store.storeName}',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Amount / Price Input
                  const Text('Price / Amount (₹) *', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Color(0xFF818CF8)),
                      hintText: '0.00',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // "Kiya Cheez" / Items Description Input
                  Text(
                    isUdhaar ? 'Kya Saman Liya (Items Description) *' : 'Payment Remarks / Details *',
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: itemCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        isUdhaar ? Icons.fastfood_rounded : Icons.comment_rounded,
                        color: const Color(0xFF818CF8),
                        size: 20,
                      ),
                      hintText: isUdhaar ? 'e.g. 2 packet doodh, chini, sabzi' : 'e.g. Cash diya, PhonePe se chukaya',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Date (Default Today)
                  const Text('Date & Time (Set by default) *', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_available_rounded, color: Color(0xFF10B981), size: 18),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('EEE, dd MMM yyyy, hh:mm a').format(entryDate),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: const Text('Today', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Notice: One-Time Upload (No edit / update)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155), width: 0.8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_clock_rounded, color: Color(0xFFEAB308), size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'One-time record: This entry is immutable and cannot be updated or modified after submission.',
                            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isUdhaar ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                        foregroundColor: isUdhaar ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final amt = double.tryParse(amountCtrl.text.trim());
                              final desc = itemCtrl.text.trim();
                              if (amt == null || amt <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid price/amount.'), backgroundColor: Color(0xFFEF4444)),
                                );
                                return;
                              }
                              if (desc.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please describe the items or payment note.'), backgroundColor: Color(0xFFEF4444)),
                                );
                                return;
                              }

                              setSheetState(() => isSaving = true);
                              try {
                                await GroceryService.addEntry(
                                  storeId: _store.id,
                                  type: entryType,
                                  amount: amt,
                                  itemsDescription: desc,
                                  entryDate: entryDate,
                                );
                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  _loadEntries();
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text('Recorded: $desc (₹${amt.toStringAsFixed(0)})'),
                                      backgroundColor: const Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isSaving = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to save entry: $e'), backgroundColor: const Color(0xFFEF4444)),
                                  );
                                }
                              }
                            },
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              isUdhaar ? 'Save Credit Entry' : 'Save Payment Entry',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmAndDeleteEntry(GroceryEntry entry) async {
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
            Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 10),
            Text('Delete Store Entry?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'Are you certain you wish to delete this ${entry.isUdhaar ? "credit" : "payment"} entry for "${entry.itemsDescription}" (₹${entry.amount.toStringAsFixed(0)})? This action cannot be reversed.',
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
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await GroceryService.deleteEntry(entry.id, _store.id);
      _loadEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry removed successfully.'),
            backgroundColor: Color(0xFF10B981),
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
    final isSettled = _store.isSettled;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _store.storeName,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_store.category} Store Khata',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Print / Save PDF Statement',
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF10B981), size: 22),
            onPressed: () => GroceryPdfService.printStoreStatement(
              store: _store,
              entries: _entries,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: GroceryService.isSyncing,
            builder: (context, syncing, _) {
              return SyncStatusBadge(
                isSyncing: syncing,
                onSync: _loadEntries,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Summary Card
                  _buildStoreSummaryCard(currency, isSettled),
                  const SizedBox(height: 18),

                  // Quick Action Buttons: Udhaar vs Chukaya
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _showAddEntrySheet('UDHAAR'),
                          icon: const Icon(Icons.shopping_bag_rounded, size: 18),
                          label: const Text('+ Udhaar Saman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _showAddEntrySheet('CHUKAYA'),
                          icon: const Icon(Icons.payments_rounded, size: 18),
                          label: const Text('+ Paise Chukaye', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Print / Save PDF Statement Button
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.5), width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => GroceryPdfService.printStoreStatement(
                        store: _store,
                        entries: _entries,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
                      label: const Text('Print / Save PDF Statement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Entries History
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Store Ledger History',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_entries.length} records (Immutable)',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_entries.isEmpty)
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
                          Icon(Icons.receipt_long_rounded, color: Colors.grey.shade600, size: 44),
                          const SizedBox(height: 10),
                          const Text(
                            'No entries recorded for this store yet.',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap "+ Udhaar Saman" to record credit items or "+ Paise Chukaye" for payments.',
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
                      itemCount: _entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final e = _entries[index];
                        return _buildEntryCard(e, currency);
                      },
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildStoreSummaryCard(NumberFormat currency, bool isSettled) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSettled ? const Color(0xFF10B981).withOpacity(0.5) : const Color(0xFFF59E0B).withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pending Store Balance', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(_store.pendingBalance),
                    style: TextStyle(
                      color: isSettled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSettled ? const Color(0xFF10B981).withOpacity(0.18) : const Color(0xFFF59E0B).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSettled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    width: 0.9,
                  ),
                ),
                child: Text(
                  isSettled ? 'Hisaab Chukta ✅' : '₹${currency.format(_store.pendingBalance)} Baaki ⏳',
                  style: TextStyle(
                    color: isSettled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
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
                      currency.format(_store.totalUdhaar),
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
                      currency.format(_store.totalChukaya),
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

  Widget _buildEntryCard(GroceryEntry entry, NumberFormat currency) {
    final isUdhaar = entry.isUdhaar;
    final color = isUdhaar ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 0.9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isUdhaar ? Icons.shopping_cart_outlined : Icons.check_circle_outline_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isUdhaar ? 'Udhaar Saman' : 'Paise Chukaye',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      currency.format(entry.amount),
                      style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.itemsDescription,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(entry.entryDate),
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Delete button (No edit option is rendered - strict immutability)
          IconButton(
            tooltip: 'Delete Entry',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 16),
            ),
            onPressed: () => _confirmAndDeleteEntry(entry),
          ),
        ],
      ),
    );
  }
}

