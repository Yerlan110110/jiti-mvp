import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';

class SocketService {
  io.Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  io.Socket? get socket => _socket;

  Future<void> connect() async {
    if (_socket != null && _isConnected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    _socket = io.io(
      ApiConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      print('🔌 Socket connected');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      print('❌ Socket disconnected');
    });

    _socket!.onConnectError((data) {
      _isConnected = false;
      print('⚠️ Socket error: $data');
    });
  }

  void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }

  void on(String event, Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void joinOrderRoom(String orderId) {
    emit('order:join', {'orderId': orderId});
  }

  void leaveOrderRoom(String orderId) {
    emit('order:leave', {'orderId': orderId});
  }

  void goOnline() {
    emit('driver:online');
  }

  void goOffline() {
    emit('driver:offline');
  }

  void updateLocation(double lat, double lng) {
    emit('driver:location-update', {'lat': lat, 'lng': lng});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }
}
