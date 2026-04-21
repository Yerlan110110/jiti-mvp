import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jiti_app/core/constants/constants.dart';
import 'package:jiti_app/core/network/api_client.dart';
import 'package:jiti_app/core/network/socket_service.dart';
import 'package:jiti_app/core/widgets/shared_widgets.dart';
import 'package:jiti_app/features/auth/data/models.dart';

class OrderResponsesPage extends StatefulWidget {
  final String orderId;
  const OrderResponsesPage({super.key, required this.orderId});

  @override
  State<OrderResponsesPage> createState() => _OrderResponsesPageState();
}

class _OrderResponsesPageState extends State<OrderResponsesPage> {
  List<OrderResponseModel> _responses = [];
  OrderModel? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenSocket();
  }

  void _listenSocket() {
    final socket = context.read<SocketService>();
    socket.on('order:response', (data) {
      final response = OrderResponseModel.fromJson(data);
      setState(() => _responses.insert(0, response));
    });
    socket.on('order:driver-selected', (data) {
      if (mounted) Navigator.pop(context, 'tracking');
    });
  }

  Future<void> _loadData() async {
    try {
      final api = context.read<ApiClient>();
      final orderRes = await api.get('${ApiConstants.orders}/${widget.orderId}');
      final responsesRes = await api.get('${ApiConstants.orders}/${widget.orderId}/responses');
      setState(() {
        _order = OrderModel.fromJson(orderRes.data);
        _responses = (responsesRes.data as List).map((e) => OrderResponseModel.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _selectDriver(OrderResponseModel response) async {
    try {
      final api = context.read<ApiClient>();
      await api.post('${ApiConstants.orders}/${widget.orderId}/select-driver', data: {'responseId': response.id});
      if (mounted) Navigator.pop(context, 'tracking');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка выбора водителя')));
    }
  }

  Future<void> _cancelOrder() async {
    try {
      final api = context.read<ApiClient>();
      await api.post('${ApiConstants.orders}/${widget.orderId}/cancel');
      if (mounted) Navigator.pop(context, 'cancelled');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка отмены')));
    }
  }

  @override
  void dispose() {
    context.read<SocketService>().off('order:response');
    context.read<SocketService>().off('order:driver-selected');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.responses),
        actions: [TextButton(onPressed: _cancelOrder, child: const Text(AppStrings.cancel, style: TextStyle(color: Color(AppColors.error))))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(AppColors.primary)))
          : Column(children: [
              if (_order != null)
                GlassCard(child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Ваша цена: ${_order!.clientPrice.toStringAsFixed(0)} ₸', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    StatusBadge(status: _order!.status),
                  ])),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(AppColors.primary).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: Text('${_responses.length}', style: const TextStyle(color: Color(AppColors.primary), fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                ])),
              Expanded(
                child: _responses.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.hourglass_top_rounded, size: 64, color: Color(AppColors.textHint)),
                        const SizedBox(height: 16),
                        const Text('Ожидание откликов...', style: TextStyle(color: Color(AppColors.textSecondary), fontSize: 16)),
                        const SizedBox(height: 8),
                        const SizedBox(width: 120, child: LinearProgressIndicator(color: Color(AppColors.primary))),
                      ]))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _responses.length,
                        itemBuilder: (ctx, i) => _DriverResponseCard(response: _responses[i], onSelect: () => _selectDriver(_responses[i])),
                      ),
              ),
            ]),
    );
  }
}

class _DriverResponseCard extends StatelessWidget {
  final OrderResponseModel response;
  final VoidCallback onSelect;
  const _DriverResponseCard({required this.response, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(AppColors.surface), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(AppColors.border))),
      child: Column(children: [
        Row(children: [
          CircleAvatar(backgroundColor: const Color(AppColors.primary).withValues(alpha: 0.2), child: const Icon(Icons.person_rounded, color: Color(AppColors.primary))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(response.driverName ?? 'Водитель', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            if (response.carBrand != null || response.carModel != null)
              Text('${response.carBrand ?? ''} ${response.carModel ?? ''} • ${response.carPlate ?? ''}', style: const TextStyle(color: Color(AppColors.textSecondary), fontSize: 13)),
          ])),
          Text('${response.proposedPrice.toStringAsFixed(0)} ₸', style: const TextStyle(color: Color(AppColors.accent), fontSize: 20, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onSelect, style: ElevatedButton.styleFrom(backgroundColor: const Color(AppColors.success), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text(AppStrings.selectDriver))),
      ]),
    );
  }
}
