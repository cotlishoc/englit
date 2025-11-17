import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../state/category_state.dart';
import 'add_word_screen.dart';
import 'categories_screen.dart';
import 'dictionary_screen.dart';
import 'profile_screen.dart';
import 'repeat_screen.dart';
import 'study_screen.dart';

// --- Современная карточка (вспомогательный виджет) ---
class _ModernCard extends StatelessWidget {
  final Widget child;
  final double? height;
  const _ModernCard({required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color top = isDark ? const Color(0xFF2A0B2B) : const Color(0xFFF3FFF5);
    final Color bottom = isDark ? const Color(0xFF3A0B46) : const Color(0xFFE8F8EA);
    final shadowColor = isDark ? Colors.black : theme.colorScheme.primary.withOpacity(0.12);

    // --- Скругление всегда одинаковое, не зависит от темы ---
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [top, bottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24), // фиксированное скругление
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// --- Главный экран ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _period = 'Месяц';
  Map<String, Map<String, int>> _dailyStats = {};
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _navigateToScreen(BuildContext context, Widget screen) {
    final categoryState = Provider.of<CategoryState>(context, listen: false);
    if (categoryState.selectedCategoryId == null && screen is! AddWordScreen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, сначала выберите категорию.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screen),
      );
    }
  }

  DateTime _periodFrom(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'Неделя':
        return now.subtract(const Duration(days: 6));
      case 'Месяц':
        return now.subtract(const Duration(days: 29));
      case '3 месяца':
        return now.subtract(const Duration(days: 90));
      case 'Все':
      default:
        return DateTime(2025, 1, 1);
    }
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    final from = _periodFrom(_period);
    final to = DateTime.now();
    final data = await _firestoreService.getDailyStats(from, to);
    setState(() {
      _dailyStats = data;
      _loadingStats = false;
    });
  }

  Widget _buildPeriodSelector() {
    final options = ['Все', '3 месяца', 'Месяц', 'Неделя'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
      children: options.map((opt) {
          final selected = opt == _period || (opt == '3 месяца' && _period == '3 месяца');
          return Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: ChoiceChip(
              label: Text(opt),
              selected: selected,
              onSelected: (v) {
                if (v) {
                  setState(() => _period = opt);
                  _loadStats();
                }
            },
            ),
          );
        }).toList(),
      ),
    );
  }

