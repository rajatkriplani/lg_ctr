import 'package:dartssh2/dartssh2.dart';
import 'dart:convert';
import 'dart:io';

class SSHService {
  SSHClient? _client;
  bool isConnected = false;

  Future<void> connect({
    required String host,
    required String username,
    required String password,
    int port = 22,
  }) async {
    try {
      final socket = await SSHSocket.connect(host, port);
      _client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );
      isConnected = true;
    } catch (e) {
      isConnected = false;
      throw Exception('Failed to connect: $e');
    }
  }

  Future<String> execute(String command) async {
    if (_client == null || !isConnected) {
      throw Exception('Not connected to SSH');
    }

    try {
      final session = await _client!.execute(command);
      final stdoutStream = await session.stdout.toList();
      final result = utf8.decode(stdoutStream.expand((e) => e).toList());
      return result;
    } catch (e) {
      throw Exception('Failed to execute command: $e');
    }
  }

  Future<void> uploadFile(String localPath, String remotePath) async {
    if (_client == null || !isConnected) {
      throw Exception('Not connected to SSH');
    }

    try {
      final sftp = await _client!.sftp();
      final file = File(localPath);
      final bytes = await file.readAsBytes();
      
      // Open file with correct SFTP open mode
      final handle = await sftp.open(
        remotePath,
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write,
      );
      
      await handle.writeBytes(bytes);
      await handle.close();
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<void> disconnect() async {
    if (_client != null) {
      _client!.close();
      isConnected = false;
    }
  }
}