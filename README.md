# 🏍️ MotoSquad: Real-Time Rider Convoy & Intercom Network

**MotoSquad** is built specifically for motorcycle and cycling groups to solve the #1 problem on road trips: **getting separated, missing turns, dealing with cellular dead-zones, and riding safety.**

---

## 🌟 Core Features Built & Configured

| Feature | Description |
| :--- | :--- |
| 🗺️ **Live Convoy Telemetry** | Real-time map displaying all squad riders with live speed (km/h), bearing heading, battery %, and role markers. |
| 🛡️ **Convoy Roles** | **Lead Rider** (Gold Star/Navigator), **Tail Sweeper** (Blue Shield who ensures nobody is left behind), **Scout**, and **Pack Riders**. |
| ⚠️ **Separation Detection** | Automatically computes convoy distance gap. If any rider falls > 500m behind the Leader, an instant HUD audio & visual alert flashes on the Leader's & Sweeper's screens. |
| 🎙️ **Push-to-Talk (PTT)** | Low-latency walkie-talkie intercom. Press & hold glove-friendly button (or handlebar Bluetooth button) to speak with radio beep sound cues. |
| 🚨 **Distress SOS Beacon** | One-tap emergency beacon with a 5-second accidental cancel countdown. Sounds siren across all squad phones, locks rider GPS, and provides quick navigation. |
| 📍 **Squad Waypoints** | Leader can drop Petrol Pumps, Regroup points, Lunch pitstops, or Road Hazards directly onto everyone's map simultaneously. |
| 📡 **Offline & Mesh Resilience** | Local SQLite/SharedPreferences store-and-forward buffer for when cell signal drops in valleys, plus BLE (Bluetooth Low Energy) proximity radar fallback. |

---

## 🚀 Instant Test Drive (Live Convoy Simulator)

The companion real-time server and multi-rider simulator is already running at:
👉 **[http://localhost:4040](http://localhost:4040)**

### What you can test right now in your browser:
1. Open [http://localhost:4040](http://localhost:4040) on your desktop or mobile browser.
2. Watch **Apex-1 (Lead)**, **Blaze**, **Tail-Shield (Sweeper)**, and **Phantom (Lagging)** moving dynamically in real time along a scenic Himalayan mountain route.
3. Observe the **Convoy Separation Alert** triggering when Phantom lags behind the group.
4. Click & Hold the **HOLD TO TALK** button to test the PTT radio audio cues and live transmitting broadcast.
5. Click **SOS** to trigger an emergency distress siren and pin the stranded bike on everyone's screen.
6. Click the Pin icon to drop a **Fuel Station** or **Regroup Point** for the entire squad.

---

## 📱 Running the Flutter Mobile App (Android & iOS)

### 1. Prerequisites (Flutter SDK)
If you don't already have Flutter installed on your Windows machine:
1. Download the Flutter SDK from: [flutter.dev/docs/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows)
2. Extract the zip to `C:\src\flutter` and add `C:\src\flutter\bin` to your System `PATH`.
3. Open a new terminal and run:
   ```bash
   flutter doctor
   ```

### 2. Run the App
From the `motosquad` directory:
```bash
cd C:\Users\anmol\.gemini\antigravity\scratch\motosquad
flutter pub get
flutter run
```

### 3. Connecting to the Convoy Server
- If testing on an **Android Emulator**: The app automatically defaults to `http://10.0.2.2:4040`.
- If testing on a **Physical Phone (Android/iPhone)**: Connect your phone to the same Wi-Fi network as your PC and enter your computer's local IP (e.g., `http://192.168.1.50:4040`) in the app setup screen.

---

## 📁 Codebase Structure

```
motosquad/
├── pubspec.yaml                      # Flutter dependencies (flutter_map, socket_io_client, geolocator, etc.)
├── lib/
│   ├── main.dart                     # App entry point & theme configuration
│   ├── models/
│   │   ├── rider.dart                # Rider entity (role, telemetry, battery, speed, lastSeen)
│   │   ├── ride_session.dart         # Convoy session data & threshold limits
│   │   ├── sos_alert.dart            # Emergency alert payload
│   │   └── waypoint.dart             # Waypoint pins (fuel, regroup, food, hazard)
│   ├── services/
│   │   ├── location_service.dart     # Continuous high-accuracy GPS tracking & distance calculations
│   │   ├── socket_ptt_service.dart   # Socket.io connection, PTT voice streaming, SOS signaling
│   │   ├── audio_alert_service.dart  # Radio chirps, roger beeps, and emergency sirens
│   │   └── offline_storage_service.dart # Buffer location pings when in cellular dead zones
│   ├── providers/
│   │   └── convoy_provider.dart      # Convoy state orchestrator & separation gap analysis
│   ├── widgets/
│   │   ├── ptt_button.dart           # Big glove-friendly Hold-to-Talk button with pulse animations
│   │   ├── rider_radar_card.dart     # Rider telemetry card with battery & distance
│   │   └── separation_banner.dart    # Convoy lag warning banner
│   └── screens/
│       ├── session_setup_screen.dart # Convoy join/create & role selector
│       ├── convoy_map_screen.dart    # Live OpenStreetMap HUD with squad markers
│       └── sos_dialog.dart           # Accidental-proof 5-second countdown SOS dialog
└── server/
    ├── package.json
    ├── server.js                     # Real-time WebSocket relay & convoy route simulator
    └── public/                       # Interactive browser simulator (HTML/CSS/JS)
```

---

## 🏍️ Hardware & Headset Integration Tips

1. **Helmet Intercoms (Sena / Cardo / FreedConn)**:
   The app uses standard Android/iOS telecom audio sessions. Pair your Bluetooth helmet headset; audio from PTT broadcasts routes directly into your helmet speakers, and the helmet mic is used for talking.
2. **Handlebar PTT Button**:
   Any generic Bluetooth BLE media button (like a camera shutter button or motorcycle handlebar remote) can trigger the `ConvoyProvider.startTransmitting()` and `ConvoyProvider.stopTransmitting()` methods via key event listener (`KeyDownEvent` / `KeyUpEvent`).
