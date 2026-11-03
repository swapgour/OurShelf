import 'package:flutter/material.dart';

/// A starter catalogue entry: tap to add straight to the shared list.
///
/// Covers every example item named in the product spec's "what's
/// pre-loaded" table — a hand-picked stand-in for the full ~300-item photo
/// catalogue; swapping in real product photos and the full regional set is
/// a later milestone.
class CatalogueItem {
  const CatalogueItem(this.name, this.category, this.unit, this.icon);

  final String name;
  final String category;
  final String unit;
  final IconData icon;
}

const List<CatalogueItem> starterCatalogue = [
  // Dairy & eggs
  CatalogueItem('Milk', 'Dairy & eggs', '500 ml', Icons.local_drink),
  CatalogueItem('Curd', 'Dairy & eggs', 'pack', Icons.icecream),
  CatalogueItem('Paneer', 'Dairy & eggs', '200 g', Icons.lunch_dining),
  CatalogueItem('Butter', 'Dairy & eggs', 'pack', Icons.bakery_dining),
  CatalogueItem('Ghee', 'Dairy & eggs', '500 g', Icons.opacity),
  CatalogueItem('Cheese', 'Dairy & eggs', 'pack', Icons.lunch_dining),
  CatalogueItem('Eggs', 'Dairy & eggs', 'dozen', Icons.egg),
  // Fruits
  CatalogueItem('Banana', 'Fruits', 'dozen', Icons.emoji_food_beverage),
  CatalogueItem('Apple', 'Fruits', 'kg', Icons.apple),
  CatalogueItem('Mango', 'Fruits', 'kg', Icons.local_florist),
  CatalogueItem('Papaya', 'Fruits', 'pc', Icons.local_florist),
  CatalogueItem('Orange', 'Fruits', 'kg', Icons.circle),
  CatalogueItem('Grapes', 'Fruits', 'kg', Icons.grain),
  CatalogueItem('Pomegranate', 'Fruits', 'kg', Icons.circle),
  // Vegetables
  CatalogueItem('Onion', 'Vegetables', 'kg', Icons.eco),
  CatalogueItem('Potato', 'Vegetables', 'kg', Icons.eco),
  CatalogueItem('Tomato', 'Vegetables', 'kg', Icons.eco),
  CatalogueItem('Ginger', 'Vegetables', '100 g', Icons.eco),
  CatalogueItem('Garlic', 'Vegetables', '100 g', Icons.eco),
  CatalogueItem('Green chilli', 'Vegetables', '100 g', Icons.eco),
  CatalogueItem('Spinach', 'Vegetables', 'bunch', Icons.eco),
  CatalogueItem('Coriander', 'Vegetables', 'bunch', Icons.eco),
  // Grains & flours
  CatalogueItem('Rice', 'Grains & flours', 'kg', Icons.rice_bowl),
  CatalogueItem('Atta (wheat flour)', 'Grains & flours', 'kg', Icons.grain),
  CatalogueItem('Maida', 'Grains & flours', 'kg', Icons.grain),
  CatalogueItem('Suji', 'Grains & flours', 'kg', Icons.grain),
  CatalogueItem('Poha', 'Grains & flours', 'kg', Icons.grain),
  CatalogueItem('Oats', 'Grains & flours', 'pack', Icons.grain),
  // Pulses & dals
  CatalogueItem('Toor dal', 'Pulses & dals', 'kg', Icons.grain),
  CatalogueItem('Moong dal', 'Pulses & dals', 'kg', Icons.grain),
  CatalogueItem('Chana dal', 'Pulses & dals', 'kg', Icons.grain),
  CatalogueItem('Masoor dal', 'Pulses & dals', 'kg', Icons.grain),
  CatalogueItem('Rajma', 'Pulses & dals', 'kg', Icons.grain),
  CatalogueItem('Chole', 'Pulses & dals', 'kg', Icons.grain),
  // Spices & masalas
  CatalogueItem('Turmeric', 'Spices & masalas', '100 g', Icons.spa),
  CatalogueItem('Chilli powder', 'Spices & masalas', '100 g', Icons.spa),
  CatalogueItem('Jeera', 'Spices & masalas', '100 g', Icons.spa),
  CatalogueItem('Garam masala', 'Spices & masalas', '100 g', Icons.spa),
  CatalogueItem('Salt', 'Spices & masalas', 'kg', Icons.spa),
  // Oils & ghee
  CatalogueItem('Sunflower oil', 'Oils & ghee', '1 L', Icons.opacity),
  CatalogueItem('Mustard oil', 'Oils & ghee', '1 L', Icons.opacity),
  CatalogueItem('Groundnut oil', 'Oils & ghee', '1 L', Icons.opacity),
  // Bakery & breakfast
  CatalogueItem('Bread', 'Bakery & breakfast', 'pack', Icons.bakery_dining),
  CatalogueItem('Biscuits', 'Bakery & breakfast', 'pack', Icons.cookie),
  CatalogueItem('Cornflakes', 'Bakery & breakfast', 'pack', Icons.breakfast_dining),
  CatalogueItem('Jam', 'Bakery & breakfast', 'jar', Icons.breakfast_dining),
  // Snacks & beverages
  CatalogueItem('Namkeen', 'Snacks & beverages', 'pack', Icons.fastfood),
  CatalogueItem('Chips', 'Snacks & beverages', 'pack', Icons.fastfood),
  CatalogueItem('Tea', 'Snacks & beverages', 'pack', Icons.emoji_food_beverage),
  CatalogueItem('Coffee', 'Snacks & beverages', 'pack', Icons.coffee),
  CatalogueItem('Juice', 'Snacks & beverages', '1 L', Icons.local_bar),
  // Cleaning & household
  CatalogueItem('Detergent', 'Cleaning & household', 'pack', Icons.local_laundry_service),
  CatalogueItem('Dishwash liquid', 'Cleaning & household', 'bottle', Icons.soap),
  CatalogueItem('Floor cleaner', 'Cleaning & household', 'bottle', Icons.cleaning_services),
  CatalogueItem('Garbage bags', 'Cleaning & household', 'pack', Icons.delete_outline),
  // Personal care
  CatalogueItem('Soap', 'Personal care', 'pack', Icons.bathtub),
  CatalogueItem('Shampoo', 'Personal care', 'bottle', Icons.shower),
  CatalogueItem('Toothpaste', 'Personal care', 'tube', Icons.health_and_safety),
  CatalogueItem('Sanitary items', 'Personal care', 'pack', Icons.health_and_safety),
  // Baby & pet
  CatalogueItem('Diapers', 'Baby & pet', 'pack', Icons.child_care),
  CatalogueItem('Baby food', 'Baby & pet', 'pack', Icons.child_care),
  CatalogueItem('Pet food', 'Baby & pet', 'pack', Icons.pets),
];

const List<String> catalogueCategories = [
  'Dairy & eggs',
  'Fruits',
  'Vegetables',
  'Grains & flours',
  'Pulses & dals',
  'Spices & masalas',
  'Oils & ghee',
  'Bakery & breakfast',
  'Snacks & beverages',
  'Cleaning & household',
  'Personal care',
  'Baby & pet',
];
