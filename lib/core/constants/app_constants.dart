import 'package:flutter/material.dart';

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
}

class AppBorderRadius {
  static const double sm = 6.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;

  static BorderRadius get smBorder => BorderRadius.circular(sm);
  static BorderRadius get mdBorder => BorderRadius.circular(md);
  static BorderRadius get lgBorder => BorderRadius.circular(lg);
  static BorderRadius get xlBorder => BorderRadius.circular(xl);
}

class AppConstants {
  static const List<String> fuelTypes = [
    'Pertalite',
    'Pertamax',
    'Pertamax Turbo',
  ];

  static const Map<String, String> maintenanceTypes = {
    'Ganti Oli': 'Ganti Oli Mesin',
    'Ganti Filter Udara': 'Filter Udara',
    'Servis Rem': 'Rem (Kampas/Piringan)',
    'Kuras Radiator': 'Kuras Radiator (Coolant)',
    'Ganti Aki': 'Ganti Aki Baru',
  };

  // Default maintenance type for new entries
  static const String defaultMaintenanceType = 'Ganti Oli';
}
