# Auch: Autonomous Android Agent (MVP)

Auch is a functional MVP of an on-device autonomous agent for Android. It uses a local Vision-Language Model (VLM) to perceive the screen, understand user goals, and perform actions like tapping and scrolling.

## 🚀 Features

*   **Autonomous Operation:** "See" the screen, "Think" about the next step, and "Act" by simulating gestures.
*   **On-Device Intelligence:** Powered by the [Cactus](https://github.com/cactus-compute/cactus-flutter) Flutter package and the `LFM2-VL-1.6B` model. No cloud APIs required.
*   **Accessibility Integration:** Leverages Android's `AccessibilityService` for precise UI tree retrieval and gesture injection.
*   **Privacy-First:** All processing happens locally on the device.

## 🛠 Prerequisites

* **Flutter SDK:** 3.38.x (current build used 3.38.3).
* **Android SDK:** Target/compile SDK from Flutter toolchain (currently 34/35 are pulled automatically). Min SDK 30.
* **Android Device/Emulator:** AccessibilityService capable; screenshot capture path requires Android 13+ (API 33+) because we rely on `takeScreenshot`.
* **Model File:** `LFM2-VL-1.6B.gguf` (must be obtained separately).

## 📥 Setup & Installation

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/minitap-ai/auch.git
    cd auch
    ```

2.  **Add the Model:**
    *   Download the `LFM2-VL-1.6B.gguf` model.
    *   Place it in the `assets/models/` directory:
        ```
        assets/models/LFM2-VL-1.6B.gguf
        ```

3.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```

4.  **Place the model on-device (required):**
    * Put `LFM2-VL-1.6B.gguf` in one of:
      * `/storage/emulated/0/Download/` (easiest: `adb push LFM2-VL-1.6B.gguf /sdcard/Download/`)
      * Or directly into the app docs dir after first run: `/storage/emulated/0/Android/data/com.auch.app/files/`
    * On first launch the app will copy from these locations into its internal storage.

5.  **Build/Install:**
    * Debug build:
      ```bash
      flutter build apk --debug
      adb install -r build/app/outputs/flutter-apk/app-debug.apk
      ```
    * Or run directly to a connected device/emulator:
      ```bash
      flutter run
      ```

## 📱 Usage

1.  **Enable Accessibility Service:**
    *   Go to Android Settings -> Accessibility.
    *   Find **"Auch Agent"**.
    *   Toggle it **ON** and allow full control.
2.  **Start the Agent:**
    *   Open the Auch app.
    *   Enter a goal (e.g., "Open Settings and find WiFi").
    *   Tap **Start Agent**.
3.  **Observation:** The app logs its thought process ("Analysis" and "Plan") as it navigates. Screenshots are saved to the app cache while running.

## ⚠️ Important Notes

*   **Experimental:** This is an MVP. It may not handle all edge cases or complex UI hierarchies perfectly.
*   **Performance:** Inference speed depends on the device's NPU/GPU/CPU capabilities.
*   **Model Size:** The `LFM2-VL-1.6B` model is large (~2GB+). Ensure your device has enough storage and RAM.
*   **Screenshots:** Current implementation requires Android 13+; older devices will need an alternative capture path (not implemented).

## 🤝 Contributing

Contributions are welcome! Please read `ARCHITECTURE.md` to understand the system design before making changes.
