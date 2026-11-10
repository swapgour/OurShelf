/// One line of a starter template: a catalogue item name plus a quantity
/// suited to that template's household size.
class TemplateLine {
  const TemplateLine(this.name, this.category, this.quantity, this.unit);

  final String name;
  final String category;
  final String quantity;
  final String unit;
}

class ListTemplate {
  const ListTemplate(this.name, this.description, this.lines);

  final String name;
  final String description;
  final List<TemplateLine> lines;
}

/// Ready lists a group can load in one tap instead of building a first list
/// item by item.
const List<ListTemplate> starterTemplates = [
  ListTemplate('Indian family of 4 – monthly', 'Monthly essentials for a family', [
    TemplateLine('Rice', 'Grains & Flours', '10', 'kg'),
    TemplateLine('Atta (wheat flour)', 'Grains & Flours', '5', 'kg'),
    TemplateLine('Toor dal', 'Pulses & Dals', '2', 'kg'),
    TemplateLine('Moong dal', 'Pulses & Dals', '1', 'kg'),
    TemplateLine('Sunflower oil', 'Oils & Ghee', '2', 'L'),
    TemplateLine('Onion', 'Vegetables', '5', 'kg'),
    TemplateLine('Potato', 'Vegetables', '5', 'kg'),
    TemplateLine('Milk', 'Dairy & Eggs', '30', '500 ml'),
    TemplateLine('Eggs', 'Dairy & Eggs', '2', 'dozen'),
    TemplateLine('Turmeric', 'Spices & Masalas', '1', '100 g'),
    TemplateLine('Chilli powder', 'Spices & Masalas', '1', '100 g'),
    TemplateLine('Salt', 'Spices & Masalas', '1', 'kg'),
    TemplateLine('Tea', 'Beverages', '1', 'pack'),
    TemplateLine('Detergent', 'Cleaning & Household', '1', 'pack'),
    TemplateLine('Soap', 'Personal Care & Healthcare', '4', 'pack'),
  ]),
  ListTemplate('Couple – weekly', 'A week of groceries for two', [
    TemplateLine('Milk', 'Dairy & Eggs', '7', '500 ml'),
    TemplateLine('Eggs', 'Dairy & Eggs', '1', 'dozen'),
    TemplateLine('Bread', 'Breakfast & Cereals', '1', 'pack'),
    TemplateLine('Rice', 'Grains & Flours', '2', 'kg'),
    TemplateLine('Onion', 'Vegetables', '1', 'kg'),
    TemplateLine('Tomato', 'Vegetables', '1', 'kg'),
    TemplateLine('Banana', 'Fruits', '1', 'dozen'),
    TemplateLine('Tea', 'Beverages', '1', 'pack'),
    TemplateLine('Dishwash liquid', 'Cleaning & Household', '1', 'bottle'),
  ]),
  ListTemplate('Bachelor – basics', 'Simple living essentials', [
    TemplateLine('Milk', 'Dairy & Eggs', '3', '500 ml'),
    TemplateLine('Eggs', 'Dairy & Eggs', '1', 'dozen'),
    TemplateLine('Bread', 'Breakfast & Cereals', '1', 'pack'),
    TemplateLine('Rice', 'Grains & Flours', '1', 'kg'),
    TemplateLine('Namkeen', 'Snacks & Sweets', '1', 'pack'),
    TemplateLine('Coffee', 'Beverages', '1', 'pack'),
    TemplateLine('Dishwash liquid', 'Cleaning & Household', '1', 'bottle'),
    TemplateLine('Garbage bags', 'Cleaning & Household', '1', 'pack'),
  ]),
  ListTemplate('New baby', 'Household plus baby essentials', [
    TemplateLine('Diapers', 'Baby & Pet', '2', 'pack'),
    TemplateLine('Baby food', 'Baby & Pet', '2', 'pack'),
    TemplateLine('Milk', 'Dairy & Eggs', '14', '500 ml'),
    TemplateLine('Sanitary items', 'Personal Care & Healthcare', '1', 'pack'),
    TemplateLine('Detergent', 'Cleaning & Household', '1', 'pack'),
  ]),
  ListTemplate('Diwali', 'Festival shopping essentials', [
    TemplateLine('Ghee', 'Dairy & Eggs', '1', 'kg'),
    TemplateLine('Sunflower oil', 'Oils & Ghee', '2', 'L'),
    TemplateLine('Rice', 'Grains & Flours', '5', 'kg'),
    TemplateLine('Biscuits', 'Breakfast & Cereals', '4', 'pack'),
    TemplateLine('Namkeen', 'Snacks & Sweets', '3', 'pack'),
    TemplateLine('Milk', 'Dairy & Eggs', '4', '500 ml'),
    TemplateLine('Camphor', 'Pooja & Religious Items', '1', 'pack'),
    TemplateLine('Diya', 'Pooja & Religious Items', '1', 'pack'),
  ]),
  ListTemplate('Christmas', 'Festive essentials for the season', [
    TemplateLine('Butter', 'Dairy & Eggs', '2', 'pack'),
    TemplateLine('Eggs', 'Dairy & Eggs', '2', 'dozen'),
    TemplateLine('Maida', 'Grains & Flours', '2', 'kg'),
    TemplateLine('Cheese', 'Dairy & Eggs', '2', 'pack'),
    TemplateLine('Juice', 'Beverages', '2', '1 L'),
  ]),
  ListTemplate('Eid', 'Festival shopping essentials', [
    TemplateLine('Rice', 'Grains & Flours', '5', 'kg'),
    TemplateLine('Ghee', 'Dairy & Eggs', '1', 'kg'),
    TemplateLine('Milk', 'Dairy & Eggs', '4', '500 ml'),
    TemplateLine('Garam masala', 'Spices & Masalas', '1', '100 g'),
    TemplateLine('Biscuits', 'Breakfast & Cereals', '4', 'pack'),
  ]),
];
