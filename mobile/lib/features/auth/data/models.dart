class UserModel {
  final String id;
  final String phone;
  final String? name;
  final String role;
  final String? carBrand;
  final String? carModel;
  final String? carColor;
  final String? carPlate;
  final bool isOnline;

  UserModel({
    required this.id,
    required this.phone,
    this.name,
    required this.role,
    this.carBrand,
    this.carModel,
    this.carColor,
    this.carPlate,
    this.isOnline = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      name: json['name'],
      role: json['role'] ?? 'client',
      carBrand: json['carBrand'],
      carModel: json['carModel'],
      carColor: json['carColor'],
      carPlate: json['carPlate'],
      isOnline: json['isOnline'] ?? false,
    );
  }

  bool get isRegistered => name != null && name!.isNotEmpty;
  bool get isDriver => role == 'driver';
  bool get isClient => role == 'client';
}

class OrderModel {
  final String id;
  final String clientId;
  final String? clientName;
  final String? clientPhone;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? carBrand;
  final String? carModel;
  final String? carColor;
  final String? carPlate;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final double clientPrice;
  final double? finalPrice;
  final String status;
  final String createdAt;

  OrderModel({
    required this.id,
    required this.clientId,
    this.clientName,
    this.clientPhone,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.carBrand,
    this.carModel,
    this.carColor,
    this.carPlate,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.clientPrice,
    this.finalPrice,
    required this.status,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? '',
      clientId: json['clientId'] ?? '',
      clientName: json['clientName'],
      clientPhone: json['clientPhone'],
      driverId: json['driverId'],
      driverName: json['driverName'],
      driverPhone: json['driverPhone'],
      carBrand: json['carBrand'],
      carModel: json['carModel'],
      carColor: json['carColor'],
      carPlate: json['carPlate'],
      pickupLat: (json['pickupLat'] ?? 0).toDouble(),
      pickupLng: (json['pickupLng'] ?? 0).toDouble(),
      dropoffLat: (json['dropoffLat'] ?? 0).toDouble(),
      dropoffLng: (json['dropoffLng'] ?? 0).toDouble(),
      clientPrice: (json['clientPrice'] ?? 0).toDouble(),
      finalPrice: json['finalPrice']?.toDouble(),
      status: json['status'] ?? 'created',
      createdAt: json['createdAt'] ?? '',
    );
  }
}

class OrderResponseModel {
  final String id;
  final String orderId;
  final String driverId;
  final String? driverName;
  final String? driverPhone;
  final String? carBrand;
  final String? carModel;
  final String? carColor;
  final String? carPlate;
  final double proposedPrice;
  final String status;

  OrderResponseModel({
    required this.id,
    required this.orderId,
    required this.driverId,
    this.driverName,
    this.driverPhone,
    this.carBrand,
    this.carModel,
    this.carColor,
    this.carPlate,
    required this.proposedPrice,
    required this.status,
  });

  factory OrderResponseModel.fromJson(Map<String, dynamic> json) {
    return OrderResponseModel(
      id: json['id'] ?? '',
      orderId: json['orderId'] ?? '',
      driverId: json['driverId'] ?? '',
      driverName: json['driverName'],
      driverPhone: json['driverPhone'],
      carBrand: json['carBrand'],
      carModel: json['carModel'],
      carColor: json['carColor'],
      carPlate: json['carPlate'],
      proposedPrice: (json['proposedPrice'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
    );
  }
}
