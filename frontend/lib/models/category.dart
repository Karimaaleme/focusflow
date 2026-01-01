import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final Color color;
  final IconData? icon;

  Category({
    required this.id,
    required this.name,
    required this.color,
    this.icon,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.value,
      'icon_code': icon?.codePoint,
      'icon_font_family': icon?.fontFamily,
      'icon_font_package': icon?.fontPackage,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      color: Color(json['color']),
      icon: json['icon_code'] != null
          ? IconData(
              json['icon_code'],
              fontFamily: json['icon_font_family'],
              fontPackage: json['icon_font_package'],
            )
          : null,
    );
  }
}
