import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/routine_entry.dart';
import '../services/routine_service.dart';
import '../services/theme_service.dart';

class DailyRoutineScreen extends StatefulWidget {
  const DailyRoutineScreen({super.key});

  @override
  State<DailyRoutineScreen> createState() => _DailyRoutineScreenState();
}

class _DailyRoutineScreenState extends State<DailyRoutineScreen> {
  String _selectedCategoryFilter = 'all';
  DateTime? _selectedDateFilter;
  String _dateFilterMode = 'all'; // 'all', 'today', 'yesterday', 'custom'

  final List<Color> _paletteColors = const [
    Color(0xFF10B981), // Emerald
    Color(0xFF38BDF8), // Sky
    Color(0xFF8B5CF6), // Violet
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEF4444), // Red
    Color(0xFF84CC16), // Lime
    Color(0xFFA855F7), // Purple
    Color(0xFFF97316), // Orange
  ];

  final List<IconData> _paletteIcons = const [
    Icons.agriculture_rounded,
    Icons.directions_car_rounded,
    Icons.shopping_bag_rounded,
    Icons.work_rounded,
    Icons.home_rounded,
    Icons.fitness_center_rounded,
    Icons.school_rounded,
    Icons.construction_rounded,
    Icons.medical_services_rounded,
    Icons.restaurant_rounded,
    Icons.flight_takeoff_rounded,
    Icons.build_rounded,
    Icons.computer_rounded,
    Icons.handshake_rounded,
    Icons.payments_rounded,
  ];

  @override
  void initState() {
    super.initState();
    RoutineService.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<RoutineEntry> _getFilteredEntries() {
    return RoutineService.cachedEntries.where((entry) {
      // Category filter
      if (_selectedCategoryFilter != 'all' && entry.categoryId != _selectedCategoryFilter) {
        return false;
      }

      // Date filter
      if (_dateFilterMode == 'today') {
        if (!_isSameDay(entry.date, DateTime.now())) return false;
      } else if (_dateFilterMode == 'yesterday') {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        if (!_isSameDay(entry.date, yesterday)) return false;
      } else if (_dateFilterMode == 'custom' && _selectedDateFilter != null) {
        if (!_isSameDay(entry.date, _selectedDateFilter!)) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppAccentTheme>(
      valueListenable: ThemeService.accentNotifier,
      builder: (context, accent, _) {
        return ValueListenableBuilder<int>(
          valueListenable: RoutineService.dataVersion,
          builder: (context, _, __) {
            final filteredEntries = _getFilteredEntries();

            return Scaffold(
              backgroundColor: const Color(0xFF0F172A),
              appBar: AppBar(
                backgroundColor: const Color(0xFF0F172A),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Routine & Work Diary',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Rozana kaam ka record aur hisab',
                      style: TextStyle(color: accent.light, fontSize: 11),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.category_rounded, color: Colors.white70),
                    tooltip: 'Categories Manage Karein',
                    onPressed: () => _showManageCategoriesDialog(context, accent),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                backgroundColor: accent.primary,
                foregroundColor: Colors.white,
                elevation: 6,
                icon: const Icon(Icons.add_task_rounded, size: 20),
                label: const Text('Kaam Darj Karein', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showAddEditEntrySheet(context, accent),
              ),
              body: Column(
                children: [
                  // 1. Date Filter Bar
                  _buildDateFilterBar(accent),

                  // 2. Category Filter Chips
                  _buildCategoryFilterChips(accent),

                  const SizedBox(height: 8),

                  // 3. Summary Stats Banner
                  _buildSummaryStats(filteredEntries, accent),

                  // 4. Entries List
                  Expanded(
                    child: filteredEntries.isEmpty
                        ? _buildEmptyState(accent)
                        : _buildEntriesList(filteredEntries, accent),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Top Date Filter Bar
  Widget _buildDateFilterBar(AppAccentTheme accent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Row(
        children: [
          _buildDateTab('All Dates', 'all', accent),
          _buildDateTab('Aaj', 'today', accent),
          _buildDateTab('Kal', 'yesterday', accent),
          _buildCustomDateTab(accent),
        ],
      ),
    );
  }

  Widget _buildDateTab(String label, String mode, AppAccentTheme accent) {
    final isSelected = _dateFilterMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _dateFilterMode = mode;
            if (mode != 'custom') _selectedDateFilter = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? accent.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDateTab(AppAccentTheme accent) {
    final isSelected = _dateFilterMode == 'custom';
    final label = _selectedDateFilter != null
        ? DateFormat('dd MMM').format(_selectedDateFilter!)
        : 'Pick Date';

    return Expanded(
      child: GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDateFilter ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: accent.primary,
                    surface: const Color(0xFF1E293B),
                    onSurface: Colors.white,
                  ),
                ),
                child: child!,
              );
            },
          );

          if (picked != null) {
            setState(() {
              _dateFilterMode = 'custom';
              _selectedDateFilter = picked;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? accent.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 13,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Horizontally scrollable Category Filter Chips
  Widget _buildCategoryFilterChips(AppAccentTheme accent) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          // "All" filter chip
          _buildCategoryFilterChip(
            id: 'all',
            label: 'All Categories',
            icon: Icons.dashboard_outlined,
            color: accent.light,
            isSelected: _selectedCategoryFilter == 'all',
          ),

          // Categories from RoutineService
          ...RoutineService.allCategories.map((cat) {
            return _buildCategoryFilterChip(
              id: cat.id,
              label: cat.name,
              icon: cat.iconData,
              color: cat.color,
              isSelected: _selectedCategoryFilter == cat.id,
            );
          }),

          // "+ Add Category" button
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: ActionChip(
              backgroundColor: const Color(0xFF1E293B),
              side: const BorderSide(color: Color(0xFF334155)),
              avatar: Icon(Icons.add_circle_outline_rounded, color: accent.light, size: 16),
              label: Text(
                'Nayi Category',
                style: TextStyle(color: accent.light, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showAddCategoryDialog(context, accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip({
    required String id,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        backgroundColor: const Color(0xFF1E293B),
        selectedColor: color.withValues(alpha: 0.22),
        side: BorderSide(
          color: isSelected ? color : const Color(0xFF334155),
          width: isSelected ? 1.5 : 1,
        ),
        avatar: Icon(icon, color: isSelected ? color : const Color(0xFF94A3B8), size: 16),
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        showCheckmark: false,
        onSelected: (_) {
          setState(() {
            _selectedCategoryFilter = id;
          });
        },
      ),
    );
  }

  /// Summary Stats Banner
  Widget _buildSummaryStats(List<RoutineEntry> entries, AppAccentTheme accent) {
    final totalCount = entries.length;
    final totalHours = entries.fold<double>(0.0, (sum, e) => sum + (e.hoursSpent ?? 0.0));
    final totalExpense = entries.fold<double>(0.0, (sum, e) => sum + (e.expense ?? 0.0));

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.light.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Entries', '$totalCount', Icons.checklist_rounded, accent.light),
          Container(width: 1, height: 26, color: const Color(0xFF334155)),
          _buildStatItem('Hours Logged', '${totalHours.toStringAsFixed(1)} hrs', Icons.timer_outlined, const Color(0xFF38BDF8)),
          if (totalExpense > 0) ...[
            Container(width: 1, height: 26, color: const Color(0xFF334155)),
            _buildStatItem('Expense', '₹${totalExpense.toStringAsFixed(0)}', Icons.currency_rupee_rounded, const Color(0xFFF59E0B)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5)),
          ],
        ),
      ],
    );
  }

  /// Empty State UI
  Widget _buildEmptyState(AppAccentTheme accent) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: accent.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: accent.light.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.event_note_rounded, size: 40, color: accent.light),
            ),
            const SizedBox(height: 16),
            const Text(
              'Koi Kaam Darj Nahi Hai',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Is filter ke liye abhi koi routine entry nahi mili.\nNaya kaam log karne ke liye niche tap karein.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: () => _showAddEditEntrySheet(context, accent),
              icon: const Icon(Icons.add_task_rounded, size: 18),
              label: const Text('Naya Kaam Add Karein', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// List of Routine Entries
  Widget _buildEntriesList(List<RoutineEntry> entries, AppAccentTheme accent) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final category = RoutineService.getCategory(entry.categoryId);

        // Date header if date changes or first item
        final bool showDateHeader = index == 0 ||
            !_isSameDay(entry.date, entries[index - 1].date);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDateHeader) _buildDateHeader(entry.date, accent),
            _buildEntryCard(entry, category, accent),
          ],
        );
      },
    );
  }

  /// Date Section Header
  Widget _buildDateHeader(DateTime date, AppAccentTheme accent) {
    String dateLabel;
    if (_isSameDay(date, DateTime.now())) {
      dateLabel = 'Aaj • Today (${DateFormat('dd MMM yyyy').format(date)})';
    } else if (_isSameDay(date, DateTime.now().subtract(const Duration(days: 1)))) {
      dateLabel = 'Kal • Yesterday (${DateFormat('dd MMM yyyy').format(date)})';
    } else {
      dateLabel = DateFormat('EEEE, dd MMMM yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6, left: 4),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded, size: 12, color: accent.light),
          const SizedBox(width: 6),
          Text(
            dateLabel,
            style: TextStyle(
              color: accent.light,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Single Entry Card
  Widget _buildEntryCard(RoutineEntry entry, RoutineCategory category, AppAccentTheme accent) {
    final catColor = category.color;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: entry.isCompleted ? const Color(0xFF334155) : const Color(0xFFEF4444).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showAddEditEntrySheet(context, accent, entryToEdit: entry),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon Badge
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: catColor.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Icon(category.iconData, color: catColor, size: 22),
                ),
                const SizedBox(width: 12),

                // Main Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Category Badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                decoration: entry.isCompleted ? TextDecoration.none : TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: catColor.withValues(alpha: 0.3), width: 0.8),
                            ),
                            child: Text(
                              category.name,
                              style: TextStyle(color: catColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),

                      if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          entry.notes!,
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Meta details: Time, Hours, Expense
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (entry.time != null && entry.time!.isNotEmpty)
                            _buildMetaBadge(Icons.access_time_rounded, entry.time!, const Color(0xFF94A3B8)),
                          if (entry.hoursSpent != null && entry.hoursSpent! > 0)
                            _buildMetaBadge(Icons.timer_outlined, '${entry.hoursSpent} hrs', const Color(0xFF38BDF8)),
                          if (entry.expense != null && entry.expense! > 0)
                            _buildMetaBadge(Icons.currency_rupee_rounded, '₹${entry.expense!.toStringAsFixed(0)} kharch', const Color(0xFFF59E0B)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Trailing 3-dot popup menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 18),
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) async {
                    if (val == 'edit') {
                      _showAddEditEntrySheet(context, accent, entryToEdit: entry);
                    } else if (val == 'toggle') {
                      await RoutineService.updateEntry(entry.copyWith(isCompleted: !entry.isCompleted));
                    } else if (val == 'delete') {
                      _confirmDeleteEntry(context, entry);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(entry.isCompleted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: const Color(0xFF10B981), size: 18),
                          const SizedBox(width: 8),
                          Text(entry.isCompleted ? 'Mark Pending' : 'Mark Completed', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, color: Color(0xFF38BDF8), size: 18),
                          const SizedBox(width: 8),
                          Text('Edit Entry', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 8),
                          Text('Delete Entry', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaBadge(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w500)),
      ],
    );
  }

  /// Confirm Entry Deletion
  void _confirmDeleteEntry(BuildContext context, RoutineEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Entry?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Kya aap "${entry.title}" ko delete karna chahte hain?', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.pop(ctx);
              await RoutineService.deleteEntry(entry.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Add / Edit Work Entry Bottom Sheet
  void _showAddEditEntrySheet(BuildContext context, AppAccentTheme accent, {RoutineEntry? entryToEdit}) {
    final isEditing = entryToEdit != null;
    final titleController = TextEditingController(text: entryToEdit?.title ?? '');
    final hoursController = TextEditingController(text: entryToEdit?.hoursSpent?.toString() ?? '');
    final expenseController = TextEditingController(text: entryToEdit?.expense?.toString() ?? '');
    final notesController = TextEditingController(text: entryToEdit?.notes ?? '');

    String selectedCatId = entryToEdit?.categoryId ??
        (_selectedCategoryFilter != 'all' ? _selectedCategoryFilter : RoutineService.allCategories.first.id);

    DateTime selectedDate = entryToEdit?.date ?? (_selectedDateFilter ?? DateTime.now());
    TimeOfDay? selectedTime = entryToEdit?.time != null
        ? _parseTimeOfDay(entryToEdit!.time!)
        : TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final category = RoutineService.getCategory(selectedCatId);

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                left: 18,
                right: 18,
                top: 14,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                border: Border.all(color: accent.light.withValues(alpha: 0.35), width: 1.5),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF475569),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Sheet Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'Kaam Edit Karein' : 'Naya Kaam Darj Karein',
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title Input
                    const Text('Kaam ka Naam / Title *', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Jaise: Khet me paani lagaya, Market se samaan laya...',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Category Chuniye *', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                        GestureDetector(
                          onTap: () {
                            _showAddCategoryDialog(context, accent, onAdded: (newCat) {
                              setModalState(() {
                                selectedCatId = newCat.id;
                              });
                            });
                          },
                          child: Text(
                            '+ Nayi Category',
                            style: TextStyle(color: accent.light, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: RoutineService.allCategories.map((cat) {
                          final isSelected = cat.id == selectedCatId;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              selected: isSelected,
                              backgroundColor: const Color(0xFF1E293B),
                              selectedColor: cat.color.withValues(alpha: 0.25),
                              side: BorderSide(
                                color: isSelected ? cat.color : const Color(0xFF334155),
                                width: isSelected ? 1.5 : 1,
                              ),
                              avatar: Icon(cat.iconData, color: isSelected ? cat.color : const Color(0xFF94A3B8), size: 15),
                              label: Text(
                                cat.name,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              onSelected: (_) {
                                setModalState(() {
                                  selectedCatId = cat.id;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Date & Time pickers
                    Row(
                      children: [
                        // Date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tareekh / Date', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: ColorScheme.dark(
                                            primary: accent.primary,
                                            surface: const Color(0xFF1E293B),
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      selectedDate = picked;
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_month_rounded, color: accent.light, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('dd MMM yyyy').format(selectedDate),
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Waqt / Time (Optional)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: selectedTime ?? TimeOfDay.now(),
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      selectedTime = picked;
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, color: accent.light, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        selectedTime != null ? selectedTime!.format(context) : 'Set Time',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Hours spent & Expense (Optional)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Kitne Ghante Laga? (hrs)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: hoursController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 2.5',
                                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                  filled: true,
                                  fillColor: const Color(0xFF1E293B),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  prefixIcon: const Icon(Icons.timer_outlined, color: Color(0xFF38BDF8), size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Kharch Hua? (₹)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: expenseController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 500',
                                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                  filled: true,
                                  fillColor: const Color(0xFF1E293B),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Color(0xFFF59E0B), size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Notes / Description
                    const Text('Khaas Jankari / Remarks (Optional)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Kaam ke baare me kuch aur likhna chahte hain...',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        onPressed: () async {
                          final title = titleController.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kripya kaam ka naam / title darj karein.'),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                            return;
                          }

                          final hours = double.tryParse(hoursController.text.trim());
                          final expense = double.tryParse(expenseController.text.trim());
                          final formattedTime = selectedTime != null ? selectedTime!.format(context) : null;

                          if (isEditing) {
                            await RoutineService.updateEntry(
                              entryToEdit.copyWith(
                                title: title,
                                categoryId: category.id,
                                categoryName: category.name,
                                date: selectedDate,
                                time: formattedTime,
                                hoursSpent: hours,
                                expense: expense,
                                notes: notesController.text.trim(),
                              ),
                            );
                          } else {
                            await RoutineService.addEntry(
                              title: title,
                              categoryId: category.id,
                              categoryName: category.name,
                              date: selectedDate,
                              time: formattedTime,
                              hoursSpent: hours,
                              expense: expense,
                              notes: notesController.text.trim(),
                            );
                          }

                          Navigator.pop(sheetContext);
                        },
                        child: Text(
                          isEditing ? 'Update Kaam' : 'Save Kaam',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    try {
      final format = DateFormat.jm(); // e.g. "5:08 PM"
      final dt = format.parse(timeStr);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      return null;
    }
  }

  /// Add Custom Category Dialog
  void _showAddCategoryDialog(BuildContext context, AppAccentTheme accent, {ValueChanged<RoutineCategory>? onAdded}) {
    final nameController = TextEditingController();
    Color selectedColor = _paletteColors.first;
    IconData selectedIcon = _paletteIcons.first;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Icon(Icons.new_label_rounded, color: accent.light, size: 22),
              const SizedBox(width: 8),
              const Text('Nayi Category Banayein', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Category ka Naam', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Jaise: Gym & Fitness, Study, Construction...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),

                // Color Picker
                const Text('Rang / Color', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _paletteColors.map((c) {
                    final isSel = c.value == selectedColor.value;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: isSel ? Colors.white : Colors.transparent, width: 2),
                        ),
                        child: isSel ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Icon Picker
                const Text('Icon Chuniye', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _paletteIcons.map((ic) {
                    final isSel = ic.codePoint == selectedIcon.codePoint;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIcon = ic),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSel ? selectedColor.withValues(alpha: 0.3) : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSel ? selectedColor : const Color(0xFF334155)),
                        ),
                        child: Icon(ic, size: 18, color: isSel ? selectedColor : const Color(0xFF94A3B8)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: accent.primary),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final colorHex = '#${selectedColor.value.toRadixString(16).substring(2)}';
                final newCat = await RoutineService.addCustomCategory(
                  name: name,
                  iconCode: selectedIcon.codePoint,
                  colorHex: colorHex,
                );

                Navigator.pop(dialogCtx);
                if (onAdded != null) onAdded(newCat);
                if (mounted) setState(() {});
              },
              child: const Text('Save Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog to view/delete custom categories
  void _showManageCategoriesDialog(BuildContext context, AppAccentTheme accent) {
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final customList = RoutineService.allCategories.where((c) => c.isCustom).toList();

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Categories', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('5 Inbuilt Categories (Default):', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: RoutineService.defaultCategories.map((c) {
                      return Chip(
                        backgroundColor: const Color(0xFF0F172A),
                        side: BorderSide(color: c.color.withValues(alpha: 0.5)),
                        avatar: Icon(c.iconData, size: 14, color: c.color),
                        label: Text(c.name, style: TextStyle(color: c.color, fontSize: 10.5, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Aapki Custom Categories:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      TextButton.icon(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                        onPressed: () {
                          Navigator.pop(dialogCtx);
                          _showAddCategoryDialog(context, accent);
                        },
                        icon: Icon(Icons.add, size: 14, color: accent.light),
                        label: Text('Add New', style: TextStyle(color: accent.light, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (customList.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Koi custom category nahi hai.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    )
                  else
                    ...customList.map((cat) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(cat.iconData, color: cat.color, size: 20),
                        title: Text(cat.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                          onPressed: () async {
                            await RoutineService.deleteCustomCategory(cat.id);
                            setDialogState(() {});
                            if (mounted) setState(() {});
                          },
                        ),
                      );
                    }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Close', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            ],
          );
        },
      ),
    );
  }
}
