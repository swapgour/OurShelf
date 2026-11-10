import 'package:flutter/material.dart';

const categoryIcons = <String, IconData>{
  'Vegetables': Icons.eco_outlined,
  'Fruits': Icons.apple,
  'Dairy & Eggs': Icons.egg_outlined,
  'Grains & Flours': Icons.grain,
  'Pulses & Dals': Icons.rice_bowl_outlined,
  'Spices & Masalas': Icons.local_fire_department_outlined,
  'Oils & Ghee': Icons.opacity,
  'Dry Fruits & Nuts': Icons.icecream_outlined,
  'Breakfast & Cereals': Icons.bakery_dining_outlined,
  'Ready Mixes': Icons.soup_kitchen_outlined,
  'Snacks & Sweets': Icons.fastfood_outlined,
  'Beverages': Icons.local_cafe_outlined,
  'Cleaning & Household': Icons.cleaning_services_outlined,
  'Personal Care & Healthcare': Icons.soap_outlined,
  'Pooja & Religious Items': Icons.self_improvement_outlined,
  'Household Utilities': Icons.lightbulb_outline,
  'Services & Expenses': Icons.handyman_outlined,
  'Baby & Pet': Icons.child_care_outlined,
  // Household bills & transfers — not groceries, but tracked the same way
  // so they share Expenses/Reports totals and the Activity feed for free.
  'House EMI': Icons.home_work_outlined,
  'Internet Bill': Icons.wifi,
  'Mobile Recharge': Icons.smartphone_outlined,
  'Electricity Bill': Icons.bolt_outlined,
  'Transfer to Parents': Icons.family_restroom_outlined,
  'Other Bill': Icons.receipt_long_outlined,
};

/// Bill/transfer categories offered when logging a household expense that
/// isn't a grocery purchase — kept separate from [starterCatalogue] since
/// these have no quantity/unit and never belong on the shopping list.
const billCategories = <String>[
  'House EMI',
  'Internet Bill',
  'Mobile Recharge',
  'Electricity Bill',
  'Transfer to Parents',
  'Other Bill',
];

/// Jewel-toned palette so category accents match the app's royal theme.
const categoryPalette = <Color>[
  Color(0xFF6A1B9A), // amethyst
  Color(0xFFC9A227), // gold
  Color(0xFF00695C), // emerald
  Color(0xFF1565C0), // sapphire
  Color(0xFFC62828), // ruby
  Color(0xFF4527A0), // royal indigo
  Color(0xFF00838F), // teal sapphire
  Color(0xFF8D6E63), // bronze
];

IconData iconForCategory(String category) =>
    categoryIcons[category] ?? Icons.shopping_basket_outlined;

Color colorForCategory(String category) =>
    categoryPalette[category.hashCode.abs() % categoryPalette.length];

/// Categories whose products are normally sold/measured by weight or
/// count, never by volume — used to flag a likely-stale unit (e.g.
/// "Groundnut" still showing "1 L" from when it was miscategorized as an
/// oil) without ever changing it automatically; the user reviews and
/// corrects it by hand.
const _solidCategories = {
  'Dry Fruits & Nuts',
  'Spices & Masalas',
  'Pulses & Dals',
  'Grains & Flours',
  'Snacks & Sweets',
  'Breakfast & Cereals',
  'Ready Mixes',
};

bool unitLooksOffForCategory(String category, String unit) {
  if (!_solidCategories.contains(category)) return false;
  final u = unit.toLowerCase();
  return u.contains('ml') ||
      u.contains('litre') ||
      u.contains('liter') ||
      RegExp(r'(^|\s)l$').hasMatch(u.trim()) ||
      u.contains('bottle');
}
