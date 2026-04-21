import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jiti_app/core/constants/constants.dart';
import 'package:jiti_app/core/network/api_client.dart';
import 'package:jiti_app/core/widgets/shared_widgets.dart';
import 'package:jiti_app/features/auth/data/models.dart';

class HistoryPage extends StatefulWidget {
  final String title;
  const HistoryPage({super.key, this.title = 'История'});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<OrderModel> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final api = context.read<ApiClient>();
      final res = await api.get(ApiConstants.myOrders);
      setState(() {
        _orders = (res.data as List).map((e) => OrderModel.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(AppColors.primary)))
          : _orders.isEmpty
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.history_rounded, size: 64, color: Color(AppColors.textHint)),
                  SizedBox(height: 16),
                  Text('Нет заказов', style: TextStyle(color: Color(AppColors.textSecondary))),
                ]))
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16), itemCount: _orders.length,
                    itemBuilder: (ctx, i) {
                      final order = _orders[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(AppColors.surface), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(AppColors.border))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text('${(order.finalPrice ?? order.clientPrice).toStringAsFixed(0)} ₸', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                            StatusBadge(status: order.status),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [const Icon(Icons.circle, size: 10, color: Color(AppColors.success)), const SizedBox(width: 8), Text('${order.pickupLat.toStringAsFixed(4)}, ${order.pickupLng.toStringAsFixed(4)}', style: const TextStyle(color: Color(AppColors.textSecondary), fontSize: 13))]),
                          const SizedBox(height: 4),
                          Row(children: [const Icon(Icons.location_on, size: 10, color: Color(AppColors.error)), const SizedBox(width: 8), Text('${order.dropoffLat.toStringAsFixed(4)}, ${order.dropoffLng.toStringAsFixed(4)}', style: const TextStyle(color: Color(AppColors.textSecondary), fontSize: 13))]),
                          const SizedBox(height: 8),
                          Text(order.createdAt.isNotEmpty ? order.createdAt.substring(0, 16).replaceAll('T', ' ') : '', style: const TextStyle(color: Color(AppColors.textHint), fontSize: 12)),
                        ]),
                      );
                    },
                  ),
                ),
    );
  }
}
