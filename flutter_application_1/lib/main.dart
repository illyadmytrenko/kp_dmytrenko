import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class Task {
  String title;
  String description;
  DateTime dueDate;
  String category;
  bool isCompleted;

  Task({
    required this.title,
    required this.description,
    required this.dueDate,
    this.category = 'Other',
    this.isCompleted = false,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      title: json['title'],
      description: json['description'],
      dueDate: DateTime.parse(json['dueDate']),
      category: json['category'] ?? 'Custom',
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'category': category,
      'isCompleted': isCompleted,
    };
  }
}

//------------------------------------------------------------//

class TaskListProvider extends ChangeNotifier {
  List<Task> tasks = [];
  TaskListProvider() {
    loadTasks();
  }

  void loadTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String tasksJson = prefs.getString('tasks') ?? '[]';

    List<Map<String, dynamic>> tasksMapList =
        List<Map<String, dynamic>>.from(json.decode(tasksJson));

    tasks = tasksMapList.map((taskMap) => Task.fromJson(taskMap)).toList();

    notifyListeners();
  }

  void saveTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String tasksJson = json.encode(tasks.map((task) => task.toJson()).toList());
    prefs.setString('tasks', tasksJson);
  }

  void addTask(Task task, [String sortBy = 'By Date (Newest First)']) {
    tasks.add(task);
    saveTasks();
    sortTasks(sortBy);
    notifyListeners();
  }

  void updateTask(int index, Task task,
      [String sortBy = 'By Date (Newest First)']) {
    tasks[index] = task;
    saveTasks();
    sortTasks(sortBy);
    notifyListeners();
  }

  void deleteTask(int index) {
    tasks.removeAt(index);
    saveTasks();
    notifyListeners();
  }

  void sortTasks(String sortBy) {
    switch (sortBy) {
      case 'By Date (Newest First)':
        tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case 'By Date (Oldest First)':
        tasks.sort((a, b) => b.dueDate.compareTo(a.dueDate));
        break;
      case 'Completed':
        tasks.sort((a, b) => a.isCompleted == b.isCompleted
            ? 0
            : a.isCompleted
                ? -1
                : 1);
        break;
      case 'Incomplete':
        tasks.sort((a, b) => a.isCompleted == b.isCompleted
            ? 0
            : a.isCompleted
                ? 1
                : -1);
        break;
      case 'Work':
      case 'Personal':
      case 'Study':
      case 'Health':
      case 'Home':
      case 'Other':
        tasks.sort((a, b) {
          if (a.category == sortBy && b.category != sortBy) {
            return -1;
          } else if (a.category != sortBy && b.category == sortBy) {
            return 1;
          } else {
            return a.dueDate.compareTo(b.dueDate);
          }
        });
        break;
    }
    notifyListeners();
  }
}

//------------------------------------------------------------//

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TaskListProvider(),
      child: MaterialApp(
        title: 'Task Manager',
        initialRoute: '/',
        routes: {
          '/': (context) => TaskListScreen(),
          '/calendar': (context) => CalendarScreen(),
        },
      ),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  @override
  TaskListScreenState createState() => TaskListScreenState();
}

//------------------------------------------------------------//

class TaskListScreenState extends State<TaskListScreen> {
  bool showCompletedTasks = false;
  String selectedMonth = 'All';
  int selectedYear = DateTime.now().year;
  static String selectedFilter = 'By Date (Newest First)';
  int _currentIndex = 0;

