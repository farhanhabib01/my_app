import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  static final AudioPlayer bg = AudioPlayer();
  static final List<AudioPlayer> coinPool = List.generate(4, (_) => AudioPlayer());
  static final AudioPlayer jump = AudioPlayer();
  static final AudioPlayer gameOver = AudioPlayer();

  static bool _preloaded = false;
  static bool _preloading = false;

  static Future<void> preload() async {
    if (_preloaded || _preloading) return;
    _preloading = true;
    try {
      for (final p in coinPool) {
        await p.setPlayerMode(PlayerMode.lowLatency);
      }
      await jump.setPlayerMode(PlayerMode.lowLatency);
      await gameOver.setPlayerMode(PlayerMode.lowLatency);
      await bg.setReleaseMode(ReleaseMode.loop);
      await bg.setVolume(0.5);

      final List<Future<void>> loadTasks = [
        bg.setSourceAsset('sounds/background.mp3'),
        jump.setSourceAsset('sounds/jump.mp3'),
        gameOver.setSourceAsset('sounds/gameover.mp3'),
      ];
      for (final p in coinPool) {
        loadTasks.add(p.setSourceAsset('sounds/coin.mp3'));
      }
      await Future.wait(loadTasks);
      _preloaded = true;
    } catch (_) {
    } finally {
      _preloading = false;
    }
  }

  static Future<void> playBackgroundMusic() async {
    try {
      await bg.setReleaseMode(ReleaseMode.loop);
      await bg.play(AssetSource('sounds/background.mp3'));
    } catch (_) {}
  }

  static Future<void> stopBackgroundMusic() async {
    try {
      await bg.stop();
    } catch (_) {}
  }

  static void playCoin() {
    final player = AudioPlayer();
    try {
      player.setPlayerMode(PlayerMode.lowLatency);
      player.setReleaseMode(ReleaseMode.release);
      player.onPlayerComplete.listen((_) => player.dispose());
      player.play(AssetSource('sounds/coin.mp3'));
    } catch (_) {
      player.dispose();
    }
  }

  static Future<void> playJump() async {
    try {
      await jump.stop();
      await jump.play(AssetSource('sounds/jump.mp3'));
    } catch (_) {}
  }

  static Future<void> playGameOver() async {
    try {
      await gameOver.stop();
      await gameOver.play(AssetSource('sounds/gameover.mp3'));
    } catch (_) {}
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudioPlayer.global.setAudioContext(
    AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Runner Chase Elite Overdrive',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.black,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const StartScreen(),
    );
  }
}

