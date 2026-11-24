import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/person.dart';
import '../models/transaction.dart';
import '../services/sync_service.dart';
import '../widgets/adaptive_refresh_indicator.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/sync_status_badge.dart';
import '../widgets/transaction_detail_sheet.dart';
import 'add_transaction_screen.dart';

class PersonsScreen extends StatefulWidget {
  const PersonsScreen({super.key});

  @override
  State<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonsScreenState extends State<PersonsScreen> {
  String? _statusFilter;
  late Future<List<Person>> _personsFuture;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    SyncService.dataVersion.addListener(_onDataVersionChanged);
    _loadPersons();
  }

  @override
  void dispose() {
    SyncService.dataVersion.removeListener(_onDataVersionChanged);
    super.dispose();
  }

  void _onDataVersionChanged() {
    if (mounted) {
      final cached = SyncService.cachedPersons;
      final filtered = _statusFilter == null
          ? cached
          : cached.where((p) => p.status == _statusFilter).toList();
      setState(() {
        _personsFuture = Future.value(filtered);
      });
    }
  }

  Future<void> _loadPersons() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    final f = SyncService.syncPersons(status: _statusFilter);
    setState(() {
      _personsFuture = f;
    });
    try {
      await f;
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _openAddTransaction(Person? person, {String initialType = 'GIVEN', double? initialAmount}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionScreen(
        initialType: initialType,
        initialPerson: person,
        initialAmount: initialAmount,
      ),
    );
    if (result == true) {
      _loadPersons();
    }
  }

  void _showPersonDetailSheet(BuildContext context, Person person) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Live retrieve latest person state from cachedPersons
            final currentPerson = SyncService.cachedPersons.firstWhere(
              (p) => p.id == person.id,
              orElse: () => person,
            );

