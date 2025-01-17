import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'services/settings_service.dart';
import 'services/ssh_service.dart';
import 'services/lg_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Register services
  final settings = SettingsService();
  await settings.init();
  
  GetIt.I.registerSingleton<SettingsService>(settings);
  GetIt.I.registerSingleton<SSHService>(SSHService());
  GetIt.I.registerSingleton<LGService>(LGService(GetIt.I<SSHService>()));
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LG Controller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SettingsService _settings = GetIt.I<SettingsService>();
  final SSHService _ssh = GetIt.I<SSHService>();
  final LGService _lg = GetIt.I<LGService>();
  String? selectedKML;
  bool isConnected = false;

  final List<String> kmlFiles = [
    'assets/kml1.kml',
    'assets/kml2.kml',
  ];

  Future<void> _showSettingsDialog() async {
    final settings = _settings.getConnectionSettings();
    final ipController = TextEditingController(text: settings['ip']);
    final usernameController = TextEditingController(text: settings['username']);
    final passwordController = TextEditingController(text: settings['password']);
    final portController = TextEditingController(text: settings['port'].toString());

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(labelText: 'IP Address'),
            ),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            TextField(
              controller: portController,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _settings.saveConnectionSettings(
                ip: ipController.text,
                username: usernameController.text,
                password: passwordController.text,
                port: int.parse(portController.text),
              );
              Navigator.pop(context);
              _connect();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _connect() async {
    try {
      final settings = _settings.getConnectionSettings();
      await _ssh.connect(
        host: settings['ip'],
        username: settings['username'],
        password: settings['password'],
        port: settings['port'],
      );
      setState(() => isConnected = true);
      _showSnackBar('Connected successfully');
    } catch (e) {
      _showSnackBar('Connection failed: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    if (_settings.hasConnectionSettings()) {
      _connect();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSettingsDialog();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LG Controller'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Logo Controls', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: isConnected ? () async {
                        try {
                          await _lg.setLogo();
                          _showSnackBar('Logo set successfully');
                        } catch (e) {
                          _showSnackBar('Failed to set logo: $e');
                        }
                      } : null,
                      child: const Text('Set Logo'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: isConnected ? () async {
                        try {
                          await _lg.clearLogo();
                          _showSnackBar('Logo cleared successfully');
                        } catch (e) {
                          _showSnackBar('Failed to clear logo: $e');
                        }
                      } : null,
                      child: const Text('Clear Logo'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('KML Controls', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: selectedKML,
                      hint: const Text('Select KML'),
                      isExpanded: true,
                      items: kmlFiles.map((String file) {
                        return DropdownMenuItem<String>(
                          value: file,
                          child: Text(file.split('/').last),
                        );
                      }).toList(),
                      onChanged: isConnected ? (String? value) {
                        setState(() => selectedKML = value);
                      } : null,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: isConnected && selectedKML != null ? () async {
                        try {
                          await _lg.sendKML(selectedKML!);
                          _showSnackBar('KML sent successfully');
                        } catch (e) {
                          _showSnackBar('Failed to send KML: $e');
                        }
                      } : null,
                      child: const Text('Send KML'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: isConnected ? () async {
                        try {
                          await _lg.clearKML();
                          _showSnackBar('KML cleared successfully');
                        } catch (e) {
                          _showSnackBar('Failed to clear KML: $e');
                        }
                      } : null,
                      child: const Text('Clear KML'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}