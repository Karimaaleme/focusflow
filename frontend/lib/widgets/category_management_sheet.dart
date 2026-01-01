import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/category_service.dart';

class CategoryManagementSheet extends StatefulWidget {
  const CategoryManagementSheet({super.key});

  @override
  State<CategoryManagementSheet> createState() => _CategoryManagementSheetState();
}

class _CategoryManagementSheetState extends State<CategoryManagementSheet> {
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await CategoryService.getCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
        _isLoading = false;
      });
    }
  }

  void _showAddEditDialog({Category? category}) {
    showDialog(
      context: context,
      builder: (_) => _CategoryDialog(
        category: category,
        onSave: (newCat) async {
          if (category == null) {
            await CategoryService.addCategory(newCat);
          } else {
            await CategoryService.updateCategory(newCat);
          }
          _loadCategories();
        },
      ),
    );
  }

  Future<void> _deleteCategory(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Category?"),
        content: const Text("This will not delete associated tasks, but they will lose their color grouping."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CategoryService.deleteCategory(id);
      _loadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Manage Categories",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: ListView.separated(
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cat.color.withOpacity(0.2),
                      child: Icon(cat.icon ?? Icons.label, color: cat.color),
                    ),
                    title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                          onPressed: () => _showAddEditDialog(category: cat),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          onPressed: () => _deleteCategory(cat.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add),
              label: const Text("Create New Category"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 16), // SafeArea padding basically
        ],
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final Category? category;
  final Function(Category) onSave;

  const _CategoryDialog({this.category, required this.onSave});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late Color _selectedColor;
  late IconData _selectedIcon;

  final List<Color> _colors = [
    Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.teal, Colors.pink, Colors.brown
  ];
  final List<IconData> _icons = [
    Icons.work, Icons.person, Icons.school, Icons.favorite, Icons.fitness_center, Icons.shopping_cart, Icons.flight, Icons.home, Icons.star
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category?.name ?? '');
    _selectedColor = widget.category?.color ?? _colors.first;
    _selectedIcon = widget.category?.icon ?? _icons.first;
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final newCat = Category(
        id: widget.category?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameCtrl.text.trim(),
        color: _selectedColor,
        icon: _selectedIcon,
      );
      widget.onSave(newCat);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? "New Category" : "Edit Category"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Category Name", border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text("Color", style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colors.map((c) => GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: CircleAvatar(
                    backgroundColor: c,
                    radius: 14,
                    child: _selectedColor == c ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text("Icon", style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _icons.map((i) => GestureDetector(
                  onTap: () => setState(() => _selectedIcon = i),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedIcon == i ? Colors.grey[200] : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _selectedIcon == i ? Colors.black : Colors.grey[300]!),
                    ),
                    child: Icon(i, size: 20, color: Colors.black87),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        FilledButton(onPressed: _submit, child: const Text("Save")),
      ],
    );
  }
}
