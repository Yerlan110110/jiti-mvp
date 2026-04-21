import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jiti_app/core/constants/constants.dart';
import 'package:jiti_app/features/auth/presentation/bloc/auth_bloc.dart';

class VerificationPage extends StatefulWidget {
  final String phone;
  const VerificationPage({super.key, required this.phone});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  void _onDigitEntered(int index) {
    if (_controllers[index].text.isNotEmpty && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_controllers.every((c) => c.text.isNotEmpty)) {
      final code = _controllers.map((c) => c.text).join();
      context.read<AuthBloc>().add(VerifyCode(widget.phone, code));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.read<AuthBloc>().add(CheckAuth()),
        ),
        title: const Text(AppStrings.enterCode),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.mark_email_read_rounded, size: 64, color: Color(AppColors.primary)),
            const SizedBox(height: 24),
            Text(
              'Код отправлен на\n${widget.phone}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(AppColors.textSecondary)),
            ),
            const SizedBox(height: 8),
            Text('(Mock-код: 1234)', style: TextStyle(color: const Color(AppColors.accent).withValues(alpha: 0.7), fontSize: 13)),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                return Container(
                  width: 64, height: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: const Color(AppColors.surfaceLight),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: const Color(AppColors.border).withValues(alpha: 0.5))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(AppColors.primary), width: 2)),
                    ),
                    onChanged: (_) => _onDigitEntered(i),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                if (state is AuthLoading) {
                  return const CircularProgressIndicator(color: Color(AppColors.primary));
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}