Widget _buildHistogram() {
  if (_loadingStats) return const Center(child: CircularProgressIndicator());
  if (_dailyStats.isEmpty) return const Center(child: Text('Нет данных для выбранного периода', style: TextStyle(color: Colors.grey)));

  final Map<String, Map<String, int>> agg = {};
  String fmtDay(DateTime d) => '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}';

  final from = _periodFrom(_period);
  final to = DateTime.now();

  // Создаем список всех дат в периоде
  List<String> allDates = [];
  
  if (_period == 'Все') {
    DateTime cur = DateTime(from.year, from.month, 1);
    final endMonth = DateTime(to.year, to.month, 1);
    while (!cur.isAfter(endMonth)) {
      final key = '${cur.year}-${cur.month.toString().padLeft(2,'0')}';
      agg[key] = {'learned': 0, 'learning': 0};
      allDates.add(key);
      cur = DateTime(cur.year, cur.month + 1, 1);
    }
  } else if (_period == '3 месяца' || _period == 'Месяц') {
    DateTime cur = from.subtract(Duration(days: from.weekday - 1));
    while (!cur.isAfter(to)) {
      final key = '${cur.year}-${cur.month.toString().padLeft(2,'0')}-${cur.day.toString().padLeft(2,'0')}';
      agg[key] = {'learned': 0, 'learning': 0};
      allDates.add(key);
      cur = cur.add(const Duration(days: 7));
    }
  } else {
    DateTime cur = from;
    while (!cur.isAfter(to)) {
      final key = '${cur.year}-${cur.month.toString().padLeft(2,'0')}-${cur.day.toString().padLeft(2,'0')}';
      agg[key] = {'learned': 0, 'learning': 0};
      allDates.add(key);
      cur = cur.add(const Duration(days: 1));
    }
  }

  // Заполняем данными
  for (var e in _dailyStats.entries) {
    final dt = DateTime.parse(e.key);
    String key;

    if (_period == 'Все') {
      key = '${dt.year}-${dt.month.toString().padLeft(2,'0')}';
    } else if (_period == '3 месяца' || _period == 'Месяц') {
      final weekStart = dt.subtract(Duration(days: dt.weekday - 1));
      key = '${weekStart.year}-${weekStart.month.toString().padLeft(2,'0')}-${weekStart.day.toString().padLeft(2,'0')}';
    } else {
      key = e.key;
    }

    if (agg.containsKey(key)) {
      agg[key]!['learned'] = (agg[key]!['learned'] ?? 0) + (e.value['learned'] ?? 0);
      agg[key]!['learning'] = (agg[key]!['learning'] ?? 0) + (e.value['learning'] ?? 0);
    }
  }

  // Находим максимальное значение для масштабирования
  int maxVal = 1;
  for (var key in allDates) {
    final learned = agg[key]?['learned'] ?? 0;
    final learning = agg[key]?['learning'] ?? 0;
    final sum = learned + learning;
    if (sum > maxVal) maxVal = sum;
  }

  final axisColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  final learnedColor = Theme.of(context).colorScheme.primary;
  final learningColor = Theme.of(context).colorScheme.primaryContainer;

  final double chartHeight = 150.0; // Увеличили высоту графика
  final double labelHeight = 35.0; // Увеличили высоту для подписей

  return Container(
    width: double.infinity,
    height: chartHeight + labelHeight + 25,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Вся гистограмма
        SizedBox(
          height: chartHeight + labelHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Y-ось
              SizedBox(
                width: 35,
                height: chartHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(maxVal.toString(), style: TextStyle(fontSize: 12, color: axisColor)),
                    Text(((maxVal / 2).ceil()).toString(), style: TextStyle(fontSize: 12, color: axisColor)),
                    Text('0', style: TextStyle(fontSize: 12, color: axisColor)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              
              // Столбцы и подписи - широкая область с прокруткой
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    // Ширина = количество дат * ширина блока + отступы
                    width: allDates.length * 50.0, // Увеличили ширину блоков
                    height: chartHeight + labelHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: allDates.map((key) {
                        final learned = agg[key]?['learned'] ?? 0;
                        final learning = agg[key]?['learning'] ?? 0;

                        final learnedH = maxVal == 0 ? 0.0 : (learned / maxVal) * chartHeight;
                        final learningH = maxVal == 0 ? 0.0 : (learning / maxVal) * chartHeight;

                        return Container(
                          width: 45, // Увеличили ширину блока
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Столбцы графика
                              Container(
                                height: chartHeight,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (learnedH > 0)
                                      Container(
                                        height: learnedH,
                                        width: 32, // Увеличили ширину столбцов
                                        color: learnedColor,
                                        alignment: Alignment.center,
                                        child: Text(
                                          learned > 0 ? learned.toString() : '', 
                                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)
                                        ),
                                      ),
                                    if (learningH > 0)
                                      Container(
                                        height: learningH,
                                        width: 32, // Увеличили ширину столбцов
                                        color: learningColor,
                                        alignment: Alignment.center,
                                        child: Text(
                                          learning > 0 ? learning.toString() : '', 
                                          style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold)
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Подпись даты
                              SizedBox(
                                height: labelHeight,
                                child: Transform.rotate(
                                  angle: -0.5,
                                  child: Container(
                                    width: 60,
                                    padding: const EdgeInsets.only(top: 10.0),
                                    child: Text(
                                      _period == 'Все' 
                                        ? '${key.split('-')[1]}.${key.split('-')[0].substring(2)}'
                                        : fmtDay(DateTime.parse(key)),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11, // Увеличили шрифт
                                        color: axisColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Легенда
        Container(
          height: 25,
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stop, size: 14, color: learnedColor),
              const SizedBox(width: 6),
              const Text('learned', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              Icon(Icons.stop, size: 14, color: learningColor),
              const SizedBox(width: 6),
              const Text('learning', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    ),
  );
}

 Widget _buildStatsContent(int learnedCount, int repetitionCount) {
  final learnedColor = Theme.of(context).colorScheme.primary;
  final learningColor = Theme.of(context).colorScheme.primaryContainer;
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min, // Добавьте это
    children: [
      _buildStatRow(Icons.check_circle_outline, 'Всего изучено слов', '$learnedCount'),
      const SizedBox(height: 8),
      _buildPeriodSelector(),
      const SizedBox(height: 8), // Уменьшили отступ
      // График теперь будет занимать только нужное место
      _buildHistogram(),
      const SizedBox(height: 4), // Уменьшили отступ
    ],
  );
}

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Widget _buildCategorySelector(BuildContext context) {
    return Consumer<CategoryState>(
      builder: (context, categoryState, child) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CategoriesScreen()),
            );
          },
          child: _ModernCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Категория: ${categoryState.selectedCategoryName}',
                    style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodyMedium?.color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLargeCard(BuildContext context, {required String title, VoidCallback? onTap, double height = 150, Widget? content}) {
    return GestureDetector(
      onTap: onTap,
      child: _ModernCard(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color),
            ),
            const SizedBox(height: 8.0),
            if (content != null) Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallButton(BuildContext context, {required String text, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: _ModernCard(
          height: 80,
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 50,
        backgroundColor: theme.appBarTheme.backgroundColor,
        surfaceTintColor: theme.appBarTheme.surfaceTintColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10, top: 6, bottom: 6),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3A0B46) : theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(isDark ? 0.12 : 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.person_outline, size: 28, color: theme.colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _firestoreService.getUserStream(),
          builder: (context, snapshot) {
            int totalLearned = 0;
            int repetitions = 0;
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              totalLearned = data['stats']?['totalLearnedWords'] ?? 0;
              repetitions = data['stats']?['repetitionsCount'] ?? 0;
            }
 
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildCategorySelector(context),
                  const SizedBox(height: 16.0),
                  _buildLargeCard(
                    context,
                    title: 'Изучить новые слова',
                    onTap: () => _navigateToScreen(context, const StudyScreen()),
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    children: <Widget>[
                      _buildSmallButton(
                        context,
                        text: 'повторение слов',
                        onTap: () => _navigateToScreen(context, const RepeatScreen()),
                      ),
                      const SizedBox(width: 16.0),
                      _buildSmallButton(
                        context,
                        text: 'словарь',
                        onTap: () => _navigateToScreen(context, const DictionaryScreen()),
                      ),
                      const SizedBox(width: 16.0),
                      _buildSmallButton(
                        context,
                        text: 'добавить свое слово',
                        onTap: () {
                           Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AddWordScreen()),
                            );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  // Статистика занимает оставшуюся часть экрана
                  // В методе build HomeScreen, в Expanded с карточкой статистики:
                  Expanded(
                    child: _buildLargeCard(
                      context,
                      title: 'Статистика',
                      content: snapshot.connectionState == ConnectionState.waiting
                          ? const Center(child: CircularProgressIndicator())
                          : _buildStatsContent(totalLearned, repetitions),
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            );
           },
         ),
       ),
     );
   }
 }