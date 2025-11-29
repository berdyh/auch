# Android Native Layer

This directory contains the Kotlin source code that interacts directly with the Android Operating System.

## Key Components

*   **`app/src/main/kotlin/com/auch/app/MobileAgentService.kt`**:
    *   **AccessibilityService**: The core component that runs in the background.
    *   **Capabilities**:
        *   `canRetrieveWindowContent`: To read the screen elements.
        *   `canPerformGestures`: To tap and swipe.
        *   `canTakeScreenshot`: To see the screen (API 30+).
    *   **Logic**:
        *   Captures screenshots to the app's cache directory.
        *   Traverses the view hierarchy to build a simplified JSON tree of clickable elements.
        *   Recycles system resources (`AccessibilityNodeInfo`, `HardwareBuffer`) to prevent leaks.

*   **`app/src/main/kotlin/com/auch/app/MainActivity.kt`**:
    *   **FlutterActivity**: The host for the Flutter UI.
    *   **MethodChannel**: Bridges calls from Dart (`captureState`, `performAction`) to the `MobileAgentService`.

*   **`app/src/main/AndroidManifest.xml`**:
    *   Declares the service and necessary permissions.

*   **`app/src/main/res/xml/accessibility_service_config.xml`**:
    *   Configures the accessibility service settings (feedback type, flags, etc.).
