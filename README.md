# KUMA - Dark Asylum 🏚️👻

A **3D Horror Found-Footage** game built with Flutter and Dart. Experience the terror of a dark abandoned asylum through a first-person perspective with raycasting 3D rendering.

## 🎮 About

**KUMA** is a first-person horror game where you wake up in an abandoned psychiatric hospital. Your mission: find keys, unlock doors, and escape before the darkness consumes you.

### Features

- 🏗️ **Raycasting 3D Engine** - Custom-built Wolfenstein/Doom-style raycasting renderer
- 🔦 **Flashlight System** - Battery-powered flashlight with drain mechanics
- 📹 **Found-Footage Camera UI** - REC indicator, battery display, vignette & noise overlay
- 🎯 **First-Person Controls** - Virtual joystick + touch look for mobile
- 🚪 **Interaction System** - Open doors, collect keys, read notes
- 🗺️ **Asylum Map** - Dark corridors, bloody walls, and hidden rooms
- 👻 **Horror Events** - Jumpscare system, ambient horror, dynamic lighting
- 🔊 **Audio System** - Ambient sounds, footsteps, jumpscare audio
- 📝 **Story Notes** - Discover the asylum's dark secrets

## 🎯 How to Play

1. **Move**: Use the left joystick to walk and strafe
2. **Look**: Swipe the right side of the screen to rotate
3. **Flashlight**: Tap the flashlight button (top-right) to toggle
4. **Interact**: Tap the **E** button when near doors, items, or notes
5. **Run**: Hold the run button (uses stamina)
6. **Objective**: Find keys → Unlock doors → Reach the exit

## 🗺️ Map Legend

| Wall Type | Color | Description |
|-----------|-------|-------------|
| 1 | Dark Gray | Concrete Wall |
| 2 | Dark Red | Bloody Wall |
| 3 | Brown | Rusty Metal |
| 4 | Red Frame | Door Frame |
| 5 | Cracked | Damaged Wall |
| 6 | Exit | Escape Door |

## 🛠️ Tech Stack

- **Framework**: Flutter 3.x
- **Language**: Dart 3.x
- **Rendering**: Custom Raycasting Engine (Canvas/CustomPainter)
- **Architecture**: Provider State Management
- **Audio**: audioplayers package

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point
├── core/
│   ├── raycast_engine.dart      # 3D raycasting renderer
│   ├── game_map.dart            # Level/map data & objects
│   ├── player.dart              # Player state & movement
│   ├── flashlight.dart          # Flashlight & battery system
│   ├── game_state.dart          # Central game state manager
│   └── audio_manager.dart       # Audio system
├── widgets/
│   ├── raycast_renderer.dart    # 3D view CustomPainter
│   ├── camera_overlay.dart      # Found-footage UI overlay
│   ├── joystick_widget.dart     # Virtual joystick
│   ├── flashlight_button.dart   # Flashlight toggle
│   ├── interaction_prompt.dart  # "Open/Pick up/Read" prompts
│   ├── game_hud.dart            # Score, stamina, inventory
│   ├── message_overlay.dart     # Game messages
│   └── note_overlay.dart        # Note reading view
└── screens/
    ├── main_menu_screen.dart    # Title screen
    └── game_screen.dart         # Main gameplay screen
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.0+
- Dart SDK 3.0+

### Installation

```bash
# Clone the repository
git clone https://github.com/ttg92195-cmyk/kuma.git

# Navigate to project
cd kuma

# Get dependencies
flutter pub get

# Run on device/emulator
flutter run
```

### Build Release

```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release
```

## 🎨 Design Philosophy

- **Dark Mode**: Black and Vibrant Red color palette
- **Found-Footage Style**: Camera overlay with REC indicator, vignette, scanlines
- **Atmospheric Horror**: Dynamic lighting, flashlight dependency, ambient sounds
- **Mobile-First**: Touch controls optimized for mobile gameplay

## 📜 License

This project is open source and available under the [MIT License](LICENSE).

---

*KUMA - Where darkness is your only companion.*