// ============================================================
// Background star / particle field used behind the Start Screen
// ============================================================
class _BgParticle {
  double x, y, speed, size, twinkle;
  _BgParticle({required this.x, required this.y, required this.speed, required this.size, required this.twinkle});
}

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});
  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _glowController;
  late AnimationController _ringRotateController;
  late AnimationController _shimmerController;
  late AnimationController _entranceController;
  late AnimationController _particleController;

  final Random _rand = Random();
  final List<_BgParticle> _particles = [];

  double loadingProgress = 0.0;
  bool isLoaded = false;
  Timer? loadingTimer;

  @override
  void initState() {
    super.initState();
    SoundManager.preload().then((_) {
      if (mounted) SoundManager.playBackgroundMusic();
    });

    for (int i = 0; i < 40; i++) {
      _particles.add(_BgParticle(
        x: _rand.nextDouble(),
        y: _rand.nextDouble(),
        speed: 0.05 + _rand.nextDouble() * 0.15,
        size: 1.0 + _rand.nextDouble() * 2.4,
        twinkle: _rand.nextDouble(),
      ));
    }

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: 0, end: 14).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
    _ringRotateController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();

    loadingTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      setState(() {
        loadingProgress = (loadingProgress + 0.02).clamp(0.0, 1.0);
        if (loadingProgress >= 1.0) {
          isLoaded = true;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _ringRotateController.dispose();
    _shimmerController.dispose();
    _particleController.dispose();
    _entranceController.dispose();
    loadingTimer?.cancel();
    super.dispose();
  }

  void goToGame() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (context, animation, _) => const GameScreen(),
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.06, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Animation<double> _staggered(double start, double end) {
    return CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final titleFade = _staggered(0.0, 0.55);
    final logoFade = _staggered(0.15, 0.7);
    final ctaFade = _staggered(0.35, 1.0);

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient backdrop
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) {
                final t = _glowController.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1 + sin(t * 2 * pi) * 0.3, -1),
                      end: Alignment(1, 1 + cos(t * 2 * pi) * 0.3),
                      colors: const [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                    ),
                  ),
                );
              },
            ),
          ),

          // Drifting star / dust particle field
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _StarFieldPainter(particles: _particles, t: _particleController.value),
                );
              },
            ),
          ),

          // Soft vignette for depth
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.1,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                FadeTransition(
                  opacity: titleFade,
                  child: SlideTransition(
                    position: titleFade.drive(Tween(begin: const Offset(0, -0.3), end: Offset.zero)),
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        return ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) => LinearGradient(
                            colors: const [Colors.white, Colors.amberAccent, Colors.white],
                            stops: const [0.3, 0.5, 0.7],
                            begin: Alignment(-1 + 2 * _shimmerController.value, 0),
                            end: Alignment(1 + 2 * _shimmerController.value, 0),
                          ).createShader(bounds),
                          child: child,
                        );
                      },
                      child: const Text(
                        'RUNNER CHASE OVERDRIVE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 3))],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FadeTransition(
                  opacity: titleFade,
                  child: const Text(
                    'DYNAMIC THEMES • 5S SHIELD • BLAST PHYSICS',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ),
                const Spacer(),
                FadeTransition(
                  opacity: logoFade,
                  child: ScaleTransition(
                    scale: logoFade,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_bounceAnimation, _glowController, _ringRotateController]),
                      builder: (context, _) {
                        return Transform.translate(
                          offset: Offset(0, -_bounceAnimation.value),
                          child: SizedBox(
                            width: 190,
                            height: 190,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Transform.rotate(
                                  angle: _ringRotateController.value * 2 * pi,
                                  child: CustomPaint(
                                    size: const Size(178, 178),
                                    painter: _DashedRingPainter(color: Colors.amberAccent.withValues(alpha: 0.55)),
                                  ),
                                ),
                                Container(
                                  width: 150 + (sin(_glowController.value * pi * 2) * 10),
                                  height: 150 + (sin(_glowController.value * pi * 2) * 10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5), width: 3),
                                  ),
                                ),
                                ClipOval(
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                      boxShadow: const [BoxShadow(color: Colors.amber, blurRadius: 24, spreadRadius: 3)],
                                    ),
                                    child: Image.asset(
                                      'assets/icon/icon.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(colors: [Colors.amber, Colors.deepOrange], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                        ),
                                        child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 60),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.12, vertical: 30),
                  child: FadeTransition(
                    opacity: ctaFade,
                    child: SlideTransition(
                      position: ctaFade.drive(Tween(begin: const Offset(0, 0.3), end: Offset.zero)),
                      child: isLoaded
                          ? AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) => Transform.scale(scale: _pulseAnimation.value, child: child),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.5), blurRadius: 24, spreadRadius: 1)],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: goToGame,
                                  icon: const Icon(Icons.play_arrow_rounded, size: 30),
                                  label: const Text('OVERDRIVE START', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    minimumSize: const Size(double.infinity, 58),
                                    elevation: 12,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Stack(
                                    children: [
                                      LinearProgressIndicator(
                                        value: loadingProgress,
                                        minHeight: 14,
                                        backgroundColor: Colors.black38,
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                                      ),
                                      Positioned.fill(
                                        child: AnimatedBuilder(
                                          animation: _shimmerController,
                                          builder: (context, _) => FractionallySizedBox(
                                            alignment: Alignment(-1 + 2 * _shimmerController.value, 0),
                                            widthFactor: 0.25,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.5), Colors.white.withValues(alpha: 0)],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'LOADING ${(loadingProgress * 100).toInt()}%',
                                  style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  final List<_BgParticle> particles;
  final double t;
  _StarFieldPainter({required this.particles, required this.t});
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (p.y + t * p.speed) % 1.0;
      final opacity = (0.25 + 0.65 * (0.5 + 0.5 * sin((t * 6 + p.twinkle) * 2 * pi))).clamp(0.0, 1.0);
      final paint = Paint()..color = Colors.white.withValues(alpha: opacity * 0.6);
      canvas.drawCircle(Offset(p.x * size.width, y * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) => true;
}

class _DashedRingPainter extends CustomPainter {
  final Color color;
  _DashedRingPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final radius = size.width / 2;
    const dashCount = 26;
    for (int i = 0; i < dashCount; i++) {
      final angle1 = (i / dashCount) * 2 * pi;
      final angle2 = angle1 + (pi / dashCount) * 0.6;
      final p1 = Offset(radius + radius * cos(angle1), radius + radius * sin(angle1));
      final p2 = Offset(radius + radius * cos(angle2), radius + radius * sin(angle2));
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) => false;
}

enum ItemType { coin, keyItem, car, barricade, bush, shield, turbo, magnet }

class FallingItem {
  int lane;
  double y;
  ItemType type;
  String? carImage;
  bool dodged = false;
  double spawnT = 0; // used for a small entrance pop animation
  FallingItem({required this.lane, required this.y, required this.type, this.carImage});
}

class FloatingPopup {
  double x;
  double y;
  int life;
  static const int maxLife = 35;
  final String text;
  final Color color;
  FloatingPopup({required this.x, required this.y, required this.text, this.color = Colors.amberAccent, this.life = maxLife});

  double get scale {
    final t = 1 - (life / maxLife);
    return t < 0.2 ? 0.5 + 0.7 * Curves.easeOutBack.transform(t / 0.2) : 1.0;
  }
}

class BlastShockwave {
  double x;
  double y;
  int life;
  static const int maxLife = 22;
  BlastShockwave({required this.x, required this.y, this.life = maxLife});
}

class DebrisParticle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  int life;
  static const int maxLife = 26;
  DebrisParticle({required this.x, required this.y, required this.vx, required this.vy, required this.color, this.life = maxLife});
}

// Parallax background building/tree used for depth
class _SceneryObject {
  double x; // 0..1 across width
  double baseY;
  double scale;
  bool isBuilding;
  Color color;
  _SceneryObject({required this.x, required this.baseY, required this.scale, required this.isBuilding, required this.color});
}

// Ground-level dust puff spawned on jump landing
class _DustPuff {
  double x, y;
  int life;
  static const int maxLife = 18;
  _DustPuff({required this.x, required this.y, this.life = maxLife});
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const int laneCount = 3;

  bool isIntroPhase = true;
  int playerLane = 1;
  double playerY = 0.7;
  double playerLaneAnim = 1.0;

  int policeLane = 1;
  double policeY = 1.2;
  double policeLaneAnim = 1.0;
  int policeLaneDelayCounter = 0;

  double sceneryOffset = 0;
  double roadOffset = 0;
  double speed = 0.0065;

  List<FallingItem> items = [];
  List<FloatingPopup> popups = [];
  List<BlastShockwave> shockwaves = [];
  List<DebrisParticle> debris = [];
  List<_TrailParticle> trailParticles = [];
  List<_SceneryObject> scenery = [];
  List<_DustPuff> dustPuffs = [];

  int score = 0;
  int highestScore = 0;
  int coins = 0;
  int highestCoins = 0;
  int keys = 0;
  int level = 1;
  int highestLevel = 1;

  int coinCombo = 0;
  int scoreMultiplier = 1;
  String? activeBanner;
  int bannerTimer = 0;

  int levelFlashTimer = 0;
  bool _wasJumping = false;

  // Active Power-up Timers
  int shieldTimer = 0; // 5 Seconds (300 ticks)
  int turboTimer = 0;  // 3.5 Seconds (210 ticks)
  int magnetTimer = 0; // 6 Seconds (360 ticks)

  bool isGameOver = false;
  bool isArrested = false;
  bool isPaused = false;
  int resumeCountdown = 0;
  Timer? countdownTimer;
  Timer? gameTimer;

  bool showRevivePrompt = false;
  int reviveTimerSeconds = 4;
  Timer? reviveTimer;
  bool isRevivingCloud = false;

  final Random random = Random();
  int tickCounter = 0;
  int nextSpawnTick = 30;

  double dragStartX = 0;
  double dragStartY = 0;

  bool isJumping = false;
  int jumpTick = 0;
  static const int jumpDuration = 20;
  static const double jumpHeight = 90;

  late AnimationController _shakeController;
  late AnimationController _scoreBumpController;
  late Animation<double> _scoreBumpAnimation;
  late AnimationController _pulseAuraController;
  late AnimationController _hudEntranceController;
  late AnimationController _gameOverController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))
      ..addListener(() => setState(() {}));
    _scoreBumpController = AnimationController(vsync: this, duration: const Duration(milliseconds: 240))
      ..addListener(() => setState(() {}));
    _scoreBumpAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(_scoreBumpController);
    _pulseAuraController = AnimationController(vsync: this, duration: const Duration(milliseconds: 550))..repeat(reverse: true);
    _hudEntranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _gameOverController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

    _generateScenery();
    setupGame();
  }

  void _generateScenery() {
    scenery.clear();
    for (int i = 0; i < 10; i++) {
      final left = random.nextBool();
      scenery.add(_SceneryObject(
        x: left ? random.nextDouble() * 0.12 : 0.88 + random.nextDouble() * 0.12,
        baseY: i * 0.28,
        scale: 0.7 + random.nextDouble() * 0.8,
        isBuilding: random.nextBool(),
        color: [Colors.blueGrey.shade700, Colors.indigo.shade700, Colors.teal.shade700, Colors.brown.shade600][random.nextInt(4)],
      ));
    }
  }

  void setupGame() {
    gameTimer?.cancel();
    countdownTimer?.cancel();
    reviveTimer?.cancel();
    items.clear();
    popups.clear();
    shockwaves.clear();
    debris.clear();
    trailParticles.clear();
    dustPuffs.clear();

    score = 0;
    coins = 0;
    keys = 0;
    level = 1;
    speed = 0.0065;
    shieldTimer = 0;
    turboTimer = 0;
    magnetTimer = 0;
    coinCombo = 0;
    scoreMultiplier = 1;
    activeBanner = null;
    levelFlashTimer = 0;

    playerLane = 1;
    playerLaneAnim = 1.0;
    policeLane = 1;
    policeLaneAnim = 1.0;
    policeY = 1.2;

    isIntroPhase = true;
    isGameOver = false;
    isArrested = false;
    isPaused = false;
    showRevivePrompt = false;
    isRevivingCloud = false;
    resumeCountdown = 0;

    isJumping = false;
    jumpTick = 0;
    tickCounter = 0;
    nextSpawnTick = 30;

    _gameOverController.reset();
    _hudEntranceController.forward(from: 0);

    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (isIntroPhase) {
        setState(() {});
      } else {
        updateGame();
      }
    });
  }

  void startChase() {
    setState(() => isIntroPhase = false);
    SoundManager.playBackgroundMusic();
  }

  void triggerShockwave(double lane, double y) {
    shockwaves.add(BlastShockwave(x: lane, y: y));
    for (int i = 0; i < 18; i++) {
      debris.add(
        DebrisParticle(
          x: lane,
          y: y,
          vx: (random.nextDouble() * 14 - 7),
          vy: (random.nextDouble() * 14 - 7),
          color: [Colors.orangeAccent, Colors.cyanAccent, Colors.amberAccent, Colors.white][random.nextInt(4)],
        ),
      );
    }
    _shakeController.forward(from: 0);
    HapticFeedback.mediumImpact();
  }

  void togglePause() {
    if (isGameOver || isIntroPhase || showRevivePrompt) return;
    setState(() => isPaused = !isPaused);
  }

  void updateGame() {
    if (isGameOver || isPaused || showRevivePrompt) return;
    setState(() {
      tickCounter++;
      final currentSpeed = turboTimer > 0 ? speed * 1.85 : speed;

      roadOffset += currentSpeed * 500;
      if (roadOffset > 80) roadOffset = 0;
      sceneryOffset += currentSpeed * 260;
      if (sceneryOffset > 1.0) sceneryOffset -= 1.0;

      playerLaneAnim += (playerLane - playerLaneAnim) * 0.32;
      policeLaneAnim += (policeLane - policeLaneAnim) * 0.22;

      // Decrement Power-up timers
      if (shieldTimer > 0) shieldTimer--;
      if (turboTimer > 0) turboTimer--;
      if (magnetTimer > 0) magnetTimer--;
      if (bannerTimer > 0) {
        bannerTimer--;
        if (bannerTimer <= 0) activeBanner = null;
      }
      if (levelFlashTimer > 0) levelFlashTimer--;

      // Police AI tracking
      policeLaneDelayCounter++;
      if (policeLaneDelayCounter > 16) {
        policeLaneDelayCounter = 0;
        if (policeLane < playerLane) policeLane++;
        else if (policeLane > playerLane) policeLane--;
      }
      double targetPoliceY = turboTimer > 0 ? 1.3 : playerY + 0.13;
      policeY += (targetPoliceY - policeY) * 0.1;

      if (isJumping) {
        jumpTick++;
        if (jumpTick >= jumpDuration) {
          isJumping = false;
          jumpTick = 0;
        }
      }
      // Landing dust puff (edge-triggered when jump just ended)
      if (_wasJumping && !isJumping) {
        dustPuffs.add(_DustPuff(x: playerLaneAnim, y: playerY + 0.07));
        dustPuffs.add(_DustPuff(x: playerLaneAnim - 0.15, y: playerY + 0.08));
        dustPuffs.add(_DustPuff(x: playerLaneAnim + 0.15, y: playerY + 0.08));
      }
      _wasJumping = isJumping;
      for (var d in dustPuffs) { d.life--; }
      dustPuffs.removeWhere((d) => d.life <= 0);

      // Police Catch Condition
      if (policeLane == playerLane && policeY - playerY < 0.08 && !isArrested && !isJumping && shieldTimer == 0 && turboTimer == 0) {
        arrestPlayer();
        return;
      }

      // Trail particle effect
      if (turboTimer > 0 || coinCombo >= 5) {
        trailParticles.add(_TrailParticle(
          lane: playerLaneAnim,
          y: playerY + 0.06,
          color: turboTimer > 0 ? Colors.cyanAccent : Colors.amberAccent,
        ));
      }
      for (var t in trailParticles) { t.life--; }
      trailParticles.removeWhere((t) => t.life <= 0);

      // Level 4 Playable Balance Spawn Generator
      if (tickCounter >= nextSpawnTick) {
        int count = level <= 2 ? 1 : (level == 3 ? 2 : (random.nextDouble() < 0.65 ? 2 : 3));
        List<int> usedLanes = [];

        for (int i = 0; i < count; i++) {
          int lane;
          do {
            lane = random.nextInt(laneCount);
          } while (usedLanes.contains(lane) && usedLanes.length < laneCount);
          usedLanes.add(lane);

          double chance = random.nextDouble();
          ItemType type;

          if (level >= 2 && chance < 0.05) {
            type = ItemType.keyItem;
          } else if (level >= 2 && chance < 0.11) {
            type = ItemType.shield; // 5s Shield
          } else if (level >= 3 && chance < 0.16) {
            type = ItemType.turbo; // Nitro Turbo Boost
          } else if (level >= 2 && chance < 0.22) {
            type = ItemType.magnet; // Super Magnet
          } else if (chance < 0.58) {
            type = ItemType.coin;
          } else if (chance < 0.82) {
            type = ItemType.car;
          } else {
            type = ItemType.barricade;
          }

          String? carImg = type == ItemType.car ? (random.nextBool() ? 'assets/game/car1.png' : 'assets/game/car2.png') : null;
          items.add(FallingItem(lane: lane, y: -0.18 - (i * 0.09), type: type, carImage: carImg));
        }
        nextSpawnTick = tickCounter + (38 - (level * 3)).clamp(16, 40) + random.nextInt(8);
      }

      // Magnet Curved Physics & Item movement
      for (var item in items) {
        if (magnetTimer > 0 && item.type == ItemType.coin) {
          item.lane += (playerLane > item.lane ? 1 : (playerLane < item.lane ? -1 : 0));
        }
        item.y += currentSpeed;
        if (item.spawnT < 1) item.spawnT = (item.spawnT + 0.12).clamp(0.0, 1.0);
      }

      // Shockwaves & Debris lifecycle
      for (var s in shockwaves) { s.life--; }
      shockwaves.removeWhere((s) => s.life <= 0);
      for (var d in debris) {
        d.x += d.vx * 0.001;
        d.y += d.vy * 0.001;
        d.life--;
      }
      debris.removeWhere((d) => d.life <= 0);

      // Collision Engine with Invincible Shield & Blast
      for (var item in List<FallingItem>.from(items)) {
        if (item.dodged) continue;

        // Near-Miss / Close Shave Calculation
        if (item.type == ItemType.car && (item.lane - playerLane).abs() == 1 && (item.y - playerY).abs() < 0.03 && !item.dodged) {
          item.dodged = true;
          score += 50;
          popups.add(FloatingPopup(x: playerLane.toDouble(), y: playerY - 0.08, text: '🔥 CLOSE SHAVE! +50', color: Colors.orangeAccent));
        }

        if (item.lane == playerLane && item.y > playerY - 0.06 && item.y < playerY + 0.06) {
          if (item.type == ItemType.coin) {
            coins += 1;
            coinCombo++;
            if (coinCombo == 5) {
              scoreMultiplier = 2;
              activeBanner = '🔥 COMBO x2 ACTIVE! 🔥';
              bannerTimer = 90;
            } else if (coinCombo == 10) {
              scoreMultiplier = 3;
              activeBanner = '⚡ MEGA COMBO x3! ⚡';
              bannerTimer = 90;
            }
            score += 10 * scoreMultiplier;
            popups.add(FloatingPopup(x: item.lane.toDouble(), y: item.y, text: '+${10 * scoreMultiplier}'));
            items.remove(item);
            SoundManager.playCoin();
            _scoreBumpController.forward(from: 0);
          } else if (item.type == ItemType.keyItem) {
            keys += 1;
            score += 50;
            popups.add(FloatingPopup(x: item.lane.toDouble(), y: item.y, text: 'KEY! +1', color: Colors.cyanAccent));
            items.remove(item);
            SoundManager.playCoin();
          } else if (item.type == ItemType.shield) {
            shieldTimer = 300; // 5 Full Seconds
            activeBanner = '🛡️ 5-SECOND SHIELD ACTIVE!';
            bannerTimer = 100;
            popups.add(FloatingPopup(x: item.lane.toDouble(), y: item.y, text: '🛡️ 5S SHIELD!', color: Colors.purpleAccent));
            items.remove(item);
            SoundManager.playCoin();
          } else if (item.type == ItemType.turbo) {
            turboTimer = 210; // 3.5 Seconds Turbo
            activeBanner = '⚡ NITRO TURBO ENGAGED!';
            bannerTimer = 100;
            popups.add(FloatingPopup(x: item.lane.toDouble(), y: item.y, text: '⚡ NITRO TURBO!', color: Colors.cyanAccent));
            items.remove(item);
            SoundManager.playCoin();
          } else if (item.type == ItemType.magnet) {
            magnetTimer = 360; // 6 Seconds Magnet
            activeBanner = '🧲 COIN MAGNET ACTIVE!';
            bannerTimer = 100;
            popups.add(FloatingPopup(x: item.lane.toDouble(), y: item.y, text: '🧲 MAGNET!', color: Colors.tealAccent));
            items.remove(item);
            SoundManager.playCoin();
          } else if (isJumping) {
            item.dodged = true;
          } else {
            // Blast obstacle if Shield or Turbo is active
            if (shieldTimer > 0 || turboTimer > 0) {
              triggerShockwave(item.lane.toDouble(), item.y);
              popups.add(FloatingPopup(x: item.lane.toDouble(), y: item.y, text: '💥 SMASHED!', color: Colors.redAccent));
              items.remove(item);
            } else {
              arrestPlayer();
              return;
            }
          }
        }
      }

      items.removeWhere((item) => item.y > 1.15);

      for (var p in popups) {
        p.y -= 0.007;
        p.life--;
      }
      popups.removeWhere((p) => p.life <= 0);

      if (tickCounter % 18 == 0) score += 1 * scoreMultiplier;
      final newLevel = (coins ~/ 10) + 1;
      if (newLevel != level) {
        level = newLevel;
        levelFlashTimer = 20;
        HapticFeedback.lightImpact();
      }

      if (score > highestScore) highestScore = score;
      if (coins > highestCoins) highestCoins = coins;
      if (level > highestLevel) highestLevel = level;
    });
  }

  void arrestPlayer() {
    isArrested = true;
    _shakeController.forward(from: 0);
    HapticFeedback.heavyImpact();
    triggerReviveOrGameOver();
  }

  void triggerReviveOrGameOver() {
    gameTimer?.cancel();
    SoundManager.stopBackgroundMusic();
    SoundManager.playGameOver();

    if (keys > 0) {
      setState(() {
        showRevivePrompt = true;
        reviveTimerSeconds = 4;
      });
      reviveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          reviveTimerSeconds--;
          if (reviveTimerSeconds <= 0) {
            timer.cancel();
            showRevivePrompt = false;
            setState(() => isGameOver = true);
            _gameOverController.forward(from: 0);
          }
        });
      });
    } else {
      setState(() => isGameOver = true);
      _gameOverController.forward(from: 0);
    }
  }

  void useKeyToRevive() {
    if (keys <= 0) return;
    reviveTimer?.cancel();
    setState(() {
      keys--;
      showRevivePrompt = false;
      isRevivingCloud = true;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          isRevivingCloud = false;
          isGameOver = false;
          isArrested = false;
          policeY = 1.2;
          shieldTimer = 180; // 3 seconds respawn protection
          items.removeWhere((i) => (i.y - playerY).abs() < 0.25);
        });
        SoundManager.playBackgroundMusic();
        gameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) => updateGame());
      }
    });
  }

  void triggerJump() {
    if (isGameOver || isJumping || isPaused || isIntroPhase || showRevivePrompt) return;
    setState(() {
      isJumping = true;
      jumpTick = 0;
    });
    SoundManager.playJump();
    HapticFeedback.selectionClick();
  }

  void moveLeft() {
    if (!isGameOver && !isPaused && playerLane > 0 && !showRevivePrompt) {
      setState(() => playerLane--);
      HapticFeedback.selectionClick();
    }
  }

  void moveRight() {
    if (!isGameOver && !isPaused && playerLane < laneCount - 1 && !showRevivePrompt) {
      setState(() => playerLane++);
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    countdownTimer?.cancel();
    reviveTimer?.cancel();
    _shakeController.dispose();
    _scoreBumpController.dispose();
    _pulseAuraController.dispose();
    _hudEntranceController.dispose();
    _gameOverController.dispose();
    super.dispose();
  }

  // Dynamic Theme Colors based on progression
  List<Color> get themeBackground {
    if (score < 150) {
      return [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]; // Sunny Highway
    } else if (score < 300) {
      return [const Color(0xFFE65100), const Color(0xFF3E2723)]; // Sunset Neon
    } else {
      return [const Color(0xFF0D47A1), const Color(0xFF1A237E)]; // Cyber Midnight
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final roadWidth = size.width * 0.84;
    final laneWidth = roadWidth / laneCount;
    final roadLeft = (size.width - roadWidth) / 2;
    final shakeDx = sin(_shakeController.value * pi * 8) * (1 - _shakeController.value) * 14;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (isIntroPhase) startChase();
        },
        onHorizontalDragEnd: (d) {
          if (d.velocity.pixelsPerSecond.dx > 100) moveRight();
          if (d.velocity.pixelsPerSecond.dx < -100) moveLeft();
        },
        onVerticalDragEnd: (d) {
          if (d.velocity.pixelsPerSecond.dy < -100) triggerJump();
        },
        child: Transform.translate(
          offset: Offset(shakeDx, 0),
          child: Stack(
            children: [
              // Dynamic Background
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(seconds: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: themeBackground),
                  ),
                ),
              ),

              // Parallax scenery (buildings/trees on either side of the road)
              ...scenery.map((s) {
                final y = (s.baseY + sceneryOffset) % 1.2 - 0.15;
                return Positioned(
                  left: s.x * size.width - (s.isBuilding ? 22 : 14) * s.scale,
                  top: y * size.height,
                  child: Opacity(
                    opacity: 0.55,
                    child: s.isBuilding
                        ? Container(
                            width: 44 * s.scale,
                            height: 90 * s.scale,
                            decoration: BoxDecoration(
                              color: s.color,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                            ),
                          )
                        : Icon(Icons.park_rounded, size: 42 * s.scale, color: s.color),
                  ),
                );
              }),

              // Road Surface
              Positioned(
                left: roadLeft,
                top: 0,
                width: roadWidth,
                height: size.height,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.grey[900]!, Colors.grey[850]!, Colors.grey[900]!],
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 18, spreadRadius: -2),
                    ],
                  ),
                ),
              ),

              // Road Dividers
              ...List.generate(laneCount - 1, (i) {
                return Positioned(
                  left: roadLeft + (i + 1) * laneWidth - 2,
                  top: 0,
                  width: 4,
                  height: size.height,
                  child: CustomPaint(painter: DashedLinePainter(offset: roadOffset)),
                );
              }),

              // Landing dust puffs
              ...dustPuffs.map((d) {
                final t = 1 - (d.life / _DustPuff.maxLife);
                return Positioned(
                  left: roadLeft + d.x * laneWidth + laneWidth / 2 - (10 + t * 16),
                  top: d.y * size.height - (10 + t * 16) / 2,
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0) * 0.5,
                    child: Container(
                      width: 20 + t * 32,
                      height: 20 + t * 32,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    ),
                  ),
                );
              }),

              // Trail Particles
              ...trailParticles.map((t) => Positioned(
                    left: roadLeft + t.lane * laneWidth + laneWidth / 2 - 8,
                    top: t.y * size.height,
                    child: Opacity(
                      opacity: (t.life / _TrailParticle.maxLife).clamp(0.0, 1.0),
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: t.color, boxShadow: [BoxShadow(color: t.color, blurRadius: 10)]),
                      ),
                    ),
                  )),

              // Shockwaves
              ...shockwaves.map((s) => Positioned(
                    left: roadLeft + s.x * laneWidth + laneWidth / 2 - (1 - (s.life / BlastShockwave.maxLife)) * 60,
                    top: s.y * size.height - (1 - (s.life / BlastShockwave.maxLife)) * 60,
                    child: Opacity(
                      opacity: (s.life / BlastShockwave.maxLife).clamp(0.0, 1.0),
                      child: Container(
                        width: (1 - (s.life / BlastShockwave.maxLife)) * 120,
                        height: (1 - (s.life / BlastShockwave.maxLife)) * 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amberAccent, width: 4),
                          boxShadow: const [BoxShadow(color: Colors.amberAccent, blurRadius: 16)],
                        ),
                      ),
                    ),
                  )),

              // Debris Shards
              ...debris.map((d) => Positioned(
                    left: roadLeft + d.x * laneWidth + laneWidth / 2,
                    top: d.y * size.height,
                    child: Opacity(
                      opacity: (d.life / DebrisParticle.maxLife).clamp(0.0, 1.0),
                      child: Transform.rotate(
                        angle: d.life * 0.4,
                        child: Container(width: 8, height: 8, decoration: BoxDecoration(color: d.color, borderRadius: BorderRadius.circular(2), boxShadow: [BoxShadow(color: d.color, blurRadius: 6)])),
                      ),
                    ),
                  )),

              // Items & Obstacles
              ...items.map((item) => Positioned(
                    left: roadLeft + item.lane * laneWidth + laneWidth / 2 - 40,
                    top: item.y * size.height,
                    child: Transform.scale(
                      scale: 0.4 + 0.6 * Curves.easeOutBack.transform(item.spawnT),
                      child: _buildItemVisual(item),
                    ),
                  )),

              // Police Officer with subtle siren glow
              Positioned(
                left: roadLeft + policeLaneAnim * laneWidth + laneWidth / 2 - 28,
                top: policeY * size.height,
                child: AnimatedBuilder(
                  animation: _pulseAuraController,
                  builder: (context, child) => Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_pulseAuraController.value > 0.5 ? Colors.redAccent : Colors.blueAccent).withValues(alpha: 0.55),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                  child: Image.asset('assets/game/police.png', width: 56, height: 56, errorBuilder: (_, __, ___) => const Icon(Icons.local_police, color: Colors.blue, size: 50)),
                ),
              ),

              // Player Character with Kinetic Lean, Squash-Stretch & Shield/Turbo Auras
              Positioned(
                left: roadLeft + playerLaneAnim * laneWidth + laneWidth / 2 - 40,
                top: playerY * size.height - (isJumping ? sin((jumpTick / jumpDuration) * pi) * jumpHeight : 0),
                child: Transform.rotate(
                  angle: (playerLane - playerLaneAnim) * -0.3,
                  child: Transform.scale(
                    scaleX: isJumping ? 1 - sin((jumpTick / jumpDuration) * pi) * 0.12 : 1.0,
                    scaleY: isJumping ? 1 + sin((jumpTick / jumpDuration) * pi) * 0.12 : 1.0,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (shieldTimer > 0)
                          AnimatedBuilder(
                            animation: _pulseAuraController,
                            builder: (_, __) => Container(
                              width: 95 + _pulseAuraController.value * 12,
                              height: 95 + _pulseAuraController.value * 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.purpleAccent, width: 3.5),
                                boxShadow: [BoxShadow(color: Colors.purpleAccent.withValues(alpha: 0.6), blurRadius: 18)],
                              ),
                            ),
                          ),
                        if (turboTimer > 0)
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.cyanAccent, width: 3),
                              boxShadow: [BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.7), blurRadius: 22)],
                            ),
                          ),
                        Image.asset('assets/game/character.gif', width: 80, height: 80, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 70, color: Colors.amber)),
                      ],
                    ),
                  ),
                ),
              ),

              // Popups
              ...popups.map((p) => Positioned(
                    left: roadLeft + p.x * laneWidth + laneWidth / 2 - 30,
                    top: p.y * size.height,
                    child: Transform.scale(
                      scale: p.scale,
                      child: Text(
                        p.text,
                        style: TextStyle(color: p.color, fontSize: 18, fontWeight: FontWeight.w900, shadows: const [Shadow(color: Colors.black, blurRadius: 6)]),
                      ),
                    ),
                  )),

              // Level-up screen flash
              if (levelFlashTimer > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (levelFlashTimer / 20).clamp(0.0, 1.0) * 0.25,
                      child: Container(color: Colors.amberAccent),
                    ),
                  ),
                ),

              // Vignette overlay for cinematic depth
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.15,
                        colors: [Colors.transparent, Color(0x66000000)],
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // Dynamic Banner
              if (activeBanner != null)
                Positioned(
                  top: 110,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(activeBanner),
                      tween: Tween(begin: 0.5, end: 1.0),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      builder: (context, v, child) => Transform.scale(scale: v, child: child),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)],
                        ),
                        child: Text(
                          activeBanner!,
                          style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                        ),
                      ),
                    ),
                  ),
                ),

              // HUD & Power-up Duration Indicators
              if (!isIntroPhase)
                Positioned(
                  top: 40,
                  left: 14,
                  right: 14,
                  child: FadeTransition(
                    opacity: _hudEntranceController,
                    child: SlideTransition(
                      position: _hudEntranceController.drive(Tween(begin: const Offset(0, -0.4), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic))),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _hudCard('SCORE', '$score', scoreMultiplier > 1 ? Colors.amberAccent : Colors.white, scaleWith: _scoreBumpAnimation),
                              _hudCard('LVL', '$level', Colors.amber),
                              _hudCard('COINS', '$coins', Colors.amberAccent),
                              _hudCard('KEYS', '$keys', Colors.cyanAccent),
                              GestureDetector(
                                onTap: togglePause,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: const Icon(Icons.pause_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Active Power-up Gauge Chips
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (shieldTimer > 0) _powerupChip('SHIELD', '${(shieldTimer / 60).toStringAsFixed(1)}s', Colors.purpleAccent, shieldTimer / 300),
                              if (turboTimer > 0) _powerupChip('NITRO', '${(turboTimer / 60).toStringAsFixed(1)}s', Colors.cyanAccent, turboTimer / 210),
                              if (magnetTimer > 0) _powerupChip('MAGNET', '${(magnetTimer / 60).toStringAsFixed(1)}s', Colors.tealAccent, magnetTimer / 360),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Tap To Escape Screen
              if (isIntroPhase)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.9, end: 1.05),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeInOut,
                        builder: (context, v, child) => Transform.scale(scale: v, child: child),
                        child: const Text(
                          'TAP TO ESCAPE!',
                          style: TextStyle(color: Colors.amberAccent, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 3, shadows: [Shadow(color: Colors.black87, blurRadius: 16)]),
                        ),
                      ),
                    ),
                  ),
                ),

              // Pause Overlay
              if (isPaused)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.pause_circle_filled_rounded, color: Colors.amberAccent, size: 64),
                            const SizedBox(height: 12),
                            const Text('PAUSED', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2)),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: togglePause,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('RESUME', style: TextStyle(fontWeight: FontWeight.w900)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Revive Prompt
              if (showRevivePrompt)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      color: Colors.black87,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.vpn_key_rounded, color: Colors.cyanAccent, size: 54),
                            const SizedBox(height: 10),
                            const Text('CAUGHT!', style: TextStyle(color: Colors.redAccent, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2)),
                            const SizedBox(height: 8),
                            Text('Use a key to revive? ($reviveTimerSeconds s)', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: useKeyToRevive,
                              icon: const Icon(Icons.flash_on_rounded),
                              label: const Text('REVIVE NOW', style: TextStyle(fontWeight: FontWeight.w900)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyanAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Revive Cloud Effect
              if (isRevivingCloud)
                Positioned.fill(
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      builder: (context, v, child) => Opacity(
                        opacity: (1 - v).clamp(0.0, 1.0),
                        child: Container(color: Colors.cyanAccent.withValues(alpha: 0.5 * (1 - v))),
                      ),
                    ),
                  ),
                ),

              // Game Over — polished staggered reveal
              if (isGameOver)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      color: Colors.black87,
                      child: Center(
                        child: FadeTransition(
                          opacity: _gameOverController,
                          child: ScaleTransition(
                            scale: CurvedAnimation(parent: _gameOverController, curve: Curves.easeOutBack),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('GAME OVER', style: TextStyle(color: Colors.redAccent, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 2, shadows: [Shadow(color: Colors.black87, blurRadius: 14)])),
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _statChip(Icons.stars_rounded, '$score', 'SCORE', Colors.amberAccent),
                                    const SizedBox(width: 12),
                                    _statChip(Icons.monetization_on_rounded, '$coins', 'COINS', Colors.amber),
                                    const SizedBox(width: 12),
                                    _statChip(Icons.emoji_events_rounded, '$highestScore', 'BEST', Colors.orangeAccent),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                ElevatedButton.icon(
                                  onPressed: setupGame,
                                  icon: const Icon(Icons.refresh_rounded),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                                    elevation: 10,
                                  ),
                                  label: const Text('PLAY AGAIN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _hudCard(String label, String value, Color color, {Animation<double>? scaleWith}) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
    if (scaleWith == null) return card;
    return AnimatedBuilder(
      animation: scaleWith,
      builder: (context, child) => Transform.scale(scale: scaleWith.value, child: child),
      child: card,
    );
  }

  Widget _powerupChip(String name, String time, Color color, double progress) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
              const SizedBox(width: 4),
              Text(time, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 46,
              height: 3,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.black38,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemVisual(FallingItem item) {
    switch (item.type) {
      case ItemType.coin:
        return Image.asset('assets/game/coin.png', width: 45, height: 45, errorBuilder: (_, __, ___) => const Icon(Icons.monetization_on, color: Colors.amber, size: 40));
      case ItemType.keyItem:
        return const Icon(Icons.vpn_key_rounded, color: Colors.cyanAccent, size: 38);
      case ItemType.shield:
        return const Icon(Icons.shield_rounded, color: Colors.purpleAccent, size: 42);
      case ItemType.turbo:
        return const Icon(Icons.bolt_rounded, color: Colors.cyanAccent, size: 44);
      case ItemType.magnet:
        return const Icon(Icons.electric_bolt_rounded, color: Colors.tealAccent, size: 40);
      case ItemType.car:
        return Image.asset(item.carImage ?? 'assets/game/car1.png', width: 80, height: 120, errorBuilder: (_, __, ___) => Container(width: 70, height: 100, color: Colors.red));
      case ItemType.barricade:
        return Container(
          width: 60,
          height: 38,
          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.black, width: 2)),
          child: const Center(child: Icon(Icons.block, color: Colors.white, size: 24)),
        );
      case ItemType.bush:
        return Image.asset('assets/game/bushes.png', width: 55, height: 55, errorBuilder: (_, __, ___) => const Icon(Icons.park, color: Colors.green, size: 45));
    }
  }
}

class _TrailParticle {
  double lane;
  double y;
  Color color;
  int life;
  static const int maxLife = 16;
  _TrailParticle({required this.lane, required this.y, required this.color, this.life = maxLife});
}

class DashedLinePainter extends CustomPainter {
  final double offset;
  DashedLinePainter({required this.offset});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white70..strokeWidth = 4;
    double startY = -80 + offset;
    while (startY < size.height) {
      canvas.drawLine(Offset(size.width / 2, startY), Offset(size.width / 2, startY + 30.0), paint);
      startY += 60.0;
    }
  }
  @override
  bool shouldRepaint(covariant DashedLinePainter oldDelegate) => true;
}