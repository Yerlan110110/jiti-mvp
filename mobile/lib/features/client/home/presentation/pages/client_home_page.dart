import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:jiti_app/core/constants/constants.dart';
import 'package:jiti_app/features/client/home/presentation/bloc/client_home_cubit.dart';

class ClientHomePage extends StatefulWidget {
  final VoidCallback onOrderCreated;
  final VoidCallback onHistoryTap;
  final VoidCallback onLogout;

  const ClientHomePage({super.key, required this.onOrderCreated, required this.onHistoryTap, required this.onLogout});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  final MapController _mapController = MapController();
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ClientHomeCubit>().initMap(null);
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<ClientHomeCubit, ClientHomeState>(
        listener: (context, state) {
          if (state is ClientHomeError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: const Color(AppColors.error)));
          }
          if (state is ClientOrderCreated) {
            widget.onOrderCreated();
          }
        },
        builder: (context, state) {
          if (state is ClientHomeLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(AppColors.primary)));
          }
          if (state is! ClientHomeMapReady) {
            return const Center(child: CircularProgressIndicator());
          }

          final mapState = state;
          final markers = <Marker>[];

          if (mapState.pickupPoint != null) {
            markers.add(Marker(point: mapState.pickupPoint!, width: 50, height: 50, child: const _MapPin(color: Color(AppColors.success), label: 'A')));
          }
          if (mapState.dropoffPoint != null) {
            markers.add(Marker(point: mapState.dropoffPoint!, width: 50, height: 50, child: const _MapPin(color: Color(AppColors.error), label: 'B')));
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapState.currentLocation ?? const LatLng(51.1694, 71.4491),
                  initialZoom: 13,
                  onTap: (tapPos, point) => context.read<ClientHomeCubit>().selectPoint(point),
                ),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.jiti.app'),
                  if (markers.isNotEmpty) MarkerLayer(markers: markers),
                  if (mapState.pickupPoint != null && mapState.dropoffPoint != null)
                    PolylineLayer(polylines: [Polyline(points: [mapState.pickupPoint!, mapState.dropoffPoint!], strokeWidth: 3, color: const Color(AppColors.primary).withValues(alpha: 0.7), pattern: const StrokePattern.dotted())]),
                ],
              ),

              if (mapState.isSelectingPickup || mapState.isSelectingDropoff)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12, left: 20, right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: mapState.isSelectingPickup ? const Color(AppColors.success).withValues(alpha: 0.9) : const Color(AppColors.error).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.touch_app_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(mapState.isSelectingPickup ? 'Нажмите на карту — Точка A' : 'Нажмите на карту — Точка B', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),

              Positioned(
                top: MediaQuery.of(context).padding.top + 8, left: 12,
                child: CircleAvatar(
                  backgroundColor: const Color(AppColors.surface).withValues(alpha: 0.9),
                  child: IconButton(icon: const Icon(Icons.menu_rounded, color: Colors.white), onPressed: () => _showMenu(context)),
                ),
              ),

              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(AppColors.background).withValues(alpha: 0), const Color(AppColors.background)])),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        _PointSelector(label: AppStrings.pointA, point: mapState.pickupPoint, isActive: mapState.isSelectingPickup, color: const Color(AppColors.success), onTap: () => context.read<ClientHomeCubit>().startSelectingPickup()),
                        const SizedBox(height: 8),
                        _PointSelector(label: AppStrings.pointB, point: mapState.dropoffPoint, isActive: mapState.isSelectingDropoff, color: const Color(AppColors.error), onTap: () => context.read<ClientHomeCubit>().startSelectingDropoff()),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _priceController, keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(hintText: '${AppStrings.price} (₸)', prefixIcon: const Icon(Icons.payments_rounded, color: Color(AppColors.primary)), fillColor: const Color(AppColors.surface)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            final price = double.tryParse(_priceController.text);
                            if (price == null || price <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите цену'))); return; }
                            context.read<ClientHomeCubit>().createOrder(price);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(AppColors.primary), minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.local_taxi_rounded), SizedBox(width: 8), Text(AppStrings.createOrder, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))]),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(AppColors.surface),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(AppColors.textHint), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        ListTile(leading: const Icon(Icons.history_rounded, color: Color(AppColors.primary)), title: const Text(AppStrings.history, style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(ctx); widget.onHistoryTap(); }),
        ListTile(leading: const Icon(Icons.logout_rounded, color: Color(AppColors.error)), title: const Text('Выйти', style: TextStyle(color: Color(AppColors.error))), onTap: () { Navigator.pop(ctx); widget.onLogout(); }),
        const SizedBox(height: 16),
      ])),
    );
  }
}

class _PointSelector extends StatelessWidget {
  final String label;
  final LatLng? point;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;
  const _PointSelector({required this.label, this.point, required this.isActive, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: isActive ? color.withValues(alpha: 0.15) : const Color(AppColors.surface), borderRadius: BorderRadius.circular(16), border: Border.all(color: isActive ? color : const Color(AppColors.border))),
        child: Row(children: [
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(point != null ? '${point!.latitude.toStringAsFixed(4)}, ${point!.longitude.toStringAsFixed(4)}' : label, style: TextStyle(color: point != null ? Colors.white : const Color(AppColors.textHint), fontSize: 14))),
          Icon(isActive ? Icons.touch_app_rounded : Icons.edit_location_alt_rounded, color: color.withValues(alpha: 0.7), size: 20),
        ]),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final String label;
  const _MapPin({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)), child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
      Icon(Icons.location_on_rounded, color: color, size: 32),
    ]);
  }
}
