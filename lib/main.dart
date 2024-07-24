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
  Map<String, bool> taskVisibility = {}; // Explicitly define type

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
        tasks = (json.decode(storedTasks) as List<dynamic>)
            .cast<Map<String, dynamic>>();
        // Initialize taskVisibility map
        tasks.forEach((task) {
          taskVisibility[task['id'] as String] = false; // Explicitly cast to String
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
        'progress': 0, // Progress indicator, starts at 0
      };

      setState(() {
        tasks.add(newTask);
        taskVisibility[newTask['id'] as String] = false; // Explicitly cast to String
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

      _updateTaskProgress(taskId); // Update progress when task is checked/unchecked

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
        final completedSubTasks =
            subTasks.where((subTask) => subTask['isChecked']).length;
        final progress =
        (completedSubTasks / totalSubTasks * 100).toInt();
        setState(() {
          tasks[index]['progress'] = progress;
        });
      } else {
        // If there are no subtasks, set progress to 100% if task is completed
        final isChecked = task['isChecked'] ?? false;
        final progress = isChecked ? 100 : 0;
        setState(() {
          tasks[index]['progress'] = progress;
        });
      }
    }
  }

  Future<void> toggleSubTask(
      String taskId, int subTaskIndex, bool isChecked) async {
    final index = tasks.indexWhere((task) => task['id'] == taskId);
    if (index != -1) {
      setState(() {
        tasks[index]['subTasks'][subTaskIndex]['isChecked'] = isChecked;
      });

      _updateTaskProgress(taskId); // Update progress when subtask is checked/unchecked

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('tasks', json.encode(tasks));
    }
  }

  // Function to toggle subtasks visibility
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
      // Display all tasks, whether completed or not
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
                final taskDateTime =
                DateTime.parse(task['dateTime']);
                final progress =
                calculateTaskProgress(task); // Calculate progress

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('yyyy-MM-dd').format(
                          taskDateTime), // Display date
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Progress: $progress%', // Display progress
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
                          decoration: isChecked
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              deleteTask(taskId);
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.add),
                            onPressed: () {
                              _showSubTaskInputDialog(
                                  context, taskId);
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.expand),
                            onPressed: () {
                              toggleSubtasksVisibility(
                                  taskId);
                            },
                          ),
                          Checkbox(
                            value: isChecked,
                            onChanged: (bool? value) {
                              updateTask(taskId,
                                  isChecked: value ?? false);
                            },
                          ),
                        ],
                      ),
                    ),
                    if (taskVisibility[taskId] ?? false)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...List.generate(
                            task['subTasks'].length,
                                (subIndex) {
                              final subTask =
                              task['subTasks'][subIndex];
                              return Row(
                                children: [
                                  Checkbox(
                                    value: subTask['isChecked'],
                                    onChanged: (bool? value) {
                                      toggleSubTask(
                                          taskId,
                                          subIndex,
                                          value ?? false);
                                    },
                                  ),
                                  Text(subTask['subTask']),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    if (!isChecked) Divider(), // Show divider only for tasks that are not checked
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  // Function to calculate task progress
  int calculateTaskProgress(Map<String, dynamic> task) {
    bool isChecked = task['isChecked'] ?? false;
    if (isChecked) {
      return 100; // If main task is checked, progress is 100%
    } else {
      List<dynamic> subTasks = task['subTasks'] ?? [];
      int totalSubTasks = subTasks.length;
      int completedSubTasks =
          subTasks.where((subTask) => subTask['isChecked']).length;
      return totalSubTasks > 0
          ? ((completedSubTasks / totalSubTasks) * 100).toInt()
          : 0;
    }
  }

  Future<void> _showTaskInputDialog(BuildContext context) async {
    String taskName = '';
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add a Task'),
          content: Form(
            key: _form,
            child: TextFormField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter task name',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a task name';
                }
                return null;
              },
              onChanged: (value) {
                taskName = value;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Add'),
              onPressed: () {
                if (_form.currentState!.validate()) {
                  addTask(taskName);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSubTaskInputDialog(
      BuildContext context, String taskId) async {
    String subTaskName = '';
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add a Subtask'),
          content: Form(
            key: _form,
            child: TextFormField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter subtask name',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a subtask name';
                }
                return null;
              },
              onChanged: (value) {
                subTaskName = value;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Add'),
              onPressed: () {
                if (_form.currentState!.validate()) {
                  addSubTask(taskId, subTaskName);
                  Navigator.of(context).pop();
                }
              },
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