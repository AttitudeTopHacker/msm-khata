import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/sync_status_badge.dart';
import '../widgets/transaction_detail_sheet.dart';
import '../services/connectivity_service.dart';
import 'export_statement_screen.dart';

class HistoryScreen extends StatefulWidget {
  final String? initialTypeFilter;

  const HistoryScreen({super.key, this.initialTypeFilter});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<TransactionItem>> _transactionsFuture;
  List<TransactionItem> _allTransactions = [];
  List<TransactionItem> _filteredTransactions = [];
  bool _isSyncing = false;

  String _searchQuery = '';
  String _selectedType = 'ALL'; // ALL, GIVEN, TAKEN, EXPENSE, INCOME
  String _selectedTime = 'ALL'; // ALL, THIS_MONTH, THIS_YEAR
  String _selectedStatus = 'ALL'; // ALL, PENDING, SETTLED

  @override
  void initState() {
    super.initState();
    if (widget.initialTypeFilter != null) {
      _selectedType = widget.initialTypeFilter!;
    }
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    ConnectivityService.checkNow();
    final f = ApiService.getTransactions();
    setState(() {
      _transactionsFuture = f.then((list) {
        _allTransactions = list;
        _applyFilters();
        return list;
      });
    });
    try {
      await f;
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _applyFilters() {
    final now = DateTime.now();
    final currentYearMonth = DateFormat('yyyy-MM').format(now);
    final currentYear = DateFormat('yyyy').format(now);

    setState(() {
      _filteredTransactions = _allTransactions.where((t) {
        // 1. Type Filter
        if (_selectedType != 'ALL' && t.type != _selectedType) {
          return false;
        }

        // 2. Status Filter
        if (_selectedStatus == 'PENDING' && t.isSettled) {
          return false;
        }
        if (_selectedStatus == 'SETTLED' && !t.isSettled) {
          return false;
        }

        // 3. Time Filter
        final date = t.transactionDate ?? '';
        if (_selectedTime == 'THIS_MONTH') {
          if (!date.startsWith(currentYearMonth)) {
            return false;
          }
        } else if (_selectedTime == 'THIS_YEAR') {
          if (!date.startsWith(currentYear)) {
            return false;
          }
        }

        // 4. Search Filter (Person, Category, Notes, Amount)
        if (_searchQuery.trim().isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final person = (t.personName ?? '').toLowerCase();
          final category = (t.categoryName ?? '').toLowerCase();
          final notes = (t.notes ?? '').toLowerCase();
          final amount = t.amount.toString();

          if (!person.contains(query) &&
              !category.contains(query) &&
              !notes.contains(query) &&
              !amount.contains(query)) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final txDate = DateTime(dt.year, dt.month, dt.day);
      if (txDate == today) {
        return 'Today, ${DateFormat('hh:mm a').format(dt)}';
      } else if (txDate == today.subtract(const Duration(days: 1))) {
        return 'Yesterday, ${DateFormat('hh:mm a').format(dt)}';
      } else {
        return DateFormat('dd MMM yyyy').format(dt);
      }
    } catch (_) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final totalFilteredAmount = _filteredTransactions.fold<double>(0.0, (sum, t) => sum + t.amount);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ledger History & Filters',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
            ),
            Text(
              'Search, multi-filter & complete ledger',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Export & A4 Print Sheet',
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF10B981), size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExportStatementScreen()),
              );
            },
          ),
          SyncStatusBadge(
            isSyncing: _isSyncing,
            onSync: _loadTransactions,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<TransactionItem>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _allTransactions.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: ShimmerTransactionList(count: 6),
            );
          }
          if (snapshot.hasError && _allTransactions.isEmpty) {
            return Center(
              child: Text(
                'Failed to load history: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          return Column(
            children: [
              // 1. Search Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) {
                    _searchQuery = val;
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by person, category, note...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF818CF8)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                    ),
                  ),
                ),
              ),

