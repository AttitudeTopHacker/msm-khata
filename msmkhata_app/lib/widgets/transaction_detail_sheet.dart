import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../screens/add_transaction_screen.dart';

class TransactionDetailSheet extends StatefulWidget {
  final TransactionItem item;
  final VoidCallback? onTransactionChanged;

  const TransactionDetailSheet({
    super.key,
    required this.item,
    this.onTransactionChanged,
  });

  static Future<bool?> show(
    BuildContext context, {
    required TransactionItem item,
    VoidCallback? onTransactionChanged,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailSheet(
        item: item,
        onTransactionChanged: onTransactionChanged,
      ),
    );
  }

  @override
  State<TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<TransactionDetailSheet> {
  late TransactionItem _item;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  DateTime get _parsedDate {
    if (_item.transactionDate != null && _item.transactionDate!.isNotEmpty) {
      try {
        return DateTime.parse(_item.transactionDate!).toLocal();
      } catch (_) {}
    }
    return DateTime.now();
  }

  String _formatFullDate(DateTime dt) {
    return DateFormat('EEE, dd MMMM yyyy, hh:mm a').format(dt);
  }

  void _handleChangeDate() async {
    final current = _parsedDate;
    final now = DateTime.now();
    final initial = current.isAfter(now) ? now : current;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'Select Transaction Date (Past or Today)',
      confirmText: 'Update Date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    // Retain the current time of day or set to current time
    final updatedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      current.hour,
      current.minute,
    );

    setState(() => _isLoading = true);

    try {
      final updated = await ApiService.updateTransaction(
        id: _item.id,
        transactionDate: updatedDateTime.toIso8601String(),
      );
      if (mounted) {
        setState(() {
          _item = updated;
        });
        widget.onTransactionChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction date updated to ${DateFormat('dd MMM yyyy').format(pickedDate)}'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update date: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleToggleSettle() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.settleTransaction(_item.id, isSettled: !_item.isSettled);
      if (mounted) {
        setState(() {
          _item = TransactionItem(
            id: _item.id,
            type: _item.type,
            amount: _item.amount,
            paymentMode: _item.paymentMode,
            dueDate: _item.dueDate,
            isSettled: !_item.isSettled,
            notes: _item.notes,
            transactionDate: _item.transactionDate,
            personId: _item.personId,
            personName: _item.personName,
            categoryId: _item.categoryId,
            categoryName: _item.categoryName,
            categoryColor: _item.categoryColor,
          );
        });
        widget.onTransactionChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Entry?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this transaction permanently from your ledger?',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.deleteTransaction(_item.id);
      if (mounted) {
        widget.onTransactionChanged?.call();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted successfully'),
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleEditFull() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionScreen(
        initialType: _item.type,
        existingTransaction: _item,
      ),
    );

    if (result == true && mounted) {
      widget.onTransactionChanged?.call();
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isGiven = _item.type == 'GIVEN';
    final isTaken = _item.type == 'TAKEN';
    final isIncome = _item.type == 'INCOME';

    final color = isGiven
        ? const Color(0xFF10B981)
        : isTaken
            ? const Color(0xFFEF4444)
            : isIncome
                ? const Color(0xFF38BDF8)
                : const Color(0xFFF59E0B);

    final typeLabel = isGiven
        ? 'Money Lent (To Receive)'
        : isTaken
            ? 'Money Borrowed (To Pay)'
            : isIncome
                ? 'Income Entry'
                : 'Expense Entry';

    final date = _parsedDate;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF64748B),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header: Type + Settle Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.4), width: 1),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              if (isGiven || isTaken)
                ActionChip(
                  avatar: Icon(
                    _item.isSettled ? Icons.check_circle_rounded : Icons.pending_outlined,
                    size: 16,
                    color: _item.isSettled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                  label: Text(_item.isSettled ? 'Settled' : 'Pending Settlement'),
                  backgroundColor: const Color(0xFF0F172A),
                  labelStyle: TextStyle(
                    color: _item.isSettled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  side: BorderSide(
                    color: _item.isSettled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    width: 0.8,
                  ),
                  onPressed: _isLoading ? null : _handleToggleSettle,
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Amount
          Text(
            currency.format(_item.amount),
            style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),

          // Contact or Category
          Text(
            _item.personName ?? _item.categoryName ?? 'General Transaction',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),

          // 📅 TRANSACTION DATE CARD (CUSTOM EDITABLE)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.4), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event_note_rounded, color: Color(0xFF818CF8), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transaction Date',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatFullDate(date),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _handleChangeDate,
                  icon: const Icon(Icons.edit_calendar_rounded, size: 15),
                  label: const Text('Edit Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Payment mode & Remarks
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155), width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payment_rounded, color: Color(0xFF64748B), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Payment Method: ${_item.paymentMode}',
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (_item.notes != null && _item.notes!.isNotEmpty) ...[
                  const Divider(color: Color(0xFF1E293B), height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes_rounded, color: Color(0xFF64748B), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _item.notes!,
                          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Bottom Action Buttons: Edit Full Details & Delete
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isLoading ? null : _handleDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete Entry', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _handleEditFull,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit Entry', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
