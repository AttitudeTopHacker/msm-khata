import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/person.dart';
import '../services/api_service.dart';

class PersonsScreen extends StatefulWidget {
  const PersonsScreen({super.key});

  @override
  State<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonsScreenState extends State<PersonsScreen> {
  String? _statusFilter;
  late Future<List<Person>> _personsFuture;

  @override
  void initState() {
    super.initState();
    _loadPersons();
  }

  void _loadPersons() {
    setState(() {
      _personsFuture = ApiService.getPersons(status: _statusFilter);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Len-Den Contacts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                _filterChip('TO_RECEIVE', 'Lena Hai', const Color(0xFF10B981)),
                _filterChip('TO_PAY', 'Dena Hai', const Color(0xFFEF4444)),
                _filterChip('SETTLED', 'Settled', const Color(0xFF64748B)),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Person>>(
              future: _personsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return const Center(
                    child: Text('Koi contact nahi mila', style: TextStyle(color: Color(0xFF94A3B8))),
                  );
                }

                return ListView.separated(
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
                                    Text('Diye: ${currency.format(person.totalGiven)}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                    const SizedBox(width: 10),
                                    Text('Liye: ${currency.format(person.totalTaken)}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
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
                                  isReceive ? 'Lena Hai' : isPay ? 'Dena Hai' : 'Settled',
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