              // 2. Filter Bar: Type Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    _buildTypeChip('ALL', 'All'),
                    _buildTypeChip('GIVEN', 'Lent', color: const Color(0xFF10B981)),
                    _buildTypeChip('TAKEN', 'Borrowed', color: const Color(0xFFEF4444)),
                    _buildTypeChip('EXPENSE', 'Expense', color: const Color(0xFFF59E0B)),
                    _buildTypeChip('INCOME', 'Income', color: const Color(0xFF38BDF8)),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 3. Sub-Filters: Time & Status
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    // Time selector
                    _buildFilterDropdown(
                      label: 'Time: ${_selectedTime == 'ALL' ? 'All Time' : _selectedTime == 'THIS_MONTH' ? 'This Month' : 'This Year'}',
                      icon: Icons.calendar_today_rounded,
                      items: const [
                        {'val': 'ALL', 'title': 'All Time'},
                        {'val': 'THIS_MONTH', 'title': 'This Month'},
                        {'val': 'THIS_YEAR', 'title': 'This Year'},
                      ],
                      selectedValue: _selectedTime,
                      onSelect: (val) {
                        _selectedTime = val;
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 8),

                    // Settlement selector
                    _buildFilterDropdown(
                      label: 'Status: ${_selectedStatus == 'ALL' ? 'All Status' : _selectedStatus == 'PENDING' ? 'Pending' : 'Settled'}',
                      icon: Icons.check_circle_outline_rounded,
                      items: const [
                        {'val': 'ALL', 'title': 'All Status'},
                        {'val': 'PENDING', 'title': 'Pending Only'},
                        {'val': 'SETTLED', 'title': 'Settled Only'},
                      ],
                      selectedValue: _selectedStatus,
                      onSelect: (val) {
                        _selectedStatus = val;
                        _applyFilters();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 4. Filter Results Summary Banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${_filteredTransactions.length} entries match',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _isSyncing ? null : _loadTransactions,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Icon(
                              Icons.sync_rounded,
                              size: 15,
                              color: _isSyncing ? const Color(0xFF818CF8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Total: ${currency.format(totalFilteredAmount)}',
                      style: const TextStyle(
                        color: Color(0xFF818CF8),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 5. Transactions List
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFF818CF8),
                  backgroundColor: const Color(0xFF1E293B),
                  onRefresh: _loadTransactions,
                  child: _filteredTransactions.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF64748B)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No matching records found',
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                        _selectedType = 'ALL';
                                        _selectedTime = 'ALL';
                                        _selectedStatus = 'ALL';
                                        _applyFilters();
                                      });
                                    },
                                    child: const Text('Reset All Filters', style: TextStyle(color: Color(0xFF818CF8))),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        itemCount: _filteredTransactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _filteredTransactions[index];
                          final isGiven = item.type == 'GIVEN';
                          final isTaken = item.type == 'TAKEN';
                          final isIncome = item.type == 'INCOME';

                          final color = isGiven
                              ? const Color(0xFF10B981)
                              : isTaken
                                  ? const Color(0xFFEF4444)
                                  : isIncome
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFFF59E0B);

                          final typeBadge = isGiven
                              ? 'Lent'
                              : isTaken
                                  ? 'Borrowed'
                                  : isIncome
                                      ? 'Income'
                                      : 'Expense';

                          return InkWell(
                            onTap: () async {
                              final updated = await TransactionDetailSheet.show(
                                context,
                                item: item,
                                onTransactionChanged: _loadTransactions,
                              );
                              if (updated == true) {
                                _loadTransactions();
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF334155), width: 0.8),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isGiven
                                          ? Icons.arrow_outward_rounded
                                          : isTaken
                                              ? Icons.arrow_downward_rounded
                                              : isIncome
                                                  ? Icons.account_balance_wallet_rounded
                                                  : Icons.shopping_bag_rounded,
                                      color: color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.personName ?? item.categoryName ?? item.type,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                typeBadge,
                                                style: TextStyle(
                                                  color: color,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.event_note_rounded, size: 12, color: const Color(0xFF64748B)),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatDate(item.transactionDate),
                                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '•  ${item.paymentMode}',
                                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                            ),
                                            if (item.notes != null && item.notes!.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '•  ${item.notes}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        currency.format(item.amount),
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (item.isSettled)
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Settled',
                                            style: TextStyle(
                                              color: Color(0xFF10B981),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF475569), size: 18),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTypeChip(String type, String label, {Color color = const Color(0xFF4F46E5)}) {
    final isSelected = _selectedType == type;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedType = type;
            _applyFilters();
          });
        },
        selectedColor: color.withOpacity(0.25),
        backgroundColor: const Color(0xFF1E293B),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? color : const Color(0xFF334155),
          width: isSelected ? 1.5 : 0.8,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required IconData icon,
    required List<Map<String, String>> items,
    required String selectedValue,
    required ValueChanged<String> onSelect,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelect,
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      itemBuilder: (context) => items
          .map(
            (it) => PopupMenuItem<String>(
              value: it['val'],
              child: Text(
                it['title']!,
                style: TextStyle(
                  color: selectedValue == it['val'] ? const Color(0xFF818CF8) : Colors.white,
                  fontWeight: selectedValue == it['val'] ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: const Color(0xFF818CF8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
