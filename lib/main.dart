import 'dart:ui'; // Required for Glass Effect
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'track_bus_screen.dart'; 
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart'; 
import 'package:flutter/services.dart';
import 'driver_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
// --- Constants & New Theme Colors ---
class AppColors {
  static const Color mainBackground = Color(0xFFFFFDF6);
  static const Color primaryDark = Color(0xFF4C5372);
  static const Color deepNavy = Color(0xFF4C5372);
  static const Color secondaryDark = Color(0xFF7C7E9D);
  static const Color accent = Color(0xFF949AB1);
  static const Color lightAccent = Color(0xFFE2D4E0);
  static const Color white = Colors.white;
  static const Color grey = Color(0xFF858585);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  Future<void> _initializeFirebase() async {
    await Future.delayed(const Duration(seconds: 2));
    await Firebase.initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeFirebase(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const MaterialApp(home: Scaffold(body: Center(child: Text("Firebase Error"))));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            home: Scaffold(
              backgroundColor: const Color(0xFFFFFDF6),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/icon/app_icon.png', width: 120, height: 120),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(color: AppColors.deepNavy),
                    const SizedBox(height: 16),
                    const Text(
                      "Initializing Smart Yatra...",
                      style: TextStyle(
                        color: AppColors.deepNavy,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const SmartYatraApp();
      },
    );
  }
}

class SmartYatraApp extends StatelessWidget {
  const SmartYatraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Yatra',
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: AppColors.mainBackground,
        primaryColor: AppColors.deepNavy,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        // Fetch user role
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
              final userData = userSnapshot.data!.data() as Map<String, dynamic>;
              final String role = userData['role'] ?? 'student';

              if (role == 'driver') {
                return DriverDashboard(driverEmail: user.email ?? '');
              } else {
                return const MainContainer();
              }
            }
            
            // Fallback
            return const LoginScreen();
          },
        );
      },
    );
  }
}

// --- Animation Helper Widgets ---
class FadeInSlide extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;

  const FadeInSlide({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = const Duration(milliseconds: 0),
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    Future.delayed(Duration(milliseconds: widget.delay.inMilliseconds + (widget.index * 100)), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin,
    this.padding,
    this.borderRadius = 20,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: widget.margin,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: AppColors.lightAccent,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class PulsingWidget extends StatefulWidget {
  final Widget child;
  final bool animate;

  const PulsingWidget({super.key, required this.child, this.animate = true});

  @override
  State<PulsingWidget> createState() => _PulsingWidgetState();
}

class _PulsingWidgetState extends State<PulsingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) return widget.child;
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding,
    this.margin,
  });


  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Blur intensity
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4), // Semi-transparent white
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(color: AppColors.deepNavy.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// --- Main Container ---
class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  String _activeScreen = 'home';
  String? _selectedBusId;
  DateTime? _lastPressedAt;

  // Navigation Handlers
  void _handleTrackBus() => setState(() => _activeScreen = 'detail');
  void _handleSelectBus(String busId) => setState(() { _selectedBusId = busId; _activeScreen = 'detail'; });
  void _handleBackToHome() => setState(() => _activeScreen = 'home');
  void _handleBackToList() => setState(() => _activeScreen = 'list');
  void _handleViewBusList() => setState(() => _activeScreen = 'list');
  void _handleNavigate(String screen) => setState(() => _activeScreen = screen);

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (_activeScreen) {
      case 'home':
        content = DashboardHomeScreen(onTrackBus: _handleTrackBus, onViewBusList: _handleViewBusList);
        break;
      case 'list':
        content = BusListScreen(onBack: _handleBackToHome, onSelectBus: _handleSelectBus);
        break;
      case 'detail':
        // Ensure BusDetailScreen exists or comment this out if not ready
        content = BusDetailScreen(onBack: _handleBackToList, busId: _selectedBusId ?? 'bus_01');
        break;
      case 'profile':
        content = const SettingsProfileScreen();
        break;
      default:
        content = DashboardHomeScreen(onTrackBus: _handleTrackBus, onViewBusList: _handleViewBusList);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        
        final now = DateTime.now();
        if (_lastPressedAt == null || 
            now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.mainBackground,
        resizeToAvoidBottomInset: false, 
        body: Stack(
          children: [
            Positioned.fill(child: content),

            // Bottom Navigation
            if (_activeScreen != 'detail')
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: BottomNav(activeScreen: _activeScreen, onNavigate: _handleNavigate),
              ),
          ],
        ),
      ),
    );
  }
}
// --- 1. Dashboard Home Screen ---
class DashboardHomeScreen extends StatefulWidget {
  final VoidCallback onTrackBus;
  final VoidCallback onViewBusList;

