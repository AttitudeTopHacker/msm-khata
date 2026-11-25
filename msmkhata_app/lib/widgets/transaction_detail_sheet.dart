import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/connectivity_service.dart';
import '../services/policy_service.dart';
import '../services/sync_service.dart';
import '../screens/add_transaction_screen.dart';
import 'person_detail_sheet.dart';

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
        final clean = _item.transactionDate!.split('T')[0].split(' ')[0];
        final parts = clean.split('-');
        if (parts.length == 3) {
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
        return DateTime.parse(clean);
      } catch (_) {}
    }
    return DateTime.now();
  }

  String _formatFullDate(DateTime dt) {
    return DateFormat('EEEE, dd MMMM yyyy').format(dt);
  }

  void _handleChangeDate() async {
    if (!PolicyService.canEditDate) {
      PolicyService.showRestrictedDialog(
        context,
        title: 'Date Modification Restricted',
        message: 'Changing or modifying transaction dates has been disabled by the administrator. All entries retain their recorded timestamps.',
      );
      return;
    }

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

    final dateStr = DateFormat('yyyy-MM-dd').format(pickedDate);

    setState(() => _isLoading = true);

    try {
      final updated = await SyncService.updateTransactionItem(
        id: _item.id,
        transactionDate: dateStr,
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

  void _openPersonLedger() {
    PersonDetailSheet.showForTransaction(context, _item, onChanged: () {
      widget.onTransactionChanged?.call();
      final updated = SyncService.cachedTransactions.firstWhere(
        (t) => t.id == _item.id,
        orElse: () => _item,
      );
      if (mounted) {
        setState(() {
          _item = updated;
        });
      }
    });
  }

  void _showSettlementChoiceDialog() {
    final hasPerson = (_item.personName != null && _item.personName!.trim().isNotEmpty) ||
        (_item.personId != null && _item.personId!.isNotEmpty);
    final personName = _item.personName ?? 'Contact';
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    if (!hasPerson) {
      _confirmToggleSettlementOnly();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF334155), width: 1.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF475569),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.handshake_rounded, color: Color(0xFFF59E0B), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Settlement & Ledger Action',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Manage settlement for $personName',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Option 1: Open Full Khata & Settle (Chukta)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1.2),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openPersonLedger();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.menu_book_rounded, color: Color(0xFF10B981), size: 22),
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
                                        'Open $personName\'s Khata',
                                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Chukta',
                                        style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'View total lent, borrowed & full history to do complete settlement',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Option 2: Mark only this entry as Settled / Unsettled
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155), width: 1),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmToggleSettlementOnly();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (_item.isSettled ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _item.isSettled ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                              color: _item.isSettled ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _item.isSettled ? 'Mark Entry as Pending (Unsettled)' : 'Mark only this entry as Settled',
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _item.isSettled
                                      ? 'Reopen this ${currency.format(_item.amount)} transaction in outstanding balance'
                                      : 'Mark only this ${currency.format(_item.amount)} transaction as paid / settled',
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmToggleSettlementOnly() async {
    final willSettle = !_item.isSettled;
    final actionText = willSettle ? 'Mark as Settled' : 'Mark as Pending';
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(
              willSettle ? Icons.check_circle_outline_rounded : Icons.pending_outlined,
              color: willSettle ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              '$actionText?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          willSettle
              ? 'Are you sure you want to mark this ${currency.format(_item.amount)} entry as settled?'
              : 'Are you sure you want to reopen this ${currency.format(_item.amount)} entry as pending settlement?',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willSettle ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _handleToggleSettle();
    }
  }

  void _handleToggleSettle() async {
    setState(() => _isLoading = true);
    final willSettle = !_item.isSettled;
    try {
      final updatedItem = await SyncService.updateTransactionItem(
        id: _item.id,
        isSettled: willSettle,
      );
      if (mounted) {
        setState(() {
          _item = updatedItem;
        });
        widget.onTransactionChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  willSettle ? Icons.check_circle_rounded : Icons.pending_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    willSettle
                        ? 'Transaction marked as settled successfully'
                        : 'Transaction reopened as pending settlement',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: willSettle ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleDelete() async {
    if (!ConnectivityService().isOnline.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFEF4444),
          content: Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You are offline. To protect ledger integrity, please delete entries only when connected.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    if (!PolicyService.canDeleteEntry) {
      PolicyService.showRestrictedDialog(
        context,
        title: 'Entry Deletion Restricted',
        message: 'Deleting historical ledger transactions has been disabled by the administrator.',
      );
      return;
    }

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
      await SyncService.deleteTransaction(_item.id);
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
    if (!PolicyService.canEditEntry) {
      PolicyService.showRestrictedDialog(
        context,
        title: 'Entry Editing Restricted',
        message: 'Editing existing ledger entries has been disabled by the administrator. You may still record new transactions without restriction.',
      );
      return;
    }

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
        ? const Color(0xFF38BDF8)
        : isTaken
            ? const Color(0xFFF59E0B)
            : isIncome
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444);

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
                  onPressed: _isLoading ? null : _showSettlementChoiceDialog,
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Amount
          Text(
            isIncome
                ? '+${currency.format(_item.amount)}'
                : (_item.type == 'EXPENSE' ? '-${currency.format(_item.amount)}' : currency.format(_item.amount)),
            style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),

          // Contact or Category
          if (_item.personName != null && _item.personName!.trim().isNotEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _openPersonLedger,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _item.personName!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Khata', style: TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold)),
                          SizedBox(width: 3),
                          Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF818CF8), size: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Text(
              _item.categoryName ?? 'General Transaction',
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
                ValueListenableBuilder<int>(
                  valueListenable: PolicyService.policyVersion,
                  builder: (context, _, __) {
                    final canEditDate = PolicyService.canEditDate;
                    return ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canEditDate ? const Color(0xFF4F46E5) : const Color(0xFF334155),
                        foregroundColor: canEditDate ? Colors.white : const Color(0xFF94A3B8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _isLoading ? null : _handleChangeDate,
                      icon: Icon(canEditDate ? Icons.edit_calendar_rounded : Icons.lock_outline_rounded, size: 15),
                      label: Text(canEditDate ? 'Edit Date' : 'Locked', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    );
                  },
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

          // Bottom Action Buttons: Edit Full Details & Delete (Guarded by Enterprise Policy)
          ValueListenableBuilder<int>(
            valueListenable: PolicyService.policyVersion,
            builder: (context, _, __) {
              final canDelete = PolicyService.canDeleteEntry;
              final canEdit = PolicyService.canEditEntry;

              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: canDelete ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                        side: BorderSide(
                          color: canDelete ? const Color(0xFFEF4444) : const Color(0xFF334155),
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isLoading ? null : _handleDelete,
                      icon: Icon(canDelete ? Icons.delete_outline_rounded : Icons.lock_outline_rounded, size: 18),
                      label: Text(
                        canDelete ? 'Delete Entry' : 'Delete (Restricted)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canEdit ? const Color(0xFF4F46E5) : const Color(0xFF334155),
                        foregroundColor: canEdit ? Colors.white : const Color(0xFF94A3B8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _isLoading ? null : _handleEditFull,
                      icon: Icon(canEdit ? Icons.edit_rounded : Icons.lock_outline_rounded, size: 18),
                      label: Text(
                        canEdit ? 'Edit Entry' : 'Edit (Restricted)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
