import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/person.dart';
import '../services/sync_service.dart';
import '../widgets/adaptive_refresh_indicator.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/sync_status_badge.dart';

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
    _loadPersons();
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
                initialData: _statusFilter == null && SyncService.cachedPersons.isNotEmpty ? SyncService.cachedPersons : null,
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
                          child: Text('No contacts found', style: TextStyle(color: Color(0xFF94A3B8))),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: AdaptiveRefreshIndicator.scrollPhysics(),
                  padding: const EdgeInsets.all(16),
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: badgeColor.withOpacity(0.2), width: 1),
                      ),
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
                                if (person.phone != null)
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
                        ],
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
