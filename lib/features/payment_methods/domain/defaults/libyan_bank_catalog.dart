import '../entities/libyan_bank_definition.dart';

/// Canonical Libyan bank names and separate natural-language aliases.
///
/// These are identity labels for account resolution only. Presence in this
/// catalog never claims a live bank connection or payment integration.
abstract final class LibyanBankCatalog {
  static const banks = <LibyanBankDefinition>[
    LibyanBankDefinition(
      id: 'national_union',
      displayName: 'مصرف الاتحاد الوطني',
      aliases: ['الاتحاد الوطني', 'National Union Bank'],
    ),
    LibyanBankDefinition(
      id: 'imaar',
      displayName: 'مصرف إعمار',
      aliases: ['إعمار', 'اعمار', 'Imaar Bank'],
    ),
    LibyanBankDefinition(
      id: 'islamic_finance',
      displayName: 'مصرف التمويل الإسلامي',
      aliases: ['التمويل الإسلامي', 'Islamic Finance Bank'],
    ),
    LibyanBankDefinition(
      id: 'daman_islamic',
      displayName: 'مصرف الضمان الإسلامي',
      aliases: ['الضمان الإسلامي', 'Daman Islamic Bank'],
    ),
    LibyanBankDefinition(
      id: 'seraj_islamic',
      displayName: 'مصرف السراج الإسلامي',
      aliases: ['السراج الإسلامي', 'Al Seraj Islamic Bank'],
    ),
    LibyanBankDefinition(
      id: 'jumhouria',
      displayName: 'مصرف الجمهورية',
      aliases: ['الجمهورية', 'Jumhouria Bank'],
    ),
    LibyanBankDefinition(
      id: 'commercial_national',
      displayName: 'المصرف التجاري الوطني',
      aliases: ['التجاري', 'التجاري الوطني', 'Commercial National Bank', 'NCB'],
    ),
    LibyanBankDefinition(
      id: 'wahda',
      displayName: 'مصرف الوحدة',
      aliases: ['الوحدة', 'Wahda Bank'],
    ),
    LibyanBankDefinition(
      id: 'sahara',
      displayName: 'مصرف الصحارى',
      aliases: ['الصحارى', 'Sahara Bank'],
    ),
    LibyanBankDefinition(
      id: 'north_africa',
      displayName: 'مصرف شمال أفريقيا',
      aliases: ['شمال أفريقيا', 'North Africa Bank'],
    ),
    LibyanBankDefinition(
      id: 'commerce_development',
      displayName: 'مصرف التجارة والتنمية',
      aliases: ['التجارة والتنمية', 'Trade and Development Bank', 'TDB'],
    ),
    LibyanBankDefinition(
      id: 'alaman',
      displayName: 'مصرف الامان للتجارة والاستثمار',
      aliases: ['مصرف الأمان', 'الأمان', 'الامان', 'Al Aman Bank'],
    ),
    LibyanBankDefinition(
      id: 'atib',
      displayName: 'مصرف السراي للتجارة والاستثمار',
      aliases: ['السراي', 'ATIB', 'Assaray Bank'],
    ),
    LibyanBankDefinition(
      id: 'united_commerce_investment',
      displayName: 'المصرف المتحد للتجارة والاستثمار',
      aliases: ['المتحد', 'United Bank for Commerce and Investment'],
    ),
    LibyanBankDefinition(
      id: 'arab_ejmaa',
      displayName: 'مصرف الأجماع العربي',
      aliases: ['الأجماع العربي', 'الاجماع العربي', 'Arab Ejmaa Bank'],
    ),
    LibyanBankDefinition(
      id: 'libyan_foreign',
      displayName: 'المصرف الليبي الخارجي',
      aliases: ['الليبي الخارجي', 'Libyan Foreign Bank'],
    ),
    LibyanBankDefinition(
      id: 'libyan_islamic',
      displayName: 'المصرف الإسلامي الليبي',
      aliases: ['الإسلامي', 'الاسلامي', 'Libyan Islamic Bank'],
    ),
    LibyanBankDefinition(
      id: 'nuran',
      displayName: 'مصرف النوران',
      aliases: ['النوران', 'Nuran Bank'],
    ),
    LibyanBankDefinition(
      id: 'yaqeen',
      displayName: 'مصرف اليقين',
      aliases: ['اليقين', 'Yaqeen Bank'],
    ),
    LibyanBankDefinition(
      id: 'andalus',
      displayName: 'مصرف الأندلس',
      aliases: ['الأندلس', 'الاندلس', 'Andalus Bank'],
    ),
    LibyanBankDefinition(
      id: 'tadamon',
      displayName: 'مصرف التضامن',
      aliases: ['التضامن', 'Tadamon Bank'],
    ),
    LibyanBankDefinition(
      id: 'arab_islamic_investment',
      displayName: 'مصرف الاستثمار العربي الإسلامي',
      aliases: ['الاستثمار العربي', 'Arab Islamic Investment Bank'],
    ),
    LibyanBankDefinition(
      id: 'mediterranean',
      displayName: 'مصرف المتوسط',
      aliases: ['المتوسط', 'Mediterranean Bank'],
    ),
    LibyanBankDefinition(
      id: 'waha',
      displayName: 'مصرف الواحة',
      aliases: ['الواحة', 'Waha Bank'],
    ),
    LibyanBankDefinition(
      id: 'wafa',
      displayName: 'مصرف الوفاء',
      aliases: ['الوفاء', 'Wafa Bank'],
    ),
    LibyanBankDefinition(
      id: 'first_gulf_libya',
      displayName: 'مصرف الخليج الأول الليبي',
      aliases: ['الخليج الأول', 'First Gulf Libya Bank'],
    ),
  ];

  static LibyanBankDefinition? matchAlias(String input) {
    for (final bank in banks) {
      if (bank.matchesText(input)) {
        return bank;
      }
    }
    return null;
  }
}
