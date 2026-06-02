# Cine Stream 🎬

Cine Stream is a premium, open-source movie and TV show streaming application built with Flutter, specifically optimized for **Android TV** (D-pad/Remote navigation) with a sleek, cinematic user interface.

## ✨ Key Features

- **📺 Android TV Optimized**: Full D-pad and remote control support for seamless living room navigation.
- **🎨 Cinematic UI/UX**: Dark mode by default with vibrant neon-red accents, edge-to-edge gradients, and fluid micro-animations.
- **🔍 Advanced Search & Filtering**: Dynamic, space-saving search layout that auto-hides filters to maximize screen real estate when scrolling through movie grids.
- **♾️ Infinite Scrolling**: Effortlessly browse through vast libraries of content without ever hitting a manual "Next Page" button.
- **📝 Dual Subtitles (Dual Sub)**: Integrated support for dual subtitles (e.g., English + Vietnamese) directly on the video player for the ultimate language learning and viewing experience.
- **🎥 Custom Video Player**: Built-in media player with custom TV controls, subtitle toggles, and smooth seeking.

## 🚀 Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (Dart)
- **State Management**: flutter_bloc (Cubit)
- **Networking**: Dio
- **Video Player**: media_kit
- **Image Caching**: cached_network_image
- **Architecture**: Clean Architecture (Domain / Data / Presentation layers)
- **Data Source**: Custom API integrations (KissKh)

## 🛠️ Getting Started

### Prerequisites
- Flutter SDK (v3.11.5+)
- Android Studio / VS Code
- An Android TV Emulator (e.g., AndroidTV x64) or a physical Android TV device.

### Installation

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd cine_stream
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app (on TV Emulator):**
   ```bash
   flutter emulators --launch AndroidTV_x64
   flutter run
   ```

## 🎮 Navigation Guide (TV)
- Use **Up/Down/Left/Right (D-pad)** to navigate through movie cards and UI elements.
- Press **Select (OK/Enter)** to open a movie, play a video, or toggle a filter.
- Use the **Back** button to close the virtual keyboard or exit a screen.

## 📝 License
This project is for educational and personal use. 
