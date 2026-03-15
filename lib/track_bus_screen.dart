import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BusDetailScreen extends StatelessWidget {
  final VoidCallback onBack;
  final String busId; 

  const BusDetailScreen({super.key, required this.onBack, required this.busId});

  // Helper to format Timestamp to "10:30 AM"
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown";
    DateTime date = timestamp.toDate();
    String hour = date.hour > 12 ? (date.hour - 12).toString() : date.hour.toString();
    String minute = date.minute.toString().padLeft(2, '0');
    String period = date.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('buses').doc(busId).snapshots(),
        builder: (context, snapshot) {
          
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var busData = snapshot.data!.data() as Map<String, dynamic>?;
          if (busData == null) return const Center(child: Text("Bus data not found"));

          // 1. GET DATA
          String busName = busData['busNumber'] ?? 'Unknown';
          String route = busData['route'] ?? 'Unknown Route';
          String status = busData['status'] ?? 'Stopped';
          int? delayMinutes = busData['delayMinutes'];
          Timestamp? trafficExpiresAt = busData['trafficExpiresAt'];

          if (status == 'Traffic' && trafficExpiresAt != null) {
            if (DateTime.now().isAfter(trafficExpiresAt.toDate())) {
              status = 'Driving';
            }
          }
          
          // 2. CHECK STATUS (Green vs Red vs Orange)
          bool isOnline = (status != 'Stopped');
          Color statusColor = Colors.green;
          String statusText = "Live Tracking";
          String statusSubtitle = "";

          if (status == 'Driving') {
            statusColor = Colors.green;
            statusText = "Live Tracking";
          } else if (status == 'On Break') {
            statusColor = Colors.orange;
            statusText = "Bus on Break";
            statusSubtitle = "Expected delay: ${delayMinutes ?? 0} mins";
          } else if (status == 'Traffic') {
            statusColor = Colors.orangeAccent;
            statusText = "Slight Delay due to Traffic";
          } else if (status == 'SOS') {
            statusColor = Colors.red;
            statusText = "EMERGENCY: SOS Signal Active";
          } else {
            statusColor = Colors.grey;
            statusText = "Tracking Stopped";
          }

          // 3. GET TIME
          String lastUpdatedTime = _formatTimestamp(busData['lastUpdated']);

          // 4. COORDINATES
          double lat = (busData['latitude'] is num) ? busData['latitude'].toDouble() : 9.9312;
          double lng = (busData['longitude'] is num) ? busData['longitude'].toDouble() : 76.2673;

          return Stack(
            children: [
              // --- MAP LAYER ---
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6, 
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(lat, lng),
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.smart_yatra_student',
                    ),
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState == ConnectionState.waiting) return const MarkerLayer(markers: []);

                        String? assignedRoute;
                        if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                          assignedRoute = userData?['assignedRoute'] as String?;
                        }

                        if (assignedRoute == null || assignedRoute.isEmpty) {
                          return const MarkerLayer(markers: []);
                        }

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('buses').where('route', isEqualTo: assignedRoute).snapshots(),
                          builder: (context, busSnapshot) {
                            if (!busSnapshot.hasData) return const MarkerLayer(markers: []);
                            
                            List<Marker> busMarkers = [];
                            for (var doc in busSnapshot.data!.docs) {
                              final data = doc.data() as Map<String, dynamic>?;
                              if (data == null) continue;

                              final bLat = data['latitude'];
                              final bLng = data['longitude'];
                              
                              if (bLat == null || bLng == null) continue;
                              
                              double latVal = (bLat is num) ? bLat.toDouble() : 0.0;
                              double lngVal = (bLng is num) ? bLng.toDouble() : 0.0;
                              if (latVal == 0.0 && lngVal == 0.0) continue;

                              final bStatus = data['status'] ?? 'Stopped';
                              Color mColor = Colors.grey;
                              if (bStatus == 'Driving') mColor = Colors.blue;
                              else if (bStatus == 'On Break' || bStatus == 'Traffic') mColor = Colors.orange;
                              else if (bStatus == 'SOS') mColor = Colors.red;

                              final bNum = data['busNumber'] ?? 'Unknown Bus';
                              final bRoute = data['route'] ?? '';

                              // Optional: highlight current selected bus (busId) differently
                              bool isCurrentBus = doc.id == busId;
                              if (isCurrentBus) mColor = statusColor;

                              busMarkers.add(
                                Marker(
                                  point: LatLng(latVal, lngVal),
                                  width: 80,
                                  height: 80,
                                  child: GestureDetector(
                                    onTap: () {
                                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('$bNum - $bRoute ($bStatus)'),
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    child: Icon(
                                      Icons.directions_bus,
                                      color: mColor,
                                      size: isCurrentBus ? 50 : 40, // Slightly bigger if it's the requested bus
                                    ),
                                  ),
                                ),
                              );
                            }

                            return MarkerLayer(markers: busMarkers);
                          },
                        );
                      }
                    ),
                  ],
                ),
              ),
              
              // --- TOP BAR ---
              Positioned(
                top: 50,
                left: 16,
                child: GestureDetector(
                  onTap: onBack,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                    child: const Icon(Icons.arrow_back, color: Colors.black),
                  ),
                ),
              ),
              
              // --- LIVE BADGE (Only if Driving) ---
              if (isOnline)
                Positioned(
                  top: 50,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 8),
                        SizedBox(width: 6),
                        Text("LIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ),

              // --- BOTTOM PANEL ---
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.45,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag Handle
                        Center(child: Container(width: 40, height: 6, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)))),
                        const SizedBox(height: 24),
                        
                        // Bus & Route Info
                        Text(busName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        Text(route, style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 20),

                        // STATUS CARD
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(isOnline ? Icons.gps_fixed : Icons.gps_off, color: statusColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(statusText, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: status == 'SOS' ? 16 : 14)),
                                    if (statusSubtitle.isNotEmpty)
                                      Text(statusSubtitle, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                                    // TIME DISPLAY
                                    Text("Last updated: $lastUpdatedTime", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                        
                        const Spacer(),
                        
                        // Helper Text
                        const Center(child: Text("Bus location updates automatically.", style: TextStyle(fontSize: 12, color: Colors.grey))),
                      ],
                    ),
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}