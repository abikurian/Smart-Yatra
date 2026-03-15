import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';

// --- NEW THEME COLORS ---
const Color kMainColor = Color(0xFFFFFDF6); // Background (Off-White)
const Color kTextColor = Color(0xFF4C5372); // Primary Dark (Dark Slate Blue)
const Color kGreyAccent = Color(
  0xFF7C7E9D,
); // Secondary Dark (Medium Slate Blue)
const Color kWarmAccent = Color(0xFFE2D4E0); // Light Accent (Pale Lavender)
const Color kWhite = Colors.white;

const Color kAccentRed = Color(0xFFE63946);
const Color kAccentOrange = Color(0xFFFB8500);
const Color kAccentGreen = Color(0xFF2A9D8F);
const Color kAccent = Color(0xFF949AB1); // Accent (Muted Blue)

class DriverDashboard extends StatefulWidget {
  final String driverEmail;
  const DriverDashboard({super.key, this.driverEmail = "bus1@driver.com"});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  // --- STATE VARIABLES ---
  String viewState = "setup"; // 'setup' or 'dashboard'
  String? selectedBusId;
  String? selectedBusName;
  String? selectedRoute;
  bool isTripActive = false;
  bool isBreakMode = false;
  String statusMessage = "Ready to Start";
  StreamSubscription<Position>? _positionStream;
  DateTime? _lastPressedAt;

  // Driver Phone Mapping (Simulated DB)
  final Map<String, String> driverPhoneRegistry = {
    'bus1@driver.com': '9341627036',
    'bus2@driver.com': '9998887776',
    'admin@driver.com': '1234567890',
  };

  String get myPhoneNumber =>
      driverPhoneRegistry[widget.driverEmail] ?? '0000000000';

  final List<String> routes = [
    "Route 1: Pala - Kochi",
    "Route 2: Kochi - Aluva",
    "Route 3: Kottayam - Tvpm",
  ];

  // --- LOGIC METHODS ---