  @override
  void initState() {
    CustomDropdown.showBorder = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Color.fromARGB(255, 249, 253, 255),
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(width: 20),
              buildMonthDropdown(),
              SizedBox(width: 20),
              buildYearDropdown(),
              SizedBox(width: 20),
              buildFilterDropdown(),
            ],
          ),
        ),
      ),
      backgroundColor: Color.fromARGB(255, 247, 252, 255),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Consumer<TaskListProvider>(
          builder: (context, taskProvider, child) {
            List<Task> filteredTasks = filterTasks(taskProvider.tasks);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: ListView.builder(
                itemCount: filteredTasks.length,
                itemBuilder: (context, index) {
                  Task task = filteredTasks[index];
                  return TaskItem(
                    task: task,
                    onCheckboxChanged: (value) {
                      taskProvider.updateTask(
                        taskProvider.tasks.indexOf(task),
                        Task(
                          title: task.title,
                          description: task.description,
                          dueDate: task.dueDate,
                          category: task.category,
                          isCompleted: value!,
                        ),
                      );
                      if (value) {
                        TaskItem.showCompletionDialog(context, task);
                      }
                    },
                    onEditPressed: () {
                      FloatingButton.showTaskDialog(
                        context,
                        taskProvider,
                        selectedFilter,
                        taskProvider.tasks.indexOf(task),
                      );
                    },
                    onDeletePressed: () {
                      taskProvider.deleteTask(taskProvider.tasks.indexOf(task));
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingButton(),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          CustomBottomNavigationBar.navigateToScreen(context, index);
        },
      ),
    );
  }

  static const List<String> months = [
    'All',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  Widget buildMonthDropdown() {
    return CustomDropdown<String>(
      options: months,
      selectedValue: selectedMonth,
      onChanged: (String? newValue) {
        setState(() {
          selectedMonth = newValue!;
        });
      },
    );
  }

  Widget buildYearDropdown() {
    int currentYear = DateTime.now().year;
    List<int> years = List.generate(10, (index) => currentYear + index);

    return CustomDropdown<int>(
      options: years,
      selectedValue: selectedYear,
      onChanged: (int? newValue) {
        setState(() {
          selectedYear = newValue!;
        });
      },
    );
  }

  Widget buildFilterDropdown() {
    List<String> filterOptions = [
      'By Date (Newest First)',
      'By Date (Oldest First)',
      'Completed',
      'Incomplete',
      'Work',
      'Personal',
      'Study',
      'Health',
      'Home',
      'Other',
    ];

    return CustomDropdown<String>(
      options: filterOptions,
      selectedValue: selectedFilter,
      onChanged: onFilterChanged,
    );
  }

  List<Task> filterTasks(List<Task> tasks) {
    if (selectedMonth == "All") {
      return tasks.where((task) => task.dueDate.year == selectedYear).toList();
    } else {
      int selectedMonthIndex = months.indexOf(selectedMonth);
      return tasks
          .where((task) =>
              task.dueDate.month == selectedMonthIndex &&
              task.dueDate.year == selectedYear)
          .toList();
    }
  }

  void onFilterChanged(String? newValue) {
    setState(() {
      selectedFilter = newValue!;
      context.read<TaskListProvider>().sortTasks(selectedFilter);
    });
  }
}

//------------------------------------------------------------//

class TaskDialog extends StatefulWidget {
  Task task;
  TaskListProvider taskProvider;
  String selectedFilter;
  int? index;

  TaskDialog({
    required this.task,
    required this.taskProvider,
    required this.selectedFilter,
    this.index,
  });

  @override
  TaskDialogState createState() => TaskDialogState();
}

//------------------------------------------------------------//

class TaskDialogState extends State<TaskDialog> {
  late String selectedCategory;

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.task.category;
    CustomDropdown.showBorder = false;
  }

  List<String> baseCategories = [
    'Other',
    'Work',
    'Personal',
    'Study',
    'Health',
    'Home',
  ];

  @override
  Widget build(BuildContext context) {
    String title = widget.task.title;
    return AlertDialog(
      title: Center(
        child: Text(
          widget.index != null ? 'Edit Task' : 'Add Task',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      content: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            // padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1),
                borderRadius: BorderRadius.circular(8),
                color: Color.fromARGB(255, 217, 222, 224),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  decoration: InputDecoration(labelText: 'Title'),
                  controller: TextEditingController(text: widget.task.title),
                  onChanged: (value) {
                    widget.task.title = value;
                    if (widget.task.title.length < 1) setState(() {});
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            // padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1),
                borderRadius: BorderRadius.circular(8),
                color: Color.fromARGB(255, 217, 222, 224),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  decoration: InputDecoration(labelText: 'Description'),
                  controller:
                      TextEditingController(text: widget.task.description),
                  onChanged: (value) {
                    widget.task.description = value;
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            // padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1),
                borderRadius: BorderRadius.circular(8),
                color: Color.fromARGB(255, 217, 222, 224),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Text('Due Date: '),
                    TextButton(
                      onPressed: () async {
                        DateTime? selectedDate = await showDatePicker(
                          context: context,
                          initialDate: widget.task.dueDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (selectedDate != null) {
                          TimeOfDay? selectedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (selectedTime != null) {
                            selectedDate = DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              selectedTime.hour,
                              selectedTime.minute,
                            );
                            setState(() {
                              widget.task.dueDate = selectedDate!;
                            });
                          }
                        }
                      },
                      child: Consumer<TaskListProvider>(
                        builder: (context, taskProvider, child) {
                          return Text(
                            DateFormat('yyyy-MM-dd HH:mm')
                                .format(widget.task.dueDate),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            // padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1),
                borderRadius: BorderRadius.circular(8),
                color: Color.fromARGB(255, 217, 222, 224),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Text('Category: '),
                    SizedBox(width: 8),
                    CustomDropdown<String>(
                      options: baseCategories,
                      selectedValue: selectedCategory,
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedCategory = newValue!;
                          widget.task.category = newValue;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        Container(
          padding: EdgeInsets.all(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.red),
                  foregroundColor: MaterialStateProperty.all(Colors.white),
                  textStyle: MaterialStateProperty.all(TextStyle(fontSize: 16)),
                ),
                child: Text('Cancel'),
              ),
              SizedBox(width: 20),
              TextButton(
                onPressed: () {
                  if (widget.task.title.isEmpty) {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text(
                            'Please enter a title',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.black, width: 1),
                          ),
                        );
                      },
                    );
                  } else {
                    if (widget.index != null) {
                      widget.taskProvider.updateTask(
                          widget.index!, widget.task, widget.selectedFilter);
                    } else {
                      widget.taskProvider
                          .addTask(widget.task, widget.selectedFilter);
                    }
                    Navigator.of(context).pop();
                  }
                },
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.green),
                  foregroundColor: MaterialStateProperty.all(Colors.white),
                  textStyle: MaterialStateProperty.all(TextStyle(fontSize: 16)),
                ),
                child: Text('Save'),
              ),
            ],
          ),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black, width: 1),
      ),
    );
  }
}

