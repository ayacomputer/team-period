import 'package:flutter/material.dart';
import '../models/cycle_summary.dart';

/// Central place for all phase-specific colours and icons.
/// Import this anywhere you need phase styling.

class PhaseTheme {
  const PhaseTheme._();

  static Color primaryColor(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.period:
        return const Color(0xFFE11D48); // rose-600
      case CyclePhase.fertile:
        return const Color(0xFF16A34A); // green-600
      case CyclePhase.ovulation:
        return const Color(0xFF7C3AED); // violet-600
      case CyclePhase.follicular:
        return const Color(0xFFEA580C); // orange-600
      case CyclePhase.luteal:
        return const Color(0xFF475569); // slate-600
    }
  }

  static Color lightColor(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.period:
        return const Color(0xFFFFF1F2); // rose-50
      case CyclePhase.fertile:
        return const Color(0xFFF0FDF4); // green-50
      case CyclePhase.ovulation:
        return const Color(0xFFF5F3FF); // violet-50
      case CyclePhase.follicular:
        return const Color(0xFFFFF7ED); // orange-50
      case CyclePhase.luteal:
        return const Color(0xFFF8FAFC); // slate-50
    }
  }

  static Color accentColor(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.period:
        return const Color(0xFFFDA4AF); // rose-300
      case CyclePhase.fertile:
        return const Color(0xFF86EFAC); // green-300
      case CyclePhase.ovulation:
        return const Color(0xFFC4B5FD); // violet-300
      case CyclePhase.follicular:
        return const Color(0xFFFDBA74); // orange-300
      case CyclePhase.luteal:
        return const Color(0xFF94A3B8); // slate-400
    }
  }
}
