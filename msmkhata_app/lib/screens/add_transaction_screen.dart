import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/person.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final String initialType;
  final TransactionItem? existingTransaction;

  const AddTransactionScreen({
    super.key,
    this.initialType = 'GIVEN',
    this.existingTransaction,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late String _selectedType;
  String _paymentMode = 'UPI';
  final _amountController = TextEditingController();
  final _personController = TextEditingController();
  final _categoryController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  List<Category> _categories = [];
  Category? _selectedCategory;
  bool _isLoadingCategories = false;

  List<Person> _persons = [];
  Person? _selectedPerson;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;

    if (widget.existingTransaction != null) {
      final tx = widget.existingTransaction!;
      _selectedType = tx.type;
      _paymentMode = tx.paymentMode;
      _amountController.text = tx.amount == tx.amount.roundToDouble()
          ? tx.amount.toInt().toString()
          : tx.amount.toString();
      _personController.text = tx.personName ?? '';
      _categoryController.text = tx.categoryName ?? '';
      _notesController.text = tx.notes ?? '';
      if (tx.transactionDate != null && tx.transactionDate!.isNotEmpty) {
        try {
          _selectedDate = DateTime.parse(tx.transactionDate!).toLocal();
        } catch (_) {}
      }
    }

    _loadCategories();
    _loadPersons();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _personController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final list = await ApiService.getCategories();
      if (mounted) {
        setState(() {
          _categories = list;
          if (_categoryController.text.isNotEmpty) {
            final match = _categories.where(
              (c) => c.name.toLowerCase() == _categoryController.text.trim().toLowerCase(),
            );
            if (match.isNotEmpty) {
              _selectedCategory = match.first;
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _categories = ApiService.defaultCategories;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _loadPersons() async {
    try {
      final list = await ApiService.getPersons();
      if (mounted) {
        setState(() {
          _persons = list;
        });
      }
    } catch (_) {
      // Ignore person load failure
    }
  }

  Color _parseHexColor(String hex) {
    try {
      String cleanHex = hex.replaceAll('#', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return const Color(0xFF4F46E5);
    }
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('market')) return Icons.storefront_rounded;
    if (lower.contains('mandi')) return Icons.store_rounded;
    if (lower.contains('agri') || lower.contains('crop')) return Icons.eco_rounded;
    if (lower.contains('plough') || lower.contains('jutai') || lower.contains('tractor')) return Icons.agriculture_rounded;
    if (lower.contains('irrigat') || lower.contains('water') || lower.contains('sinch')) return Icons.water_drop_rounded;
    if (lower.contains('diesel') || lower.contains('fuel') || lower.contains('petrol')) return Icons.local_gas_station_rounded;
    if (lower.contains('seed') || lower.contains('fertilis') || lower.contains('beej')) return Icons.grass_rounded;
    if (lower.contains('labour') || lower.contains('worker') || lower.contains('wage')) return Icons.engineering_rounded;
    if (lower.contains('house') || lower.contains('home') || lower.contains('grocery')) return Icons.shopping_basket_rounded;
    return Icons.category_rounded;
  }

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    String selectedHex = '#3B82F6';
    final presetColors = [
      '#3B82F6', // Blue (Market)
      '#10B981', // Emerald (Mandi)
      '#84CC16', // Lime (Agriculture)
      '#D97706', // Amber (Ploughing)
      '#06B6D4', // Cyan (Irrigation)
      '#EF4444', // Red (Diesel)
      '#8B5CF6', // Purple (Labour)
      '#14B8A6', // Teal (Fertiliser)
      '#F59E0B', // Orange (Household)
      '#EC4899', // Pink
    ];
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              title: Row(
                children: const [
                  Icon(Icons.add_circle_outline_rounded, color: Color(0xFF38BDF8), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Add New Category',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'e.g. Nursery, Seeds, Equipment, Utility Bill, Pesticides, etc.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Category Name',
                        labelStyle: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13),
                        hintText: 'e.g. Pesticides, Sand / Soil',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Category Colour:',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presetColors.map((hex) {
                        final color = _parseHexColor(hex);
                        final isSel = selectedHex == hex;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedHex = hex),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSel
                                  ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)]
                                  : null,
                            ),
                            child: isSel ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  onPressed: isSaving ? null : () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    setDialogState(() => isSaving = true);

                    try {
                      final newCat = await ApiService.createCategory(
                        name: name,
                        type: _selectedType == 'INCOME' ? 'INCOME' : 'EXPENSE',
                        color: selectedHex,
                      );
                      if (mounted) {
                        setState(() {
                          _categories.removeWhere((c) => c.name.toLowerCase() == newCat.name.toLowerCase());
                          _categories.insert(0, newCat);
                          _selectedCategory = newCat;
                          _categoryController.text = newCat.name;
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Category '$name' added and selected!"),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (_) {
                      // Offline/local fallback
                      final localCat = Category(
                        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
                        name: name,
                        type: _selectedType == 'INCOME' ? 'INCOME' : 'EXPENSE',
                        color: selectedHex,
                      );
                      if (mounted) {
                        setState(() {
                          _categories.removeWhere((c) => c.name.toLowerCase() == localCat.name.toLowerCase());
                          _categories.insert(0, localCat);
                          _selectedCategory = localCat;
                          _categoryController.text = localCat.name;
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Category '$name' selected!"),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Add & Select', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select Transaction Date',
      confirmText: 'Done',
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

    if (picked != null) {
      final now = DateTime.now();
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          now.hour,
          now.minute,
        );
      });
    }
  }

  void _submit() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final isLenDen = _selectedType == 'GIVEN' || _selectedType == 'TAKEN';
    final personName = _personController.text.trim();
    final categoryName = _categoryController.text.trim();

    if (isLenDen && personName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a contact name')),
      );
      return;
    }

    if (!isLenDen && categoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a category')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.existingTransaction != null) {
        await ApiService.updateTransaction(
          id: widget.existingTransaction!.id,
          amount: amount,
          paymentMode: _paymentMode,
          notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
          transactionDate: _selectedDate.toIso8601String(),
        );
      } else {
        String? catId = !isLenDen ? _selectedCategory?.id : null;
        if (catId != null && (catId.startsWith('c') || catId.startsWith('local_'))) {
          catId = null; // Let backend resolve UUID via name
        }

        await ApiService.createTransaction(
          type: _selectedType,
          amount: amount,
          paymentMode: _paymentMode,
          personName: isLenDen ? personName : null,
          personId: isLenDen ? _selectedPerson?.id : null,
          categoryName: !isLenDen ? categoryName : null,
          categoryId: catId,
          notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
          transactionDate: _selectedDate.toIso8601String(),
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLenDen = _selectedType == 'GIVEN' || _selectedType == 'TAKEN';

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                  color: const Color(0xFF64748B),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingTransaction != null ? 'Edit Ledger Entry' : 'Add Ledger Entry',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  isLenDen ? 'Contact Ledger' : 'Expense / Income',
                  style: TextStyle(
                    color: isLenDen ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Type Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _typeChip('GIVEN', 'Lent', const Color(0xFF10B981), Icons.call_made_rounded),
                  _typeChip('TAKEN', 'Borrowed', const Color(0xFFEF4444), Icons.call_received_rounded),
                  _typeChip('EXPENSE', 'Expense', const Color(0xFFF59E0B), Icons.shopping_bag_outlined),
                  _typeChip('INCOME', 'Income', const Color(0xFF38BDF8), Icons.trending_up_rounded),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Amount Field
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(color: Color(0xFF818CF8), fontSize: 26, fontWeight: FontWeight.bold),
                hintText: '0',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            // 📅 TRANSACTION DATE SELECTOR (CUSTOM DATE SUPPORT)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.event_note_rounded, size: 16, color: Color(0xFF818CF8)),
                    SizedBox(width: 6),
                    Text(
                      'Transaction Date',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _pickCustomDate,
                  icon: const Icon(Icons.edit_calendar_rounded, size: 14, color: Color(0xFF818CF8)),
                  label: const Text('Pick Date', style: TextStyle(color: Color(0xFF818CF8), fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Quick Date Selection Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _dateQuickChip('Today', DateTime.now()),
                  _dateQuickChip('Yesterday', DateTime.now().subtract(const Duration(days: 1))),
                  _dateQuickChip('2 Days Ago', DateTime.now().subtract(const Duration(days: 2))),
                  ActionChip(
                    avatar: const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF818CF8)),
                    label: const Text('Other Date...'),
                    backgroundColor: const Color(0xFF0F172A),
                    labelStyle: const TextStyle(color: Color(0xFF818CF8), fontSize: 12, fontWeight: FontWeight.w600),
                    side: const BorderSide(color: Color(0xFF334155)),
                    onPressed: _pickCustomDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Clickable Selected Date Card
            InkWell(
              onTap: _pickCustomDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.4), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF818CF8)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(Icons.edit_rounded, color: Color(0xFF818CF8), size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 1. PERSON SECTION (FOR GIVEN / TAKEN - Contacts)
            if (isLenDen) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.person_rounded, size: 16, color: Color(0xFF10B981)),
                      SizedBox(width: 6),
                      Text(
                        'Contact Name',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Text(
                    _selectedType == 'GIVEN' ? 'Money Lent' : 'Money Borrowed',
                    style: TextStyle(
                      color: _selectedType == 'GIVEN' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Autocomplete / Searchable input for Person
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _personController.text),
                optionsBuilder: (TextEditingValue textVal) {
                  if (textVal.text.isEmpty) {
                    return _persons.map((p) => p.name).take(6);
                  }
                  return _persons
                      .map((p) => p.name)
                      .where((name) => name.toLowerCase().contains(textVal.text.toLowerCase()));
                },
                onSelected: (String selection) {
                  _personController.text = selection;
                  final match = _persons.where((p) => p.name.toLowerCase() == selection.toLowerCase());
                  setState(() {
                    _selectedPerson = match.isNotEmpty ? match.first : null;
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                  controller.addListener(() {
                    if (_personController.text != controller.text) {
                      _personController.text = controller.text;
                    }
                  });
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onEditingComplete: onEditingComplete,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Contact Name',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      hintText: 'e.g. Arthur, David, Oliver (Auto-creates if new)',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF64748B), size: 20),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFF1E293B),
                      child: Container(
                        width: 300,
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.person_outline, color: Color(0xFF10B981), size: 18),
                              title: Text(option, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Existing Contact Chips
              if (_persons.isNotEmpty) ...[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _persons.take(6).map((p) {
                      final isSel = _personController.text.trim().toLowerCase() == p.name.toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: CircleAvatar(
                            radius: 10,
                            backgroundColor: const Color(0xFF10B981),
                            child: Text(
                              p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          label: Text(p.name),
                          backgroundColor: isSel ? const Color(0xFF10B981).withOpacity(0.25) : const Color(0xFF0F172A),
                          labelStyle: TextStyle(
                            color: isSel ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: isSel ? const Color(0xFF10B981) : const Color(0xFF334155),
                            width: 1,
                          ),
                          onPressed: () {
                            setState(() {
                              _personController.text = p.name;
                              _selectedPerson = p;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],

            // 2. CATEGORY SECTION (FOR EXPENSE / INCOME - Market, Mandi, Agriculture, etc.)
            if (!isLenDen) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.category_rounded, size: 16, color: Color(0xFFF59E0B)),
                      SizedBox(width: 6),
                      Text(
                        'Select Category',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _showAddCategoryDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Row(
                        children: const [
                          Icon(Icons.add_circle, size: 16, color: Color(0xFF38BDF8)),
                          SizedBox(width: 4),
                          Text(
                            '+ New Category',
                            style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Category Choice Chips with Pre-seeded & Custom Categories
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Prominent + Add Category Chip
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16, color: Color(0xFF38BDF8)),
                    label: const Text('+ New Category'),
                    backgroundColor: const Color(0xFF0F172A),
                    labelStyle: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                    side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
                    onPressed: _showAddCategoryDialog,
                  ),

                  // Loaded / Default Categories
                  ..._categories.map((cat) {
                    final isSelected = _selectedCategory?.id == cat.id ||
                        _categoryController.text.trim().toLowerCase() == cat.name.toLowerCase();
                    final catColor = _parseHexColor(cat.color);
                    final catIcon = _getCategoryIcon(cat.name);

                    return ChoiceChip(
                      avatar: Icon(catIcon, size: 16, color: isSelected ? Colors.white : catColor),
                      label: Text(cat.name),
                      selected: isSelected,
                      selectedColor: catColor.withOpacity(0.35),
                      backgroundColor: const Color(0xFF0F172A),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: isSelected ? catColor : const Color(0xFF334155),
                        width: isSelected ? 1.8 : 1,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCategory = cat;
                            _categoryController.text = cat.name;
                          } else {
                            _selectedCategory = null;
                            _categoryController.text = '';
                          }
                        });
                      },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 10),

              // Category Text field (Allows editing / custom typing)
              TextField(
                controller: _categoryController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Selected Category (or enter custom name)',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  hintText: 'e.g. Market, Mandi, Agriculture, Ploughing, Diesel',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  prefixIcon: const Icon(Icons.label_outline_rounded, color: Color(0xFF64748B), size: 20),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                onChanged: (text) {
                  final match = _categories.where((c) => c.name.toLowerCase() == text.trim().toLowerCase());
                  setState(() {
                    _selectedCategory = match.isNotEmpty ? match.first : null;
                  });
                },
              ),
            ],

            const SizedBox(height: 14),

            // Payment Mode Selector
            DropdownButtonFormField<String>(
              value: _paymentMode,
              dropdownColor: const Color(0xFF0F172A),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Payment Method',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              items: const [
                DropdownMenuItem(value: 'UPI', child: Text('UPI (GPay / PhonePe / Paytm)')),
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer (IMPS/NEFT)')),
                DropdownMenuItem(value: 'OTHER', child: Text('Other')),
              ],
              onChanged: (val) => setState(() => _paymentMode = val!),
            ),

            const SizedBox(height: 14),

            // Notes
            TextField(
              controller: _notesController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Remarks / Notes (Optional)',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                hintText: isLenDen
                    ? 'Reason for transaction'
                    : 'Details e.g. 5 hours ploughing, 20L diesel, wholesale commission',
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.existingTransaction != null ? 'Update Entry' : 'Save Entry',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateQuickChip(String label, DateTime targetDate) {
    final isSelected = _selectedDate.year == targetDate.year &&
        _selectedDate.month == targetDate.month &&
        _selectedDate.day == targetDate.day;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF4F46E5).withOpacity(0.35),
        backgroundColor: const Color(0xFF0F172A),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 12,
        ),
        side: BorderSide(
          color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF334155),
          width: isSelected ? 1.4 : 1,
        ),
        onSelected: (_) {
          final now = DateTime.now();
          setState(() {
            _selectedDate = DateTime(
              targetDate.year,
              targetDate.month,
              targetDate.day,
              now.hour,
              now.minute,
            );
          });
        },
      ),
    );
  }

  Widget _typeChip(String type, String label, Color color, IconData icon) {
    final isSelected = _selectedType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : color),
        label: Text(label),
        selected: isSelected,
        selectedColor: color.withOpacity(0.35),
        backgroundColor: const Color(0xFF0F172A),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? color : Colors.transparent,
          width: 1.2,
        ),
        onSelected: (_) => setState(() {
          _selectedType = type;
        }),
      ),
    );
  }
}