            final isReceive = currentPerson.netBalance > 0;
            final isPay = currentPerson.netBalance < 0;
            final badgeColor = isReceive
                ? const Color(0xFF10B981)
                : isPay
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF64748B);

            // Filter transactions involving this person
            final personTxList = SyncService.cachedTransactions.where((t) {
              final matchesId = t.personId != null && t.personId == currentPerson.id;
              final matchesName = t.personName != null &&
                  t.personName!.trim().toLowerCase() == currentPerson.name.trim().toLowerCase();
              return matchesId || matchesName;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: Color(0xFF334155), width: 1.2)),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF475569),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  // Header Info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: badgeColor.withOpacity(0.15),
                          child: Text(
                            currentPerson.name.isNotEmpty ? currentPerson.name[0].toUpperCase() : '?',
                            style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 22),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentPerson.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              if (currentPerson.phone != null && currentPerson.phone!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  currentPerson.phone!,
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Net Balance Tag
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currency.format(currentPerson.netBalance.abs()),
                              style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isReceive ? 'To Receive' : isPay ? 'To Pay' : 'Settled',
                                style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Summary Cards: Lent vs Borrowed
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.call_made_rounded, color: Color(0xFF38BDF8), size: 14),
                                    SizedBox(width: 5),
                                    Text('Total Lent (Diya)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currency.format(currentPerson.totalGiven),
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.call_received_rounded, color: Color(0xFFF59E0B), size: 14),
                                    SizedBox(width: 5),
                                    Text('Total Borrowed (Liya)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currency.format(currentPerson.totalTaken),
                                  style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Quick Action Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0369A1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.call_made_rounded, size: 16),
                            label: const Text('+ Lend Money', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _openAddTransaction(currentPerson, initialType: 'GIVEN');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB45309),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.call_received_rounded, size: 16),
                            label: const Text('+ Borrow Money', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _openAddTransaction(currentPerson, initialType: 'TAKEN');
                            },
                          ),
                        ),
                        if (currentPerson.netBalance.abs() > 0) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isReceive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                              label: Text(
                                isReceive ? 'Chukta' : 'Chukao',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                // If to receive: record receipt (TAKEN)
                                // If to pay: record repayment (GIVEN)
                                _openAddTransaction(
                                  currentPerson,
                                  initialType: isReceive ? 'TAKEN' : 'GIVEN',
                                  initialAmount: currentPerson.netBalance.abs(),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFF334155), height: 1),

                  // Ledger Timeline Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ledger History (${personTxList.length})',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Text(
                          'Tap entry to inspect / edit',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  // Ledger Timeline Entries
                  Expanded(
                    child: personTxList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.history_rounded, color: Color(0xFF475569), size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  'No transactions recorded with ${currentPerson.name} yet.',
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            itemCount: personTxList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final tx = personTxList[idx];
                              final isLent = tx.type.toUpperCase() == 'GIVEN';
                              final txColor = isLent ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B);

                              return Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) => TransactionDetailSheet(item: tx),
                                      ).then((_) {
                                        setSheetState(() {});
                                        _loadPersons();
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: txColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              isLent ? Icons.call_made_rounded : Icons.call_received_rounded,
                                              color: txColor,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      isLent ? 'Lent (Money Given)' : 'Borrowed (Money Taken)',
                                                      style: TextStyle(
                                                        color: txColor,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    if (tx.isSettled) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF10B981).withOpacity(0.15),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: const Text(
                                                          'Settled',
                                                          style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.bold),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  tx.notes != null && tx.notes!.isNotEmpty
                                                      ? tx.notes!
                                                      : (tx.transactionDate ?? ''),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                currency.format(tx.amount),
                                                style: TextStyle(
                                                  color: txColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                tx.paymentMode,
                                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
        title: const Text('Contacts Ledger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          SyncStatusBadge(
            isSyncing: _isSyncing,
            onSync: _loadPersons,
          ),
          const SizedBox(width: 14),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: const Text(
          'Add Entry',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        onPressed: () => _openAddTransaction(null, initialType: 'GIVEN'),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip(null, 'All Contacts'),
                _filterChip('TO_RECEIVE', 'To Receive', const Color(0xFF10B981)),
                _filterChip('TO_PAY', 'To Pay', const Color(0xFFEF4444)),
                _filterChip('SETTLED', 'Settled', const Color(0xFF64748B)),
              ],
            ),
          ),

          Expanded(
            child: AdaptiveRefreshIndicator(
              color: const Color(0xFF818CF8),
              backgroundColor: const Color(0xFF1E293B),
              onRefresh: _loadPersons,
              child: FutureBuilder<List<Person>>(
                future: _personsFuture,
                initialData: _statusFilter == null ? SyncService.cachedPersons : null,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const ShimmerContactList(count: 6);
                  }
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return ListView(
                      physics: AdaptiveRefreshIndicator.scrollPhysics(),
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Text('No contacts found. Tap "+ Add Entry" to create one!', style: TextStyle(color: Color(0xFF94A3B8))),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: AdaptiveRefreshIndicator.scrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final person = list[index];
                      final isReceive = person.netBalance > 0;
                      final isPay = person.netBalance < 0;
                      final badgeColor = isReceive
                          ? const Color(0xFF10B981)
                          : isPay
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF64748B);

                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: badgeColor.withOpacity(0.2), width: 1),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _showPersonDetailSheet(context, person),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: badgeColor.withOpacity(0.15),
                                    child: Text(
                                      person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                                      style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          person.name,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        if (person.phone != null && person.phone!.isNotEmpty)
                                          Text(
                                            person.phone!,
                                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                          ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text('Lent: ${currency.format(person.totalGiven)}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                            const SizedBox(width: 10),
                                            Text('Borrowed: ${currency.format(person.totalTaken)}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        currency.format(person.netBalance.abs()),
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isReceive ? 'To Receive' : isPay ? 'To Pay' : 'Settled',
                                          style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF475569), size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String? status, String label, [Color color = const Color(0xFF818CF8)]) {
    final isSelected = _statusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: color.withOpacity(0.25),
        backgroundColor: const Color(0xFF1E293B),
        labelStyle: TextStyle(
          color: isSelected ? color : const Color(0xFF94A3B8),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(color: isSelected ? color : Colors.transparent),
        onSelected: (_) {
          setState(() => _statusFilter = status);
          _loadPersons();
        },
      ),
    );
  }
}
