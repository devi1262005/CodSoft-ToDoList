import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ToDoPage extends StatefulWidget {
  const ToDoPage({Key? key}) : super(key: key);

  @override
  _ToDoPageState createState() => _ToDoPageState();
}

class _ToDoPageState extends State<ToDoPage> {
  final _form = GlobalKey<FormState>();
  List<Map<String, dynamic>> tasks = [];
  bool isLoading = true;
  Map<String, bool> taskVisibility = {};

  @override
  void initState() {
    super.initState();
    readData();
  }

  Future<void> readData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedTasks = prefs.getString('tasks');

    if (storedTasks != null) {
      setState(() {
        tasks = (json.decode(storedTasks) as List<dynamic>).cast<Map<String, dynamic>>();
        tasks.forEach((task) {
          taskVisibility[task['id'] as String] = false;
        });
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> addTask(String taskName) async {
    if (taskName.isNotEmpty) {
      final newTask = {
        'task': taskName,
        'subTasks': [],
        'isChecked': false,
        'dateTime': DateTime.now().toString(),
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'progress': 0,
      };

      setState(() {
        tasks.add(newTask);
        taskVisibility[newTask['id'] as String] = false;
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('tasks', json.encode(tasks));
    }
  }

  Future<void> addSubTask(String taskId, String subTaskName) async {
    final index = tasks.indexWhere((task) => task['id'] == taskId);
    if (index != -1) {
      final newSubTask = {
        'subTask': subTaskName,
        'isChecked': false,
      };
      setState(() {
        tasks[index]['subTasks'].add(newSubTask);
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('tasks', json.encode(tasks));
    }
  }

  Future<void> deleteTask(String taskId) async {
    setState(() {
      tasks.removeWhere((task) => task['id'] == taskId);
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('tasks', json.encode(tasks));
  }

  Future<void> updateTask(String taskId, {required bool isChecked}) async {
    final index = tasks.indexWhere((task) => task['id'] == taskId);
    if (index != -1) {
      setState(() {
        tasks[index]['isChecked'] = isChecked;
      });

      _updateTaskProgress(taskId);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('tasks', json.encode(tasks));
    }
  }

  void _updateTaskProgress(String taskId) {
    final index = tasks.indexWhere((task) => task['id'] == taskId);
    if (index != -1) {
      final task = tasks[index];
      final subTasks = task['subTasks'] as List<dynamic>;
      final totalSubTasks = subTasks.length;
      if (totalSubTasks > 0) {
        final completedSubTasks = subTasks.where((subTask) => subTask['isChecked']).length;
        final progress = (completedSubTasks / totalSubTasks * 100).toInt();
        setState(() {
          tasks[index]['progress'] = progress;
        });
      } else {
        final isChecked = task['isChecked'] ?? false;
        final progress = isChecked ? 100 : 0;
        setState(() {
          tasks[index]['progress'] = progress;
        });
      }
    }
  }

  Future<void> toggleSubTask(String taskId, int subTaskIndex, bool isChecked) async {
    final index = tasks.indexWhere((task) => task['id'] == taskId);
    if (index != -1) {
      setState(() {
        tasks[index]['subTasks'][subTaskIndex]['isChecked'] = isChecked;
      });

      _updateTaskProgress(taskId);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('tasks', json.encode(tasks));
    }
  }

  void toggleSubtasksVisibility(String taskId) {
    setState(() {
      taskVisibility[taskId] = !(taskVisibility[taskId] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Center(
            child: Text(
              "To Do",
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tasks'),
              Tab(text: 'In Progress'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: isLoading
            ? Center(
          child: CircularProgressIndicator(),
        )
            : TabBarView(
          children: [
            buildTaskList(context, 'Tasks'),
            buildTaskList(context, 'In Progress'),
            buildTaskList(context, 'Completed'),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _showTaskInputDialog(context);
          },
          tooltip: 'Add Task',
          child: Icon(Icons.add),
          backgroundColor: Colors.amber,
        ),
      ),
    );
  }

  Widget buildTaskList(BuildContext context, String tab) {
    List<Map<String, dynamic>> filteredTasks = [];
    if (tab == 'Tasks') {
      filteredTasks = tasks.toList();
    } else if (tab == 'In Progress') {
      filteredTasks = tasks.where((task) => !task['isChecked']).toList();
    } else if (tab == 'Completed') {
      filteredTasks = tasks.where((task) => task['isChecked']).toList();
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: filteredTasks.isEmpty
                ? Center(
              child: Text(
                "No tasks yet",
                style: TextStyle(fontSize: 18.0),
              ),
            )
                : ListView.builder(
              itemCount: filteredTasks.length,
              itemBuilder: (context, index) {
                final task = filteredTasks[index];
                final taskName = task['task'] ?? '';
                final isChecked = task['isChecked'] ?? false;
                final taskId = task['id'];
                final taskDateTime = DateTime.parse(task['dateTime']);
                final progress = calculateTaskProgress(task);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('yyyy-MM-dd').format(taskDateTime),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Progress: $progress%',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    ListTile(
                      title: Text(
                        taskName,
                        style: TextStyle(
                          decoration: isChecked ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: buildTrailingButtons(tab, taskId, isChecked),
                      ),
                    ),
                    if (taskVisibility[taskId] ?? false)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children: List.generate(
                            task['subTasks'].length,
                                (subIndex) {
                              final subTask = task['subTasks'][subIndex];
                              return Row(
                                children: [
                                  Checkbox(
                                    value: subTask['isChecked'],
                                    onChanged: (bool? value) {
                                      toggleSubTask(taskId, subIndex, value ?? false);
                                    },
                                  ),
                                  Text(subTask['subTask']),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    Divider(), // Keeps the divider always visible
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  int calculateTaskProgress(Map<String, dynamic> task) {
    bool isChecked = task['isChecked'] ?? false;
    if (isChecked) {
      return 100;
    } else {
      List<dynamic> subTasks = task['subTasks'] ?? [];
      int totalSubTasks = subTasks.length;
      int completedSubTasks = subTasks.where((subTask) => subTask['isChecked']).length;
      return totalSubTasks > 0 ? ((completedSubTasks / totalSubTasks) * 100).toInt() : 0;
    }
  }

  List<Widget> buildTrailingButtons(String tab, String taskId, bool isChecked) {
    List<Widget> buttons = [];
    if (tab == 'Tasks') {
      buttons = [
        IconButton(
          icon: Icon(Icons.check),
          onPressed: () {
            updateTask(taskId, isChecked: !isChecked);
          },
        ),
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () {
            _showSubTaskInputDialog(context, taskId);
          },
        ),
        IconButton(
          icon: Icon(taskVisibility[taskId] ?? false ? Icons.expand_less : Icons.expand_more),
          onPressed: () {
            toggleSubtasksVisibility(taskId);
          },
        ),
        IconButton(
          icon: Icon(Icons.delete),
          onPressed: () {
            deleteTask(taskId);
          },
        ),
      ];
    } else {
      buttons = [
        IconButton(
          icon: Icon(taskVisibility[taskId] ?? false ? Icons.expand_less : Icons.expand_more),
          onPressed: () {
            toggleSubtasksVisibility(taskId);
          },
        ),
        IconButton(
          icon: Icon(Icons.delete),
          onPressed: () {
            deleteTask(taskId);
          },
        ),
      ];
    }
    return buttons;
  }

  void _showTaskInputDialog(BuildContext context) {
    final TextEditingController taskController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add Task"),
          content: TextField(
            controller: taskController,
            decoration: InputDecoration(hintText: "Task name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (taskController.text.isNotEmpty) {
                  addTask(taskController.text);
                }
                Navigator.of(context).pop();
              },
              child: Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void _showSubTaskInputDialog(BuildContext context, String taskId) {
    final TextEditingController subTaskController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add Subtask"),
          content: TextField(
            controller: subTaskController,
            decoration: InputDecoration(hintText: "Subtask name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (subTaskController.text.isNotEmpty) {
                  addSubTask(taskId, subTaskController.text);
                }
                Navigator.of(context).pop();
              },
              child: Text("Add"),
            ),
          ],
        );
      },
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: ToDoPage(),
  ));
}