import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/person.dart';
import '../models/transaction.dart';
import '../services/sync_service.dart';
import '../screens/add_transaction_screen.dart';
import 'transaction_detail_sheet.dart';

class PersonDetailSheet {
  static Future<void> showForTransaction(
    BuildContext context,
    TransactionItem item, {
    VoidCallback? onChanged,
  }) async {
    Person? person;
    if (item.personId != null && item.personId!.isNotEmpty) {
      final matches = SyncService.cachedPersons.where((p) => p.id == item.personId);
      if (matches.isNotEmpty) person = matches.first;
    }
    if (person == null && item.personName != null && item.personName!.trim().isNotEmpty) {
      final matches = SyncService.cachedPersons.where(
        (p) => p.name.trim().toLowerCase() == item.personName!.trim().toLowerCase(),
      );
      if (matches.isNotEmpty) person = matches.first;
    }
    if (person == null && item.personName != null && item.personName!.trim().isNotEmpty) {
      person = Person(
        id: item.personId ?? '',
        name: item.personName!.trim(),
      );
    }
    if (person != null && context.mounted) {
      show(context, person, onChanged: onChanged);
    }
  }

  static void show(
    BuildContext context,
    Person person, {
    VoidCallback? onChanged,
  }) {
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
              (p) => (person.id.isNotEmpty && p.id == person.id) ||
                  p.name.trim().toLowerCase() == person.name.trim().toLowerCase(),
              orElse: () {
                final pTxs = SyncService.cachedTransactions.where((t) {
                  final matchesId = t.personId != null && t.personId == person.id && person.id.isNotEmpty;
                  final matchesName = t.personName != null &&
                      t.personName!.trim().toLowerCase() == person.name.trim().toLowerCase();
                  return matchesId || matchesName;
                }).toList();
                double given = 0;
                double taken = 0;
                for (final t in pTxs) {
                  if (t.isSettled) continue;
                  if (t.type.toUpperCase() == 'GIVEN') given += t.amount;
                  if (t.type.toUpperCase() == 'TAKEN') taken += t.amount;
                }
                return Person(
                  id: person.id,
                  name: person.name,
                  phone: person.phone,
                  totalGiven: given,
                  totalTaken: taken,
                  netBalance: given - taken,
                  status: (given - taken) > 0 ? 'TO_RECEIVE' : ((given - taken) < 0 ? 'TO_PAY' : 'SETTLED'),
                  transactionCount: pTxs.length,
                );
              },
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
              final matchesId = t.personId != null && t.personId == currentPerson.id && currentPerson.id.isNotEmpty;
              final matchesName = t.personName != null &&
                  t.personName!.trim().toLowerCase() == currentPerson.name.trim().toLowerCase();
              return matchesId || matchesName;
            }).toList();

            void openAddTx(Person? p, {String initialType = 'GIVEN', double? initialAmount}) async {
              final result = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AddTransactionScreen(
                  initialType: initialType,
                  initialPerson: p,
                  initialAmount: initialAmount,
                ),
              );
              if (result == true) {
                setSheetState(() {});
                onChanged?.call();
              }
            }

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
                                const Row(
                                  children: [
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
                                const Row(
                                  children: [
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
                              openAddTx(currentPerson, initialType: 'GIVEN');
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
                              openAddTx(currentPerson, initialType: 'TAKEN');
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
                                openAddTx(
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
                                        onChanged?.call();
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
}
