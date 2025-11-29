# Flutter Source Code

This directory contains the Dart code that powers the "Brain" and UI of the Auch agent.

## Structure

*   **`main.dart`**: The entry point of the application. Contains the main UI widget, the Agent Loop logic, and the `MethodChannel` invocation code.
*   **`agent/`**: Contains logic specific to the agent's cognition and prompting.
*   **`services/`**: Contains infrastructure services for model management and LLM inference.
