import 'package:flutter/material.dart';

const categoryIcons = <String, IconData>{
  'Dairy & eggs': Icons.egg_outlined,
  'Fruits': Icons.apple,
  'Vegetables': Icons.eco_outlined,
  'Grains & flours': Icons.grain,
  'Pulses & dals': Icons.rice_bowl_outlined,
  'Spices & masalas': Icons.local_fire_department_outlined,
  'Oils & ghee': Icons.opacity,
  'Bakery & breakfast': Icons.bakery_dining_outlined,
  'Snacks & beverages': Icons.local_cafe_outlined,
  'Cleaning & household': Icons.cleaning_services_outlined,
  'Personal care': Icons.soap_outlined,
  'Baby & pet': Icons.child_care_outlined,
  'Pooja & festive': Icons.local_fire_department_outlined,
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