  const DashboardHomeScreen({super.key, required this.onTrackBus, required this.onViewBusList});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> with TickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
    );
    _headerSlideAnimation = Tween<Offset>(begin: const Offset(-0.2, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic),
    );
    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quickActions = [
      {'icon': Icons.map_outlined, 'label': 'Track Bus', 'color': const Color(0xFF4A90D9)},
      {'icon': Icons.history, 'label': 'History', 'color': const Color(0xFF7B68EE)},
      {'icon': Icons.favorite_outline, 'label': 'Favorites', 'color': const Color(0xFFFF6B6B)},
      {'icon': Icons.support_agent_outlined, 'label': 'Support', 'color': const Color(0xFF50C878)},
    ];

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Animated Header
            FadeInSlide(
              index: 0,
              delay: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SlideTransition(
                          position: _headerSlideAnimation,
                          child: FadeTransition(
                            opacity: _headerFadeAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Welcome back!",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.secondaryDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).get(),
                                  builder: (context, snapshot) {
                                    String name = "Student";
                                    if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                                      name = snapshot.data!.get('name') ?? "Student";
                                    }
                                    return Text(
                                      "Hi, $name!",
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryDark,
                                      ),
                                    );
                                  }
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            _buildIconBtn(Icons.notifications_none, hasBadge: true),
                            const SizedBox(width: 8),
                            _buildIconBtn(Icons.settings_outlined),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Hero Card
            FadeInSlide(
              index: 1,
              delay: const Duration(milliseconds: 300),
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return _buildEmptyHeroCard(isLoading: true);
                  }

                  String? assignedRoute;
                  if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                    assignedRoute = userData?['assignedRoute'] as String?;
                  }

                  if (assignedRoute == null || assignedRoute.isEmpty) {
                    return _buildEmptyHeroCard();
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('buses').where('route', isEqualTo: assignedRoute).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildEmptyHeroCard(isLoading: true);
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyHeroCard();
                      }

                       // Grab the first element since it's filtered by route
                      var busDoc = snapshot.data!.docs.first;
                      final busData = busDoc.data() as Map<String, dynamic>;
                      
                      final busNumber = busData['busNumber'] ?? 'Unknown Bus';
                      final route = busData['route'] ?? 'Unknown Route';
                      final status = busData['status'] ?? 'Stopped';
                      final lat = busData['latitude'];
                      final lng = busData['longitude'];
                      final busId = busDoc.id;

                      Color statusDotColor = Colors.grey;
                      int extraDelay = 0;
                      int delayMinutes = busData['delayMinutes'] as int? ?? 0;
                      Timestamp? trafficExpiresAt = busData['trafficExpiresAt'] as Timestamp?;

                      String displayStatus = status;

                      if (status == 'Driving') {
                        statusDotColor = const Color(0xFF50C878);
                        displayStatus = "Live on route";
                      } else if (status == 'Traffic') {
                        statusDotColor = Colors.orange;
                        displayStatus = "Slight Delay (Traffic)";
                        if (trafficExpiresAt != null && DateTime.now().isBefore(trafficExpiresAt.toDate())) {
                          extraDelay = 5;
                        }
                      } else if (status == 'On Break') {
                        statusDotColor = Colors.orange;
                        displayStatus = "On Break (Delayed by $delayMinutes mins)";
                        extraDelay = delayMinutes;
                      } else if (status == 'SOS') {
                        statusDotColor = Colors.red;
                        displayStatus = "EMERGENCY: SOS Active";
                      }

                      return FutureBuilder<Position?>(
                        future: _determinePosition(),
                        builder: (context, positionSnapshot) {
                          String etaText = "Calculating ETA...";
                          
                          if (positionSnapshot.hasData && positionSnapshot.data != null && lat is num && lng is num) {
                            final userLat = positionSnapshot.data!.latitude;
                            final userLng = positionSnapshot.data!.longitude;
                            
                            // Distance in meters
                            final double distanceInMeters = Geolocator.distanceBetween(
                              userLat, userLng, lat.toDouble(), lng.toDouble()
                            );
                            
                            // Average speed 30km/h = ~8.33 m/s
                            // time = distance / speed
                            double timeInSeconds = distanceInMeters / 8.33;
                            int timeInMinutes = (timeInSeconds / 60).round() + extraDelay;
                            
                            etaText = timeInMinutes <= 0 ? "Arriving now" : "Arriving in $timeInMinutes min";
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: AnimatedCard(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => BusDetailScreen(onBack: () => Navigator.pop(context), busId: busId)));
                              },
                              padding: const EdgeInsets.all(24),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: AppColors.lightAccent,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "Your Daily Route",
                                          style: TextStyle(color: AppColors.secondaryDark, fontWeight: FontWeight.w500),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.accent,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.access_time, color: Colors.white, size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                etaText,
                                                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      route,
                                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                    ),
                                    Text(
                                      "Bus: $busNumber",
                                      style: const TextStyle(color: AppColors.secondaryDark, fontSize: 16),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        PulsingWidget(
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: statusDotColor,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: statusDotColor,
                                                  blurRadius: 8,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          displayStatus,
                                          style: TextStyle(
                                            color: status == 'SOS' ? Colors.red : AppColors.primaryDark, 
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryDark,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          elevation: 0,
                                        ),
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => BusDetailScreen(onBack: () => Navigator.pop(context), busId: busId)));
                                        },
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.gps_fixed, size: 18),
                                            SizedBox(width: 8),
                                            Text("Track Live Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                      );
                    },
                  );
                }
              ),
            ),

            const SizedBox(height: 24),

            // Quick Actions
            FadeInSlide(
              index: 2,
              delay: const Duration(milliseconds: 400),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Quick Actions",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: quickActions.asMap().entries.map((entry) {
                        final action = entry.value;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: entry.key < quickActions.length - 1 ? 12 : 0),
                            child: AnimatedCard(
                              onTap: () {},
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: (action['color'] as Color).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      action['icon'] as IconData,
                                      color: action['color'] as Color,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    action['label'] as String,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.deepNavy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Nearby Buses Section -> Your Assigned Bus
            FadeInSlide(
              index: 3,
              delay: const Duration(milliseconds: 500),
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  String? assignedRoute;
                  if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                    assignedRoute = userData?['assignedRoute'] as String?;
                  }

                  if (assignedRoute == null || assignedRoute.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Your Assigned Bus",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          ),
                          const SizedBox(height: 12),
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                "No route assigned. Please contact college administration.",
                                style: TextStyle(color: AppColors.primaryDark, fontSize: 16, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Your Assigned Bus",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                            ),
                            GestureDetector(
                              onTap: widget.onViewBusList,
                              child: Text(
                                "View All",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark.withOpacity(0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<Position?>(
                          future: _determinePosition(),
                          builder: (context, positionSnapshot) {
                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('buses').where('route', isEqualTo: assignedRoute).snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                                }
                                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No buses available currently.")));
                                }
                                
                                var busDocs = snapshot.data!.docs;
                                final userPos = positionSnapshot.data;

                                return Column(
                                  children: busDocs.map((doc) {
                                    final busData = doc.data() as Map<String, dynamic>;
                                    final busNumber = busData['busNumber'] ?? 'Unknown Bus';
                                    final route = busData['route'] ?? 'Unknown Route';
                                    final status = busData['status'] ?? 'Stopped';
                                    final lat = busData['latitude'];
                                    final lng = busData['longitude'];
                                    
                                    int extraDelay = 0;
                                    int delayMinutes = busData['delayMinutes'] as int? ?? 0;
                                    Timestamp? trafficExpiresAt = busData['trafficExpiresAt'] as Timestamp?;
                                    
                                    Color badgeColor = Colors.grey;
                                    String displayStatus = status;
                                    String rightPillText = "Wait...";

                                    if (status == 'Driving') {
                                      badgeColor = const Color(0xFF50C878);
                                      displayStatus = 'Live';
                                    } else if (status == 'Traffic') {
                                      badgeColor = Colors.orange;
                                      displayStatus = 'Traffic';
                                      if (trafficExpiresAt != null && DateTime.now().isBefore(trafficExpiresAt.toDate())) {
                                        extraDelay = 5;
                                      }
                                    } else if (status == 'On Break') {
                                      badgeColor = Colors.orange;
                                      displayStatus = 'Break (${delayMinutes}m)';
                                      extraDelay = delayMinutes;
                                    } else if (status == 'SOS') {
                                      badgeColor = Colors.red;
                                      displayStatus = 'SOS ACTIVE';
                                    }

                                    if (userPos != null && lat is num && lng is num) {
                                      final double distanceInMeters = Geolocator.distanceBetween(
                                        userPos.latitude, userPos.longitude, lat.toDouble(), lng.toDouble()
                                      );
                                      double timeInSeconds = distanceInMeters / 8.33;
                                      int timeInMinutes = (timeInSeconds / 60).round() + extraDelay;
                                      rightPillText = timeInMinutes <= 0 ? "Now" : "${timeInMinutes}m";
                                      if (status == 'SOS') rightPillText = "SOS";
                                    } else {
                                      rightPillText = status == 'Driving' ? "Active" : "Halted";
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: AnimatedCard(
                                        onTap: widget.onViewBusList,
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryDark,
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  const Icon(Icons.directions_bus, color: Colors.white, size: 28),
                                                  Positioned(
                                                    bottom: 4,
                                                    right: 4,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: badgeColor,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        displayStatus,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 8,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    busNumber,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color: AppColors.primaryDark,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    route,
                                                    style: const TextStyle(
                                                      color: AppColors.secondaryDark,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: badgeColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: badgeColor.withOpacity(0.3)),
                                              ),
                                              child: Column(
                                                children: [
                                                  Icon(status == 'SOS' ? Icons.warning_rounded : Icons.access_time, size: 18, color: badgeColor),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    rightPillText,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: badgeColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            );
                          }
                        ),
                      ],
                    ),
                  );
                }
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, {bool hasBadge = false}) {
    // ... (unchanged _buildIconBtn structure below)
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.lightAccent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.primaryDark, size: 22),
        ),
        if (hasBadge)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  // --- Helpers for Dynamic Hero Card ---
  Widget _buildEmptyHeroCard({bool isLoading = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedCard(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.lightAccent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Your Daily Route", style: TextStyle(color: AppColors.secondaryDark, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              isLoading 
                  ? const CircularProgressIndicator()
                  : const Text("No active route assigned", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
            ],
          ),
        ),
      ),
    );
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
  }
}

// --- 2. Bus List Screen ---
class BusListScreen extends StatelessWidget {
  final VoidCallback onBack;
  final Function(String) onSelectBus;

  const BusListScreen({super.key, required this.onBack, required this.onSelectBus});

  Future<void> _makePhoneCall(BuildContext context, String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No phone number linked.")));
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) await launchUri;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back, color: AppColors.deepNavy),
                  ),
                ),
                const Text("Your Assigned Bus", style: TextStyle(color: AppColors.deepNavy, fontSize: 20, fontWeight: FontWeight.bold)),
                const Icon(Icons.cloud_sync, color: AppColors.deepNavy),
              ],
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).get(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      
                    String? assignedRoute;
                    if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                      final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                      assignedRoute = userData?['assignedRoute'] as String?;
                    }

                    if (assignedRoute == null || assignedRoute.isEmpty) {
                      return const Center(child: Text("No route assigned. Please contact college administration.", style: TextStyle(color: AppColors.primaryDark, fontSize: 16, fontWeight: FontWeight.w500), textAlign: TextAlign.center,));
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('buses').where('route', isEqualTo: assignedRoute).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (snapshot.hasError) {
                          print('Firestore Error (main.dart): ${snapshot.error}');
                          return Center(child: Text("Error: ${snapshot.error}"));
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          print('Warning: No buses found in Firestore collection');
                          return const Center(child: Text("No buses found online."));
                        }
                        final buses = snapshot.data!.docs;

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                          itemCount: buses.length,
                          itemBuilder: (context, index) {
                            var busData = buses[index].data() as Map<String, dynamic>;
                            String busName = busData['busNumber'] ?? 'Unknown Bus';
                            String route = busData['route'] ?? 'Unknown Route';
                            String status = busData['status'] ?? 'Unknown';
                            String? driverPhone = busData['driverPhone'];

                            return GestureDetector(
                              onTap: () => onSelectBus(buses[index].id),
                              child: GlassContainer(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: AppColors.deepNavy, borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.directions_bus, color: Colors.white),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(busName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                                          Text(route, style: TextStyle(fontSize: 12, color: AppColors.deepNavy.withOpacity(0.6))),
                                        ],
                                      ),
                                    ),
                                    if (driverPhone != null && driverPhone.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: InkWell(
                                          onTap: () => _makePhoneCall(context, driverPhone),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.deepNavy.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.phone, color: AppColors.deepNavy, size: 18),
                                          ),
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: status == 'Driving' ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: status == 'Driving' ? Colors.green : Colors.red),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: status == 'Driving' ? Colors.green[800] : Colors.red[800],
                                          fontSize: 10, fontWeight: FontWeight.bold
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  }
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- 4. Settings Profile Screen ---
class SettingsProfileScreen extends StatefulWidget {
  const SettingsProfileScreen({super.key});
  @override
  State<SettingsProfileScreen> createState() => _SettingsProfileScreenState();
}

