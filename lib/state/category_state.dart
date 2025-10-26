import 'package:flutter/material.dart';
class CategoryState with ChangeNotifier {
String? _selectedCategoryId;
String _selectedCategoryName = "не выбрана";
String? get selectedCategoryId => _selectedCategoryId;
String get selectedCategoryName => _selectedCategoryName;
void setCategory(String id, String name) {
_selectedCategoryId = id;
_selectedCategoryName = name;
notifyListeners(); // Сообщаем всем подписчикам, что данные изменились
}
}