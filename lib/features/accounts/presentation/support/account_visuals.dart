import 'package:flutter/material.dart';

import '../../domain/enums/account_type.dart';

class AccountIconOption {
  const AccountIconOption({
    required this.key,
    required this.icon,
    required this.label,
  });

  final String key;
  final IconData icon;
  final String label;
}

abstract final class AccountVisuals {
  static const colors = [
    0xFF4F46E5,
    0xFF7C3AED,
    0xFF3B82F6,
    0xFF22C55E,
    0xFFF59E0B,
    0xFFEF4444,
    0xFFEC4899,
    0xFF475569,
  ];

  static const icons = [
    AccountIconOption(
      key: 'wallet',
      icon: Icons.account_balance_wallet_rounded,
      label: 'Wallet',
    ),
    AccountIconOption(key: 'cash', icon: Icons.payments_rounded, label: 'Cash'),
    AccountIconOption(
      key: 'bank',
      icon: Icons.account_balance_rounded,
      label: 'Bank',
    ),
    AccountIconOption(
      key: 'card',
      icon: Icons.credit_card_rounded,
      label: 'Card',
    ),
    AccountIconOption(
      key: 'savings',
      icon: Icons.savings_rounded,
      label: 'Savings',
    ),
    AccountIconOption(
      key: 'investment',
      icon: Icons.trending_up_rounded,
      label: 'Investment',
    ),
    AccountIconOption(
      key: 'crypto',
      icon: Icons.currency_bitcoin_rounded,
      label: 'Crypto',
    ),
  ];

  static String defaultIconKey(AccountType type) {
    return switch (type) {
      AccountType.cash => 'cash',
      AccountType.bank => 'bank',
      AccountType.creditCard || AccountType.debitCard => 'card',
      AccountType.savings => 'savings',
      AccountType.investment => 'investment',
      AccountType.crypto => 'crypto',
      AccountType.digitalWallet || AccountType.other => 'wallet',
    };
  }

  static IconData iconForKey(String key) {
    return icons
        .firstWhere((option) => option.key == key, orElse: () => icons.first)
        .icon;
  }
}
