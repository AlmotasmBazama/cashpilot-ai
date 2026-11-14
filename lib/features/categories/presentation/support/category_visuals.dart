import 'package:flutter/material.dart';

abstract final class CategoryVisuals {
  static IconData iconForKey(String key) {
    return switch (key) {
      'food' || 'restaurant' || 'groceries' => Icons.restaurant_rounded,
      'coffee' => Icons.local_cafe_rounded,
      'transport' || 'taxi' => Icons.directions_car_rounded,
      'fuel' => Icons.local_gas_station_rounded,
      'shopping' || 'clothing' => Icons.shopping_bag_rounded,
      'entertainment' || 'gaming' => Icons.sports_esports_rounded,
      'travel' || 'hotel' => Icons.flight_takeoff_rounded,
      'bills' || 'subscription' => Icons.receipt_long_rounded,
      'internet' || 'phone' => Icons.wifi_rounded,
      'rent' || 'home' => Icons.home_rounded,
      'insurance' => Icons.health_and_safety_rounded,
      'healthcare' || 'pharmacy' => Icons.local_hospital_rounded,
      'education' => Icons.school_rounded,
      'electronics' => Icons.devices_rounded,
      'pets' => Icons.pets_rounded,
      'charity' => Icons.volunteer_activism_rounded,
      'taxes' => Icons.account_balance_rounded,
      'gift' ||
      'bonus' ||
      'cashback' ||
      'refund' => Icons.card_giftcard_rounded,
      'sports' => Icons.fitness_center_rounded,
      'beauty' => Icons.spa_rounded,
      'salary' || 'freelance' => Icons.work_rounded,
      'investment' || 'interest' => Icons.trending_up_rounded,
      'rental_income' => Icons.real_estate_agent_rounded,
      'transfer' => Icons.swap_horiz_rounded,
      _ => Icons.category_rounded,
    };
  }

  static const iconKeys = [
    'food',
    'coffee',
    'transport',
    'shopping',
    'bills',
    'home',
    'salary',
    'investment',
    'gift',
    'transfer',
    'other',
  ];

  static const colors = [
    0xFF4F46E5,
    0xFF7C3AED,
    0xFF3B82F6,
    0xFF22C55E,
    0xFFEF4444,
    0xFFF59E0B,
    0xFFEC4899,
    0xFF64748B,
  ];
}
