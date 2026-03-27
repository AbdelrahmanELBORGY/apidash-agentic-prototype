import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() {
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) async {
    try {
      final requestJson = jsonDecode(line);
      final id = requestJson['id'];
      final rpcMethod = requestJson['method'];

      // 1. HANDSHAKE (Now includes 'prompts' capability)
      if (rpcMethod == 'initialize') {
        stdout.writeln(jsonEncode({
          "jsonrpc": "2.0", "id": id,
          "result": {
            "protocolVersion": "2024-11-05",
            "capabilities": {
              "tools": {},
              "prompts": {}
            },
            "serverInfo": {"name": "apidash-agentic-engine", "version": "6.0.0"}
          }
        }));
      }

      // 2. EXPOSE PROMPTS
      else if (rpcMethod == 'prompts/list') {
        stdout.writeln(jsonEncode({
          "jsonrpc": "2.0", "id": id,
          "result": {
            "prompts": [{
              "name": "run_agentic_tests",
              "description": "Runs the full end-to-end autonomous API testing workflow.",
              "arguments": [
                {
                  "name": "api_spec_url",
                  "description": "The URL of the real OpenAPI JSON file to test.",
                  "required": true
                }
              ]
            }]
          }
        }));
      }

      // 3. RETURN THE PROMPT TEXT
      else if (rpcMethod == 'prompts/get' && requestJson['params']['name'] == 'run_agentic_tests') {
        final specUrl = requestJson['params']['arguments']['api_spec_url'];

        final promptText = """
You are the API Dash Autonomous Testing Agent. I want you to perform an end-to-end Agentic workflow.

Step 1: Understand. Use the `read_openapi_spec` tool to fetch and read the real API documentation from: $specUrl
Step 2: Generate & Execute. Autonomously design one GET test and one POST test based entirely on the spec you just read. Use the `execute_apidash_request` tool to run both tests natively. (Generate realistic JSON mock data based on the schema).
Step 3: Validate. Check the status_code returned from your native executions against the expected responses.
Step 4: Report. Print out a final Test Coverage Report showing what you tested, the data you generated, and if the endpoints passed.
""";

        stdout.writeln(jsonEncode({
          "jsonrpc": "2.0", "id": id,
          "result": {
            "description": "Agentic Testing Workflow",
            "messages": [
              {
                "role": "user",
                "content": {"type": "text", "text": promptText}
              }
            ]
          }
        }));
      }

      // 4. EXPOSE TOOLS (Upgraded read_openapi_spec to take a URL)
      else if (rpcMethod == 'tools/list') {
        stdout.writeln(jsonEncode({
          "jsonrpc": "2.0", "id": id,
          "result": {
            "tools": [
              {
                "name": "read_openapi_spec",
                "description": "Fetches a real OpenAPI JSON specification from a URL.",
                "inputSchema": {
                  "type": "object",
                  "properties": {"url": {"type": "string"}},
                  "required": ["url"]
                }
              },
              {
                "name": "execute_apidash_request",
                "description": "Executes a complete HTTP request.",
                "inputSchema": {
                  "type": "object",
                  "properties": {
                    "url": {"type": "string"},
                    "method": {"type": "string"},
                    "headers": {"type": "object", "additionalProperties": {"type": "string"}},
                    "body": {"type": "string"}
                  },
                  "required": ["url", "method"]
                }
              }
            ]
          }
        }));
      }

      // 5. EXECUTE TOOLS
      else if (rpcMethod == 'tools/call' && requestJson['params']['name'] == 'read_openapi_spec') {
        final url = requestJson['params']['arguments']['url'];
        try {
          final response = await http.get(Uri.parse(url));
          stdout.writeln(jsonEncode({
            "jsonrpc": "2.0", "id": id,
            "result": {"content": [{"type": "text", "text": response.body}]}
          }));
        } catch (e) {
          stdout.writeln(jsonEncode({
            "jsonrpc": "2.0", "id": id,
            "result": {"content": [{"type": "text", "text": "Error fetching spec: $e"}]}
          }));
        }
      }
      else if (rpcMethod == 'tools/call' && requestJson['params']['name'] == 'execute_apidash_request') {
        // [Same execution code as the previous step goes here]
        final args = requestJson['params']['arguments'];
        final urlString = args['url'];
        final httpMethod = args['method'].toString().toUpperCase();
        final headers = args['headers'] != null ? Map<String, String>.from(args['headers']) : <String, String>{};
        final body = args['body'];

        var uri = Uri.parse(urlString);
        var httpRequest = http.Request(httpMethod, uri);
        httpRequest.headers.addAll(headers);
        if (body != null) httpRequest.body = body;

        try {
          var streamedResponse = await httpRequest.send();
          var response = await http.Response.fromStream(streamedResponse);
          final resultReport = {"status_code": response.statusCode, "response_body": response.body};
          stdout.writeln(jsonEncode({
            "jsonrpc": "2.0", "id": id,
            "result": {"content": [{"type": "text", "text": jsonEncode(resultReport)}]}
          }));
        } catch (e) {
          stdout.writeln(jsonEncode({
            "jsonrpc": "2.0", "id": id,
            "result": {"content": [{"type": "text", "text": "Error: $e"}]}
          }));
        }
      }
    } catch (e) {}
  });
}