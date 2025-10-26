import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../services/firestore_service.dart';
import '../state/category_state.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('Выбор категорий')),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.getCategoriesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Не удалось загрузить категории.'));
          }
          
          List<CategoryModel> categories = [];
          if (snapshot.hasData) {
            categories = snapshot.data!.docs.map((doc) {
              return CategoryModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
            }).toList();
          }

          // --- ИЗМЕНЕНИЕ: Добавляем нашу кастомную категорию в начало списка ---
          categories.insert(0, CategoryModel(id: 'user_words', name: 'Мои слова'));

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isCustom = category.id == 'user_words';
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: ListTile(
                  leading: Icon(isCustom ? Icons.star : Icons.library_books_outlined),
                  title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Provider.of<CategoryState>(context, listen: false)
                        .setCategory(category.id, category.name);
                    Navigator.of(context).pop();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}