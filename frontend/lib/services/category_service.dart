import 'package:flutter/material.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart'; 
// Commented out to avoid dependency issues if not configured, using in-memory default with mock persistence logic for now. 
// Ideally we use shared_preferences or secure_storage.

import '../models/category.dart';

class CategoryService {
  static final List<Category> _defaults = [
    Category(id: '1', name: 'Work', color: Colors.blue, icon: Icons.work),
    Category(id: '2', name: 'Personal', color: Colors.green, icon: Icons.person),
    Category(id: '3', name: 'Study', color: Colors.orange, icon: Icons.school),
    Category(id: '4', name: 'Health', color: Colors.red, icon: Icons.favorite),
  ];

  static List<Category> _categories = List.from(_defaults);

  static Future<List<Category>> getCategories() async {
    // Simulate load
    return _categories;
  }

  static Future<void> addCategory(Category category) async {
    _categories.add(category);
  }

  static Future<void> updateCategory(Category category) async {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _categories[index] = category;
    }
  }

  static Future<void> deleteCategory(String id) async {
    _categories.removeWhere((c) => c.id == id);
  }
  
  static Color getColorFor(String categoryName) {
    try {
      return _categories.firstWhere(
        (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
        orElse: () => Category(id: '0', name: '', color: Colors.grey),
      ).color;
    } catch (_) {
      return Colors.grey;
    }
  }
}
