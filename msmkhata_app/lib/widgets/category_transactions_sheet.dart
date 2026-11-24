import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/stats.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import 'category_icon_helper.dart';
import 'transaction_detail_sheet.dart';

class CategoryTransactionsSheet extends StatefulWidget {
  final CategoryBreakdown category;
  final VoidCallback? onTransactionChanged;

  const CategoryTransactionsSheet({
    super.key,
    required this.category,
    this.onTransactionChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required CategoryBreakdown category,
    VoidCallback? onTransactionChanged,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 700;

    if (isDesktop) {
      return showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 800),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CategoryTransactionsSheet(
                category: category,
                onTransactionChanged: onTransactionChanged,
              ),
            ),
          ),
        ),
      );
    } else {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.9,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: CategoryTransactionsSheet(
              category: category,
              onTransactionChanged: onTransactionChanged,
            ),
          ),
        ),
      );
    }
  }

  @override
  State<CategoryTransactionsSheet> createState() => _CategoryTransactionsSheetState();
}

class _CategoryTransactionsSheetState extends State<CategoryTransactionsSheet> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 100;
  int _currentPage = 0;
  String _searchQuery = '';
  // Sort: 0 = Newest first, 1 = Oldest first, 2 = Highest amount
  int _sortMode = 0;

  @override
  void initState() {
    super.initState();
    SyncService.dataVersion.addListener(_onDataUpdated);
  }

  @override
  void dispose() {
    SyncService.dataVersion.removeListener(_onDataUpdated);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onDataUpdated() {
    if (mounted) setState(() {});
  }

  bool _matchesCategory(TransactionItem tx) {
    final targetName = widget.category.categoryName.trim().toLowerCase();

    // 1. Direct name match
    if (tx.categoryName != null && tx.categoryName!.trim().toLowerCase() == targetName) {
      return true;
    }

    // 2. Direct ID match
    if (widget.category.categoryId != null &&
        widget.category.categoryId!.isNotEmpty &&
        tx.categoryId == widget.category.categoryId) {
      return true;
    }

    // 3. Match via defaultCategories registry
    if (tx.categoryId != null) {
      for (final c in ApiService.defaultCategories) {
        if (c.id == tx.categoryId && c.name.trim().toLowerCase() == targetName) {
          return true;
        }
      }
    }

    return false;
  }

  List<TransactionItem> _getFilteredTransactions() {
    final allCategoryTx = SyncService.cachedTransactions.where(_matchesCategory).toList();

    // Apply search filter
    List<TransactionItem> list = allCategoryTx;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((tx) {
        final note = (tx.notes ?? '').toLowerCase();
        final person = (tx.personName ?? '').toLowerCase();
        final amt = tx.amount.toString();
        final date = (tx.transactionDate ?? '').toLowerCase();
        final mode = tx.paymentMode.toLowerCase();
        return note.contains(q) ||
            person.contains(q) ||
            amt.contains(q) ||
            date.contains(q) ||
            mode.contains(q);
      }).toList();
    }

    // Apply sorting
    list = List.from(list);
    if (_sortMode == 0) {
      // Newest first
      list.sort((a, b) {
        final da = a.transactionDate ?? '';
        final db = b.transactionDate ?? '';
        final cmp = db.compareTo(da);
        if (cmp != 0) return cmp;
        return (b.createdAt ?? '').compareTo(a.createdAt ?? '');
      });
    } else if (_sortMode == 1) {
      // Oldest first
      list.sort((a, b) {
        final da = a.transactionDate ?? '';
        final db = b.transactionDate ?? '';
        final cmp = da.compareTo(db);
        if (cmp != 0) return cmp;
        return (a.createdAt ?? '').compareTo(b.createdAt ?? '');
      });
    } else if (_sortMode == 2) {
      // Highest amount
      list.sort((a, b) => b.amount.compareTo(a.amount));
    }

    return list;
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final themeColor = _parseColor(widget.category.color);
    final visual = CategoryIconHelper.getVisual(
      categoryName: widget.category.categoryName,
      type: 'EXPENSE',
      categoryColorHex: widget.category.color,
    );

    final allMatching = SyncService.cachedTransactions.where(_matchesCategory).toList();
    final totalSpentInCat = allMatching.fold<double>(0.0, (sum, tx) => sum + tx.amount);

    final filteredList = _getFilteredTransactions();
    final totalCount = filteredList.length;
    final totalPages = (totalCount / _pageSize).ceil().clamp(1, 9999);

    if (_currentPage >= totalPages) {
      _currentPage = totalPages - 1;
    }

    final startIndex = _currentPage * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalCount);
    final pageItems = (startIndex < totalCount)
        ? filteredList.sublist(startIndex, endIndex)
        : <TransactionItem>[];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          // Drag handle on mobile
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF475569),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Header Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 0.8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 1.2),
                      ),
                      child: Icon(visual.icon, color: themeColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.category.categoryName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Drill-down Transaction Ledger',
                            style: TextStyle(
                              color: const Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Metrics Badges Bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Spent',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currency.format(totalSpentInCat),
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Entries',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${allMatching.length} Transactions',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Expense Share',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.category.percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: themeColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search and Sort Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            color: const Color(0xFF131D31),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search note, amount, date, person...',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _currentPage = 0;
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          _currentPage = 0;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                PopupMenuButton<int>(
                  initialValue: _sortMode,
                  tooltip: 'Sort Transactions',
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF334155)),
                  ),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Icon(Icons.sort_rounded, color: Colors.white, size: 18),
                  ),
                  onSelected: (val) {
                    setState(() {
                      _sortMode = val;
                      _currentPage = 0;
                    });
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 0,
                      child: Text('Newest First (Default)', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    const PopupMenuItem(
                      value: 1,
                      child: Text('Oldest First', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    const PopupMenuItem(
                      value: 2,
                      child: Text('Highest Amount', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Transaction List or Empty State
          Expanded(
            child: pageItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.receipt_long_outlined,
                            size: 48,
                            color: const Color(0xFF64748B),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No transactions found matching "$_searchQuery"'
                                : 'No transactions recorded for ${widget.category.categoryName}',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: pageItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = pageItems[index];
                      final dateStr = item.transactionDate ?? '';

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            final updated = await TransactionDetailSheet.show(
                              context,
                              item: item,
                              onTransactionChanged: () {
                                widget.onTransactionChanged?.call();
                                if (mounted) setState(() {});
                              },
                            );
                            if (updated == true) {
                              widget.onTransactionChanged?.call();
                              if (mounted) setState(() {});
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF334155), width: 0.7),
                            ),
                            child: Row(
                              children: [
                                // Date & Payment mode column
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: themeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF94A3B8)),
                                      const SizedBox(height: 2),
                                      Text(
                                        dateStr.length >= 10 ? dateStr.substring(8, 10) : '••',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Note / Person info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (item.notes != null && item.notes!.trim().isNotEmpty)
                                            ? item.notes!
                                            : widget.category.categoryName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F172A),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              item.paymentMode,
                                              style: const TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            dateStr,
                                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                          ),
                                          if (item.personName != null && item.personName!.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            const Icon(Icons.person_outline, size: 12, color: Color(0xFF818CF8)),
                                            const SizedBox(width: 2),
                                            Flexible(
                                              child: Text(
                                                item.personName!,
                                                style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 11),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // Amount & Chevron
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '-${currency.format(item.amount)}',
                                      style: const TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 16,
                                      color: Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Pagination Bar (Smooth 100 per page navigation)
          if (totalCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(top: BorderSide(color: Color(0xFF334155), width: 0.8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${startIndex + 1}–$endIndex of $totalCount',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                        color: _currentPage > 0 ? Colors.white : const Color(0xFF475569),
                        tooltip: 'Previous 100 Transactions',
                        onPressed: _currentPage > 0
                            ? () {
                                setState(() => _currentPage--);
                                _scrollController.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                              }
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(
                          'Page ${_currentPage + 1} / $totalPages',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        color: _currentPage < totalPages - 1 ? Colors.white : const Color(0xFF475569),
                        tooltip: 'Next 100 Transactions',
                        onPressed: _currentPage < totalPages - 1
                            ? () {
                                setState(() => _currentPage++);
                                _scrollController.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
