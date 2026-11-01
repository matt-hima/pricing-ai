import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

void main() {
  runApp(const AIBrowserProxyApp());
}

class AIBrowserProxyApp extends StatelessWidget {
  const AIBrowserProxyApp({Key? key}) : constructor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Browsing Assistant Proxy',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  HttpServer? _server;
  bool _isProxyRunning = false;
  int _port = 8080;
  final List<String> _logs = [];
  String _currentAiAnalysis = 'No page analyzed yet. Start browsing to see local AI insights!';
  bool _isAiThinking = false;

  void _toggleProxy() async {
    if (_isProxyRunning) {
      await _server?.close(force: true);
      setState(() {
        _isProxyRunning = false;
        _addLog('Proxy server stopped.');
      });
    } else {
      try {
        _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
        setState(() {
          _isProxyRunning = true;
          _addLog('Proxy server running locally on port $_port');
        });
        _listenToTraffic();
      } catch (e) {
        _addLog('Error starting proxy: $e');
      }
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, '[${DateTime.now().toString().substring(11, 19)}] $message');
    });
  }

  void _listenToTraffic() async {
    if (_server == null) return;
    await for (HttpRequest request in _server!) {
      _addLog('Intercepted request: ${request.method} -> ${request.uri}');
      
      // Simple pass-through boilerplate concept.
      // Real HTTPS requires custom Root CA generation & MitM handling.
      try {
        var client = HttpClient();
        var upstreamRequest = await client.openUrl(request.method, request.uri);
        
        // Copy request headers
        request.headers.forEach((name, values) {
          for (var value in values) {
            upstreamRequest.headers.add(name, value);
          }
        });
        
        // Pipe request body
        await upstreamRequest.addStream(request);
        var upstreamResponse = await upstreamRequest.close();
        
        // Copy response status and headers
        request.response.statusCode = upstreamResponse.statusCode;
        upstreamResponse.headers.forEach((name, values) {
          for (var value in values) {
            request.response.headers.add(name, value);
          }
        });

        // Intercept Text / HTML contents for Local AI processing
        if (upstreamResponse.headers.contentType?.mimeType == 'text/html' || 
            upstreamResponse.headers.contentType?.mimeType == 'text/plain') {
          
          List<int> bodyBytes = await upstreamResponse.expand((bytes) => bytes).toList();
          String contentText = utf8.decode(bodyBytes, allowMalformed: true);
          
          _analyzeWithLocalAi(contentText, request.uri.toString());
          
          request.response.add(bodyBytes);
        } else {
          await request.response.addStream(upstreamResponse);
        }
      } catch (e) {
        _addLog('Proxy Error handling request: $e');
      } finally {
        await request.response.close();
      }
    }
  }

  Future<void> _analyzeWithLocalAi(String pageText, String url) async {
    setState(() {
      _isAiThinking = true;
      _currentAiAnalysis = 'Local AI is analyzing content from: $url...';
    });
    
    // Clean up text roughly to avoid sending huge HTML boilerplate markup
    String cleanText = pageText.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
    if (cleanText.length > 2000) cleanText = cleanText.substring(0, 2000);

    try {
      // Connect to locally running Ollama instance
      final response = await http.post(
        Uri.parse('http://localhost:11434/api/generate'),
        body: jsonEncode({
          'model': 'llama3', // Default local model name
          'prompt': 'Analyze this extracted webpage content and provide a 3-bullet summary with primary takeaways:\n\n$cleanText',
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          _currentAiAnalysis = data['response'] ?? 'Empty response from local model.';
        });
        _addLog('Successfully analyzed content for $url');
      } else {
        setState(() {
          _currentAiAnalysis = 'Ollama error (Status ${response.statusCode}). Ensure Ollama is running locally.';
        });
      }
    } catch (e) {
      setState(() {
        _currentAiAnalysis = 'Could not connect to Ollama. Make sure "ollama run llama3" or your alternative engine is active on localhost:11434.\n\nError Details: $e';
      });
    } finally {
      setState(() {
        _isAiThinking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local AI Browsing Proxy Dashboard'),
        backgroundColor: Colors.deepPurple.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Panel: Control and Live Stream Logs
            Expanded(
              flex: 1,
              child: Card(
                color: const Color(0xFF1E1E1E),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Proxy Settings', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(labelText: 'Local Port', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              controller: TextEditingController(text: _port.toString()),
                              onChanged: (val) => _port = int.tryParse(val) ?? 8080,
                              enabled: !_isProxyRunning,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _toggleProxy,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isProxyRunning ? Colors.red : Colors.green,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                            child: Text(_isProxyRunning ? 'STOP PROXY' : 'START PROXY'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('Live HTTP Interception Logs', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            itemCount: _logs.length,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text(
                                _logs[index],
                                style: const TextStyle(fontFamily: 'Courier', color: Colors.greenAccent, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Right Panel: Local AI Agent Assistant Outputs
            Expanded(
              flex: 1,
              child: Card(
                color: const Color(0xFF1E1E1E),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.between,
                        children: [
                          Text('Local AI Analysis Engine', style: Theme.of(context).textTheme.titleLarge),
                          if (_isAiThinking) const CircularProgressIndicator(strokeWidth: 2),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D2D2D),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _currentAiAnalysis,
                              style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white70),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
