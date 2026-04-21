import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:jiti_app/core/network/api_client.dart';
import 'package:jiti_app/core/network/socket_service.dart';
import 'package:jiti_app/core/theme/app_theme.dart';
import 'package:jiti_app/core/constants/constants.dart';
import 'package:jiti_app/features/auth/data/models.dart';
import 'package:jiti_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:jiti_app/features/auth/presentation/pages/login_page.dart';
import 'package:jiti_app/features/auth/presentation/pages/verification_page.dart';
import 'package:jiti_app/features/auth/presentation/pages/registration_page.dart';
import 'package:jiti_app/features/client/home/presentation/bloc/client_home_cubit.dart';
import 'package:jiti_app/features/client/home/presentation/pages/client_home_page.dart';
import 'package:jiti_app/features/client/orders/presentation/pages/order_responses_page.dart';
import 'package:jiti_app/features/client/tracking/presentation/pages/tracking_page.dart';
import 'package:jiti_app/features/client/history/presentation/pages/history_page.dart';
import 'package:jiti_app/features/driver/home/presentation/pages/driver_home_page.dart';

final getIt = GetIt.instance;

void setupDI() {
  getIt.registerLazySingleton<ApiClient>(() => ApiClient());
  getIt.registerLazySingleton<SocketService>(() => SocketService());
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupDI();
  runApp(const JitiApp());
}

class JitiApp extends StatelessWidget {
  const JitiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiClient>.value(value: getIt<ApiClient>()),
        RepositoryProvider<SocketService>.value(value: getIt<SocketService>()),
      ],
      child: BlocProvider(
        create: (context) => AuthBloc(apiClient: getIt<ApiClient>())..add(CheckAuth()),
        child: MaterialApp(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: const AuthWrapper(),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          // Connect socket when authenticated
          context.read<SocketService>().connect();
        }
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: const Color(AppColors.error),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is AuthLoading) {
          return const _SplashScreen();
        }
        if (state is AuthCodeSent) {
          return VerificationPage(phone: state.phone);
        }
        if (state is AuthNeedsRegistration) {
          return const RegistrationPage();
        }
        if (state is AuthAuthenticated) {
          if (state.user.isDriver) {
            return DriverHomePage(
              onHistoryTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _wrapProviders(const HistoryPage(title: 'История поездок')))),
              onLogout: () => context.read<AuthBloc>().add(Logout()),
            );
          }
          return BlocProvider(
            create: (_) => ClientHomeCubit(
              apiClient: getIt<ApiClient>(),
              socketService: getIt<SocketService>(),
            ),
            child: _ClientFlowWrapper(user: state.user),
          );
        }
        // Default: login
        return const LoginPage();
      },
    );
  }

  Widget _wrapProviders(Widget child) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiClient>.value(value: getIt<ApiClient>()),
        RepositoryProvider<SocketService>.value(value: getIt<SocketService>()),
      ],
      child: child,
    );
  }
}

class _ClientFlowWrapper extends StatefulWidget {
  final UserModel user;
  const _ClientFlowWrapper({required this.user});

  @override
  State<_ClientFlowWrapper> createState() => _ClientFlowWrapperState();
}

class _ClientFlowWrapperState extends State<_ClientFlowWrapper> {
  // ignore: unused_field
  String? _activeOrderId;

  @override
  void initState() {
    super.initState();
    _checkActiveOrder();
  }

  Future<void> _checkActiveOrder() async {
    try {
      final api = getIt<ApiClient>();
      final res = await api.get(ApiConstants.activeOrder);
      if (res.data != null && res.data is Map) {
        final order = OrderModel.fromJson(res.data);
        setState(() => _activeOrderId = order.id);
        _navigateToOrderFlow(order);
      }
    } catch (_) {}
  }

  void _navigateToOrderFlow(OrderModel order) {
    if (order.status == 'searching' || order.status == 'has_responses') {
      _openResponses(order.id);
    } else if (order.status == 'driver_selected' || order.status == 'in_progress') {
      _openTracking(order.id);
    }
  }

  void _openResponses(String orderId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ApiClient>.value(value: getIt<ApiClient>()),
            RepositoryProvider<SocketService>.value(value: getIt<SocketService>()),
          ],
          child: OrderResponsesPage(orderId: orderId),
        ),
      ),
    );
    if (result == 'tracking') {
      _openTracking(orderId);
    } else {
      setState(() => _activeOrderId = null);
    }
  }

  void _openTracking(String orderId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ApiClient>.value(value: getIt<ApiClient>()),
            RepositoryProvider<SocketService>.value(value: getIt<SocketService>()),
          ],
          child: TrackingPage(orderId: orderId),
        ),
      ),
    );
    setState(() => _activeOrderId = null);
  }

  @override
  Widget build(BuildContext context) {
    return ClientHomePage(
      onOrderCreated: () {
        final state = context.read<ClientHomeCubit>().state;
        if (state is ClientOrderCreated) {
          setState(() => _activeOrderId = state.order.id);
          _openResponses(state.order.id);
        }
      },
      onHistoryTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiRepositoryProvider(
              providers: [
                RepositoryProvider<ApiClient>.value(value: getIt<ApiClient>()),
                RepositoryProvider<SocketService>.value(value: getIt<SocketService>()),
              ],
              child: const HistoryPage(),
            ),
          ),
        );
      },
      onLogout: () => context.read<AuthBloc>().add(Logout()),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(AppColors.primary), Color(AppColors.accent)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.local_taxi_rounded, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.appName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Color(AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
