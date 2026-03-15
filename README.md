Markdown
# 🚌 Smart-Yatra: Real-Time College Transit System

Smart-Yatra is a dual-app, real-time bus tracking ecosystem built with Flutter and Firebase. Designed specifically for college transit, it features strict route-based privacy, live GPS telemetry, and dynamic ETA calculations that react instantly to real-world driver conditions.



## ✨ Core Features

### 🎓 Passenger App (Student Dashboard)
* **Secure Route Privacy:** Implements a strict "Lock-and-Key" Firestore architecture. Students can only track the specific bus assigned to them by the college administration.
* **Live GPS Tracking:** Integrates `flutter_map` and the `geolocator` package to display the assigned bus moving in real-time.
* **Dynamic Physics & ETA Engine:** Calculates arrival times on the fly by computing the physical distance between the student and the bus, assuming standard city velocities.
* **Smart IoT Dashboards:** UI dynamically adapts to driver conditions. Automatically adds mathematically precise time penalties to the ETA if the driver reports "Traffic" or "On Break", and flashes high-visibility alerts for "SOS".

### 🚦 Driver App (Driver Dashboard)
* **Background Telemetry:** Broadcasts live latitude/longitude coordinates directly to Cloud Firestore.
* **IoT Status Broadcaster:** Drivers can push complex state changes (Traffic, On Break, SOS) to the cloud without interrupting the background GPS thread.
* **Clean State Management:** Automatically purges expired traffic delays and resets routing statuses using Firebase's `FieldValue.delete()` to keep the database optimized.

---

## 🏗️ System Architecture

Smart-Yatra uses a centralized cloud database to mediate between the dual mobile interfaces:

1. **Authentication Gate:** A unified login system automatically routes users to either the Driver Dashboard or Student Dashboard based on their Firebase Auth claims.
2. **The Data Pipeline:** The Driver app pushes `geolocator` data and active status updates to the `buses` Firestore collection. 
3. **The Privacy Filter:** The Student app reads their `assignedRoute` from the `users` collection, and uses a strict `.where()` query to only pull the live stream of their assigned vehicle.

---

## 🛠️ Tech Stack

* **Frontend:** Flutter & Dart
* **Backend:** Firebase Authentication, Cloud Firestore
* **Hardware Integration:** `geolocator` (GPS)
* **Mapping:** `flutter_map`

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (Version 3.10+)
* A Firebase Project with Authentication and Firestore enabled.

### Installation

**1. Clone the repository**
```bash
git clone [https://github.com/YourUsername/Smart-Yatra.git](https://github.com/YourUsername/Smart-Yatra.git)
```

2. Install dependencies
```Bash
flutter pub get
```

3. Configure Firebase

Add your google-services.json file to android/app/.

Add your GoogleService-Info.plist file to ios/Runner/.

(Note: These files are ignored via .gitignore for security).

4. Run the application

```Bash
flutter run
```
👥 Contributors
Abi Kurian Varghese 

Archana Binu * Athul Krishnan K * Anand Krishna KJ Project Guide: Mrs. Lisha Kurian (Asst. Prof. CSE Dept, SNGCE)

***