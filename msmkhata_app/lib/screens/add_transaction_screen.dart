import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/person.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/account_service.dart';
import '../services/connectivity_service.dart';
import '../services/policy_service.dart';
import '../services/sync_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final String initialType;
  final TransactionItem? existingTransaction;
  final double? initialAvailableBalance;

  const AddTransactionScreen({
    super.key,
    this.initialType = 'GIVEN',
    this.existingTransaction,
    this.initialAvailableBalance,
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
  double? _availableBalance;

  List<Category> _categories = [];
  Category? _selectedCategory;

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

    _availableBalance = widget.initialAvailableBalance;
    _amountController.addListener(_onAmountChanged);

    _loadCategories();
    _loadPersons();
    _loadAccountBalance();
  }

  void _onAmountChanged() {
    setState(() {});
  }

  Future<void> _loadAccountBalance() async {
    try {
      final activeAccount = AccountService.activeAccountNotifier.value;
      final stats = await ApiService.getDashboardStats(accountId: activeAccount.id);
      if (mounted) {
        setState(() {
          _availableBalance = stats.netAccountBalance;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _personController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
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
    // Income Categories
    if (lower.contains('paddy') || lower.contains('dhan')) return Icons.grass_rounded;
    if (lower.contains('wheat') || lower.contains('gehu')) return Icons.grain_rounded;
    if (lower.contains('sugar') || lower.contains('ganna')) return Icons.eco_rounded;
    if (lower.contains('mustard') || lower.contains('sarson') || lower.contains('oilseed')) return Icons.wb_sunny_rounded;
    if (lower.contains('vegetable') || lower.contains('sabzi') || lower.contains('fruit') || lower.contains('fal')) return Icons.local_florist_rounded;
    if (lower.contains('dairy') || lower.contains('milk') || lower.contains('doodh')) return Icons.coffee_rounded;
    if (lower.contains('rental') || lower.contains('kiraya') || lower.contains('bhaada')) return Icons.real_estate_agent_rounded;
    if (lower.contains('income') || lower.contains('kamai')) return Icons.payments_rounded;

    // Expense Categories
    if (lower.contains('mandi') || lower.contains('selling') || lower.contains('market')) return Icons.storefront_rounded;
    if (lower.contains('plough') || lower.contains('jutai')) return Icons.agriculture_rounded;
    if (lower.contains('irrigat') || lower.contains('water') || lower.contains('sinch')) return Icons.water_drop_rounded;
    if (lower.contains('diesel') || lower.contains('fuel') || lower.contains('petrol')) return Icons.local_gas_station_rounded;
    if (lower.contains('fertil') || lower.contains('seed') || lower.contains('pesticide') || lower.contains('khaad') || lower.contains('beej')) return Icons.spa_rounded;
    if (lower.contains('labour') || lower.contains('mazdoor') || lower.contains('wage')) return Icons.groups_rounded;
    if (lower.contains('machin') || lower.contains('equip') || lower.contains('tool')) return Icons.handyman_rounded;
    if (lower.contains('family')) return Icons.family_restroom_rounded;
    if (lower.contains('house') || lower.contains('home')) return Icons.home_rounded;
    if (lower.contains('crop') || lower.contains('harvest')) return Icons.cut_rounded;
    if (lower.contains('person')) return Icons.person_rounded;

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
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a category name.'),
                          backgroundColor: Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    // Check for duplicate category name (case-insensitive)
                    final isDuplicate = _categories.any(
                      (c) => c.name.trim().toLowerCase() == name.toLowerCase(),
                    );
                    if (isDuplicate) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("A category named '$name' already exists. Duplicate category names are not permitted."),
                          backgroundColor: const Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

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
                            content: Text("Category '$name' created and selected."),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (err) {
                      final errMsg = err.toString().replaceFirst('Exception: ', '');
                      if (errMsg.toLowerCase().contains('duplicate') || errMsg.toLowerCase().contains('already exists')) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errMsg),
                            backgroundColor: const Color(0xFFEF4444),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

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
                            content: Text("Category '$name' created and selected."),
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

  int _getCategoryUsageCount(Category cat) {
    int count = 0;
    final catNameLower = cat.name.trim().toLowerCase();
    for (final tx in SyncService.cachedTransactions) {
      if (tx.categoryId != null && tx.categoryId == cat.id) {
        count++;
      } else if (tx.categoryName != null &&
          tx.categoryName!.trim().toLowerCase() == catNameLower) {
        count++;
      }
    }
    return count;
  }

  void _showCategoryInUseWarningDialog(Category cat, int usageCount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cannot Delete Category',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, height: 1.4),
                children: [
                  const TextSpan(text: 'The category "'),
                  TextSpan(
                    text: cat.name,
                    style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: usageCount > 0
                        ? '" is currently associated with $usageCount transaction(s).'
                        : '" is currently associated with existing transactions.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Categories with existing transaction records cannot be deleted to preserve the integrity of your ledger. You may rename this category instead.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Rename Instead'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showRenameCategoryDialog(cat);
            },
          ),
        ],
      ),
    );
  }

  void _showCategoryOptionsSheet(Category cat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final catColor = _parseHexColor(cat.color);
        final catIcon = _getCategoryIcon(cat.name);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF475569),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Category Header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: catColor, width: 1.5),
                      ),
                      child: Icon(catIcon, color: catColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Category Options • Touch & Hold Actions',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF334155), height: 1),
                const SizedBox(height: 8),

                // Option 1: Rename Category
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Color(0xFF38BDF8), size: 22),
                  ),
                  title: const Text(
                    'Rename Category',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Change category name or color',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRenameCategoryDialog(cat);
                  },
                ),

                // Option 2: Delete Category
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 22),
                  ),
                  title: const Text(
                    'Delete Category',
                    style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Permanently remove if not used in any transactions',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleDeleteCategory(cat);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRenameCategoryDialog(Category cat) {
    final nameCtrl = TextEditingController(text: cat.name);
    String selectedHex = cat.color;
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
                  Icon(Icons.edit_rounded, color: Color(0xFF38BDF8), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Rename Category',
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
                      'Enter new name or choose a new color badge:',
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
                    final newName = nameCtrl.text.trim();
                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid category name.'),
                          backgroundColor: Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    // Prevent duplicate category name when renaming (ignoring the current category itself)
                    final isDuplicate = _categories.any(
                      (c) => c.id != cat.id && c.name.trim().toLowerCase() == newName.toLowerCase(),
                    );
                    if (isDuplicate) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("A category named '$newName' already exists. Duplicate categories are not permitted."),
                          backgroundColor: const Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    setDialogState(() => isSaving = true);

                    try {
                      Category updatedCat;
                      if (!cat.id.startsWith('c') && !cat.id.startsWith('local_')) {
                        updatedCat = await ApiService.updateCategory(
                          id: cat.id,
                          name: newName,
                          color: selectedHex,
                        );
                      } else {
                        updatedCat = Category(
                          id: cat.id,
                          name: newName,
                          type: cat.type,
                          color: selectedHex,
                        );
                      }

                      // Update local cached transactions to reflect new category name immediately
                      for (int i = 0; i < SyncService.cachedTransactions.length; i++) {
                        final tx = SyncService.cachedTransactions[i];
                        if (tx.categoryId == cat.id ||
                            (tx.categoryName != null &&
                                tx.categoryName!.trim().toLowerCase() == cat.name.trim().toLowerCase())) {
                          SyncService.cachedTransactions[i] = tx.copyWith(
                            categoryName: newName,
                            categoryColor: selectedHex,
                          );
                        }
                      }
                      SyncService.dataVersion.value++;

                      if (mounted) {
                        setState(() {
                          final idx = _categories.indexWhere((c) => c.id == cat.id || c.name.toLowerCase() == cat.name.toLowerCase());
                          if (idx != -1) {
                            _categories[idx] = updatedCat;
                          }
                          if (_selectedCategory?.id == cat.id ||
                              _selectedCategory?.name.toLowerCase() == cat.name.toLowerCase()) {
                            _selectedCategory = updatedCat;
                            _categoryController.text = updatedCat.name;
                          }
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Category renamed to '$newName' successfully."),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (err) {
                      setDialogState(() => isSaving = false);
                      final errMsg = err.toString().replaceFirst('Exception: ', '');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errMsg),
                          backgroundColor: const Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleDeleteCategory(Category cat) async {
    // 1. Strict check if category is used in existing transactions
    final inUseCount = _getCategoryUsageCount(cat);
    if (inUseCount > 0) {
      _showCategoryInUseWarningDialog(cat, inUseCount);
      return;
    }

    // 2. If not found in memory cache, show confirmation dialog before delete
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 10),
            Text('Delete Category?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you wish to delete "${cat.name}"?\nThis action cannot be undone.',
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 3. Delete from backend/local
    try {
      if (!cat.id.startsWith('c') && !cat.id.startsWith('local_')) {
        await ApiService.deleteCategory(cat.id);
      }
      if (mounted) {
        setState(() {
          _categories.removeWhere((c) => c.id == cat.id || c.name.toLowerCase() == cat.name.toLowerCase());
          if (_selectedCategory?.id == cat.id || _selectedCategory?.name.toLowerCase() == cat.name.toLowerCase()) {
            _selectedCategory = null;
            _categoryController.text = '';
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "${cat.name}" deleted successfully.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.toLowerCase().contains('used') ||
          msg.toLowerCase().contains('exist') ||
          msg.toLowerCase().contains('associat') ||
          msg.toLowerCase().contains('link')) {
        _showCategoryInUseWarningDialog(cat, inUseCount > 0 ? inUseCount : 1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickCustomDate() async {
    if (!PolicyService.canEditDate) {
      PolicyService.showRestrictedDialog(
        context,
        title: 'Date Modification Restricted',
        message: 'Changing or selecting past transaction dates has been disabled by the administrator. All entries record current timestamp.',
      );
      return;
    }

    final now = DateTime.now();
    final initial = _selectedDate.isAfter(now) ? now : _selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'Select Transaction Date (Past or Today)',
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
          now.second,
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

    // Safety Balance Check for outgoing funds (EXPENSE or GIVEN)
    final isOutgoing = _selectedType == 'EXPENSE' || _selectedType == 'GIVEN';
    if (isOutgoing && _availableBalance != null && amount > _availableBalance!) {
      final shouldProceed = await _showInsufficientBalanceDialog(
        available: _availableBalance!,
        attempted: amount,
        isExpense: _selectedType == 'EXPENSE',
      );
      if (!shouldProceed) return;
    }

    // Offline Safety Guard: Disallow mutations while offline to guarantee zero ledger conflict
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
                  'Aap offline hain! Ledger ko safe rakhne ke liye internet judne par hi entry add/update karein.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.existingTransaction != null) {
        if (!PolicyService.canEditEntry) {
          setState(() => _isLoading = false);
          PolicyService.showRestrictedDialog(
            context,
            title: 'Entry Editing Restricted',
            message: 'Editing existing ledger entries has been disabled by the administrator. You may still record new transactions without restriction.',
          );
          return;
        }

        String? catId = !isLenDen ? _selectedCategory?.id : null;
        if (catId != null && (catId.startsWith('c') || catId.startsWith('local_'))) {
          catId = null;
        }

        final notesText = _notesController.text.trim();
        final updatedTx = await ApiService.updateTransaction(
          id: widget.existingTransaction!.id,
          type: _selectedType,
          amount: amount,
          paymentMode: _paymentMode,
          personId: isLenDen ? _selectedPerson?.id : null,
          personName: isLenDen ? personName : null,
          clearPerson: !isLenDen,
          categoryId: catId,
          categoryName: !isLenDen ? categoryName : null,
          clearCategory: isLenDen,
          notes: notesText.isNotEmpty ? notesText : null,
          clearNotes: notesText.isEmpty,
          transactionDate: _selectedDate.toIso8601String(),
        );

        SyncService.onOptimisticTransactionUpdated(updatedTx);
      } else {
        String? catId = !isLenDen ? _selectedCategory?.id : null;
        if (catId != null && (catId.startsWith('c') || catId.startsWith('local_'))) {
          catId = null; // Let backend resolve UUID via name
        }

        final newTx = await ApiService.createTransaction(
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

        SyncService.onOptimisticTransactionCreated(newTx);
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

  Future<bool> _showInsufficientBalanceDialog({
    required double available,
    required double attempted,
    required bool isExpense,
  }) async {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final shortfall = attempted - available;
    final activeAccount = AccountService.activeAccountNotifier.value;

    final res = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.report_problem_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 10),
            Text('Kam Balance Warning!', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF818CF8), width: 0.8),
              ),
              child: Text(
                'Book: ${activeAccount.name}',
                style: const TextStyle(color: Color(0xFFA5B4FC), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.45),
                children: [
                  const TextSpan(text: 'Aapke is account me sirf '),
                  TextSpan(text: currency.format(available.toInt()), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' available balance hai, jabki aap '),
                  TextSpan(text: currency.format(attempted.toInt()), style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                  TextSpan(text: isExpense ? ' kharch kar rahe hain.' : ' kisi ko udhaar/pay kar rahe hain.'),
                  const TextSpan(text: '\n\nIs transaction se account '),
                  TextSpan(text: '-${currency.format(shortfall.toInt())} negative', style: const TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' ho jayega.\n\nKripya pehle balance add karein ya udhaar vasool karein:'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => Navigator.pop(ctx, 'income'),
                    icon: const Icon(Icons.trending_up, size: 16, color: Colors.white),
                    label: const Text('+ Add Income', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => Navigator.pop(ctx, 'borrow'),
                    icon: const Icon(Icons.call_received, size: 16, color: Colors.white),
                    label: const Text('+ Borrow/Taken', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'proceed'),
            child: const Text(
              'Proceed Anyway (Negative Balance)',
              style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (res == 'income') {
      setState(() {
        _selectedType = 'INCOME';
      });
      return false;
    } else if (res == 'borrow') {
      setState(() {
        _selectedType = 'TAKEN';
      });
      return false;
    } else if (res == 'proceed') {
      return true;
    }
    return false;
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

            // Live Available Balance Badge & Insufficient Balance Warning Banner
            if (_availableBalance != null) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final entered = double.tryParse(_amountController.text.trim()) ?? 0.0;
                  final isOutgoing = _selectedType == 'EXPENSE' || _selectedType == 'GIVEN';
                  final isExpense = _selectedType == 'EXPENSE';
                  final isOver = isOutgoing && entered > _availableBalance!;
                  final diff = isOver ? (entered - _availableBalance!) : 0.0;
                  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

                  if (isOver) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.6), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171), size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Kam Balance Warning (Shortfall)',
                                style: TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Aapke account me sirf ${currency.format(_availableBalance!.toInt())} bacha hai. Ye ${isExpense ? 'kharch' : 'pay'} karne par account -${currency.format(diff.toInt())} negative ho jayega!',
                            style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              InkWell(
                                onTap: () => setState(() => _selectedType = 'INCOME'),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF38BDF8), width: 0.8),
                                  ),
                                  child: const Text('+ Add Income Pehle', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => setState(() => _selectedType = 'TAKEN'),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                                  ),
                                  child: const Text('+ Borrow/Wapas Pehle', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _availableBalance! >= 0 ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                            size: 14,
                            color: _availableBalance! >= 0 ? const Color(0xFF10B981) : const Color(0xFFF87171),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Account Balance: ${currency.format(_availableBalance!.toInt())}',
                            style: TextStyle(
                              color: _availableBalance! >= 0 ? const Color(0xFF94A3B8) : const Color(0xFFF87171),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (isOutgoing && entered > 0)
                        Text(
                          'Bachega: ${currency.format((_availableBalance! - entered).toInt())}',
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 14),

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
                    children: [
                      const Icon(Icons.category_rounded, size: 16, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      const Text(
                        'Select Category',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(Hold to edit/delete)',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontStyle: FontStyle.italic),
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

                  // Loaded / Default Categories (Filtered by Expense vs Income)
                  ..._categories
                      .where((cat) => cat.type == 'BOTH' || cat.type == _selectedType)
                      .map((cat) {
                    final isSelected = _selectedCategory?.id == cat.id ||
                        _categoryController.text.trim().toLowerCase() == cat.name.toLowerCase();
                    final catColor = _parseHexColor(cat.color);
                    final catIcon = _getCategoryIcon(cat.name);

                    return GestureDetector(
                      onLongPress: () => _showCategoryOptionsSheet(cat),
                      onSecondaryTap: () => _showCategoryOptionsSheet(cat),
                      child: Tooltip(
                        message: 'Touch & hold to rename or delete',
                        child: ChoiceChip(
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
                        ),
                      ),
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

            // Submit Button (Guarded by Enterprise Policy when in Edit Mode)
            ValueListenableBuilder<int>(
              valueListenable: PolicyService.policyVersion,
              builder: (context, _, __) {
                final isEdit = widget.existingTransaction != null;
                final isBlocked = isEdit && !PolicyService.canEditEntry;

                return SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBlocked ? const Color(0xFF334155) : const Color(0xFF4F46E5),
                      foregroundColor: isBlocked ? const Color(0xFF94A3B8) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isBlocked) ...[
                                const Icon(Icons.lock_outline_rounded, size: 18),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                isEdit
                                    ? (isBlocked ? 'Editing Restricted' : 'Update Entry')
                                    : 'Save Entry',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                );
              },
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
          if (!PolicyService.canEditDate &&
              (targetDate.year != DateTime.now().year ||
               targetDate.month != DateTime.now().month ||
               targetDate.day != DateTime.now().day)) {
            PolicyService.showRestrictedDialog(
              context,
              title: 'Date Modification Restricted',
              message: 'Selecting past transaction dates has been disabled by the administrator. All entries record current timestamp.',
            );
            return;
          }
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
          if (_selectedCategory != null &&
              _selectedCategory!.type != 'BOTH' &&
              _selectedCategory!.type != type) {
            _selectedCategory = null;
            _categoryController.text = '';
          }
        }),
      ),
    );
  }
}
