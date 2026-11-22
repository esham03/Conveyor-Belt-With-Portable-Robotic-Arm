import 'dart:async';
import 'package:http/http.dart' as http;

class CameraService {
  String baseUrl = 'http://192.168.4.1';
  bool isFlashOn = false;
  bool isConnected = false;

  String get streamUrl => '$baseUrl:81/stream';
  String get snapshotUrl => '$baseUrl/snapshot';

  Future<bool> probeCamera() async {
    try {
      final res = await http.get(Uri.parse(baseUrl)).timeout(const Duration(seconds: 2));
      isConnected = (res.statusCode == 200);
      return isConnected;
    } catch (_) {
      isConnected = false;
      return false;
    }
  }

  Future<bool> toggleFlash() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/flash')).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        isFlashOn = !isFlashOn;
        return true;
      }
    } catch (_) {}
    return false;
  }
}
