# Assets

This directory stores static assets required by the application.

## Models

**Directory:** `assets/models/`

You **must** place the `LFM2-VL-1.6B.gguf` model file in this directory.

*   The `ModelManager` in the Flutter code will copy this file to the device's internal storage on the first run so that the native inference engine can access it.
*   **Note:** This file is not included in the git repository due to its size (>2GB). You must download it separately.
