import 'package:flutter/material.dart';
import '../constants/constants.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const GlassCard({super.key, required this.child, this.padding, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(AppColors.surface).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(AppColors.border).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(AppColors.primary).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.color.withValues(alpha: 0.3)),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          color: config.color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  _StatusConfig _getConfig(String status) {
    switch (status) {
      case 'created':
      case 'searching':
        return _StatusConfig('Поиск', const Color(AppColors.warning));
      case 'has_responses':
        return _StatusConfig('Есть отклики', const Color(AppColors.accent));
      case 'driver_selected':
        return _StatusConfig('Водитель выбран', const Color(AppColors.primaryLight));
      case 'in_progress':
        return _StatusConfig('В пути', const Color(AppColors.primary));
      case 'completed':
        return _StatusConfig('Завершён', const Color(AppColors.success));
      case 'cancelled':
        return _StatusConfig('Отменён', const Color(AppColors.error));
      default:
        return _StatusConfig(status, const Color(AppColors.textSecondary));
    }
  }
}

class _StatusConfig {
  final String label;
  final Color color;
  _StatusConfig(this.label, this.color);
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  const LoadingOverlay({super.key, required this.isLoading, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black45,
            child: const Center(
              child: CircularProgressIndicator(color: Color(AppColors.primary)),
            ),
          ),
      ],
    );
  }
}