  void _handleDriverLogout() async {
    if (isTripActive) stopTracking();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void toggleTrip() async {
    if (isTripActive) {
      stopTracking();
    } else {
      if (await _handleLocationPermission()) startTracking();
    }
  }

  void openBreakDialog() {
    if (!isTripActive) {
      _showSnack("Start the trip first!");
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Break Duration"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text("5 Minutes"),
                onTap: () => _startBreak(5),
              ),
              ListTile(
                title: const Text("10 Minutes"),
                onTap: () => _startBreak(10),
              ),
              ListTile(
                title: const Text("15 Minutes"),
                onTap: () => _startBreak(15),
              ),
            ],
          ),
        );
      },
    );
  }

  void _startBreak(int minutes) {
    Navigator.pop(context);
    setState(() {
      isBreakMode = true;
      statusMessage = "On Break";
    });
    FirebaseFirestore.instance.collection('buses').doc(selectedBusId).update({
      'status': 'On Break',
      'delayMinutes': minutes,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  void reportTraffic() {
    if (!isTripActive) return;
    DateTime expiresAt = DateTime.now().add(const Duration(minutes: 5));
    FirebaseFirestore.instance.collection('buses').doc(selectedBusId).update({
      'status': 'Traffic',
      'trafficExpiresAt': Timestamp.fromDate(expiresAt),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    setState(() {
      isBreakMode = false;
      statusMessage = "Traffic";
    });
    _showSnack("⚠️ Reported Heavy Traffic (5 mins)");
  }

  void triggerSOS() {
    if (!isTripActive) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm SOS", style: TextStyle(color: Colors.red)),
          content: const Text("Are you sure you want to trigger SOS?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _sendSOS();
              },
              child: const Text("YES, SOS", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _sendSOS() {
    FirebaseFirestore.instance.collection('buses').doc(selectedBusId).update({
      'status': 'SOS',
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    setState(() {
      isBreakMode = false;
      statusMessage = "SOS Active";
    });
    _showSnack("🚨 SOS Alert Sent to Admin!");
  }

  void clearStatus() {
    if (!isTripActive) return;
    setState(() {
      isBreakMode = false;
      statusMessage = "Driving";
    });
    FirebaseFirestore.instance.collection('buses').doc(selectedBusId).update({
      'status': 'Driving',
      'delayMinutes': 0,
      'trafficExpiresAt': FieldValue.delete(),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    _showSnack("✅ Status Cleared. Resuming trip.");
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack("Please enable GPS");
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    return true;
  }

  void startTracking() {
    if (selectedBusId == null) return;

    setState(() {
      isTripActive = true;
      isBreakMode = false;
      statusMessage = "Driving";
    });

    // Initialize document when starting the trip
    FirebaseFirestore.instance.collection('buses').doc(selectedBusId).update({
      'status': 'Driving',
      'route': selectedRoute,
      'driverPhone': myPhoneNumber,
      'delayMinutes': FieldValue.delete(),
      'trafficExpiresAt': FieldValue.delete(),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            // ONLY update location fields. Do not overwrite 'status' here!
            if (selectedBusId != null) {
              FirebaseFirestore.instance
                  .collection('buses')
                  .doc(selectedBusId)
                  .update({
                    'latitude': position.latitude,
                    'longitude': position.longitude,
                    'lastUpdated': FieldValue.serverTimestamp(),
                  });
            }
          },
        );
  }

  void stopTracking() {
    _positionStream?.cancel();
    setState(() {
      isTripActive = false;
      statusMessage = "Shift Ended";
    });
    if (selectedBusId != null) {
      FirebaseFirestore.instance.collection('buses').doc(selectedBusId).update({
        'status': 'Stopped',
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }

  void goBackToSetup() {
    if (isTripActive) stopTracking();
    setState(() => viewState = "setup");
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: kTextColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        final now = DateTime.now();
        if (_lastPressedAt == null ||
            now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Press back again to exit'),
              backgroundColor: kTextColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: kMainColor, // #FFFDF6 Off-White
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: viewState == "setup"
                ? _buildSetupScreen()
                : _buildDashboardScreen(),
          ),
        ),
      ),
    );
  }

  // 1. SETUP SCREEN UI
  Widget _buildSetupScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader("Trip Manifest", "Set up your route details"),
          const SizedBox(height: 30),

          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kWarmAccent, // #E2D4E0 Light Accent
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: kTextColor.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SELECT BUS",
                    style: TextStyle(
                      color: kGreyAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildBusSelector(),

                  const SizedBox(height: 30),

                  const Text(
                    "SELECT ROUTE",
                    style: TextStyle(
                      color: kGreyAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildRouteSelector(),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed:
                          (selectedBusId != null && selectedRoute != null)
                          ? () => setState(() => viewState = "dashboard")
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTextColor, // #4C5372 Primary Dark
                        foregroundColor: kMainColor, // #FFFDF6 Off-White
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        "CONFIRM & CONTINUE",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: _handleDriverLogout,
              icon: const Icon(Icons.logout, color: kAccentRed),
              label: const Text("Logout", style: TextStyle(color: kAccentRed)),
            ),
          ),
        ],
      ),
    );
  }

  // 2. DASHBOARD SCREEN UI
  Widget _buildDashboardScreen() {
    return Column(
      children: [
        // Top Info Card
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          decoration: const BoxDecoration(
            color: kWarmAccent, // #E2D4E0 Light Accent
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedBusName ?? "Bus ??",
                        style: const TextStyle(
                          color: kTextColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        selectedRoute?.split(':')[0] ?? "Route",
                        style: const TextStyle(
                          color: kGreyAccent,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: goBackToSetup,
                    icon: const Icon(Icons.settings, color: kTextColor),
                    tooltip: "Settings",
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: kAccent, // #949AB1 Accent
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: isTripActive
                          ? (isBreakMode ? kAccentOrange : kAccentGreen)
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusMessage.toUpperCase(),
                      style: const TextStyle(
                        color: kMainColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // THE BIG BUTTON - Flat and clean
              GestureDetector(
                onTap: toggleTrip,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isTripActive
                        ? kTextColor
                        : kWarmAccent, // Primary Dark when active, Light Accent when inactive
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isTripActive
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          size: 60,
                          color: isTripActive
                              ? kMainColor
                              : kTextColor, // Off-White when active, Primary Dark when inactive
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isTripActive ? "END TRIP" : "START",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isTripActive ? kMainColor : kTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom Action Bar
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.coffee_rounded,
                label: "BREAK",
                isActive: false,
                onTap: openBreakDialog,
              ),
              _buildActionButton(
                icon: Icons.traffic_rounded,
                label: "TRAFFIC",
                isActive: false,
                onTap: reportTraffic,
              ),
              _buildActionButton(
                icon: Icons.sos_rounded,
                label: "SOS",
                isActive: false,
                isDanger: true,
                onTap: triggerSOS,
              ),
              _buildActionButton(
                icon: Icons.check_circle_outline_rounded,
                label: "RESUME",
                isActive: false,
                onTap: clearStatus,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: kTextColor,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 16, color: kGreyAccent),
        ),
      ],
    );
  }

  Widget _buildBusSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('buses').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const LinearProgressIndicator(color: kTextColor);
        if (snapshot.hasError) {
          print('Firestore Error (driver_dashboard.dart): ${snapshot.error}');
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
              style: const TextStyle(color: kAccentRed),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print('Warning: No buses found in driver dashboard');
          return const Center(child: Text("No buses available"));
        }

        List<DropdownMenuItem<String>> items = snapshot.data!.docs.map((doc) {
          return DropdownMenuItem(
            value: doc.id,
            child: Text(
              doc['busNumber'] ?? 'Unknown Bus',
              style: const TextStyle(
                color: kTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: kWhite, // Pure white background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGreyAccent.withOpacity(0.3), width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text("Select Vehicle"),
              value: selectedBusId,
              icon: const Icon(Icons.keyboard_arrow_down, color: kTextColor),
              items: items,
              onChanged: (val) {
                var selectedDoc = snapshot.data!.docs.firstWhere(
                  (doc) => doc.id == val,
                );
                setState(() {
                  selectedBusId = val;
                  selectedBusName = selectedDoc['busNumber'];
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildRouteSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: kWhite, // Pure white background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGreyAccent.withOpacity(0.3), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: const Text("Select Route"),
          value: selectedRoute,
          icon: const Icon(Icons.keyboard_arrow_down, color: kTextColor),
          items: routes
              .map(
                (r) => DropdownMenuItem(
                  value: r,
                  child: Text(
                    r,
                    style: const TextStyle(
                      color: kTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => selectedRoute = val),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    bool isDanger = false,
  }) {
    Color baseColor = isDanger ? kAccentRed : kTextColor;
    Color bgColor = isActive ? baseColor : kWarmAccent;
    Color iconColor = isActive ? kMainColor : baseColor;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: baseColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
