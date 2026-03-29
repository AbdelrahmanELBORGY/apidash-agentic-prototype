# API Dash Agentic API Testing with MCP app Prototype (GSoC 2026)

This repository contains a functional Model Context Protocol (MCP) implementation within a native Flutter desktop environment. It serves as the primary technical validation for my GSoC 2026 proposal, demonstrating how AI agents can autonomously generate, execute, and self-heal API test suites.

## Visual sneak

<img width="1500" height="750" alt="image" src="https://github.com/user-attachments/assets/1f84edcc-7d6f-4841-8821-1fff15ef3861" />

## Challenges
Sandard AI integrations in developer tools are often restricted to "chatboxes" that lack deep integration with the host application's UI and native capabilities. This project solves two major hurdles:

1. Dynamic UI in AOT: Bypassing Flutter's AOT compilation limits to allow an LLM to "invent" and render interactive dashboards on the fly.

2. Native Execution: Allowing a sandboxed AI-generated interface to trigger high-performance, native Dart HTTP requests that bypass browser CORS restrictions.
Gemini said
To make your prototype repository stand out to the API Dash mentors, your README needs to transition from "simple code dump" to "professional engineering research." It should highlight that you didn't just write a script—you designed a system architecture.

## Key Features
1. Agentic Reasoning Engine
The system uses Gemini 2.5 Flash (API key included just for the prototype) to ingest API goals and generate structured JSON test strategies. It doesn't just suggest code; it designs functional, edge-case, and security-focused test plans.

2. OS-Aware MCP Sandbox
To ensure production-grade stability on Windows Native Desktop, the prototype implements a WebView Adapter Pattern. It utilizes webview_windows (Microsoft Edge WebView2) to provide a secure, high-performance sandbox for AI-generated "MCP Apps".

3. Autonomous Self-Healing with Visual Diffs
When a test fails (e.g., a 403 Forbidden error), the agent captures the native stack trace and response body. It then:

- Analyzes the failure root cause.

- Generates a fix (e.g., adding a missing Authorization header).

- Visualizes the change using a side-by-side Red/Green Diff UI, allowing users to approve the "healed" test case before re-execution.

4. Real-Time Metrics Dashboard
The UI features a dynamic metrics bar that tracks Passed, Failed, and Total tests. These values are synchronized in real-time between the native Dart execution layer and the Javascript-driven dashboard via a JSON-RPC bridge.

## Technical Architecture
The system operates on a three-tier architecture:

**The Host (Dart)**: Handles LLM orchestration, native HTTP networking, and state management.

**The Bridge (JSON-RPC)**: Facilitates secure asynchronous communication (tools/call, tools/heal) between native code and the sandbox.

**The Sandbox (HTML/JS)**: Renders the AI's "thoughts" into an interactive, reactive dashboard.

## Tech Stack
- **Flutter & Dart**
- **Google Generative AI (Gemini 2.5 Flash)**
- **webview_windows** (Microsoft Edge WebView2)
- **Model Context Protocol (MCP)** principles

## Getting Started
**Prerequisites**
1. Flutter SDK (Stable Channel)

2. Visual Studio 2022 (with "Desktop development with C++" workload)

3. A Gemini API Key (in case not included)

## Installation
1. Clone the repository:

- Bash
- git clone https://github.com/AbdelrahmanELBORGY/apidash-agentic-prototype.git
- cd apidash-agentic-prototype

2. Install dependencies:

- Bash
- flutter pub get
- Configure your API Key:
Open lib/main.dart and replace API_KEY with your actual Gemini key.

3. Run for Windows:

- Bash
- flutter run -d windows

### Option B: Run the External Plugin (Claude Desktop Integration)

This prototype includes `native_mcpServer_prototype.dart`, a headless MCP server that exposes API testing capabilities directly to Claude Desktop.

**Prerequisites:**
* Dart SDK installed globally on your machine.
* Claude Desktop App installed.

**Step 1: Locate the Dart file**
Find the absolute path to the `native_mcpServer_prototype.dart` file on your machine (e.g., `C:\Users\Name\apidash-agentic-prototype\native_mcpServer_prototype.dart` or `/Users/Name/apidash-agentic-prototype/native_mcpServer_prototype.dart`).

**Step 2: Update Claude Desktop Configuration**
You can easily open the configuration file directly from the Claude Desktop app:
1. Open Claude Desktop.
2. Go to **Settings** (click your profile name in the bottom left).
3. Click on the **Developer** tab in the left sidebar.
4. Click the **Edit Config** button. This will automatically open the `claude_desktop_config.json` file in your default text editor.
   
<img width="2127" height="1514" alt="image" src="https://github.com/user-attachments/assets/5cbc7bea-5a92-4e3f-8c8f-33c481f995bd" />

Add the Dart MCP server to the configuration (replace the path with your absolute path):

```json
{
  "mcpServers": {
    "apidash-agentic-engine": {
      "command": "dart",
      "args": [
        "run",
        "YOUR_ABSOLUTE_PATH_HERE/native_mcpServer_prototype.dart"
      ]
    }
  }
}
```

**Step 3: Restart Claude Desktop**
Completely quit and restart Claude Desktop. 

**Step 4: Run the Agentic Workflow**
1. Click the **+** (plus) icon next to the chat input bar in Claude Desktop.
2. Navigate to **Connectors** > **Add from [your_server_name]** (e.g., `apidash-agentic-engine` or `api_dash_native`).
3. Select the **Run agentic tests** prompt.
4. Paste a public OpenAPI specification URL into the argument box (e.g., the Swagger Petstore: `https://raw.githubusercontent.com/OAI/OpenAPI-Specification/main/examples/v3.0/petstore.json`) and press Enter.
<img width="2124" height="1525" alt="image" src="https://github.com/user-attachments/assets/cde22339-a495-460c-ac4a-1c82792a1d15" />


Watch as Claude autonomously reads the spec, generates accurate mock data, and executes native HTTP tests bypassing all CORS restrictions!


## GSoC 2026 Proposal
This prototype is part of a comprehensive proposal for API Dash.