//------------------------------------------------------------//

class CalendarScreen extends StatefulWidget {
  @override
  CalendarScreenState createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  int _currentIndex = 1;

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskListProvider>(context, listen: true);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 30, left: 20, right: 20, bottom: 20),
            // padding: EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 5),
            child: ClipRRect(
              child: Container(
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 123, 218, 255),
                  border: Border.all(color: Colors.black, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TableCalendar(
                  calendarFormat: _calendarFormat,
                  focusedDay: _focusedDay,
                  firstDay: DateTime(2024),
                  lastDay: DateTime(2100),
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: TextStyle(fontWeight: FontWeight.w700),
                      weekendStyle: TextStyle(fontWeight: FontWeight.w700)),
                  calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      tablePadding: EdgeInsets.all(10)),
                  headerStyle: HeaderStyle(
                      titleTextStyle:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                  availableCalendarFormats: {CalendarFormat.month: 'Month'},
                  eventLoader: (day) {
                    if (!isSameDay(_selectedDay, day) &&
                        hasTasksForDate(taskProvider.tasks, day)) {
                      return [
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 5,
                            width: 10,
                            color: Colors.red,
                          ),
                        ),
                      ];
                    }
                    return [];
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: buildTaskList(),
          ),
        ],
      ),
      floatingActionButton: FloatingButton(),
      backgroundColor: Color.fromARGB(255, 239, 250, 255),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          CustomBottomNavigationBar.navigateToScreen(context, index);
        },
      ),
    );
  }

  Widget buildTaskList() {
    return CalendarTaskList(selectedDate: _selectedDay);
  }

  bool hasTasksForDate(List<Task> tasks, DateTime date) {
    return tasks.any((task) => isSameDay(task.dueDate, date));
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}

//------------------------------------------------------------//

class CalendarTaskList extends StatelessWidget {
  final DateTime selectedDate;
  final String selectedFilter = 'By Date (Newest First)';

  const CalendarTaskList({Key? key, required this.selectedDate})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskListProvider>(
      builder: (context, taskProvider, child) {
        List<Task> tasksForSelectedDate = filterTasks(taskProvider.tasks);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          child: ListView.builder(
            itemCount: tasksForSelectedDate.length,
            itemBuilder: (context, index) {
              Task task = tasksForSelectedDate[index];
              return TaskItem(
                task: task,
                onCheckboxChanged: (value) {
                  taskProvider.updateTask(
                    taskProvider.tasks.indexOf(task),
                    Task(
                      title: task.title,
                      description: task.description,
                      dueDate: task.dueDate,
                      category: task.category,
                      isCompleted: value!,
                    ),
                  );
                  if (value) {
                    TaskItem.showCompletionDialog(context, task);
                  }
                },
                onEditPressed: () {
                  FloatingButton.showTaskDialog(
                    context,
                    taskProvider,
                    selectedFilter,
                    taskProvider.tasks.indexOf(task),
                  );
                },
                onDeletePressed: () {
                  taskProvider.deleteTask(taskProvider.tasks.indexOf(task));
                },
              );
            },
          ),
        );
      },
    );
  }

  List<Task> filterTasks(List<Task> tasks) {
    return tasks
        .where((task) => isSameDay(task.dueDate, selectedDate))
        .toList();
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}

