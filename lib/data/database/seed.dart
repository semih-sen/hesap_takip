import 'package:flutter/material.dart' show Icons;

import 'tables/enums.dart';

/// A default category definition applied on first database creation.
///
/// `name` is user-facing DB content, so Turkish is correct here (the code-in-
/// English / UI-in-Turkish rule applies to widget strings, not seeded data).
class SeedCategory {
  const SeedCategory({
    required this.name,
    required this.type,
    required this.colorValue,
    required this.iconCodePoint,
  });

  final String name;
  final CategoryType type;
  final int colorValue; // ARGB int
  final int iconCodePoint;
}

/// Default Turkish categories seeded once, in `AppDatabase.onCreate`.
///
/// `Icons.*.codePoint` is read at runtime (not a const expression), so this is
/// a top-level `final` rather than a `const` list. List order defines each
/// category's `sortOrder`.
final List<SeedCategory> kDefaultCategories = <SeedCategory>[
  // ----- Income -----
  SeedCategory(
    name: 'Maaş',
    type: CategoryType.income,
    colorValue: 0xFF43A047,
    iconCodePoint: Icons.payments.codePoint,
  ),
  SeedCategory(
    name: 'Ek Gelir',
    type: CategoryType.income,
    colorValue: 0xFF66BB6A,
    iconCodePoint: Icons.savings.codePoint,
  ),
  SeedCategory(
    name: 'Yatırım/Faiz',
    type: CategoryType.income,
    colorValue: 0xFF26A69A,
    iconCodePoint: Icons.trending_up.codePoint,
  ),
  SeedCategory(
    name: 'Hediye',
    type: CategoryType.income,
    colorValue: 0xFFEC407A,
    iconCodePoint: Icons.card_giftcard.codePoint,
  ),
  SeedCategory(
    name: 'Diğer Gelir',
    type: CategoryType.income,
    colorValue: 0xFF9CCC65,
    iconCodePoint: Icons.attach_money.codePoint,
  ),

  // ----- Expense -----
  SeedCategory(
    name: 'Market',
    type: CategoryType.expense,
    colorValue: 0xFFEF6C00,
    iconCodePoint: Icons.shopping_cart.codePoint,
  ),
  SeedCategory(
    name: 'Kira',
    type: CategoryType.expense,
    colorValue: 0xFF8E24AA,
    iconCodePoint: Icons.home.codePoint,
  ),
  SeedCategory(
    name: 'Faturalar',
    type: CategoryType.expense,
    colorValue: 0xFF00897B,
    iconCodePoint: Icons.receipt_long.codePoint,
  ),
  SeedCategory(
    name: 'Ulaşım',
    type: CategoryType.expense,
    colorValue: 0xFF3949AB,
    iconCodePoint: Icons.directions_bus.codePoint,
  ),
  SeedCategory(
    name: 'Yeme-İçme',
    type: CategoryType.expense,
    colorValue: 0xFFD81B60,
    iconCodePoint: Icons.restaurant.codePoint,
  ),
  SeedCategory(
    name: 'Sağlık',
    type: CategoryType.expense,
    colorValue: 0xFFE53935,
    iconCodePoint: Icons.local_hospital.codePoint,
  ),
  SeedCategory(
    name: 'Eğlence',
    type: CategoryType.expense,
    colorValue: 0xFF5E35B1,
    iconCodePoint: Icons.movie.codePoint,
  ),
  SeedCategory(
    name: 'Giyim',
    type: CategoryType.expense,
    colorValue: 0xFF6D4C41,
    iconCodePoint: Icons.checkroom.codePoint,
  ),
  SeedCategory(
    name: 'Eğitim',
    type: CategoryType.expense,
    colorValue: 0xFF1E88E5,
    iconCodePoint: Icons.school.codePoint,
  ),
  SeedCategory(
    name: 'Diğer Gider',
    type: CategoryType.expense,
    colorValue: 0xFF757575,
    iconCodePoint: Icons.category.codePoint,
  ),
];

class SeedCurrency {
  const SeedCurrency({
    required this.code,
    required this.symbol,
    required this.minorDigits,
    required this.symbolOnLeft,
  });

  final String code;
  final String symbol;
  final int minorDigits;
  final bool symbolOnLeft;
}

const List<SeedCurrency> kDefaultCurrencies = <SeedCurrency>[
  SeedCurrency(
    code: 'TRY',
    symbol: '₺',
    minorDigits: 2,
    symbolOnLeft: false,
  ),
  SeedCurrency(
    code: 'USD',
    symbol: r'$',
    minorDigits: 2,
    symbolOnLeft: true,
  ),
  SeedCurrency(
    code: 'EUR',
    symbol: '€',
    minorDigits: 2,
    symbolOnLeft: true,
  ),
  SeedCurrency(
    code: 'GBP',
    symbol: '£',
    minorDigits: 2,
    symbolOnLeft: true,
  ),
  SeedCurrency(
    code: 'JPY',
    symbol: '¥',
    minorDigits: 0,
    symbolOnLeft: true,
  ),
];
