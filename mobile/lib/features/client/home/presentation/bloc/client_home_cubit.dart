import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import 'package:jiti_app/core/network/api_client.dart';
import 'package:jiti_app/core/network/socket_service.dart';
import 'package:jiti_app/core/constants/constants.dart';
import 'package:jiti_app/features/auth/data/models.dart';

// States
abstract class ClientHomeState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ClientHomeInitial extends ClientHomeState {}
class ClientHomeMapReady extends ClientHomeState {
  final LatLng? pickupPoint;
  final LatLng? dropoffPoint;
  final bool isSelectingPickup;
  final bool isSelectingDropoff;
  final LatLng? currentLocation;

  ClientHomeMapReady({this.pickupPoint, this.dropoffPoint, this.isSelectingPickup = false, this.isSelectingDropoff = false, this.currentLocation});

  ClientHomeMapReady copyWith({LatLng? pickupPoint, LatLng? dropoffPoint, bool? isSelectingPickup, bool? isSelectingDropoff, LatLng? currentLocation}) {
    return ClientHomeMapReady(
      pickupPoint: pickupPoint ?? this.pickupPoint,
      dropoffPoint: dropoffPoint ?? this.dropoffPoint,
      isSelectingPickup: isSelectingPickup ?? this.isSelectingPickup,
      isSelectingDropoff: isSelectingDropoff ?? this.isSelectingDropoff,
      currentLocation: currentLocation ?? this.currentLocation,
    );
  }

  @override
  List<Object?> get props => [pickupPoint, dropoffPoint, isSelectingPickup, isSelectingDropoff, currentLocation];
}

class ClientOrderCreated extends ClientHomeState {
  final OrderModel order;
  ClientOrderCreated(this.order);
  @override
  List<Object?> get props => [order];
}

class ClientHomeError extends ClientHomeState {
  final String message;
  ClientHomeError(this.message);
  @override
  List<Object?> get props => [message];
}

class ClientHomeLoading extends ClientHomeState {}

// Cubit
class ClientHomeCubit extends Cubit<ClientHomeState> {
  final ApiClient apiClient;
  final SocketService socketService;

  ClientHomeCubit({required this.apiClient, required this.socketService}) : super(ClientHomeInitial());

  void initMap(LatLng? currentLocation) {
    emit(ClientHomeMapReady(currentLocation: currentLocation ?? const LatLng(51.1694, 71.4491)));
  }

  void startSelectingPickup() {
    if (state is ClientHomeMapReady) {
      emit((state as ClientHomeMapReady).copyWith(isSelectingPickup: true, isSelectingDropoff: false));
    }
  }

  void startSelectingDropoff() {
    if (state is ClientHomeMapReady) {
      emit((state as ClientHomeMapReady).copyWith(isSelectingPickup: false, isSelectingDropoff: true));
    }
  }

  void selectPoint(LatLng point) {
    if (state is ClientHomeMapReady) {
      final s = state as ClientHomeMapReady;
      if (s.isSelectingPickup) {
        emit(s.copyWith(pickupPoint: point, isSelectingPickup: false));
      } else if (s.isSelectingDropoff) {
        emit(s.copyWith(dropoffPoint: point, isSelectingDropoff: false));
      }
    }
  }

  Future<void> createOrder(double price) async {
    if (state is! ClientHomeMapReady) return;
    final s = state as ClientHomeMapReady;
    if (s.pickupPoint == null || s.dropoffPoint == null) {
      emit(ClientHomeError('Выберите точки A и B'));
      emit(s);
      return;
    }
    emit(ClientHomeLoading());
    try {
      final response = await apiClient.post(ApiConstants.orders, data: {
        'pickupLat': s.pickupPoint!.latitude,
        'pickupLng': s.pickupPoint!.longitude,
        'dropoffLat': s.dropoffPoint!.latitude,
        'dropoffLng': s.dropoffPoint!.longitude,
        'clientPrice': price,
      });
      final order = OrderModel.fromJson(response.data);
      socketService.joinOrderRoom(order.id);
      emit(ClientOrderCreated(order));
    } catch (e) {
      emit(ClientHomeError('Ошибка создания заказа'));
      emit(s);
    }
  }
}
