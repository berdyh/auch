# Auch: Autonomous Android Agent (MVP)

Auch is a functional MVP of an on-device autonomous agent for Android. It uses a local Vision-Language Model (VLM) to perceive the screen, understand user goals, and perform actions like tapping and scrolling.

## 🚀 Features

*   **Autonomous Operation:** "See" the screen, "Think" about the next step, and "Act" by simulating gestures.
*   **On-Device Intelligence:** Powered by the [Cactus](https://github.com/cactus-compute/cactus-flutter) Flutter package and the `LFM2-VL-1.6B` model. No cloud APIs required.
*   **Accessibility Integration:** Leverages Android's `AccessibilityService` for precise UI tree retrieval and gesture injection.
*   **Privacy-First:** All processing happens locally on the device.

## 🛠 Prerequisites

*   **Flutter SDK:** 3.13.0 or higher.
*   **Android SDK:** API Level 33 (Target), Min SDK 30.
*   **Android Device:** Must support `AccessibilityService`.
*   **Model File:** `LFM2-VL-1.6B.gguf` (must be obtained separately).

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

4.  **Run on Device:**
    ```bash
    flutter run
    ```

## 📱 Usage

1.  **Grant Permissions:** On the first run, the app will ask for necessary permissions.
2.  **Enable Accessibility Service:**
    *   Go to Android Settings -> Accessibility.
    *   Find "Auch" (or "Minitap Mobile Agent").
    *   Toggle it **ON**.
    *   Allow the service to have full control of the device.
3.  **Start the Agent:**
    *   Open the Auch app.
    *   Enter a goal (e.g., "Open Settings and find WiFi").
    *   Tap **Start Agent**.
4.  **Observation:** The app will overlay its thought process ("Analysis" and "Plan") as it navigates.

## ⚠️ Important Notes

*   **Experimental:** This is an MVP. It may not handle all edge cases or complex UI hierarchies perfectly.
*   **Performance:** Inference speed depends on the device's NPU/GPU/CPU capabilities.
*   **Model Size:** The `LFM2-VL-1.6B` model is large (~2GB+). Ensure your device has enough storage and RAM.

## 🤝 Contributing

Contributions are welcome! Please read `ARCHITECTURE.md` to understand the system design before making changes.
