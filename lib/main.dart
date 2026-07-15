import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'dart:async';

void main() {
  runApp(const ReverseCalcApp());
}

// --- データモデル ---
class Task {
  String name;
  int duration;
  bool isDone;
  bool isSkipped; // 追加

  Task({
    required this.name,
    required this.duration,
    this.isDone = false,
    this.isSkipped = false, // 追加
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'duration': duration,
    'isDone': isDone,
    'isSkipped': isSkipped, // 追加
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    name: json['name'],
    duration: json['duration'],
    isDone: json['isDone'] ?? false,
    isSkipped: json['isSkipped'] ?? false, // 追加
  );
}

class ReverseCalcApp extends StatelessWidget {
  const ReverseCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '予定逆算アプリ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ReverseCalcScreen(),
    );
  }
}

class ReverseCalcScreen extends StatelessWidget {
  const ReverseCalcScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReverseCalcContent();
  }
}

class ReverseCalcContent extends StatefulWidget {
  const ReverseCalcContent({super.key});

  @override
  State<ReverseCalcContent> createState() => _ReverseCalcContentState();
}

class _ReverseCalcContentState extends State<ReverseCalcContent> {
  DateTime goalTime = DateTime.now();
  List<Task> tasks = [];
  String goalLabel = '目標時刻';
  Map<String, Map<String, dynamic>> templates = {};
  Map<String, int> quickMaster = {'Walking': 20, '風呂': 30, 'スッキリ': 10};
  int bufferMinutes = 0;
  bool isActive = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        final now = DateTime.now();
        final normalizedGoal = DateTime(
          now.year,
          now.month,
          now.day,
          goalTime.hour,
          goalTime.minute,
        );