//------------------------------------------------------------//

class FloatingButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        showTaskDialog(
          context,
          context.read<TaskListProvider>(),
          TaskListScreenState.selectedFilter,
        );
      },
      child: Icon(Icons.add),
      backgroundColor: Color.fromARGB(255, 26, 77, 98),
      foregroundColor: Color.fromARGB(255, 240, 245, 247),
    );
  }

  static void showTaskDialog(BuildContext context,
      TaskListProvider taskProvider, String _selectedFilter,
      [int? index]) {
    Task task = index != null
        ? taskProvider.tasks[index]
        : Task(title: '', description: '', dueDate: DateTime.now());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TaskDialog(
          task: task,
          taskProvider: taskProvider,
          selectedFilter: _selectedFilter,
          index: index,
        );
      },
    );
  }
}

//------------------------------------------------------------//

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigationBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Color.fromARGB(255, 119, 165, 188),
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.black.withOpacity(0.4),
      currentIndex: currentIndex,
      onTap: onTap,
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.list),
          label: 'Tasks',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Calendar',
        ),
      ],
    );
  }

  static void navigateToScreen(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/');
        break;
      case 1:
        Navigator.pushNamed(context, '/calendar');
        break;
    }
  }
}

//------------------------------------------------------------//

class TaskItem extends StatelessWidget {
  final Task task;
  final Function(bool?) onCheckboxChanged;
  final Function() onEditPressed;
  final Function() onDeletePressed;

  const TaskItem({
    Key? key,
    required this.task,
    required this.onCheckboxChanged,
    required this.onEditPressed,
    required this.onDeletePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: Color.fromARGB(255, 217, 222, 224),
          leading: Checkbox(
            value: task.isCompleted,
            onChanged: onCheckboxChanged,
          ),
          title: Text(task.title),
          subtitle: Text(task.description),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: onEditPressed,
              ),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: onDeletePressed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showCompletionDialog(BuildContext context, Task task) {
    DateTime currentTime = DateTime.now();
    Duration completionTime = currentTime.difference(task.dueDate);

    String message;
    if (completionTime.isNegative) {
      message = "The task '${task.title}' was completed earlier than planned.";
    } else {
      message = "The task '${task.title}' has been completed.";
    }

    String timeMessage =
        "You have completed the task for ${completionTime.inMinutes} minutes.";
    if (completionTime.inHours > 0) {
      timeMessage =
          "You have completed the task for ${completionTime.inHours} hours and ${completionTime.inMinutes.remainder(60)} minutes.";
    }

    if (completionTime.isNegative) {
      completionTime = completionTime.abs();
      timeMessage =
          "You have completed the task for ${completionTime.inMinutes} minutes before the deadline.";
      if (completionTime.inHours > 0) {
        timeMessage =
            "You have completed the task for ${completionTime.inHours} hours and ${completionTime.inMinutes.remainder(60)} minutes before the deadline.";
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: BorderSide(color: Colors.black, width: 1),
          ),
          title: Center(child: Text("Task Completed")),
          titleTextStyle: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 24, color: Colors.black),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(message, textAlign: TextAlign.center),
              SizedBox(height: 10),
              Text("$timeMessage", textAlign: TextAlign.center),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(Colors.green),
                foregroundColor: MaterialStateProperty.all(Colors.white),
                textStyle: MaterialStateProperty.all(TextStyle(fontSize: 16)),
              ),
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }
}

//------------------------------------------------------------//

class CustomDropdown<T> extends StatelessWidget {
  final List<T> options;
  final T selectedValue;
  final void Function(T?) onChanged;
  static bool showBorder = true;

  const CustomDropdown({
    Key? key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Color.fromARGB(255, 217, 222, 224),
        border: showBorder ? Border.all(color: Colors.black, width: 1) : null,
      ),
      child: DropdownButton<T>(
        value: selectedValue,
        onChanged: onChanged,
        underline: Container(),
        focusColor: Color.fromARGB(255, 240, 245, 247),
        dropdownColor: Color.fromARGB(255, 240, 245, 247),
        borderRadius: BorderRadius.circular(12),
        alignment: Alignment.center,
        items: options.map<DropdownMenuItem<T>>((T value) {
          return DropdownMenuItem<T>(
            value: value,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(value.toString()),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
