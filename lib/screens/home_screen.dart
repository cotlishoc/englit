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
        borderRadius: BorderRadius.circular(24),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
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
    );
  }

  Widget _buildHistogram() {
    if (_loadingStats) return const Center(child: CircularProgressIndicator());
    if (_dailyStats.isEmpty) return const Center(child: Text('Нет данных для выбранного периода', style: TextStyle(color: Colors.grey)));

    // Генерируем последовательность ключей периодов (чтобы включать пустые периоды)
    final Map<String, Map<String, int>> agg = {};
    String fmtDay(DateTime d) => '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year.toString().substring(2)}';

    final from = _periodFrom(_period);
    final to = DateTime.now();

    if (_period == 'Все') {
      // месяцы от from до to
      DateTime cur = DateTime(from.year, from.month, 1);
      final endMonth = DateTime(to.year, to.month, 1);
      while (!cur.isAfter(endMonth)) {
        final key = '${cur.year}-${cur.month.toString().padLeft(2,'0')}';
        agg.putIfAbsent(key, () => {'learned': 0, 'learning': 0});
        cur = DateTime(cur.year, cur.month + 1, 1);
      }
    } else if (_period == '3 месяца' || _period == 'Месяц') {
      // недели (понедельники) от from до to
      DateTime cur = DateTime(from.year, from.month, from.day).subtract(Duration(days: (from.weekday - 1)));
      final end = to;
      while (!cur.isAfter(end)) {
        final key = '${cur.year}-${cur.month.toString().padLeft(2,'0')}-${cur.day.toString().padLeft(2,'0')}';
        agg.putIfAbsent(key, () => {'learned': 0, 'learning': 0});
        cur = cur.add(const Duration(days: 7));
      }
    } else {
      // Неделя — дни
      DateTime cur = DateTime(from.year, from.month, from.day);
      final end = DateTime(to.year, to.month, to.day);
      while (!cur.isAfter(end)) {
        final key = '${cur.year}-${cur.month.toString().padLeft(2,'0')}-${cur.day.toString().padLeft(2,'0')}';
        agg.putIfAbsent(key, () => {'learned': 0, 'learning': 0});
        cur = cur.add(const Duration(days: 1));
      }
    }

    // Добавляем реальные события в соответствующие периоды
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
      agg.putIfAbsent(key, () => {'learned': 0, 'learning': 0});
      agg[key]!['learned'] = (agg[key]!['learned'] ?? 0) + (e.value['learned'] ?? 0);
      agg[key]!['learning'] = (agg[key]!['learning'] ?? 0) + (e.value['learning'] ?? 0);
    }

    final entries = agg.entries.toList()..sort((a,b) => a.key.compareTo(b.key));
    int maxVal = 1;
    for (var e in entries) {
      final sum = (e.value['learned'] ?? 0) + (e.value['learning'] ?? 0);
      if (sum > maxVal) maxVal = sum;
    }

    // компоненты: слева ось, справа горизонтальная прокрутка столбцов
    final theme = Theme.of(context);
    final axisColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final learnedColor = theme.colorScheme.primary; // в dark теме будет фиолетовый
    final learningColor = theme.colorScheme.primaryContainer;

    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Y-ось
          SizedBox(
            width: 40,
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
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: entries.map((e) {
                  final learned = e.value['learned'] ?? 0;
                  final learning = e.value['learning'] ?? 0;
                  final barMaxHeight = 140.0;
                  final learnedH = maxVal == 0 ? 0.0 : (learned / maxVal) * barMaxHeight;
                  final learningH = maxVal == 0 ? 0.0 : (learning / maxVal) * barMaxHeight;

                  String label;
                  if (_period == 'Все') {
                    final parts = e.key.split('-');
                    final y = parts[0];
                    final m = parts[1];
                    label = '${m}.${y.substring(2)}'; // mm.yy
                  } else {
                    final dt = DateTime.parse(e.key);
                    label = fmtDay(dt);
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // bar container
                        Container(
                          width: 28,
                          height: learnedH + learningH == 0 ? 6 : (learnedH + learningH),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (learnedH > 0)
                                Container(
                                  height: learnedH,
                                  width: 28,
                                  color: learnedColor,
                                  child: Center(child: Text(learned.toString(), style: TextStyle(fontSize: 10, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.white))),
                                ),
                              if (learningH > 0)
                                Container(
                                  height: learningH,
                                  width: 28,
                                  color: learningColor,
                                  child: Center(child: Text(learning.toString(), style: TextStyle(fontSize: 10, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black))),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(width: 48, child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: axisColor))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsContent(int learnedCount, int repetitionCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatRow(Icons.check_circle_outline, 'Всего изучено слов', '$learnedCount'),
        const SizedBox(height: 8),
        _buildPeriodSelector(),
        const SizedBox(height: 8),
        _buildHistogram(),
        const SizedBox(height: 8),
        Row(
          children: const [
            SizedBox(width: 10),
            Icon(Icons.stop, size: 12, color: Color(0xFF2E7D32)),
            SizedBox(width: 6),
            Text('learned', style: TextStyle(fontSize: 12)),
            SizedBox(width: 12),
            Icon(Icons.stop, size: 12, color: Color(0xFFB9F6CA)),
            SizedBox(width: 6),
            Text('learning', style: TextStyle(fontSize: 12)),
          ],
        ),
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
                  Expanded(
                    child: _buildLargeCard(
                      context,
                      title: 'Статистика',
                      // убираем фиксированную высоту — карточка развернётся на весь доступный Expanded
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