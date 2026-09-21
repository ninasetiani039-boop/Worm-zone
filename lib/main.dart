import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const CacingApp());
}

class CacingApp extends StatelessWidget {
  const CacingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Cacing Jamur',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const GameScreen(),
    );
  }
}

enum Direction { up, down, left, right }
enum GameLevel { easy, medium, hard }

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

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int gridSize = 20;

  // Game Engine & State
  bool isRunning = false;
  bool isGameOver = false;
  int score = 0;
  int coins = 0;
  bool potionActive = false;
  
  Timer? gameTimer;
  Timer? potionTimer;
  int gameSpeed = 110;

  GameLevel selectedLevel = GameLevel.medium;

  // Player Snake
  List<Point> playerBody = [];
  Direction playerDir = Direction.right;
  Direction nextPlayerDir = Direction.right; // Mencegah bug double key press

  // Bot Snake
  List<Point> botBody = [];
  Direction botDir = Direction.up;
  bool botAlive = true;

  // Items
  List<Point> mushrooms = [];
  Point? coinItem;
  Point? potionItem;

  final Random random = Random();

  void startGame() {
    setState(() {
      switch (selectedLevel) {
        case GameLevel.easy:
          gameSpeed = 150;
          break;
        case GameLevel.medium:
          gameSpeed = 100;
          break;
        case GameLevel.hard:
          gameSpeed = 65;
          break;
      }

      score = 0;
      coins = 0;
      potionActive = false;
      isRunning = true;
      isGameOver = false;

      // Reset Player
      playerBody = [const Point(5, 5), const Point(4, 5), const Point(3, 5)];
      playerDir = Direction.right;
      nextPlayerDir = Direction.right;

      // Reset Bot
      botAlive = true;
      botBody = [const Point(14, 14), const Point(14, 15), const Point(14, 16)];
      botDir = Direction.up;

      mushrooms = [];
      coinItem = null;
      potionItem = null;

      spawnInitialItems();
    });

    gameTimer?.cancel();
    gameTimer = Timer.periodic(Duration(milliseconds: gameSpeed), (_) => updateGame());
  }

  void spawnInitialItems() {
    for (int i = 0; i < 3; i++) {
      spawnMushroom();
    }
    spawnCoin();
  }

  Point getRandomPos() {
    return Point(random.nextInt(gridSize), random.nextInt(gridSize));
  }

  void spawnMushroom() {
    mushrooms.add(getRandomPos());
  }

  void spawnCoin() {
    if (random.nextDouble() < 0.6) {
      coinItem = getRandomPos();
    }
  }

  void spawnPotion() {
    if (potionItem == null && random.nextDouble() < 0.3) {
      potionItem = getRandomPos();
    }
  }

  void updateGame() {
    if (!isRunning || isGameOver) return;

    setState(() {
      playerDir = nextPlayerDir;
      movePlayer();
      if (botAlive) moveBot();
      checkCollisions();
    });
  }

  void movePlayer() {
    Point head = playerBody.first;
    Point newHead;

    switch (playerDir) {
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

    playerBody.insert(0, newHead);

    // Makan Jamur
    bool ateMushroom = false;
    for (int i = 0; i < mushrooms.length; i++) {
      if (newHead == mushrooms[i]) {
        score += potionActive ? 20 : 10;
        mushrooms.removeAt(i);
        spawnMushroom();
        spawnPotion();
        ateMushroom = true;
        break;
      }
    }

    // Makan Koin
    if (coinItem != null && newHead == coinItem) {
      coins += 1;
      coinItem = null;
      Future.delayed(const Duration(seconds: 4), () => spawnCoin());
    }

    // Makan Potion
    if (potionItem != null && newHead == potionItem) {
      activatePotion();
      potionItem = null;
    }

    if (!ateMushroom) {
      playerBody.removeLast();
    }
  }

  void moveBot() {
    Point head = botBody.first;
    Point target = mushrooms.isNotEmpty ? mushrooms.first : const Point(10, 10);

    Direction newDir = botDir;
    if (target.x > head.x && botDir != Direction.left) {
      newDir = Direction.right;
    } else if (target.x < head.x && botDir != Direction.right) {
      newDir = Direction.left;
    } else if (target.y > head.y && botDir != Direction.up) {
      newDir = Direction.down;
    } else if (target.y < head.y && botDir != Direction.down) {
      newDir = Direction.up;
    }

    botDir = newDir;

    Point newHead;
    switch (botDir) {
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

    botBody.insert(0, newHead);

    bool ate = false;
    for (int i = 0; i < mushrooms.length; i++) {
      if (newHead == mushrooms[i]) {
        mushrooms.removeAt(i);
        spawnMushroom();
        ate = true;
        break;
      }
    }

    if (!ate) botBody.removeLast();
  }

  void activatePotion() {
    potionActive = true;
    potionTimer?.cancel();
    potionTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          potionActive = false;
        });
      }
    });
  }

  void checkCollisions() {
    Point head = playerBody.first;

    // Menabrak Dinding
    if (head.x < 0 || head.x >= gridSize || head.y < 0 || head.y >= gridSize) {
      triggerGameOver();
      return;
    }

    // Menabrak Badan Sendiri
    for (int i = 1; i < playerBody.length; i++) {
      if (head == playerBody[i]) {
        triggerGameOver();
        return;
      }
    }

    // Interaksi dengan Bot
    if (botAlive) {
      Point botHead = botBody.first;

      // Player menabrak badan bot
      for (Point segment in botBody) {
        if (head == segment) {
          triggerGameOver();
          return;
        }
      }

      // Bot menabrak badan player -> Bot mati & hancur jadi jamur
      for (Point segment in playerBody) {
        if (botHead == segment) {
          killBot();
          break;
        }
      }
    }
  }

  void killBot() {
    botAlive = false;
    for (Point segment in botBody) {
      mushrooms.add(segment);
    }
    botBody.clear();
  }

  void triggerGameOver() {
    gameTimer?.cancel();
    setState(() {
      isRunning = false;
      isGameOver = true;
    });
  }

  void changeDirection(Direction dir) {
    if (dir == Direction.up && playerDir != Direction.down) nextPlayerDir = Direction.up;
    if (dir == Direction.down && playerDir != Direction.up) nextPlayerDir = Direction.down;
    if (dir == Direction.left && playerDir != Direction.right) nextPlayerDir = Direction.left;
    if (dir == Direction.right && playerDir != Direction.left) nextPlayerDir = Direction.right;
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    potionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // HUD Dashboard
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildHUDItem('SKOR', '$score', Colors.greenAccent),
                  _buildHUDItem('KOIN', '🪙 $coins', Colors.amber),
                  _buildHUDItem(
                    'BOOSTER',
                    potionActive ? '2X POTION' : 'NORMAL',
                    potionActive ? Colors.purpleAccent : Colors.grey,
                  ),
                ],
              ),
            ),

            // Arena Game dengan Kontrol Swipe
            Expanded(
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.delta.dy < -3) changeDirection(Direction.up);
                  if (details.delta.dy > 3) changeDirection(Direction.down);
                },
                onHorizontalDragUpdate: (details) {
                  if (details.delta.dx < -3) changeDirection(Direction.left);
                  if (details.delta.dx > 3) changeDirection(Direction.right);
                },
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22331D),
                        border: Border.all(
                          color: potionActive ? Colors.purpleAccent : const Color(0xFF4A6B38),
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: potionActive ? Colors.purpleAccent.withOpacity(0.5) : Colors.black50,
                            blurRadius: 12,
                            spreadRadius: 2,
                          )
                        ],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          // Grid Render
                          GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: gridSize * gridSize,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: gridSize,
                            ),
                            itemBuilder: (context, index) {
                              int x = index % gridSize;
                              int y = index ~/ gridSize;
                              Point p = Point(x, y);

                              if (playerBody.contains(p)) {
                                bool isHead = playerBody.first == p;
                                return _buildSnakeCell(Colors.lightGreenAccent, isHead);
                              } else if (botAlive && botBody.contains(p)) {
                                bool isHead = botBody.first == p;
                                return _buildSnakeCell(Colors.pinkAccent, isHead);
                              } else if (mushrooms.contains(p)) {
                                return _buildMushroomCell();
                              } else if (coinItem == p) {
                                return _buildCoinCell();
                              } else if (potionItem == p) {
                                return _buildPotionCell();
                              }
                              return const SizedBox();
                            },
                          ),

                          // Start Screen
                          if (!isRunning && !isGameOver) _buildStartOverlay(),

                          // Game Over Screen
                          if (isGameOver) _buildGameOverOverlay(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Control D-Pad
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: _buildDPad(),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widget Render Helpers ---

  Widget _buildHUDItem(String title, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildSnakeCell(Color color, bool isHead) {
    return Container(
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(isHead ? 6 : 3),
        boxShadow: isHead ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 4)] : [],
      ),
      child: isHead
          ? const Center(
              child: CircleAvatar(radius: 2, backgroundColor: Colors.black),
            )
          : null,
    );
  }

  Widget _buildMushroomCell() {
    return Center(
      child: Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(
          color: Colors.deepOrangeAccent,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.star, size: 8, color: Colors.white),
      ),
    );
  }

  Widget _buildCoinCell() {
    return Center(
      child: Container(
        width: 13,
        height: 13,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [Colors.yellow, Colors.amber]),
        ),
      ),
    );
  }

  Widget _buildPotionCell() {
    return const Center(
      child: Icon(Icons.science, size: 16, color: Colors.purpleAccent),
    );
  }

  Widget _buildStartOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '🐍 CACING JAMUR',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.lightGreenAccent),
          ),
          const SizedBox(height: 16),
          DropdownButton<GameLevel>(
            value: selectedLevel,
            dropdownColor: Colors.grey[900],
            items: const [
              DropdownMenuItem(value: GameLevel.easy, child: Text('Mudah (Arena Lambat)')),
              DropdownMenuItem(value: GameLevel.medium, child: Text('Sedang (Standar)')),
              DropdownMenuItem(value: GameLevel.hard, child: Text('Sulit (Sangat Cepat)')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => selectedLevel = val);
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightGreenAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: startGame,
            child: const Text('MULAI GAME', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.88),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('GAME OVER', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          const SizedBox(height: 12),
          Text('Skor Akhir: $score', style: const TextStyle(fontSize: 18, color: Colors.white)),
          Text('Koin Terkumpul: 🪙 $coins', style: const TextStyle(fontSize: 18, color: Colors.amber)),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightGreenAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: startGame,
            child: const Text('MAIN LAGI', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDPad() {
    return Column(
      children: [
        IconButton(
          iconSize: 44,
          icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white70),
          onPressed: () => changeDirection(Direction.up),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 44,
              icon: const Icon(Icons.keyboard_arrow_left_rounded, color: Colors.white70),
              onPressed: () => changeDirection(Direction.left),
            ),
            const SizedBox(width: 40),
            IconButton(
              iconSize: 44,
              icon: const Icon(Icons.keyboard_arrow_right_rounded, color: Colors.white70),
              onPressed: () => changeDirection(Direction.right),
            ),
          ],
        ),
        IconButton(
          iconSize: 44,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
          onPressed: () => changeDirection(Direction.down),
        ),
      ],
    );
  }
}
