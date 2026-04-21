import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jiti_app/core/constants/constants.dart';
import 'package:jiti_app/features/auth/presentation/bloc/auth_bloc.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _nameController = TextEditingController();
  final _carBrandController = TextEditingController();
  final _carModelController = TextEditingController();
  final _carColorController = TextEditingController();
  final _carPlateController = TextEditingController();
  String _selectedRole = 'client';

  @override
  void dispose() {
    _nameController.dispose();
    _carBrandController.dispose();
    _carModelController.dispose();
    _carColorController.dispose();
    _carPlateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.registration)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: AppStrings.name,
                prefixIcon: Icon(Icons.person_rounded, color: Color(AppColors.primary)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(AppStrings.selectRole, style: TextStyle(color: Color(AppColors.textSecondary), fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _RoleCard(icon: Icons.person_rounded, label: AppStrings.client, isSelected: _selectedRole == 'client', onTap: () => setState(() => _selectedRole = 'client'))),
                const SizedBox(width: 16),
                Expanded(child: _RoleCard(icon: Icons.directions_car_rounded, label: AppStrings.driver, isSelected: _selectedRole == 'driver', onTap: () => setState(() => _selectedRole = 'driver'))),
              ],
            ),
            if (_selectedRole == 'driver') ...[
              const SizedBox(height: 24),
              const Text('Данные автомобиля', style: TextStyle(color: Color(AppColors.textSecondary), fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              TextField(controller: _carBrandController, decoration: const InputDecoration(hintText: AppStrings.carBrand), style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              TextField(controller: _carModelController, decoration: const InputDecoration(hintText: AppStrings.carModel), style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              TextField(controller: _carColorController, decoration: const InputDecoration(hintText: AppStrings.carColor), style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              TextField(controller: _carPlateController, decoration: InputDecoration(hintText: '${AppStrings.carPlate} *'), style: const TextStyle(color: Colors.white)),
            ],
            const SizedBox(height: 32),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                return ElevatedButton(
                  onPressed: state is AuthLoading ? null : () {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите имя'))); return; }
                    if (_selectedRole == 'driver' && _carPlateController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите госномер'))); return; }
                    context.read<AuthBloc>().add(Register(name: name, role: _selectedRole, carBrand: _carBrandController.text.trim().isNotEmpty ? _carBrandController.text.trim() : null, carModel: _carModelController.text.trim().isNotEmpty ? _carModelController.text.trim() : null, carColor: _carColorController.text.trim().isNotEmpty ? _carColorController.text.trim() : null, carPlate: _carPlateController.text.trim().isNotEmpty ? _carPlateController.text.trim() : null));
                  },
                  child: state is AuthLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text(AppStrings.register),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _RoleCard({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isSelected ? const Color(AppColors.primary).withValues(alpha: 0.15) : const Color(AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(AppColors.primary) : const Color(AppColors.border), width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: isSelected ? const Color(AppColors.primary) : const Color(AppColors.textHint)),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: isSelected ? const Color(AppColors.primary) : const Color(AppColors.textSecondary), fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