class _SettingsProfileScreenState extends State<SettingsProfileScreen> {
  bool notificationsEnabled = true;

  void _handleLogout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.deepNavy));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 140),
      child: Column(
        children: [
          Container(
            height: 300,
            width: double.infinity,
            color: AppColors.deepNavy,
            padding: const EdgeInsets.only(top: 60),
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).get(),
              builder: (context, snapshot) {
                String name = "Loading...";
                String email = FirebaseAuth.instance.currentUser?.email ?? "";
                if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                  name = snapshot.data!.get('name') ?? "Student User";
                }
                return Column(
                  children: [
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white30, width: 4), color: AppColors.mainBackground),
                      child: const Icon(Icons.person, size: 60, color: AppColors.deepNavy),
                    ),
                    const SizedBox(height: 16),
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(email.isNotEmpty ? "Student • $email" : "Student Participant", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                );
              }
            ),
          ),
          Container(
            transform: Matrix4.translationValues(0, -40, 0),
            child: GlassContainer(
              borderRadius: 32,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(width: 40, height: 6, decoration: BoxDecoration(color: AppColors.deepNavy.withOpacity(0.2), borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 24),
                  _buildSection("Account", [
                    _buildItem(Icons.edit, "Edit Profile", onTap: () => _showSnack("Edit Profile"), hasArrow: true),
                    _buildItem(Icons.lock, "Change Password", onTap: () => _showSnack("Change Password"), hasArrow: true),
                  ]),
                  _buildSection("App Preferences", [
                    _buildItem(Icons.notifications, "Notifications", isToggle: true),
                    _buildItem(Icons.language, "Language", value: "English", hasArrow: true),
                  ]),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text("Log Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.grey, letterSpacing: 1)),
        const SizedBox(height: 12),
        ...items,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildItem(IconData icon, String label, {bool hasArrow = false, bool isToggle = false, String? value, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: isToggle ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.deepNavy.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.deepNavy, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.deepNavy))),
            if (isToggle) Switch(
              value: notificationsEnabled, 
              activeColor: AppColors.deepNavy,
              onChanged: (val) => setState(() => notificationsEnabled = val)
            ),
            if (value != null) Text(value, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
            if (hasArrow) const Icon(Icons.chevron_right, color: AppColors.grey),
          ],
        ),
      ),
    );
  }
}

// --- 5. Bottom Navigation (FIXED: SAFE AREA AWARE) ---
class BottomNav extends StatelessWidget {
  final String activeScreen;
  final Function(String) onNavigate;

  const BottomNav({super.key, required this.activeScreen, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    // THIS IS THE CRITICAL FIX:
    // Calculate the height of the system navigation bar (footer)
    final double bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5)),
          ),
          // We add 'bottomPadding' to the padding so icons are pushed UP
          padding: EdgeInsets.only(
            top: 12, 
            bottom: 12 + bottomPadding, 
            left: 16, 
            right: 16
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', 'home'),
              _buildNavItem(Icons.directions_bus_rounded, 'Routes', 'list'),
              _buildNavItem(Icons.person_rounded, 'Profile', 'profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, String id) {
    final isActive = activeScreen == id;
    return GestureDetector(
      onTap: () => onNavigate(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isActive 
            ? BoxDecoration(color: AppColors.deepNavy.withOpacity(0.1), borderRadius: BorderRadius.circular(20))
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? AppColors.deepNavy : AppColors.grey, size: 26),
            if (isActive) ...[
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
            ]
          ],
        ),
      ),
    );
  }
}