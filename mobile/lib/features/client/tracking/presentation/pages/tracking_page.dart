import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:jiti_app/core/constants/constants.dart';
import 'package:jiti_app/core/network/api_client.dart';
import 'package:jiti_app/core/network/socket_service.dart';
import 'package:jiti_app/features/auth/data/models.dart';

class TrackingPage extends StatefulWidget {
  final String orderId;
  const TrackingPage({super.key, required this.orderId});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  OrderModel? _order;
  LatLng? _driverLocation;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _listenSocket();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadOrder());
  }

  void _listenSocket() {
    final socket = context.read<SocketService>();
    socket.on('driver:location', (data) {
      setState(() => _driverLocation = LatLng((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble()));
    });
    socket.on('order:status-changed', (data) {
      final order = OrderModel.fromJson(data);
      setState(() => _order = order);
      if (order.status == 'completed' || order.status == 'cancelled') {
        if (mounted) Navigator.pop(context, order.status);
      }
    });
  }

  Future<void> _loadOrder() async {
    try {
      final api = context.read<ApiClient>();
      final res = await api.get('${ApiConstants.orders}/${widget.orderId}');
      if (mounted) setState(() => _order = OrderModel.fromJson(res.data));
    } catch (_) {}
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    context.read<SocketService>().off('driver:location');
    context.read<SocketService>().off('order:status-changed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_order == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(AppColors.primary))));

    final markers = <Marker>[
      Marker(point: LatLng(_order!.pickupLat, _order!.pickupLng), width: 40, height: 40, child: const Icon(Icons.trip_origin_rounded, color: Color(AppColors.success), size: 28)),
      Marker(point: LatLng(_order!.dropoffLat, _order!.dropoffLng), width: 40, height: 40, child: const Icon(Icons.location_on_rounded, color: Color(AppColors.error), size: 32)),
    ];

    if (_driverLocation != null) {
      markers.add(Marker(point: _driverLocation!, width: 50, height: 50, child: Container(
        decoration: BoxDecoration(color: const Color(AppColors.primary), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(AppColors.primary).withValues(alpha: 0.5), blurRadius: 12)]),
        child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 28),
      )));
    }

    final statusText = {'driver_selected': 'Водитель едет к вам', 'in_progress': 'В поездке'};

    return Scaffold(body: Stack(children: [
      FlutterMap(
        options: MapOptions(initialCenter: LatLng(_order!.pickupLat, _order!.pickupLng), initialZoom: 14),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.jiti.app'),
          MarkerLayer(markers: markers),
          PolylineLayer(polylines: [Polyline(points: [LatLng(_order!.pickupLat, _order!.pickupLng), LatLng(_order!.dropoffLat, _order!.dropoffLng)], strokeWidth: 3, color: const Color(AppColors.primary).withValues(alpha: 0.5), pattern: const StrokePattern.dotted())]),
        ],
      ),
      Positioned(top: MediaQuery.of(context).padding.top + 8, left: 12, child: CircleAvatar(
        backgroundColor: const Color(AppColors.surface).withValues(alpha: 0.9),
        child: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
      )),
      Positioned(bottom: 0, left: 0, right: 0, child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(AppColors.surface), borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)]),
        child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(AppColors.textHint), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(AppColors.primary).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.directions_car_rounded, color: Color(AppColors.primary), size: 28)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_order!.driverName ?? 'Водитель', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              Text('${_order!.carBrand ?? ''} ${_order!.carModel ?? ''} • ${_order!.carPlate ?? ''}', style: const TextStyle(color: Color(AppColors.textSecondary), fontSize: 13)),
            ])),
            Text('${(_order!.finalPrice ?? _order!.clientPrice).toStringAsFixed(0)} ₸', style: const TextStyle(color: Color(AppColors.accent), fontSize: 22, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: const Color(AppColors.primary).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(statusText[_order!.status] ?? _order!.status, style: const TextStyle(color: Color(AppColors.primary), fontWeight: FontWeight.w600, fontSize: 16)))),
        ])),
      )),
    ]));
  }
}
