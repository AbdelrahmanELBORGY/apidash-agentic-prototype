import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() {
  runApp(const ApiDashAgentApp());
}

class ApiDashAgentApp extends StatelessWidget {
  const ApiDashAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'API Dash Agent Console',
      theme: ThemeData.light(useMaterial3: true), // Light theme based on your image
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _webviewController = WebviewController();
  final TextEditingController _promptController = TextEditingController();

  bool _isWebviewInitialized = false;
  bool _isAiThinking = false;
  String _lastGeneratedJson = "";

  final String _apiKey = 'INSERT API KEY HERE';
  late final GenerativeModel _model;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      await _webviewController.initialize();
      _webviewController.webMessage.listen((dynamic message) {
        _handleMcpMessage(message.toString());
      });

      // INITIAL EMPTY STATE JSON
      String initialJson = '''
      {
        "explanation": "Welcome to the Agentic Console. Type a goal in the prompt box below to generate your first test suite.",
        "tests": []
      }
      ''';

      await _renderMcpApp(initialJson, isHealed: false);
      setState(() => _isWebviewInitialized = true);
    } catch (e) {
      debugPrint("WebView init failed: $e");
    }
  }

  /// 1. THE AI GENERATION PHASE
  Future<void> _generateTestPlan(String userPrompt) async {
    // HANDLE EMPTY PROMPT
    if (userPrompt.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text("Please enter a testing goal before generating.", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: const Color(0xFFb000ff), // Matches your API Dash theme
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.only(bottom: 80, left: 20, right: 20),
        ),
      );
      return;
    }

    setState(() => _isAiThinking = true);

    try {
      final prompt = '''
      You are an API testing agent. The user wants to: "$userPrompt".
      Generate 4 API test cases covering different scenarios (e.g., success, missing auth, invalid data). 
      Return ONLY a raw JSON object, no markdown wrappers.
      Format: {"explanation": "Briefly explain strategy", "tests": [{"title": "Test Name", "expected": "200 OK"}]}
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      _lastGeneratedJson = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? '{}';

      await _renderMcpApp(_lastGeneratedJson, isHealed: false);
    } catch (e) {
      debugPrint("AI Error: $e");
    } finally {
      setState(() => _isAiThinking = false);
      _promptController.clear();
    }
  }

  /// 2. THE SELF-HEALING PHASE
  Future<void> _triggerSelfHealing(String failedTestsJson) async {
    setState(() => _isAiThinking = true);
    await _webviewController.executeScript("document.getElementById('status').innerText = 'Status: AI is analyzing the failures and self-healing...';");

    try {
      final prompt = '''
      You are an API testing agent. The following test plan was executed: 
      $failedTestsJson
      
      Test 2 failed with "403 Forbidden" (missing auth). Test 4 failed with "400 Bad Request" (missing required payload field).
      Fix ONLY the failed tests. 
      
      CRITICAL INSTRUCTIONS:
      1. Keep the titles and expected results of the passing tests (Test 1 and Test 3) EXACTLY the same.
      2. For the failed tests, change the "title" to explicitly include the fix (e.g., append "(Added Auth Header)" or "(Fixed Payload)").
      
      Return ONLY a raw JSON object, no markdown wrappers.
      Format: {"explanation": "Explain what you modified", "tests": [{"title": "Test Name", "expected": "200 OK"}]}
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final String healedJson = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? '{}';

      await _renderMcpApp(healedJson, isHealed: true, oldContent: _lastGeneratedJson);
      _lastGeneratedJson = healedJson;
    } catch (e) {
      debugPrint("Healing Error: $e");
    } finally {
      setState(() => _isAiThinking = false);
    }
  }

  /// 3. THE HTML/JS MCP APP TEMPLATE
  Future<void> _renderMcpApp(String content, {bool isHealed = false, String? oldContent}) async {
    String htmlList = "";
    String explanationBox = "";
    int totalTests = 0;

    if (content.startsWith('{')) {
      try {
        final Map<String, dynamic> data = jsonDecode(content);
        final List<dynamic> tests = data['tests'] ?? [];
        totalTests = tests.length;
        final String explanation = data['explanation'] ?? "";

        if (explanation.isNotEmpty) {
          final bgColor = isHealed ? "#e8f5e9" : "#f3e5f5";
          final borderColor = isHealed ? "#4CAF50" : "#b000ff";
          final boxTitle = isHealed ? "🛠️ What was modified:" : "💡 AI Test Strategy:";
          explanationBox = '<div style="background: $bgColor; border-left: 4px solid $borderColor; padding: 10px; margin-bottom: 15px; border-radius: 6px; font-size: 13px;"><strong>$boxTitle</strong> $explanation</div>';
        }

        if (!isHealed) {
          htmlList = tests.asMap().entries.map((entry) {
            return "<li id='test-${entry.key}' class='test-item default-test'><strong>${entry.value['title']}</strong><br/><span style='color:#666; font-size:12px;'>Expects: ${entry.value['expected']}</span><div id='msg-${entry.key}' style='margin-top:4px; font-size:12px;'></div></li>";
          }).join('');
        } else {
          List<dynamic> oldTests = [];
          if (oldContent != null) {
            try { oldTests = jsonDecode(oldContent)['tests'] ?? []; } catch (_) {}
          }

          htmlList = tests.asMap().entries.map((entry) {
            var t = entry.value;
            var oldT = (oldTests.length > entry.key) ? oldTests[entry.key] : null;
            String oldJsonStr = oldT != null ? jsonEncode(oldT) : "";
            String newJsonStr = jsonEncode(t);

            if (oldT != null && oldJsonStr != newJsonStr) {
              return '''
               <li id='test-${entry.key}' style='background: transparent; padding: 0; border: none; margin-bottom: 10px;'>
                 <div style='display: flex; flex-direction: column; gap: 4px;'>
                   <div style='background: #ffebee; border-left: 4px solid #f44336; padding: 8px 12px; border-radius: 6px; color: #c62828;'>
                     <span style='text-decoration: line-through; font-weight: bold; font-size: 13px;'>✗ Old: ${oldT['title']}</span>
                   </div>
                   <div style='background: #e8f5e9; border-left: 4px solid #4CAF50; padding: 8px 12px; border-radius: 6px; color: #2e7d32;'>
                     <span style='font-weight: bold; font-size: 13px;'>✓ New: ${t['title']}</span><br/>
                     <span style='font-size: 11px; opacity: 0.8;'>Expects: ${t['expected']}</span>
                   </div>
                 </div>
                 <div id='msg-${entry.key}' style='margin-top:4px; font-size:12px;'></div>
               </li>
               ''';
            } else {
              return '''
               <li id='test-${entry.key}' style='background: #f5f5f5; border-left: 4px solid #9e9e9e; padding: 10px 12px; border-radius: 6px; margin-bottom: 10px;'>
                 <strong style='color: #424242; font-size: 13px;'>${t['title']}</strong> <span style='color:#757575; font-size:11px;'>(Unchanged)</span><br/>
                 <span style='color:#666; font-size:12px;'>Expects: ${t['expected']}</span>
                 <div id='msg-${entry.key}' style='margin-top:4px; font-size:12px;'></div>
               </li>
               ''';
            }
          }).join('');
        }
      } catch (e) { debugPrint("JSON Parse Error: $e"); }
    }

    final String safeContentForJs = content.replaceAll("'", "\\'").replaceAll('\n', '\\n');

    final String html = '''
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        :root { color-scheme: light; }
        html, body { background-color: #F5F5F7; margin: 0; height: 100%; font-family: 'Segoe UI', sans-serif; padding: 10px; color: #333; }
        ::-webkit-scrollbar { width: 6px; height: 6px; }
        ::-webkit-scrollbar-track { background: #F5F5F7; }
        ::-webkit-scrollbar-thumb { background: #c1c1c1; border-radius: 4px; }
        
        .card { border: 1px solid #e0e0e0; padding: 20px; border-radius: 12px; background: white; box-shadow: 0 4px 12px rgba(0,0,0,0.04); }
        
        /* Compact Metrics Row */
        .dashboard-stats { display: flex; gap: 10px; margin-bottom: 15px; }
        .stat-box { flex: 1; padding: 10px; border-radius: 8px; background: #f8f9fa; text-align: center; border: 1px solid #eee; transition: 0.3s; }
        .stat-value { font-size: 20px; font-weight: bold; margin-bottom: 2px; }
        .stat-label { font-size: 11px; color: #666; text-transform: uppercase; letter-spacing: 0.5px; }
        
        button { padding: 8px 16px; cursor: pointer; border: none; border-radius: 6px; color: white; font-weight: bold; transition: 0.2s; font-size: 13px; box-shadow: 0 2px 6px rgba(0,0,0,0.1); }
        #runBtn { background: linear-gradient(135deg, #6b4ce6, #b000ff); } 
        #runBtn:hover { opacity: 0.9; transform: translateY(-1px); }
        #runBtn:disabled { background: #9e9e9e; box-shadow: none; transform: none; cursor: not-allowed; }
        #healBtn { background: linear-gradient(135deg, #ff9800, #ff5722); display: none; margin-left: 8px; } 
        #healBtn:hover { opacity: 0.9; transform: translateY(-1px); }
        
        ul { padding-left: 0; margin-bottom: 0; }
        .test-item { margin-bottom: 10px; padding: 10px 12px; border-radius: 6px; list-style-type: none; transition: all 0.3s ease; border: 1px solid #eee; }
        .default-test { background: white; border-left: 4px solid #b000ff; box-shadow: 0 1px 3px rgba(0,0,0,0.02); }
        
        /* Header Flexbox */
        .header-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; border-bottom: 1px solid #eee; padding-bottom: 15px; }
      </style>
    </head>
    <body>
      <div class="card">
        <!-- HEADER WITH BUTTONS AT THE TOP -->
        <div class="header-row">
          <div style="display: flex; align-items: center; gap: 10px;">
            <h2 style="margin:0; font-size: 18px;">Agentic API Testing DASHBOARD</h2>
            ${isHealed ? '<span style="background: #4CAF50; color: white; padding: 4px 8px; border-radius: 12px; font-size: 11px; font-weight:bold;">✨ AI Healed</span>' : ''}
          </div>
          <div style="display: flex; align-items: center;">
            <p id="status" style="color: #666; font-size: 12px; margin: 0 15px 0 0; font-style: italic;">Awaiting execution...</p>
            <button id="runBtn" onclick="runTests()">Run Tests</button>
            <button id="healBtn" onclick="triggerHeal()">✨ Auto-Fix</button>
          </div>
        </div>

        <div class="dashboard-stats">
          <div class="stat-box" id="box-total">
            <div class="stat-value" id="val-total">$totalTests</div>
            <div class="stat-label">Total Tests</div>
          </div>
          <div class="stat-box" id="box-passed">
            <div class="stat-value" id="val-passed" style="color: #ccc;">-</div>
            <div class="stat-label">Passed</div>
          </div>
          <div class="stat-box" id="box-failed">
            <div class="stat-value" id="val-failed" style="color: #ccc;">-</div>
            <div class="stat-label">Failed</div>
          </div>
        </div>

        $explanationBox
        <ul id="test-list">$htmlList</ul>
      </div>
      
      <script>
        window.onload = function() {
          if ($totalTests === 0) {
            const btn = document.getElementById('runBtn');
            btn.disabled = true;
            btn.style.background = '#e0e0e0';
            btn.style.color = '#9e9e9e';
            btn.style.cursor = 'not-allowed';
            btn.style.boxShadow = 'none';
            document.getElementById('status').innerText = 'Waiting for prompt...';
          }
        };

        function runTests() {
          document.getElementById('runBtn').innerText = 'Executing...';
          document.getElementById('status').innerText = 'Bridging to native...';
          document.getElementById('val-passed').innerText = '...';
          document.getElementById('val-failed').innerText = '...';
          
          const msg = JSON.stringify({ method: 'tools/call', params: { isHealed: $isHealed } });
          window.chrome.webview.postMessage(msg);
        }
        
        function triggerHeal() {
          document.getElementById('healBtn').innerText = 'Analyzing...';
          const msg = JSON.stringify({ method: 'tools/heal', params: { content: '$safeContentForJs' } });
          window.chrome.webview.postMessage(msg);
        }

        function receiveFromHost(msgStr) {
           const res = JSON.parse(msgStr);
           if (res.status === 'complete') {
             document.getElementById('status').innerText = 'Execution Finished.';
             document.getElementById('runBtn').innerText = 'Completed';
             document.getElementById('runBtn').disabled = true;
             
             let passedCount = 0;
             let failedCount = 0;
             
             res.results.forEach(r => {
                const li = document.getElementById('test-' + r.index);
                const msgBox = document.getElementById('msg-' + r.index);
                if (r.passed) {
                   passedCount++;
                   if(li.classList.contains('default-test')) {
                     li.style.borderLeft = '4px solid #4CAF50';
                     li.style.background = '#f1f8e9';
                   }
                   msgBox.innerHTML = '<span style="color: #2e7d32; font-weight: bold;">✓ Passed: ' + r.message + '</span>';
                } else {
                   failedCount++;
                   if(li.classList.contains('default-test')) {
                     li.style.borderLeft = '4px solid #f44336';
                     li.style.background = '#ffebee';
                   }
                   msgBox.innerHTML = '<span style="color: #c62828; font-weight: bold;">✗ Failed: ' + r.message + '</span>';
                }
             });
             
             document.getElementById('val-passed').innerText = passedCount;
             document.getElementById('val-passed').style.color = passedCount > 0 ? '#4CAF50' : '#ccc';
             document.getElementById('box-passed').style.borderColor = passedCount > 0 ? '#c8e6c9' : '#eee';
             
             document.getElementById('val-failed').innerText = failedCount;
             document.getElementById('val-failed').style.color = failedCount > 0 ? '#f44336' : '#ccc';
             document.getElementById('box-failed').style.borderColor = failedCount > 0 ? '#ffcdd2' : '#eee';
             document.getElementById('box-failed').style.background = failedCount > 0 ? '#fff5f5' : '#f8f9fa';

             if (failedCount > 0) {
               document.getElementById('healBtn').style.display = 'inline-block';
             }
           }
        }
      </script>
    </body>
    </html>
    ''';
    await _webviewController.loadStringContent(html);
  }

  /// 4. THE NATIVE EXECUTION INTERCEPTOR
  Future<void> _handleMcpMessage(String messageStr) async {
    final Map<String, dynamic> request = jsonDecode(messageStr);

    if (request['method'] == 'tools/call') {
      final bool isAlreadyHealed = request['params']['isHealed'];
      await Future.delayed(const Duration(seconds: 2)); // Simulate network request

      String granularResponse;

      if (!isAlreadyHealed) {
        // First Run: 2 Pass, 2 Fail
        granularResponse = jsonEncode({
          'status': 'complete',
          'results': [
            {'index': 0, 'passed': true, 'message': '200 OK'},
            {'index': 1, 'passed': false, 'message': '403 Forbidden. Missing Auth Token.'},
            {'index': 2, 'passed': true, 'message': '201 Created'},
            {'index': 3, 'passed': false, 'message': '400 Bad Request. Missing Payload.'}
          ]
        });
      } else {
        // Healed Run: All 4 Pass
        granularResponse = jsonEncode({
          'status': 'complete',
          'results': [
            {'index': 0, 'passed': true, 'message': '200 OK'},
            {'index': 1, 'passed': true, 'message': '200 OK (Auth Validated)'},
            {'index': 2, 'passed': true, 'message': '201 Created'},
            {'index': 3, 'passed': true, 'message': '200 OK (Payload Validated)'}
          ]
        });
      }

      final safeJson = granularResponse.replaceAll("'", "\\'");
      await _webviewController.executeScript("receiveFromHost('$safeJson')");
    }
    else if (request['method'] == 'tools/heal') {
      _triggerSelfHealing(request['params']['content']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Light gray background
      body: Row(
        children: [
          // SIDEBAR (Mockup)
          Container(
            width: 250,
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("API Dash", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                _navItem(Icons.dashboard, "Agent Dashboard", true),
                _navItem(Icons.history, "History", false),
                _navItem(Icons.settings, "Settings", false),
              ],
            ),
          ),

          // MAIN CONTENT AREA
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                children: [
                  const Text("Define, Align, Achieve. Precision testing powered by AI.",
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 20),

                  // THE WEBVIEW SANDBOX (Agent Console)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _isWebviewInitialized
                          ? Webview(_webviewController)
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // THE CHAT INPUT (Gradient Border Simulation)
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _promptController,
                              decoration: const InputDecoration(
                                hintText: "Type your API testing goal here (e.g., 'Test my checkout workflow')",
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                              ),
                              onSubmitted: _generateTestPlan,
                            ),
                          ),
                          if (_isAiThinking)
                            const Padding(padding: EdgeInsets.only(right: 20), child: CircularProgressIndicator())
                          else
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ElevatedButton.icon(
                                onPressed: () => _generateTestPlan(_promptController.text),
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text("Generate"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFf0f0ff),
                                  foregroundColor: const Color(0xFF6b4ce6),
                                  elevation: 0,
                                ),
                              ),
                            )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String title, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: isActive ? const Color(0xFF6b4ce6) : Colors.grey),
          const SizedBox(width: 15),
          Text(title, style: TextStyle(
              color: isActive ? const Color(0xFF6b4ce6) : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal
          )),
        ],
      ),
    );
  }
}