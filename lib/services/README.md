# Services

This directory contains the services that interface with the local AI model and file system.

## Files

*   **`cactus_brain.dart`**:
    *   A wrapper around the `cactus` package.
    *   Initializes the `LFM2-VL-1.6B` model.
    *   Provides the `ask()` method, which sends the image, UI tree, and prompt to the model and returns a structured `AgentResponse`.
    *   Handles JSON parsing and error recovery from the LLM output.

*   **`model_manager.dart`**:
    *   Manages the lifecycle of the GGUF model file.
    *   `ensureModelExists()`: Checks if the model is present in the application's document directory (required for the native C++ inference engine to access it).
    *   Copies the model from `assets/` if it is not found in the filesystem.
