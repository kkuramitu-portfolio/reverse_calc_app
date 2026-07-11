import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const ReverseCalcApp());
}

class ReverseCalcApp extends StatelessWidget {
  const ReverseCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '予定逆算アプリ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ReverseCalcScreen(),
    );
  }
}

class ReverseCalcScreen extends StatefulWidget {
  const ReverseCalcScreen({super.key});

  @override
  State<ReverseCalcScreen> createState() => _ReverseCalcScreenState();
}

class _ReverseCalcScreenState extends State<ReverseCalcScreen> {
  DateTime goalTime = DateTime.now();
  List<Map<String, dynamic>> tasks = [];

  @override
  void initState() {
    super.initState();
    _loadData(); // アプリ起動時にデータを読み込む
  }

  // --- データの保存と読み込み ---
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode({
      'goalTime': goalTime.toIso8601String(),
      'tasks': tasks,
    });
    await prefs.setString('app_data', encodedData);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('app_data');
    if (data != null) {
      final decodedData = json.decode(data);
      setState(() {
        goalTime = DateTime.parse(decodedData['goalTime']);
        tasks = List<Map<String, dynamic>>.from(decodedData['tasks']);
      });
    } else {
      // 初期データ
      setState(() {
        tasks = [
          {'name': 'バス出発', 'duration': 0},
          {'name': 'スッキ', 'duration': 58},
          {'name': '洗い始', 'duration': 25},
        ];
      });
    }
  }

  // --- 予定の追加ダイアログ ---
  void _showAddTaskDialog() {
    String newName = '';
    int newDuration = 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('予定逆算アプリと'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: '予定名（例：お風呂）'),
              onChanged: (value) => newName = value,
            ),
            TextField(
              decoration: const InputDecoration(labelText: '所要時間（分）'),
              keyboardType: TextInputType.number,
              onChanged: (value) => newDuration = int.tryParse(value) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                tasks.add({'name': newName, 'duration': newDuration});
                _saveData();
              });
              Navigator.pop(context);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 逆算計算
    List<Map<String, dynamic>> calculatedResults = [];
    DateTime currentTime = goalTime;

    for (var task in tasks) {
      currentTime = currentTime.subtract(Duration(minutes: task['duration']));
      calculatedResults.add({
        'name': task['name'],
        'duration': task['duration'],
        'time': DateFormat('HH:mm').format(currentTime),
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('予定逆算アプリ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          ListTile(
            tileColor: Colors.deepPurple.withOpacity(0.1),
            title: const Text('目標時刻（ここから逆算）'),
            subtitle: Text(
              DateFormat('HH:mm').format(goalTime),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            trailing: const Icon(Icons.edit_calendar),
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(goalTime),
              );
              if (time != null) {
                setState(() {
                  goalTime = DateTime(
                    goalTime.year,
                    goalTime.month,
                    goalTime.day,
                    time.hour,
                    time.minute,
                  );
                  _saveData();
                });
              }
            },
          ),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('長押しで並び替え、左スワイプで削除'),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false, // ★右側の自動「=」をオフにする
              itemCount: tasks.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = tasks.removeAt(oldIndex);
                  tasks.insert(newIndex, item);
                  _saveData();
                });
              },
              itemBuilder: (context, index) {
                final task = tasks[index];
                final calc = calculatedResults[index];
                return Dismissible(
                  key: ValueKey('${task['name']}_$index'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    setState(() {
                      tasks.removeAt(index);
                      _saveData();
                    });
                  },
                  child: ListTile(
                    key: ValueKey('${task['name']}_$index'),
                    // ★左側に「≡」アイコンを配置し、ここをドラッグのつまみに指定する
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.menu, color: Colors.grey),
                    ),
                    title: Text(task['name']),
                    subtitle: Text('所要時間: ${task['duration']}分'),
                    trailing: Text(
                      calc['time'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
