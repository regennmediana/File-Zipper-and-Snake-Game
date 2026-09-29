import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Point {
  final int x;
  final int y;

  const Point(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

enum Direction { up, down, left, right }

class SnakeGamePage extends StatefulWidget {
  const SnakeGamePage({Key? key}) : super(key: key);

  @override
  State<SnakeGamePage> createState() => _SnakeGamePageState();
}

class _SnakeGamePageState extends State<SnakeGamePage> {
  static const int gridWidth = 20;
  static const int gridHeight = 20;

  List<Point> snake = [const Point(10, 10), const Point(10, 11), const Point(10, 12)];
  Point food = const Point(5, 5);
  Set<Point> obstacles = {};
  
  Direction direction = Direction.up;
  Direction nextDirection = Direction.up;
  
  Timer? timer;
  bool isPlaying = false;
  bool isPaused = false;
  bool isAiMode = false;
  
  int score = 0;
  int level = 1;
  int speedMs = 150;
  List<int> leaderboard = [];

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    timer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  // --- LEADERBOARD LOGIC ---
  Future<void> _loadLeaderboard() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      leaderboard = (prefs.getStringList('snake_scores') ?? [])
          .map((s) => int.parse(s))
          .toList();
    });
  }

  Future<void> _saveScore(int newScore) async {
    if (newScore == 0) return;
    final prefs = await SharedPreferences.getInstance();
    leaderboard.add(newScore);
    leaderboard.sort((a, b) => b.compareTo(a));
    if (leaderboard.length > 5) leaderboard = leaderboard.sublist(0, 5);
    
    await prefs.setStringList('snake_scores', leaderboard.map((s) => s.toString()).toList());
    setState(() {});
  }

  // --- GAME ENGINE LOGIC ---
  void _startGame() {
    timer?.cancel();
    _focusNode.requestFocus(); // Auto-focus for keyboard events
    setState(() {
      snake = [const Point(10, 10), const Point(10, 11), const Point(10, 12)];
      direction = Direction.up;
      nextDirection = Direction.up;
      score = 0;
      level = 1;
      speedMs = 150;
      isPlaying = true;
      isPaused = false;
      _generateObstacles();
      _generateFood();
    });

    timer = Timer.periodic(Duration(milliseconds: speedMs), (t) => _gameLoop());
  }

  void _togglePause() {
    if (!isPlaying) return;
    setState(() {
      isPaused = !isPaused;
      if (isPaused) {
        timer?.cancel();
      } else {
        timer = Timer.periodic(Duration(milliseconds: speedMs), (t) => _gameLoop());
      }
    });
  }

  void _generateObstacles() {
    obstacles.clear();
    final random = Random();
    int obstacleCount = (level - 1) * 4;

    while (obstacles.length < obstacleCount) {
      final p = Point(random.nextInt(gridWidth), random.nextInt(gridHeight));
      if (!snake.contains(p) && p != food) {
        obstacles.add(p);
      }
    }
  }

  void _generateFood() {
    final random = Random();
    Point newFood;
    do {
      newFood = Point(random.nextInt(gridWidth), random.nextInt(gridHeight));
    } while (snake.contains(newFood) || obstacles.contains(newFood));

    setState(() => food = newFood);
  }

  void _gameLoop() {
    if (!isPlaying || isPaused) return;

    if (isAiMode) {
      final aiDirection = _getBfsNextDirection();
      if (aiDirection != null) {
        direction = aiDirection;
      }
    } else {
      direction = nextDirection;
    }

    final head = snake.first;
    Point newHead;

    switch (direction) {
      case Direction.up:
        newHead = Point(head.x, head.y - 1);
        break;
      case Direction.down:
        newHead = Point(head.x, head.y + 1);
        break;
      case Direction.left:
        newHead = Point(head.x - 1, head.y);
        break;
      case Direction.right:
        newHead = Point(head.x + 1, head.y);
        break;
    }

    // Check Wall Collision
    if (newHead.x < 0 || newHead.x >= gridWidth || newHead.y < 0 || newHead.y >= gridHeight) {
      _gameOver();
      return;
    }

    // Check Self or Obstacle Collision
    if (snake.contains(newHead) || obstacles.contains(newHead)) {
      _gameOver();
      return;
    }

    setState(() {
      snake.insert(0, newHead);

      // Check Food Collision
      if (newHead == food) {
        score += 10;
        if (score % 30 == 0) {
          level++;
          speedMs = max(50, speedMs - 15);
          timer?.cancel();
          timer = Timer.periodic(Duration(milliseconds: speedMs), (t) => _gameLoop());
          _generateObstacles();
        }
        _generateFood();
      } else {
        snake.removeLast();
      }
    });
  }

  void _gameOver() {
    timer?.cancel();
    setState(() {
      isPlaying = false;
      isPaused = false;
    });
    _saveScore(score);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Game Over"),
        content: Text("Your Score: $score\nReached Level: $level"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startGame();
            },
            child: const Text("Play Again"),
          ),
        ],
      ),
    );
  }

  // --- BFS AI AUTO-PLAY PATHFINDING ---
  Direction? _getBfsNextDirection() {
    final head = snake.first;
    final queue = Queue<List<Point>>();
    final visited = <Point>{head};

    final blocked = Set<Point>.from(obstacles)..addAll(snake.sublist(0, snake.length - 1));

    queue.add([head]);

    while (queue.isNotEmpty) {
      final path = queue.removeFirst();
      final current = path.last;

      if (current == food) {
        final nextPoint = path[1];
        if (nextPoint.x < head.x) return Direction.left;
        if (nextPoint.x > head.x) return Direction.right;
        if (nextPoint.y < head.y) return Direction.up;
        if (nextPoint.y > head.y) return Direction.down;
      }

      for (final neighbor in _getValidNeighbors(current, blocked)) {
        if (!visited.contains(neighbor)) {
          visited.add(neighbor);
          queue.add(List.from(path)..add(neighbor));
        }
      }
    }

    for (final dir in Direction.values) {
      final testHead = _getPointInDir(head, dir);
      if (_isValidPoint(testHead, blocked)) return dir;
    }

    return direction;
  }

  List<Point> _getValidNeighbors(Point p, Set<Point> blocked) {
    final neighbors = <Point>[];
    for (final dir in Direction.values) {
      final next = _getPointInDir(p, dir);
      if (_isValidPoint(next, blocked)) {
        neighbors.add(next);
      }
    }
    return neighbors;
  }

  Point _getPointInDir(Point p, Direction dir) {
    switch (dir) {
      case Direction.up: return Point(p.x, p.y - 1);
      case Direction.down: return Point(p.x, p.y + 1);
      case Direction.left: return Point(p.x - 1, p.y);
      case Direction.right: return Point(p.x + 1, p.y);
    }
  }

  bool _isValidPoint(Point p, Set<Point> blocked) {
    return p.x >= 0 &&
        p.x < gridWidth &&
        p.y >= 0 &&
        p.y < gridHeight &&
        !blocked.contains(p);
  }

  // --- UI CONTROLS ---
  void _changeDirection(Direction newDir) {
    if (isAiMode || isPaused) return;
    if ((direction == Direction.up && newDir != Direction.down) ||
        (direction == Direction.down && newDir != Direction.up) ||
        (direction == Direction.left && newDir != Direction.right) ||
        (direction == Direction.right && newDir != Direction.left)) {
      nextDirection = newDir;
    }
  }

  // --- KEYBOARD EVENT HANDLER ---
  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    final key = event.logicalKey;

    // Toggle pause with Spacebar or ESC key
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.escape) {
      _togglePause();
    } else if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      _changeDirection(Direction.up);
    } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      _changeDirection(Direction.down);
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      _changeDirection(Direction.left);
    } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
      _changeDirection(Direction.right);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text("Snake Game"),
        backgroundColor: Colors.black87,
        actions: [
          Row(
            children: [
              const Text("AI Mode"),
              Switch(
                value: isAiMode,
                onChanged: (val) => setState(() => isAiMode = val),
              ),
            ],
          ),
        ],
      ),
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: _handleKeyEvent,
        child: Column(
          children: [
            // Score & Level Bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text("Score: $score", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Level: $level", style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // Game Board
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24, width: 2),
                      color: Colors.black,
                    ),
                    child: Stack(
                      children: [
                        GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: gridWidth * gridHeight,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridWidth,
                          ),
                          itemBuilder: (context, index) {
                            final x = index % gridWidth;
                            final y = index ~/ gridWidth;
                            final p = Point(x, y);

                            Color color = Colors.transparent;
                            if (snake.first == p) {
                              color = Colors.greenAccent;
                            } else if (snake.contains(p)) {
                              color = Colors.green;
                            } else if (food == p) {
                              color = Colors.redAccent;
                            } else if (obstacles.contains(p)) {
                              color = Colors.grey;
                            }

                            return Container(
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          },
                        ),
                        if (isPaused)
                          Container(
                            color: Colors.black54,
                            child: const Center(
                              child: Text(
                                "PAUSED",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Controls & Leaderboard Section
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Action & Direction Buttons
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_drop_up, size: 36, color: Colors.white),
                        onPressed: () => _changeDirection(Direction.up),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_left, size: 36, color: Colors.white),
                            onPressed: () => _changeDirection(Direction.left),
                          ),
                          ElevatedButton(
                            onPressed: isPlaying ? null : _startGame,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: Text(isPlaying ? "Playing" : "Start"),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_right, size: 36, color: Colors.white),
                            onPressed: () => _changeDirection(Direction.right),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_drop_down, size: 36, color: Colors.white),
                        onPressed: () => _changeDirection(Direction.down),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: isPlaying ? _togglePause : null,
                        icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                        label: Text(isPaused ? "Resume" : "Pause"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
                      ),
                    ],
                  ),

                  // Leaderboard Display
                  Container(
                    width: 140,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Text("Leaderboard", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                        const Divider(color: Colors.white24),
                        if (leaderboard.isEmpty)
                          const Text("No High Scores", style: TextStyle(color: Colors.white54, fontSize: 12))
                        else
                          ...leaderboard.asMap().entries.map((entry) => Text(
                                "#${entry.key + 1}: ${entry.value} pts",
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}