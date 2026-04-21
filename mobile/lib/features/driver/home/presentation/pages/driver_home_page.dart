import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:jiti_app/core/constants/constants.dart';
import 'package:jiti_app/core/network/api_client.dart';
import 'package:jiti_app/core/network/socket_service.dart';
import 'package:jiti_app/core/widgets/shared_widgets.dart';
import 'package:jiti_app/features/auth/data/models.dart';

class DriverHomePage extends StatefulWidget {
  final VoidCallback onHistoryTap;
  final VoidCallback onLogout;
  const DriverHomePage({super.key, required this.onHistoryTap, required this.onLogout});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  bool _isOnline = false;
  List<OrderModel> _availableOrders = [];
  OrderModel? _activeOrder;
  final Set<String> _pendingResponseOrderIds = <String>{};
  Timer? _refreshTimer;
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkActiveOrder();
    _listenSocket();
  }

  void _listenSocket() {
    final socket = context.read<SocketService>();
    socket.on('order:new', (data) {
      if (_isOnline && _activeOrder == null) {
        setState(() => _availableOrders.insert(0, OrderModel.fromJson(data)));
      }
    });
    socket.on('order:status-changed', (data) { if (data is Map<String, dynamic>) _loadActiveOrder(); });
    socket.on('order:driver-selected', (data) { if (mounted) setState(() => _activeOrder = OrderModel.fromJson(data)); });
  }

  Future<void> _checkActiveOrder() async { await _loadActiveOrder(); }

  Future<void> _loadActiveOrder() async {
    try {
      final api = context.read<ApiClient>();
      final res = await api.get(ApiConstants.activeOrder);
      if (res.data != null && res.data is Map) {
        final activeOrder = OrderModel.fromJson(res.data);
        setState(() {
          _activeOrder = activeOrder;
          _pendingResponseOrderIds.remove(activeOrder.id);
        });
      }
      else { setState(() => _activeOrder = null); }
    } catch (_) {}
  }

  void _toggleOnline() {
    final socket = context.read<SocketService>();
    setState(() => _isOnline = !_isOnline);
    if (_isOnline) {
      socket.goOnline();
      _loadAvailableOrders();
      _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadAvailableOrders());
    } else {
      socket.goOffline();
      _refreshTimer?.cancel();
      setState(() => _availableOrders.clear());
    }
  }

  Future<void> _loadAvailableOrders() async {
    if (!_isOnline) return;
    try {
      final api = context.read<ApiClient>();
      final res = await api.get(ApiConstants.availableOrders);
      if (mounted) setState(() => _availableOrders = (res.data as List).map((e) => OrderModel.fromJson(e)).toList());
    } catch (_) {}
  }

  Future<void> _respondToOrder(OrderModel order, double price) async {
    if (_pendingResponseOrderIds.contains(order.id)) {
      return;
    }

    setState(() => _pendingResponseOrderIds.add(order.id));
    try {
      final api = context.read<ApiClient>();
      await api.post('${ApiConstants.orders}/${order.id}/respond', data: {'proposedPrice': price});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Отклик отправлен. Ждём ответа клиента.'),
            backgroundColor: Color(AppColors.success),
          ),
        );
      }
      _loadAvailableOrders();
    } catch (e) {
      if (mounted) {
        setState(() => _pendingResponseOrderIds.remove(order.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка отклика'),
            backgroundColor: Color(AppColors.error),
          ),
        );
      }
    }
  }

  Future<void> _startTrip() async {
    if (_activeOrder == null) return;
    try {
      final api = context.read<ApiClient>();
      final res = await api.post('${ApiConstants.orders}/${_activeOrder!.id}/start');
      setState(() => _activeOrder = OrderModel.fromJson(res.data));
    } catch (_) {}
  }

  Future<void> _completeTrip() async {
    if (_activeOrder == null) return;
    try {
      final api = context.read<ApiClient>();
      await api.post('${ApiConstants.orders}/${_activeOrder!.id}/complete');
      setState(() => _activeOrder = null);
      _loadAvailableOrders();
    } catch (_) {}
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _priceController.dispose();
    context.read<SocketService>().off('order:new');
    context.read<SocketService>().off('order:status-changed');
    context.read<SocketService>().off('order:driver-selected');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Stack(children: [
      FlutterMap(
        options: MapOptions(initialCenter: const LatLng(51.1694, 71.4491), initialZoom: 13),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.jiti.app'),
          if (_activeOrder != null) MarkerLayer(markers: [
            Marker(point: LatLng(_activeOrder!.pickupLat, _activeOrder!.pickupLng), width: 40, height: 40, child: const Icon(Icons.person_pin_circle_rounded, color: Color(AppColors.accent), size: 36)),
            Marker(point: LatLng(_activeOrder!.dropoffLat, _activeOrder!.dropoffLng), width: 40, height: 40, child: const Icon(Icons.flag_rounded, color: Color(AppColors.error), size: 32)),
          ]),
        ],
      ),

      // Top bar
      Positioned(top: MediaQuery.of(context).padding.top + 8, left: 12, right: 12, child: Row(children: [
        CircleAvatar(backgroundColor: const Color(AppColors.surface).withValues(alpha: 0.9), child: IconButton(icon: const Icon(Icons.menu_rounded, color: Colors.white), onPressed: () => _showMenu(context))),
        const Spacer(),
        GestureDetector(
          onTap: _activeOrder == null ? _toggleOnline : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _isOnline ? const Color(AppColors.success).withValues(alpha: 0.9) : const Color(AppColors.surface).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _isOnline ? const Color(AppColors.success) : const Color(AppColors.border)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(_isOnline ? AppStrings.online : AppStrings.offline, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ])),

      Positioned(bottom: 0, left: 0, right: 0, child: _activeOrder != null ? _buildActiveOrderPanel() : _isOnline ? _buildAvailableOrdersList() : _buildOfflinePanel()),
    ]));
  }

  Widget _buildOfflinePanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Color(AppColors.surface), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.power_settings_new_rounded, size: 48, color: Color(AppColors.textHint)),
        const SizedBox(height: 12),
        const Text('Вы офлайн', style: TextStyle(color: Color(AppColors.textSecondary), fontSize: 18)),
        const SizedBox(height: 8),
        const Text('Включите режим онлайн, чтобы получать заказы', textAlign: TextAlign.center, style: TextStyle(color: Color(AppColors.textHint), fontSize: 14)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _toggleOnline, style: ElevatedButton.styleFrom(backgroundColor: const Color(AppColors.success)), child: const Text('Выйти на линию')),
      ])),
    );
  }

  Widget _buildAvailableOrdersList() {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
      decoration: const BoxDecoration(color: Color(AppColors.surface), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(AppColors.textHint), borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          const Text('Доступные заказы', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: const Color(AppColors.primary).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: Text('${_availableOrders.length}', style: const TextStyle(color: Color(AppColors.primary), fontWeight: FontWeight.bold))),
        ])),
        Flexible(child: _availableOrders.isEmpty
            ? const Padding(padding: EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.inbox_rounded, size: 48, color: Color(AppColors.textHint)), SizedBox(height: 8), Text('Ожидание заказов...', style: TextStyle(color: Color(AppColors.textSecondary)))]))
            : ListView.builder(shrinkWrap: true, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _availableOrders.length, itemBuilder: (ctx, i) => _buildOrderCard(_availableOrders[i]))),
      ])),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final isPendingResponse = _pendingResponseOrderIds.contains(order.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(AppColors.surfaceLight), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(AppColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${order.clientPrice.toStringAsFixed(0)} ₸', style: const TextStyle(color: Color(AppColors.accent), fontSize: 22, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(order.clientName ?? '', style: const TextStyle(color: Color(AppColors.textSecondary), fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        Row(children: [const Icon(Icons.circle, size: 10, color: Color(AppColors.success)), const SizedBox(width: 8), Text('${order.pickupLat.toStringAsFixed(4)}, ${order.pickupLng.toStringAsFixed(4)}', style: const TextStyle(color: Color(AppColors.textSecondary), fontSize: 12))]),
        const SizedBox(height: 4),
        Row(children: [const Icon(Icons.location_on, size: 10, color: Color(AppColors.error)), const SizedBox(width: 8), Text('${order.dropoffLat.toStringAsFixed(4)}, ${order.dropoffLng.toStringAsFixed(4)}', style: const TextStyle(color: Color(AppColors.textSecondary), fontSize: 12))]),
        const SizedBox(height: 12),
        if (isPendingResponse)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(AppColors.warning).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(AppColors.warning).withValues(alpha: 0.45)),
            ),
            child: const Row(children: [
              Icon(Icons.hourglass_top_rounded, color: Color(AppColors.warning), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ждём ответа клиента',
                  style: TextStyle(color: Color(AppColors.warning), fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: isPendingResponse ? null : () => _respondToOrder(order, order.clientPrice),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPendingResponse ? const Color(AppColors.warning) : const Color(AppColors.success),
                disabledBackgroundColor: const Color(AppColors.warning),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isPendingResponse ? 'Ждём ответа' : 'Принять ${order.clientPrice.toStringAsFixed(0)} ₸',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 44,
            child: ElevatedButton(
              onPressed: isPendingResponse ? null : () => _showPriceDialog(order),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.primary),
                disabledBackgroundColor: const Color(AppColors.border),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Icon(
                isPendingResponse ? Icons.hourglass_top_rounded : Icons.edit_rounded,
                size: 20,
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  void _showPriceDialog(OrderModel order) {
    _priceController.text = order.clientPrice.toStringAsFixed(0);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(AppColors.surface), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Предложить свою цену', style: TextStyle(color: Colors.white)),
      content: TextField(controller: _priceController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), decoration: const InputDecoration(suffixText: '₸')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(AppStrings.cancel, style: TextStyle(color: Color(AppColors.textSecondary)))),
        ElevatedButton(onPressed: () { final price = double.tryParse(_priceController.text); if (price != null && price > 0) { Navigator.pop(ctx); _respondToOrder(order, price); } }, child: const Text('Предложить')),
      ],
    ));
  }

  Widget _buildActiveOrderPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(AppColors.surface), borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)]),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(AppColors.textHint), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(children: [
          const Icon(Icons.person_rounded, color: Color(AppColors.accent), size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_activeOrder!.clientName ?? 'Клиент', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            Text(_activeOrder!.clientPhone ?? '', style: const TextStyle(color: Color(AppColors.textSecondary), fontSize: 13)),
          ])),
          Text('${(_activeOrder!.finalPrice ?? _activeOrder!.clientPrice).toStringAsFixed(0)} ₸', style: const TextStyle(color: Color(AppColors.accent), fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        StatusBadge(status: _activeOrder!.status),
        const SizedBox(height: 16),
        if (_activeOrder!.status == 'driver_selected')
          ElevatedButton(onPressed: _startTrip, style: ElevatedButton.styleFrom(backgroundColor: const Color(AppColors.primary), minimumSize: const Size(double.infinity, 52)), child: const Text(AppStrings.startTrip)),
        if (_activeOrder!.status == 'in_progress')
          ElevatedButton(onPressed: _completeTrip, style: ElevatedButton.styleFrom(backgroundColor: const Color(AppColors.success), minimumSize: const Size(double.infinity, 52)), child: const Text(AppStrings.completeTrip)),
      ])),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: const Color(AppColors.surface), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(AppColors.textHint), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        ListTile(leading: const Icon(Icons.history_rounded, color: Color(AppColors.primary)), title: const Text('История', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(ctx); widget.onHistoryTap(); }),
        ListTile(leading: const Icon(Icons.logout_rounded, color: Color(AppColors.error)), title: const Text('Выйти', style: TextStyle(color: Color(AppColors.error))), onTap: () { Navigator.pop(ctx); widget.onLogout(); }),
        const SizedBox(height: 16),
      ])),
    );
  }
}