        // 目標時刻から1時間過ぎたら自動でオフにする
        if (isActive &&
            now.isAfter(normalizedGoal.add(const Duration(hours: 1)))) {
          setState(() {
            isActive = false;
            for (var t in tasks) {
              t.isDone = false;
            }
            _saveData();
          });
        } else {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode({
      'goalTime': goalTime.toIso8601String(),
      'goalLabel': goalLabel,
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'templates': templates,
      'quickMaster': quickMaster,
      'bufferMinutes': bufferMinutes,
      'isActive': isActive,
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
        goalLabel = decodedData['goalLabel'] ?? '目標時刻';
        tasks = (decodedData['tasks'] as List)
            .map((item) => Task.fromJson(item))
            .toList();
        if (decodedData['templates'] != null) {
          templates = Map<String, Map<String, dynamic>>.from(
            decodedData['templates'],
          );
        }
        if (decodedData['quickMaster'] != null) {
          quickMaster = Map<String, int>.from(decodedData['quickMaster']);
        }
        bufferMinutes = decodedData['bufferMinutes'] ?? 0;
        isActive = decodedData['isActive'] ?? false;
      });
    }
  }

  void _saveCurrentAsTemplate() {
    String templateName = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テンプレートとして保存'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'テンプレート名（例：平日の朝）'),
          onChanged: (value) => templateName = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              if (templateName.isEmpty) return;
              setState(() {
                goalLabel = templateName;
                templates[templateName] = {
                  'goalLabel': goalLabel,
                  'tasks': tasks.map((t) => t.toJson()).toList(),
                  'bufferMinutes': bufferMinutes,
                };
                _saveData();
              });
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _loadTemplate(String name) {
    setState(() {
      final data = templates[name]!;
      goalLabel = data['goalLabel'] ?? name;
      tasks = (data['tasks'] as List)
          .map((item) => Task.fromJson(item))
          .toList();
      bufferMinutes = data['bufferMinutes'] ?? 0;
      isActive = false; // 読み込み時は非アクティブに
      _saveData();
    });
  }

  void _deleteTemplate(String name) {
    setState(() {
      templates.remove(name);
      _saveData();
    });
  }

  void _showManageTemplatesDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('テンプレートの管理'),
          content: SizedBox(
            width: double.maxFinite,
            child: templates.isEmpty
                ? const Text('保存されたテンプレートはありません')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: templates.keys.length,
                    itemBuilder: (context, index) {
                      String name = templates.keys.elementAt(index);
                      return ListTile(
                        title: Text(name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _deleteTemplate(name);
                            setDialogState(() {});
                          },
                        ),
                        onTap: () {
                          _loadTemplate(name);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskDialog({Task? task, int? index}) {
    String newName = task?.name ?? '';
    int newDuration = task?.duration ?? 15;
    final isEditing = task != null;
    final nameController = TextEditingController(text: newName);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? '予定を編集' : '新しい予定を追加'),
          content: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'クイック追加（×で削除）',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ...quickMaster.entries.map(
                        (entry) => InputChip(
                          label: Text(entry.key),
                          onPressed: () {
                            setState(() {
                              tasks.add(
                                Task(name: entry.key, duration: entry.value),
                              );
                              _saveData();
                            });
                            Navigator.pop(context);
                          },
                          onDeleted: () {
                            setState(() {
                              quickMaster.remove(entry.key);
                              _saveData();
                            });
                            setDialogState(() {});
                          },
                          deleteIconColor: Colors.grey,
                        ),
                      ),
                      ActionChip(
                        // ★修正箇所①: withOpacity -> withValues
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        avatar: const Icon(Icons.add, size: 16),
                        label: const Text('登録'),
                        onPressed: () {
                          if (newName.isNotEmpty) {
                            setState(() {
                              quickMaster[newName] = newDuration;
                              _saveData();
                            });
                            setDialogState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '予定名'),
                    onChanged: (value) => newName = value,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '所要時間',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  SizedBox(
                    height: 150,
                    child: CupertinoTimerPicker(
                      mode: CupertinoTimerPickerMode.hm,
                      minuteInterval: 5,
                      initialTimerDuration: Duration(minutes: newDuration),
                      onTimerDurationChanged: (Duration duration) {
                        newDuration = duration.inMinutes;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                if (newName.isEmpty) return;
                setState(() {
                  if (isEditing) {
                    tasks[index!] = Task(name: newName, duration: newDuration);
                  } else {
                    tasks.add(Task(name: newName, duration: newDuration));
                  }
                  _saveData();
                });
                Navigator.pop(context);
              },
              child: Text(isEditing ? '更新' : '追加'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    DateTime normalizedGoal = DateTime(
      now.year,
      now.month,
      now.day,
      goalTime.hour,
      goalTime.minute,
    );
    if (normalizedGoal.isBefore(now)) {
      normalizedGoal = normalizedGoal.add(const Duration(days: 1));
    }
    // --- 不足時間の計算ロジック ---
    // 1. まだやっていない（未完了かつ未スキップ）タスクの合計時間を出す
    int remainingRequiredMinutes = tasks
        .where((t) => !t.isDone && !t.isSkipped)
        .fold(0, (sum, t) => sum + t.duration);

    // 2. タスク間のバッファも加算（未完了タスクが2つ以上ある場合）
    int activeTasksCount = tasks.where((t) => !t.isDone && !t.isSkipped).length;
    int remainingBuffer = activeTasksCount > 1
        ? (activeTasksCount - 1) * bufferMinutes
        : 0;
    int totalNeededMinutes = remainingRequiredMinutes + remainingBuffer;

    // 3. 目標までの残り時間（分）
    int minutesUntilGoal = normalizedGoal.difference(now).inMinutes;

    // 4. 不足している時間
    int timeDeficit = totalNeededMinutes - minutesUntilGoal;
    // ----------------------------

    // 全体の開始時刻計算（これは全タスクベースでOK）
    int tasksDuration = tasks.fold(0, (sum, item) => sum + item.duration);
    int totalBuffer = tasks.length > 1 ? (tasks.length - 1) * bufferMinutes : 0;
    int totalDuration = tasksDuration + totalBuffer;
    DateTime startTime = normalizedGoal.subtract(
      Duration(minutes: totalDuration),
    );

    List<DateTime> calculatedTimes = [];
    DateTime nextStartTime = startTime;
    for (int i = 0; i < tasks.length; i++) {
      calculatedTimes.add(nextStartTime);
      nextStartTime = nextStartTime.add(
        Duration(minutes: tasks[i].duration + bufferMinutes),
      );
    }

    final bool allFinished =
        tasks.isNotEmpty && tasks.every((t) => t.isDone || t.isSkipped);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('予定逆算アプリ', style: TextStyle(fontSize: 16)),
            Text(
              '現在時刻: ${DateFormat('HH:mm').format(now)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.folder_special),
            onSelected: (value) {
              if (value == 'save_new') {
                _saveCurrentAsTemplate();
              } else if (value == 'manage') {
                _showManageTemplatesDialog();
              } else if (value == 'reset') {
                setState(() {
                  for (var t in tasks) {
                    t.isDone = false;
                    t.isSkipped = false; // スキップもリセット
                  }
                  _saveData();
                });
              } else {
                _loadTemplate(value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'save_new',
                child: Row(
                  children: [
                    Icon(Icons.save, color: Colors.blue),
                    Text(' 保存'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'manage',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.grey),
                    Text(' 管理'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.orange),
                    Text(' 全リセット'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              ...templates.keys.map(
                (name) => PopupMenuItem(value: name, child: Text(name)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: Chip(label: Text('合計: $totalDuration分'))),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- 動的バナーエリア ---
          if (!isActive)
            Container(
              width: double.infinity,
              color: Colors.indigo.withValues(alpha: 0.8),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    isActive = true;
                    for (var t in tasks) {
                      t.isDone = false;
                      t.isSkipped = false; // スキップもリセット
                    }
                    _saveData();
                  });
                },
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: const Text(
                  '準備を開始する',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else
            Builder(
              builder: (context) {
                final diff = normalizedGoal.difference(now).inMinutes;
                final bool isEarly = diff > 0;

                if (allFinished) {
                  return Container(
                    width: double.infinity,
                    color: isEarly ? Colors.teal : Colors.green,
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isEarly ? Icons.timer_outlined : Icons.celebration,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              children: [
                                if (isEarly) ...[
                                  const TextSpan(text: '予定時刻の '),
                                  TextSpan(
                                    text: '$diff 分前',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const TextSpan(text: ' に準備完了！'),
                                ] else ...[
                                  const TextSpan(
                                    text: '準備完了！いってらっしゃい！',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              isActive = false;
                              for (var t in tasks) {
                                t.isDone = false;
                              }
                              _saveData();
                            });
                          },
                          child: const Text(
                            '終了',
                            style: TextStyle(
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // 準備中（未完了タスクあり）
                return Column(
                  children: [
                    if (isActive && timeDeficit > 0 && !allFinished)
                      Container(
                        width: double.infinity,
                        color: Colors.redAccent,
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '時間が $timeDeficit 分足りません！予定をスキップしてください',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      width: double.infinity,
                      color: Colors.indigo.withValues(alpha: 0.9),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.directions_run,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '準備実行中...',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setState(() {
                              isActive = false;
                              _saveData();
                            }),
                            child: const Text(
                              '中止',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          _buildGoalTimeTile(normalizedGoal),
          _buildBufferPanel(),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: tasks.length,
              // ★修正箇所②: onReorder -> onReorderItem (index調整が不要に)
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final item = tasks.removeAt(oldIndex);
                  tasks.insert(newIndex, item);
                  _saveData();
                });
              },
              itemBuilder: (context, index) {
                return _buildTaskTile(
                  tasks[index],
                  calculatedTimes[index],
                  index,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskDialog(),
        icon: const Icon(Icons.add),
        label: const Text('予定追加'),
      ),
    );
  }

  Widget _buildGoalTimeTile(DateTime normalizedGoal) {
    return ListTile(
      tileColor: Colors.indigo.withValues(alpha: 0.05),
      title: const Text(
        '目標時刻',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            DateFormat('HH:mm').format(normalizedGoal),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _showGoalLabelEditDialog(),
              child: Text(
                goalLabel,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.indigo,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
      trailing: const Icon(Icons.edit_calendar),
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(goalTime),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
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
    );
  }

  Widget _buildBufferPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.orange.withValues(alpha: 0.05),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_empty, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('タスク間の余裕：', style: TextStyle(fontSize: 12)),
              Text(
                '$bufferMinutes 分',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 4,
                children: [0, 2, 5]
                    .map(
                      (m) => ChoiceChip(
                        label: Text(
                          '$m分',
                          style: const TextStyle(fontSize: 10),
                        ),
                        selected: bufferMinutes == m,
                        onSelected: (selected) {
                          // ★修正箇所③: if文を {} で囲む
                          if (selected) {
                            setState(() {
                              bufferMinutes = m;
                              _saveData();
                            });
                          }
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          Slider(
            value: bufferMinutes.toDouble(),
            min: 0,
            max: 15,
            divisions: 15,
            activeColor: Colors.orange,
            onChanged: (value) => setState(() {
              bufferMinutes = value.toInt();
              _saveData();
            }),
          ),
        ],
      ),
    );
  }

  IconData _getTaskIcon(String name) {
    String n = name.toLowerCase();
    if (n.contains('風呂') || n.contains('洗い')) return Icons.bathtub_outlined;
    if (n.contains('walk') || n.contains('歩')) return Icons.directions_walk;
    if (n.contains('バス') || n.contains('電車')) return Icons.directions_bus;
    if (n.contains('スッキリ')) return Icons.face_retouching_natural;
    if (n.contains('spare') || n.contains('余裕')) return Icons.weekend_outlined;
    if (n.contains('飯') || n.contains('食')) return Icons.restaurant;
    if (n.contains('服') || n.contains('着')) return Icons.checkroom;
    return Icons.task_alt;
  }

  Widget _buildTaskTile(Task task, DateTime startTime, int index) {
    final now = DateTime.now();
    final endTime = startTime.add(Duration(minutes: task.duration));
    bool isCurrent = now.isAfter(startTime) && now.isBefore(endTime);
    bool isPast = now.isAfter(endTime);
    bool isLate = isPast && !task.isDone;

    return Dismissible(
      key: ValueKey(task.hashCode + index),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('削除', style: TextStyle(color: Colors.white)),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      onDismissed: (_) {
        final deletedTask = task;
        setState(() {
          tasks.removeAt(index);
          _saveData();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${deletedTask.name} を削除しました'),
            action: SnackBarAction(
              label: '元に戻す',
              onPressed: () {
                setState(() {
                  tasks.insert(index, deletedTask);
                  _saveData();
                });
              },
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          onTap: () => _showTaskDialog(task: task, index: index),
          tileColor: isCurrent && !task.isSkipped
              ? Colors.blue.withValues(alpha: 0.1)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isCurrent && !task.isSkipped
                ? const BorderSide(color: Colors.blue, width: 2)
                : BorderSide.none,
          ),
          // スキップ中はチェックボックスを隠す（または無効なアイコンにする）
          leading: task.isSkipped
              ? const Icon(Icons.block, color: Colors.grey)
              : Checkbox(
                  value: task.isDone,
                  onChanged: (bool? value) {
                    setState(() {
                      task.isDone = value ?? false;
                      _saveData();
                    });
                  },
                ),
          title: Row(
            children: [
              Icon(
                task.isSkipped ? Icons.redo : _getTaskIcon(task.name),
                size: 18,
                color: (task.isDone || task.isSkipped)
                    ? Colors.grey
                    : (isLate ? Colors.red : Colors.indigo),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.name + (task.isSkipped ? ' (スキップ中)' : ''),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: (task.isDone || task.isSkipped)
                        ? TextDecoration.lineThrough
                        : null,
                    color: (task.isDone || task.isSkipped)
                        ? Colors.grey
                        : (isLate ? Colors.red : Colors.black),
                    fontStyle: task.isSkipped
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
              // --- スキップ / 戻す ボタンの切り替え ---
              if (isActive && !task.isDone)
                IconButton(
                  icon: Icon(
                    task.isSkipped ? Icons.replay : Icons.fast_forward,
                    size: 20,
                    color: task.isSkipped ? Colors.blue : Colors.orange,
                  ),
                  tooltip: task.isSkipped ? '予定を復活させる' : 'この予定をスキップ',
                  onPressed: () => setState(() {
                    task.isSkipped = !task.isSkipped; // 状態を反転させる
                    _saveData();
                  }),
                ),
              if (isCurrent && !task.isSkipped)
                const Badge(label: Text('NOW'), backgroundColor: Colors.blue),
            ],
          ),
          // ... (subtitle と trailing はそのまま)
          subtitle: isCurrent
              ? Text(
                  'あと ${endTime.difference(now).inMinutes + 1} 分で終了予定',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Text('所要時間: ${task.duration}分'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('HH:mm').format(startTime),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: task.isDone
                          ? Colors.grey
                          : (isLate ? Colors.red : Colors.blue),
                    ),
                  ),
                  Text(
                    isLate ? '遅延中' : '開始',
                    style: TextStyle(
                      fontSize: 10,
                      color: isLate ? Colors.red : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGoalLabelEditDialog() {
    String newLabel = goalLabel;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('目標の名称を変更'),
        content: TextField(
          controller: TextEditingController(text: goalLabel),
          onChanged: (value) => newLabel = value,
          decoration: const InputDecoration(hintText: '例：バス出発、家を出る'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                goalLabel = newLabel;
                _saveData();
              });
              Navigator.pop(context);
            },
            child: const Text('更新'),
          ),
        ],
      ),
    );
  }
}
