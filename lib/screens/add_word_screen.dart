import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../state/category_state.dart';

class AddWordScreen extends StatefulWidget {
  const AddWordScreen({super.key});

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _wordController = TextEditingController();
  final _translationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _wordController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  void _saveWord() async {
    if (_formKey.currentState!.validate()) {
      // Сначала выполняем асинхронную операцию
      await _firestoreService.addUserCustomWord(
        _wordController.text.trim(),
        _translationController.text.trim(),
      );

      // --- ИСПРАВЛЕНИЕ: Добавляем проверку mounted перед использованием context ---
      if (!mounted) return;

      Provider.of<CategoryState>(context, listen: false)
          .setCategory('user_words', 'Мои слова');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Слово добавлено!'), backgroundColor: Colors.green),
      );

      _wordController.clear();
      _translationController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить свое слово')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _wordController,
                decoration: const InputDecoration(labelText: 'Слово (на английском)'),
                validator: (value) => value!.isEmpty ? 'Поле не может быть пустым' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _translationController,
                decoration: const InputDecoration(labelText: 'Перевод'),
                validator: (value) => value!.isEmpty ? 'Поле не может быть пустым' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _saveWord,
                icon: const Icon(Icons.save),
                label: const Text('Сохранить слово'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}