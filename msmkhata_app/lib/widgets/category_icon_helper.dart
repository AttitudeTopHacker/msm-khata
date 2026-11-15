import 'package:flutter/material.dart';

class CategoryVisual {
  final IconData icon;
  final Color color;

  const CategoryVisual({required this.icon, required this.color});
}

class CategoryIconHelper {
  /// Returns a tailored icon and color for a transaction based on its category name,
  /// transaction type, and any custom category hex color.
  static CategoryVisual getVisual({
    String? categoryName,
    String? type,
    String? categoryColorHex,
  }) {
    // 1. If explicit category color is passed in hex format (#RRGGBB or #AARRGGBB)
    Color? parsedColor;
    if (categoryColorHex != null && categoryColorHex.isNotEmpty) {
      try {
        String cleanHex = categoryColorHex.replaceAll('#', '');
        if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
        parsedColor = Color(int.parse(cleanHex, radix: 16));
      } catch (_) {}
    }

    final catLower = (categoryName ?? '').trim().toLowerCase();
    final typeUpper = (type ?? '').trim().toUpperCase();

    // 2. Resolve category icon and color by matching keywords
    if (catLower.isNotEmpty) {
      // Household / Home
      if (catLower.contains('house') ||
          catLower.contains('home') ||
          catLower.contains('ghar') ||
          catLower.contains('room')) {
        return CategoryVisual(
          icon: Icons.home_rounded,
          color: parsedColor ?? const Color(0xFFF59E0B), // Warm Amber
        );
      }

      // Personal
      if (catLower.contains('person') ||
          catLower.contains('self') ||
          catLower.contains('apna') ||
          catLower.contains('niz')) {
        return CategoryVisual(
          icon: Icons.person_rounded,
          color: parsedColor ?? const Color(0xFF818CF8), // Indigo
        );
      }

      // Agriculture / Farming / Ploughing
      if (catLower.contains('plough') ||
          catLower.contains('jutai') ||
          catLower.contains('tractor') ||
          catLower.contains('khet')) {
        return CategoryVisual(
          icon: Icons.agriculture_rounded,
          color: parsedColor ?? const Color(0xFF84CC16), // Lime Green
        );
      }

      // Food / Restaurant / Dining / Cafe
      if (catLower.contains('food') ||
          catLower.contains('khana') ||
          catLower.contains('hotel') ||
          catLower.contains('cafe') ||
          catLower.contains('restaurant') ||
          catLower.contains('nashta')) {
        return CategoryVisual(
          icon: Icons.restaurant_rounded,
          color: parsedColor ?? const Color(0xFF10B981), // Emerald
        );
      }

      // Grocery / Kirana / Market
      if (catLower.contains('grocery') ||
          catLower.contains('kirana') ||
          catLower.contains('rashan') ||
          catLower.contains('sabzi') ||
          catLower.contains('mandi')) {
        return CategoryVisual(
          icon: Icons.local_grocery_store_rounded,
          color: parsedColor ?? const Color(0xFF06B6D4), // Cyan
        );
      }

      // Fuel / Diesel / Petrol / Gas
      if (catLower.contains('diesel') ||
          catLower.contains('fuel') ||
          catLower.contains('petrol') ||
          catLower.contains('gas') ||
          catLower.contains('oil') ||
          catLower.contains('cng')) {
        return CategoryVisual(
          icon: Icons.local_gas_station_rounded,
          color: parsedColor ?? const Color(0xFFEF4444), // Red
        );
      }

      // Fertilizer / Seeds / Pesticide
      if (catLower.contains('fertil') ||
          catLower.contains('seed') ||
          catLower.contains('beej') ||
          catLower.contains('khaad') ||
          catLower.contains('pesticide') ||
          catLower.contains('dawai-khet')) {
        return CategoryVisual(
          icon: Icons.spa_rounded,
          color: parsedColor ?? const Color(0xFF14B8A6), // Teal
        );
      }

      // Irrigation / Water / Sinchai
      if (catLower.contains('water') ||
          catLower.contains('irrigat') ||
          catLower.contains('sinch') ||
          catLower.contains('pani') ||
          catLower.contains('pumping')) {
        return CategoryVisual(
          icon: Icons.water_drop_rounded,
          color: parsedColor ?? const Color(0xFF0284C7), // Sky Blue
        );
      }

      // Labour / Mazdoor / Wages
      if (catLower.contains('labour') ||
          catLower.contains('mazdoor') ||
          catLower.contains('wage') ||
          catLower.contains('worker') ||
          catLower.contains('majdoori')) {
        return CategoryVisual(
          icon: Icons.groups_rounded,
          color: parsedColor ?? const Color(0xFF8B5CF6), // Purple
        );
      }

      // Shopping / Clothing / Clothes / Bazaar
      if (catLower.contains('shop') ||
          catLower.contains('cloth') ||
          catLower.contains('kapde') ||
          catLower.contains('kharid') ||
          catLower.contains('mall')) {
        return CategoryVisual(
          icon: Icons.shopping_bag_rounded,
          color: parsedColor ?? const Color(0xFFEC4899), // Pink
        );
      }

      // Medical / Health / Hospital / Pharmacy
      if (catLower.contains('medic') ||
          catLower.contains('health') ||
          catLower.contains('doctor') ||
          catLower.contains('dawai') ||
          catLower.contains('hospital') ||
          catLower.contains('clinic')) {
        return CategoryVisual(
          icon: Icons.medical_services_rounded,
          color: parsedColor ?? const Color(0xFFF43F5E), // Rose
        );
      }

      // Travel / Transport / Vehicle / Car / Bike
      if (catLower.contains('travel') ||
          catLower.contains('transport') ||
          catLower.contains('gaadi') ||
          catLower.contains('bus') ||
          catLower.contains('train') ||
          catLower.contains('cab') ||
          catLower.contains('bike') ||
          catLower.contains('auto')) {
        return CategoryVisual(
          icon: Icons.directions_car_rounded,
          color: parsedColor ?? const Color(0xFF3B82F6), // Blue
        );
      }

      // Utility Bills / Electricity / Recharge / Mobile
      if (catLower.contains('bill') ||
          catLower.contains('elect') ||
          catLower.contains('bijli') ||
          catLower.contains('recharge') ||
          catLower.contains('mobile') ||
          catLower.contains('wifi') ||
          catLower.contains('internet')) {
        return CategoryVisual(
          icon: Icons.receipt_long_rounded,
          color: parsedColor ?? const Color(0xFFD97706), // Amber
        );
      }

      // Education / Fees / School / College / Books
      if (catLower.contains('educat') ||
          catLower.contains('school') ||
          catLower.contains('college') ||
          catLower.contains('fee') ||
          catLower.contains('book') ||
          catLower.contains('padhai')) {
        return CategoryVisual(
          icon: Icons.school_rounded,
          color: parsedColor ?? const Color(0xFF6366F1), // Indigo
        );
      }

      // Rental / Kiraya
      if (catLower.contains('rent') ||
          catLower.contains('kiraya') ||
          catLower.contains('bhaada')) {
        return CategoryVisual(
          icon: Icons.real_estate_agent_rounded,
          color: parsedColor ?? const Color(0xFF7C3AED), // Violet
        );
      }

      // Salary / Income / Kamai
      if (catLower.contains('salary') ||
          catLower.contains('income') ||
          catLower.contains('kamai') ||
          catLower.contains('tankhwah') ||
          catLower.contains('profit')) {
        return CategoryVisual(
          icon: Icons.payments_rounded,
          color: parsedColor ?? const Color(0xFF10B981), // Emerald
        );
      }

      // Entertainment / Movies / Sports
      if (catLower.contains('entertain') ||
          catLower.contains('movie') ||
          catLower.contains('cinema') ||
          catLower.contains('game') ||
          catLower.contains('sport')) {
        return CategoryVisual(
          icon: Icons.movie_rounded,
          color: parsedColor ?? const Color(0xFFA855F7), // Light Purple
        );
      }

      // Dairy / Milk
      if (catLower.contains('dairy') ||
          catLower.contains('milk') ||
          catLower.contains('doodh')) {
        return CategoryVisual(
          icon: Icons.coffee_rounded,
          color: parsedColor ?? const Color(0xFF38BDF8),
        );
      }

      // Crops / Harvest
      if (catLower.contains('paddy') || catLower.contains('dhan')) {
        return CategoryVisual(
          icon: Icons.grass_rounded,
          color: parsedColor ?? const Color(0xFF10B981),
        );
      }
      if (catLower.contains('wheat') ||
          catLower.contains('gehu') ||
          catLower.contains('grain')) {
        return CategoryVisual(
          icon: Icons.grain_rounded,
          color: parsedColor ?? const Color(0xFFF59E0B),
        );
      }
      if (catLower.contains('sugar') || catLower.contains('ganna')) {
        return CategoryVisual(
          icon: Icons.eco_rounded,
          color: parsedColor ?? const Color(0xFF84CC16),
        );
      }

      // Tools / Machinery / Equipment
      if (catLower.contains('machin') ||
          catLower.contains('tool') ||
          catLower.contains('equip') ||
          catLower.contains('repair')) {
        return CategoryVisual(
          icon: Icons.handyman_rounded,
          color: parsedColor ?? const Color(0xFFF97316),
        );
      }

      // Generic category with parsed color or default
      return CategoryVisual(
        icon: Icons.category_rounded,
        color: parsedColor ?? const Color(0xFFF59E0B),
      );
    }

    // 3. Fallback based on Transaction Type (GIVEN, TAKEN, INCOME, EXPENSE)
    if (typeUpper == 'GIVEN') {
      return const CategoryVisual(
        icon: Icons.arrow_outward_rounded,
        color: Color(0xFF38BDF8), // Lent: Sky Blue
      );
    } else if (typeUpper == 'TAKEN') {
      return const CategoryVisual(
        icon: Icons.arrow_downward_rounded,
        color: Color(0xFFF59E0B), // Borrowed: Amber Orange (Previous Expense color)
      );
    } else if (typeUpper == 'INCOME') {
      return const CategoryVisual(
        icon: Icons.account_balance_wallet_rounded,
        color: Color(0xFF10B981), // Income: Green
      );
    }

    return const CategoryVisual(
      icon: Icons.receipt_rounded,
      color: Color(0xFFEF4444), // Expense: Red
    );
  }
}

