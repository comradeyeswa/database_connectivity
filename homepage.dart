import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'task.dart';
import 'package:path/path.dart';

class ToDoHomePage extends StatefulWidget {
  const ToDoHomePage({Key? key}) : super(key: key);

  @override
  State<ToDoHomePage> createState() => _ToDoHomePageState();
}

class _ToDoHomePageState extends State<ToDoHomePage> {
  late Future<Database> _database;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  List<TodoItem> _todoItems = [];
  List<TodoItem> _searchedTodoItems = [];
  bool _isSearching = false;


  @override
  void initState() {
    super.initState();
    _database = _initializeDatabase();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadTodoItems();
  }

  Future<Database> _initializeDatabase() async {
    final String path = join(await getDatabasesPath(), 'todo.db');

    return openDatabase(
      path,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE todos(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, description TEXT,isCompleted INTEGER)',
        );
      },
      version: 2,
    );
  }

  Future<void> _loadTodoItems() async {
    final Database db = await _database;
    final List<Map<String, dynamic>> maps = await db.query('todos');

    setState(() {
      _todoItems = List.generate(
        maps.length,
            (index) => TodoItem(
          id: maps[index]['id'],
          title: maps[index]['title'],
          description: maps[index]['description'],
          isCompleted: maps[index]['isCompleted'] == 1,
        ),
      );
    });
  }

  Future<void> _addTodoItem(String title, String description) async {
    final Database db = await _database;
    final TodoItem newItem =
    TodoItem(title: title, description: description, isCompleted: false);

    final int itemId = await db.insert(
      'todos',
      newItem.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // await db.insert(
    //   'todos',
    //   newItem.toMap(),
    //   conflictAlgorithm: ConflictAlgorithm.replace,
    // );

    setState(() {
      //_todoItems.add(newItem);
      _todoItems.add(newItem.copyWith(id: itemId));
      _searchedTodoItems = List.from(_todoItems);
    });
  }

  Future<void> _toggleTodoItem(int id) async {
    final Database db = await _database;
    final int itemIndex = _todoItems.indexWhere((item) => item.id == id);
    final TodoItem toggledItem = _todoItems[itemIndex].copyWith(
      isCompleted: !_todoItems[itemIndex].isCompleted,
    );

    await db.update(
      'todos',
      toggledItem.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );

    setState(() {
      _todoItems[itemIndex] = toggledItem;
      _searchedTodoItems = List.from(_todoItems);
    });
  }

  Future<void> _deleteTodoItem(int id) async {
    final Database db = await _database;

    await db.delete(
      'todos',
      where: 'id = ?',
      whereArgs: [id],
    );

    setState(() {
      _todoItems.removeWhere((item) => item.id == id);
      _searchedTodoItems = List.from(_todoItems);
    });
  }

  Future<void> _editTodoItem(
      int id, String newTitle, String newDescription, bool isCompleted) async {
    final Database db = await _database;
    final int itemIndex = _todoItems.indexWhere((item) => item.id == id);
    final TodoItem editedItem = TodoItem(
        id: id,
        title: newTitle,
        description: newDescription,
        isCompleted: isCompleted);

    await db.update(
      'todos',
      editedItem.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    setState(() {
      _todoItems[itemIndex] = editedItem;
      _searchedTodoItems = List.from(_todoItems);
    });
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _titleController.clear();
      _descriptionController.clear();
      _searchedTodoItems = List.from(_todoItems);
    });
  }

  void _performSearch(String query) {
    final List<TodoItem> searchResults = _todoItems.where((item) {
      final String itemTitle = item.title.toLowerCase();
      final String itemDescription = item.description.toLowerCase();
      final String searchTerm = query.toLowerCase();

      return itemTitle.contains(searchTerm) || itemDescription.contains(searchTerm);
    }).toList();

    setState(() {
      _searchedTodoItems = searchResults;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching?TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: 'Search...',
            border: InputBorder.none,
          ),
          onChanged: _performSearch,
        )
            :const Text("TaskForce"),
        actions: [if(_isSearching)
          IconButton(onPressed: _stopSearch, icon: const Icon(Icons.clear),color: Colors.redAccent,)
        else
          IconButton(onPressed: _startSearch, icon: const Icon(Icons.search,color: Colors.white,)),],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _todoItems.length,
              itemBuilder: (context, index) {
                final TodoItem todoItem = _todoItems[index];
                return Card(child:ListTile(
                  title: Text(todoItem.title,
                      style: TextStyle(
                          decoration: todoItem.isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationThickness: 3.0)),
                  subtitle: Text(todoItem.description,
                      style: TextStyle(
                        decoration: todoItem.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationThickness: 3.0,
                      )),
                  tileColor: Colors.blueGrey,
                  splashColor: Colors.redAccent,
                  onTap: () {
                    _toggleTodoItem(todoItem.id!);
                    tapFunc(todoItem, context);
                  },
                  onLongPress: () => showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      _titleController.text = todoItem.title;
                      _descriptionController.text = todoItem.description;

                      return AlertDialog(
                        title: const Text('Edit Todo Item'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Title',
                              ),
                            ),
                            TextField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          ElevatedButton(
                            onPressed: () {
                              _editTodoItem(
                                todoItem.id!,
                                _titleController.text,
                                _descriptionController.text,
                                todoItem.isCompleted,
                              );
                              _titleController.clear();
                              _descriptionController.clear();
                              Navigator.of(context).pop();
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      );
                    },
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete,
                    ),
                    onPressed: () => _deleteTodoItem(todoItem.id!),
                    color: Colors.white,
                  ),
                ));
              },
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('New Todo Item'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                      ),
                    ),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      _addTodoItem(
                        _titleController.text,
                        _descriptionController.text,
                      );
                      _titleController.clear();
                      _descriptionController.clear();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void tapFunc(TodoItem todoItem, BuildContext context) {
    !todoItem.isCompleted
        ? showDialog(
        context: context,
        builder: (ctxt) => AlertDialog(
          title: const Text(
            "Task Finished",
            style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold),
          ),
          content: Container(
            height: 50,
            width: 50,
            decoration: const BoxDecoration(
                image: DecorationImage(
                    image: AssetImage(
                        'assets/check.jpg'),
                    fit: BoxFit.contain)),
          ),
        ))
        : showDialog(
        context: context,
        builder: (ctxt) => AlertDialog(
          title: const Text(
            "Task UnFinished",
            style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold),
          ),
          content: Container(
            height: 50,
            width: 50,
            decoration: const BoxDecoration(
                image: DecorationImage(
                    image: AssetImage(
                        'assets/cross.png'),
                    fit: BoxFit.contain)),
          ),
        ));
  }
}