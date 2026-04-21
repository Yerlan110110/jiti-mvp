import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jiti_app/core/constants/constants.dart';
import 'package:jiti_app/features/auth/presentation/bloc/auth_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(AppColors.primary), Color(AppColors.accent)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(AppColors.primary).withValues(alpha: 0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.local_taxi_rounded, size: 50, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    AppStrings.appName,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Поездки по вашим правилам',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(AppColors.textSecondary),
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  AppStrings.phone,
                  style: TextStyle(
                    color: Color(AppColors.textSecondary),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: const [_KazakhstanPhoneFormatter()],
                  style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 1),
                  decoration: const InputDecoration(
                    hintText: '+7 (___) ___-__-__',
                    prefixIcon: Icon(Icons.phone_rounded, color: Color(AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 24),
                BlocConsumer<AuthBloc, AuthState>(
                  listener: (context, state) {
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
                    return ElevatedButton(
                      onPressed: state is AuthLoading
                          ? null
                          : () {
                              final phone = _KazakhstanPhoneFormatter.normalize(
                                _phoneController.text,
                              );
                              if (phone.isNotEmpty) {
                                context.read<AuthBloc>().add(SendCode(phone));
                              }
                            },
                      child: state is AuthLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(AppStrings.sendCode),
                    );
                  },
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KazakhstanPhoneFormatter extends TextInputFormatter {
  const _KazakhstanPhoneFormatter();

  static final RegExp _nonDigits = RegExp(r'\D');

  static String normalize(String value) {
    final digits = value.replaceAll(_nonDigits, '');
    if (digits.isEmpty) {
      return '';
    }

    var localDigits = digits;
    if (localDigits.startsWith('7') || localDigits.startsWith('8')) {
      localDigits = localDigits.substring(1);
    }

    if (localDigits.length > 10) {
      localDigits = localDigits.substring(0, 10);
    }

    return '+7$localDigits';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalize(newValue.text);
    if (normalized.isEmpty) {
      return const TextEditingValue();
    }

    final localDigits = normalized.substring(2);
    final formatted = _format(localDigits);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _format(String localDigits) {
    final buffer = StringBuffer('+7');
    if (localDigits.isEmpty) {
      return buffer.toString();
    }

    buffer.write(' (');

    if (localDigits.length <= 3) {
      buffer.write(localDigits);
      return buffer.toString();
    }

    buffer.write(localDigits.substring(0, 3));
    buffer.write(') ');

    if (localDigits.length <= 6) {
      buffer.write(localDigits.substring(3));
      return buffer.toString();
    }

    buffer.write(localDigits.substring(3, 6));

    if (localDigits.length <= 8) {
      buffer.write('-${localDigits.substring(6)}');
      return buffer.toString();
    }

    buffer.write('-${localDigits.substring(6, 8)}');
    buffer.write('-${localDigits.substring(8)}');
    return buffer.toString();
  }
}
