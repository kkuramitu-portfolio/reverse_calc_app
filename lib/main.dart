import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'notification_service.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await NotificationService().init();
  }
  runApp(const ReverseCalcApp());
}

class Task {
  String name;
  int duration;
  bool isDone;
  bool isSkipped;

  Task({
    required this.name,
    required this.duration,
    this.isDone = false,
    this.isSkipped = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'duration': duration,
    'isDone': isDone,
    'isSkipped': isSkipped,
  };
  factory Task.fromJson(Map<String, dynamic> json) => Task(
    name: json['name'],
    duration: json['duration'],
    isDone: json['isDone'] ?? false,
    isSkipped: json['isSkipped'] ?? false,
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
  Widget build(BuildContext context) => const ReverseCalcContent();
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
  bool isCompleted = false;
  String _announcement = "";
  String _lastReadAnnouncement = ""; // 💡 お知らせ内容を保持する変数
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // 💡 読み込みが終わってから判定する、この1セットだけでOKです
    _loadData().then((_) {
      _checkUpdates();
    });

    // 1分ごとのタイマー
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        final now = DateTime.now();
        final normalizedGoal = _getNormalizedGoal(now);
        if (isActive &&
            now.isAfter(normalizedGoal.add(const Duration(hours: 1)))) {
          setState(() {
            isActive = false;
            isCompleted = false;
            for (var t in tasks) {
              t.isDone = false;
              t.isSkipped = false;
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

  // 💡 お知らせをチェックする関数（デモ用に文字をセット）
  Future<void> _checkUpdates() async {
    // 💡 ステップ1でコピーした「Raw」のURLに差し替えてください
    const String url =
        "https://gist.githubusercontent.com/kkuramitu-portfolio/d1eaedbafb6d60a391ad3a774501116f/raw/gistfile1.txt";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // 文字化けを防ぐため utf8 でデコード
        final data = json.decode(utf8.decode(response.bodyBytes));
        String newMessage = data['message'];

        if (mounted) {
          setState(() {
            // 最後に閉じたメッセージと違う場合のみ表示
            if (newMessage != _lastReadAnnouncement) {
              _announcement = newMessage;
            } else {
              _announcement = "";
            }
          });
        }
      }
    } catch (e) {
      debugPrint("お知らせの取得に失敗しました: $e");
    }
  }

  DateTime _getNormalizedGoal(DateTime now) {
    DateTime goal = DateTime(
      now.year,
      now.month,
      now.day,
      goalTime.hour,
      goalTime.minute,
    );
    if (now.difference(goal).inHours >= 6) {
      goal = goal.add(const Duration(days: 1));
    } else if (goal.difference(now).inHours >= 18) {
      goal = goal.subtract(const Duration(days: 1));
    }
    return goal;
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('開けませんでした: $urlString')));
      }
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_read_announcement', _lastReadAnnouncement);
    await prefs.setString(
      'app_data',
      json.encode({
        'goalTime': goalTime.toIso8601String(),
        'goalLabel': goalLabel,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'templates': templates,
        'quickMaster': quickMaster,
        'bufferMinutes': bufferMinutes,
        'isActive': isActive,
        'isCompleted': isCompleted,
        'last_read_announcement': _lastReadAnnouncement,
      }),
    );
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

        // 💡 波線が出ていた部分を { } で囲みました
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
        isCompleted = decodedData['isCompleted'] ?? false;
        _lastReadAnnouncement = decodedData['last_read_announcement'] ?? "";
      });
    }
  }

  void _saveCurrentAsTemplate() {
    String name = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テンプレート保存'),
        content: TextField(
          onChanged: (v) => name = v,
          decoration: const InputDecoration(labelText: '名前'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              if (name.isEmpty) return;
              setState(() {
                goalLabel = name;
                templates[name] = {
                  'goalLabel': name,
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
    // 💡 安全策：もし templates にその名前がなければ何もしない
    if (!templates.containsKey(name)) return;

    setState(() {
      final data = templates[name]!; // ここでは containsKey で確認済みなので安全
      goalLabel = data['goalLabel'] ?? name;
      tasks = (data['tasks'] as List)
          .map((item) => Task.fromJson(item))
          .toList();
      bufferMinutes = data['bufferMinutes'] ?? 0;
      isActive = false;
      isCompleted = false;
    });
    _saveData();
  }

  void _showManageTemplatesDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('管理'),
          content: SizedBox(
            width: double.maxFinite,
            child: templates.isEmpty
                ? const Text('なし')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: templates.keys.length,
                    itemBuilder: (context, i) {
                      String n = templates.keys.elementAt(i);
                      return ListTile(
                        title: Text(n),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              templates.remove(n);
                              _saveData();
                            });
                            setDialogState(() {});
                          },
                        ),
                        onTap: () {
                          _loadTemplate(n);
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
    String name = task?.name ?? '';
    int duration = task?.duration ?? 15;
    final isEditing = task != null;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? '編集' : '追加'),
          content: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'クイック追加',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ...quickMaster.entries.map(
                        (e) => InputChip(
                          label: Text(e.key),
                          onPressed: () {
                            setState(() {
                              tasks.add(Task(name: e.key, duration: e.value));
                              _saveData();
                            });
                            Navigator.pop(context);
                          },
                          onDeleted: () {
                            setState(() {
                              quickMaster.remove(e.key);
                              _saveData();
                            });
                            setDialogState(() {});
                          },
                          deleteIconColor: Colors.grey,
                        ),
                      ),
                      ActionChip(
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        avatar: const Icon(Icons.add, size: 16),
                        label: const Text('登録'),
                        onPressed: () {
                          if (name.isNotEmpty) {
                            setState(() {
                              quickMaster[name] = duration;
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
                    controller: TextEditingController(text: name),
                    decoration: const InputDecoration(labelText: '予定名'),
                    onChanged: (v) => name = v,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 150,
                    child: CupertinoTimerPicker(
                      mode: CupertinoTimerPickerMode.hm,
                      minuteInterval: 5,
                      initialTimerDuration: Duration(minutes: duration),
                      onTimerDurationChanged: (d) => duration = d.inMinutes,
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
                if (name.isEmpty) return;
                setState(() {
                  if (isEditing) {
                    tasks[index!] = Task(name: name, duration: duration);
                  } else {
                    tasks.add(Task(name: name, duration: duration));
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
    final normalizedGoal = _getNormalizedGoal(now);
    int tasksDur = tasks
        .where((t) => !t.isDone && !t.isSkipped)
        .fold(0, (sum, t) => sum + t.duration);
    int activeCount = tasks.where((t) => !t.isDone && !t.isSkipped).length;
    int totalNeeded =
        tasksDur + (activeCount > 1 ? (activeCount - 1) * bufferMinutes : 0);
    int timeDeficit = totalNeeded - normalizedGoal.difference(now).inMinutes;

    int totalDur =
        tasks.fold(0, (sum, t) => sum + t.duration) +
        (tasks.length > 1 ? (tasks.length - 1) * bufferMinutes : 0);
    DateTime nextStart = normalizedGoal.subtract(Duration(minutes: totalDur));
    List<DateTime> calcTimes = [];
    for (var t in tasks) {
      calcTimes.add(nextStart);
      nextStart = nextStart.add(Duration(minutes: t.duration + bufferMinutes));
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
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.folder_special),
            onSelected: (v) {
              if (v == 'save_new') {
                _saveCurrentAsTemplate();
              } else if (v == 'manage') {
                _showManageTemplatesDialog();
              } else if (v == 'reset') {
                setState(() {
                  for (var t in tasks) {
                    t.isDone = false;
                    t.isSkipped = false;
                  }
                  isActive = false;
                  isCompleted = false;
                });
                _saveData();
              } else if (v == 'show_announcement') {
                // 💡 ここでダイアログを表示
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('最新のお知らせ'),
                    content: const Text(
                      "【お知らせ】最新版 v1.0.2 が公開されました！Googleドライブから更新してください。",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('閉じる'),
                      ),
                    ],
                  ),
                );
              } else if (v == 'feedback') {
                _launchURL(
                  'https://docs.google.com/forms/d/e/1FAIpQLSfwPKdGwoEvtr3VvRbvYGuMjd6Gb0_VHIs83OCQo_Cvltv5-A/viewform?usp=pp_url&entry.1476558753=%E4%BA%88%E5%AE%9A%E9%80%86%E7%AE%97%E3%82%A2%E3%83%97%E3%83%AA',
                );
              } else {
                // 💡 上記のどれにも当てはまらない場合（保存したテンプレート名の場合）のみ実行
                _loadTemplate(v);
              }
            },
            itemBuilder: (c) => [
              const PopupMenuItem(
                value: 'save_new',
                child: Row(
                  children: [
                    Icon(Icons.save, size: 18),
                    SizedBox(width: 8),
                    Text('保存'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'manage',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 18),
                    SizedBox(width: 8),
                    Text('管理'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text('全リセット'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              ...templates.keys.map(
                (n) => PopupMenuItem(value: n, child: Text(n)),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'show_announcement',
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[700],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('最新のお知らせ'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'feedback',
                child: Row(
                  children: [
                    Icon(Icons.feedback_outlined, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Text('フィードバックを送る'),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: Chip(label: Text('合計: $totalDur分'))),
          ),
        ],
      ),
      body: Column(
        children: [
          // 💡 お知らせバナー（内容がある場合のみ表示）
          if (_announcement.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.yellow[100],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _announcement,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() {
                        _lastReadAnnouncement = _announcement; // 💡 今の内容を既読にする
                        _announcement = ""; // 画面から消す
                      });
                      _saveData(); // 💡 既読状態を保存
                    },
                  ),
                ],
              ),
            ),
          _buildDynamicBanner(
            allFinished,
            timeDeficit,
            normalizedGoal,
            now,
            calcTimes,
          ),
          _buildGoalTimeTile(normalizedGoal),
          _buildBufferPanel(),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: tasks.length,
              onReorderItem: (oldI, newI) {
                setState(() {
                  final item = tasks.removeAt(oldI);
                  tasks.insert(newI, item);
                  _saveData();
                });
              },
              itemBuilder: (c, i) => _buildTaskTile(tasks[i], calcTimes[i], i),
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

  Widget _buildDynamicBanner(
    bool allFinished,
    int deficit,
    DateTime goal,
    DateTime now,
    List<DateTime> times,
  ) {
    if (!isActive) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        color: Colors.indigo.withValues(alpha: 0.8),
        child: ElevatedButton.icon(
          onPressed: () async {
            setState(() {
              isActive = true;
              isCompleted = false;
              for (var t in tasks) {
                t.isDone = false;
                t.isSkipped = false;
              }
            });
            _saveData();
            if (!kIsWeb) {
              try {
                await NotificationService().cancelAll();
                for (int i = 0; i < tasks.length; i++) {
                  if (times[i].isAfter(DateTime.now())) {
                    await NotificationService().scheduleNotification(
                      id: i,
                      title: 'タスク開始',
                      body: '次は「${tasks[i].name}」',
                      scheduledDate: times[i],
                    );
                  }
                }
              } catch (e) {
                debugPrint(e.toString());
              }
            }
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text('準備を開始する'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.indigo,
          ),
        ),
      );
    }
    return Column(
      children: [
        if (deficit > 0 && !allFinished && !isCompleted)
          Container(
            width: double.infinity,
            color: Colors.redAccent,
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  '時間が $deficit 分足りません！',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        Builder(
          builder: (context) {
            final diff = goal.difference(now).inMinutes;
            if (isCompleted) {
              final color = diff > 0
                  ? Colors.teal
                  : (diff == 0 ? Colors.orange : Colors.red);
              return Container(
                width: double.infinity,
                color: color,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      diff < 0 ? Icons.warning : Icons.celebration,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        diff > 0
                            ? "準備完了！出発時間 $diff 分前です。"
                            : (diff == 0
                                  ? "出発時間になりました！"
                                  : "出発時間から ${diff.abs()} 分過ぎています"),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          isActive = false;
                          isCompleted = false;
                        });
                        _saveData();
                        if (!kIsWeb) {
                          try {
                            await NotificationService().cancelAll();
                          } catch (e) {
                            debugPrint(e.toString());
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: color,
                      ),
                      child: const Text('終了'),
                    ),
                  ],
                ),
              );
            } else {
              final color = Colors.indigo.withValues(alpha: 0.9);
              return Container(
                width: double.infinity,
                color: color,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      allFinished ? Icons.help_outline : Icons.directions_run,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        allFinished ? "タスク完了！今なら出発まで $diff 分前です！" : '準備実行中...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (allFinished) ...[
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isCompleted = true;
                          });
                          _saveData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.indigo,
                        ),
                        child: const Text('完了'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          isActive = false;
                          isCompleted = false;
                        });
                        _saveData();
                        if (!kIsWeb) {
                          try {
                            await NotificationService().cancelAll();
                          } catch (e) {
                            debugPrint(e.toString());
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        side: const BorderSide(color: Colors.white),
                      ),
                      child: const Text('中止'),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildGoalTimeTile(DateTime goal) {
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
            DateFormat('HH:mm').format(goal),
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
        final t = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(goalTime),
          builder: (c, ch) => MediaQuery(
            data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
            child: ch!,
          ),
        );

        // 💡 if文を { } で囲みます
        if (t != null) {
          setState(() {
            goalTime = DateTime(
              goalTime.year,
              goalTime.month,
              goalTime.day,
              t.hour,
              t.minute,
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
                        onSelected: (s) {
                          // 💡 if文を { } で囲みます
                          if (s) {
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
            onChanged: (v) => setState(() {
              bufferMinutes = v.toInt();
              _saveData();
            }),
          ),
        ],
      ),
    );
  }

  IconData _getTaskIcon(String n) {
    String s = n.toLowerCase();
    if (s.contains('風呂') || s.contains('洗い')) return Icons.bathtub_outlined;
    if (s.contains('walk') || s.contains('歩')) return Icons.directions_walk;
    if (s.contains('バス') || s.contains('電車')) return Icons.directions_bus;
    if (s.contains('スッキリ')) return Icons.face_retouching_natural;
    if (s.contains('spare') || s.contains('余裕')) return Icons.weekend_outlined;
    if (s.contains('飯') || s.contains('食')) return Icons.restaurant;
    if (s.contains('服') || s.contains('着')) return Icons.checkroom;
    return Icons.task_alt;
  }

  Widget _buildTaskTile(Task t, DateTime s, int i) {
    final now = DateTime.now();
    final end = s.add(Duration(minutes: t.duration));
    bool isCur = now.isAfter(s) && now.isBefore(end);
    bool isLate = now.isAfter(end) && !t.isDone;
    return Dismissible(
      key: ValueKey(t.hashCode + i),
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
      onDismissed: (d) {
        final old = t;
        setState(() {
          tasks.removeAt(i);
          _saveData();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${old.name} 削除'),
            action: SnackBarAction(
              label: '戻す',
              onPressed: () {
                setState(() {
                  tasks.insert(i, old);
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
          onTap: () => _showTaskDialog(task: t, index: i),
          tileColor: isCur && !t.isSkipped
              ? Colors.blue.withValues(alpha: 0.1)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isCur && !t.isSkipped
                ? const BorderSide(color: Colors.blue, width: 2)
                : BorderSide.none,
          ),
          leading: t.isSkipped
              ? const Icon(Icons.block, color: Colors.grey)
              : Checkbox(
                  value: t.isDone,
                  onChanged: (v) {
                    setState(() {
                      t.isDone = v ?? false;
                      if (!t.isDone) isCompleted = false;
                      _saveData();
                    });
                  },
                ),
          title: Row(
            children: [
              Icon(
                t.isSkipped ? Icons.redo : _getTaskIcon(t.name),
                size: 18,
                color: (t.isDone || t.isSkipped)
                    ? Colors.grey
                    : (isLate ? Colors.red : Colors.indigo),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.name + (t.isSkipped ? ' (スキップ)' : ''),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: (t.isDone || t.isSkipped)
                        ? TextDecoration.lineThrough
                        : null,
                    color: (t.isDone || t.isSkipped)
                        ? Colors.grey
                        : (isLate ? Colors.red : Colors.black),
                    fontStyle: t.isSkipped
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
              if (isActive && !t.isDone)
                IconButton(
                  icon: Icon(
                    t.isSkipped ? Icons.replay : Icons.fast_forward,
                    size: 20,
                    color: t.isSkipped ? Colors.blue : Colors.orange,
                  ),
                  onPressed: () => setState(() {
                    t.isSkipped = !t.isSkipped;
                    if (!t.isSkipped && !t.isDone) isCompleted = false;
                    _saveData();
                  }),
                ),
              if (isCur && !t.isSkipped)
                const Badge(label: Text('NOW'), backgroundColor: Colors.blue),
            ],
          ),
          subtitle: isCur && !t.isSkipped
              ? Text(
                  'あと ${end.difference(now).inMinutes + 1} 分',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Text('${t.duration}分'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('HH:mm').format(s),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: t.isDone
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
                index: i,
                child: const Icon(Icons.drag_handle, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGoalLabelEditDialog() {
    String n = goalLabel;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('目標名変更'),
        content: TextField(
          controller: TextEditingController(text: goalLabel),
          onChanged: (v) => n = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                goalLabel = n;
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
