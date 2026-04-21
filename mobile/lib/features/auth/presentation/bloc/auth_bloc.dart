import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jiti_app/core/network/api_client.dart';
import 'package:jiti_app/core/constants/constants.dart';
import 'package:jiti_app/features/auth/data/models.dart';

// Events
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class CheckAuth extends AuthEvent {}
class SendCode extends AuthEvent {
  final String phone;
  SendCode(this.phone);
  @override
  List<Object?> get props => [phone];
}
class VerifyCode extends AuthEvent {
  final String phone;
  final String code;
  VerifyCode(this.phone, this.code);
  @override
  List<Object?> get props => [phone, code];
}
class Register extends AuthEvent {
  final String name;
  final String role;
  final String? carBrand;
  final String? carModel;
  final String? carColor;
  final String? carPlate;
  Register({required this.name, required this.role, this.carBrand, this.carModel, this.carColor, this.carPlate});
  @override
  List<Object?> get props => [name, role];
}
class Logout extends AuthEvent {}

// States
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthCodeSent extends AuthState {
  final String phone;
  AuthCodeSent(this.phone);
  @override
  List<Object?> get props => [phone];
}
class AuthNeedsRegistration extends AuthState {
  final String token;
  AuthNeedsRegistration(this.token);
  @override
  List<Object?> get props => [token];
}
class AuthAuthenticated extends AuthState {
  final UserModel user;
  AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [user];
}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiClient apiClient;

  AuthBloc({required this.apiClient}) : super(AuthLoading()) {
    on<CheckAuth>(_onCheckAuth);
    on<SendCode>(_onSendCode);
    on<VerifyCode>(_onVerifyCode);
    on<Register>(_onRegister);
    on<Logout>(_onLogout);
  }

  Future<void> _onCheckAuth(CheckAuth event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        emit(AuthInitial());
        return;
      }
      final response = await apiClient.get(ApiConstants.me);
      final user = UserModel.fromJson(response.data);
      if (!user.isRegistered) {
        emit(AuthNeedsRegistration(token));
      } else {
        emit(AuthAuthenticated(user));
      }
    } catch (e) {
      emit(AuthInitial());
    }
  }

  Future<void> _onSendCode(SendCode event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await apiClient.post(ApiConstants.sendCode, data: {'phone': event.phone});
      emit(AuthCodeSent(event.phone));
    } catch (e) {
      emit(AuthError(_extractError(e)));
    }
  }

  Future<void> _onVerifyCode(VerifyCode event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await apiClient.post(ApiConstants.verifyCode, data: {
        'phone': event.phone,
        'code': event.code,
      });
      final data = response.data;
      final token = data['token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);

      final user = UserModel.fromJson(data['user']);
      if (data['isNewUser'] == true || !user.isRegistered) {
        emit(AuthNeedsRegistration(token));
      } else {
        emit(AuthAuthenticated(user));
      }
    } catch (e) {
      emit(AuthError(_extractError(e)));
    }
  }

  Future<void> _onRegister(Register event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await apiClient.post(ApiConstants.register, data: {
        'name': event.name,
        'role': event.role,
        'carBrand': event.carBrand,
        'carModel': event.carModel,
        'carColor': event.carColor,
        'carPlate': event.carPlate,
      });
      final data = response.data;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', data['token']);
      final user = UserModel.fromJson(data['user']);
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(_extractError(e)));
    }
  }

  Future<void> _onLogout(Logout event, Emitter<AuthState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    emit(AuthInitial());
  }

  String _extractError(dynamic e) {
    if (e is Exception) {
      final str = e.toString();
      if (str.contains('error')) {
        return str;
      }
    }
    return 'Произошла ошибка';
  }
}
