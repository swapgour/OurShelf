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
    TemplateLine('Rice', 'Grains & flours', '10', 'kg'),
    TemplateLine('Atta (wheat flour)', 'Grains & flours', '5', 'kg'),
    TemplateLine('Toor dal', 'Pulses & dals', '2', 'kg'),
    TemplateLine('Moong dal', 'Pulses & dals', '1', 'kg'),
    TemplateLine('Sunflower oil', 'Oils & ghee', '2', 'L'),
    TemplateLine('Onion', 'Vegetables', '5', 'kg'),
    TemplateLine('Potato', 'Vegetables', '5', 'kg'),
    TemplateLine('Milk', 'Dairy & eggs', '30', '500 ml'),
    TemplateLine('Eggs', 'Dairy & eggs', '2', 'dozen'),
    TemplateLine('Turmeric', 'Spices & masalas', '1', '100 g'),
    TemplateLine('Chilli powder', 'Spices & masalas', '1', '100 g'),
    TemplateLine('Salt', 'Spices & masalas', '1', 'kg'),
    TemplateLine('Tea', 'Snacks & beverages', '1', 'pack'),
    TemplateLine('Detergent', 'Cleaning & household', '1', 'pack'),
    TemplateLine('Soap', 'Personal care', '4', 'pack'),
  ]),
  ListTemplate('Couple – weekly', 'A week of groceries for two', [
    TemplateLine('Milk', 'Dairy & eggs', '7', '500 ml'),
    TemplateLine('Eggs', 'Dairy & eggs', '1', 'dozen'),
    TemplateLine('Bread', 'Bakery & breakfast', '1', 'pack'),
    TemplateLine('Rice', 'Grains & flours', '2', 'kg'),
    TemplateLine('Onion', 'Vegetables', '1', 'kg'),
    TemplateLine('Tomato', 'Vegetables', '1', 'kg'),
    TemplateLine('Banana', 'Fruits', '1', 'dozen'),
    TemplateLine('Tea', 'Snacks & beverages', '1', 'pack'),
    TemplateLine('Dishwash liquid', 'Cleaning & household', '1', 'bottle'),
  ]),
  ListTemplate('Bachelor – basics', 'Simple living essentials', [
    TemplateLine('Milk', 'Dairy & eggs', '3', '500 ml'),
    TemplateLine('Eggs', 'Dairy & eggs', '1', 'dozen'),
    TemplateLine('Bread', 'Bakery & breakfast', '1', 'pack'),
    TemplateLine('Rice', 'Grains & flours', '1', 'kg'),
    TemplateLine('Namkeen', 'Snacks & beverages', '1', 'pack'),
    TemplateLine('Coffee', 'Snacks & beverages', '1', 'pack'),
    TemplateLine('Dishwash liquid', 'Cleaning & household', '1', 'bottle'),
    TemplateLine('Garbage bags', 'Cleaning & household', '1', 'pack'),
  ]),
  ListTemplate('New baby', 'Household plus baby essentials', [
    TemplateLine('Diapers', 'Baby & pet', '2', 'pack'),
    TemplateLine('Baby food', 'Baby & pet', '2', 'pack'),
    TemplateLine('Milk', 'Dairy & eggs', '14', '500 ml'),
    TemplateLine('Sanitary items', 'Personal care', '1', 'pack'),
    TemplateLine('Detergent', 'Cleaning & household', '1', 'pack'),
  ]),
  ListTemplate('Diwali', 'Festival shopping essentials', [
    TemplateLine('Ghee', 'Dairy & eggs', '1', 'kg'),
    TemplateLine('Sunflower oil', 'Oils & ghee', '2', 'L'),
    TemplateLine('Rice', 'Grains & flours', '5', 'kg'),
    TemplateLine('Biscuits', 'Bakery & breakfast', '4', 'pack'),
    TemplateLine('Namkeen', 'Snacks & beverages', '3', 'pack'),
    TemplateLine('Milk', 'Dairy & eggs', '4', '500 ml'),
  ]),
  ListTemplate('Christmas', 'Festive essentials for the season', [
    TemplateLine('Butter', 'Dairy & eggs', '2', 'pack'),
    TemplateLine('Eggs', 'Dairy & eggs', '2', 'dozen'),
    TemplateLine('Maida', 'Grains & flours', '2', 'kg'),
    TemplateLine('Cheese', 'Dairy & eggs', '2', 'pack'),
    TemplateLine('Juice', 'Snacks & beverages', '2', '1 L'),
  ]),
  ListTemplate('Eid', 'Festival shopping essentials', [
    TemplateLine('Rice', 'Grains & flours', '5', 'kg'),
    TemplateLine('Ghee', 'Dairy & eggs', '1', 'kg'),
    TemplateLine('Milk', 'Dairy & eggs', '4', '500 ml'),
    TemplateLine('Garam masala', 'Spices & masalas', '1', '100 g'),
    TemplateLine('Biscuits', 'Bakery & breakfast', '4', 'pack'),
  ]),
];
