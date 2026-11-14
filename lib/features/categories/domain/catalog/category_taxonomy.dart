import '../../../../shared/domain/currency/currency_catalog.dart';

class CategoryTaxonomyEntry {
  const CategoryTaxonomyEntry({
    required this.categoryName,
    required this.description,
    required this.aliases,
  });

  final String categoryName;
  final String description;
  final List<String> aliases;
}

abstract final class CategoryTaxonomy {
  static const entries = <CategoryTaxonomyEntry>[
    CategoryTaxonomyEntry(
      categoryName: 'Groceries',
      description:
          'Food staples and grocery items such as milk, bread, eggs, rice, '
          'vegetables, fruit, meat, and drinking water.',
      aliases: <String>[
        'milk',
        'dairy',
        'bread',
        'eggs',
        'drinking water',
        'rice',
        'flour',
        'sugar',
        'vegetables',
        'fruit',
        'fruits',
        'meat',
        'chicken',
        'groceries',
        'grocery',
        'supermarket',
        'حليب',
        'لبن',
        'خبز',
        'بيض',
        'ماء',
        'مياه شرب',
        'رز',
        'ارز',
        'دقيق',
        'سكر',
        'خضره',
        'خضار',
        'فواكه',
        'لحم',
        'دجاج',
        'بقاله',
        'مواد غذائيه',
        'سوبر ماركت',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Restaurant',
      description:
          'Prepared meals from restaurants, takeaway shops, and food delivery.',
      aliases: <String>[
        'restaurant',
        'takeaway',
        'food delivery',
        'meal',
        'dinner',
        'lunch',
        'مطعم',
        'وجبه',
        'عشاء',
        'غداء',
        'اكل جاهز',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Coffee',
      description: 'Coffee, tea, and drinks bought from a cafe or coffee shop.',
      aliases: <String>[
        'cafe',
        'coffee shop',
        'coffee',
        'latte',
        'espresso',
        'مقهي',
        'كافيه',
        'قهوه',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Home',
      description:
          'Non-food household supplies, cleaning products, home tools, and '
          'home accessories.',
      aliases: <String>[
        'detergent',
        'washing powder',
        'cleaning supplies',
        'cleaner',
        'bleach',
        'broom',
        'kitchen tools',
        'home accessories',
        'household supplies',
        'مسحوق غسيل',
        'منظف',
        'كلور',
        'مكنسه',
        'ادوات مطبخ',
        'مستلزمات منزليه',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Beauty',
      description:
          'Personal-care products, toiletries, cosmetics, and grooming.',
      aliases: <String>[
        'shampoo',
        'toothpaste',
        'cosmetics',
        'personal care',
        'toiletries',
        'شامبو',
        'معجون اسنان',
        'مستحضرات شخصيه',
        'مستحضرات تجميل',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Bills',
      description:
          'Household utility bills such as electricity, water service, and gas.',
      aliases: <String>[
        'electricity',
        'electricity bill',
        'water bill',
        'gas bill',
        'utilities',
        'utility bill',
        'كهرباء',
        'فاتوره كهرباء',
        'فاتوره مياه',
        'فاتوره ماء',
        'غاز',
        'فاتوره غاز',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Phone',
      description: 'Mobile recharge, airtime, and phone bills.',
      aliases: <String>[
        'mobile recharge',
        'phone recharge',
        'airtime',
        'phone bill',
        'credit recharge',
        'تعبئه رصيد',
        'عبيت رصيد',
        'شحن رصيد',
        'رصيد',
        'فاتوره هاتف',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Internet',
      description: 'Home or mobile internet subscriptions and data packages.',
      aliases: <String>[
        'internet subscription',
        'internet bill',
        'data package',
        'wifi',
        'اشتراك انترنت',
        'فاتوره انترنت',
        'باقه نت',
        'خلصت النت',
        'النت',
        'انترنت',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Fuel',
      description: 'Vehicle fuel such as petrol, gasoline, and diesel.',
      aliases: <String>[
        'fuel',
        'petrol',
        'gasoline',
        'diesel',
        'بنزين',
        'وقود',
        'ديزل',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Pharmacy',
      description: 'Medicine and pharmacy purchases.',
      aliases: <String>[
        'medicine',
        'medication',
        'pharmacy',
        'دواء',
        'دوا',
        'صيدليه',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Salary',
      description: 'Salary, wages, and regular employment income.',
      aliases: <String>['salary', 'paycheck', 'wage', 'راتب', 'مرتب'],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Freelance',
      description: 'Income earned from freelance or independent work.',
      aliases: <String>[
        'freelance',
        'freelance payment',
        'independent work',
        'شغل حر',
        'فريلانس',
        'مقابل شغل',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Business Revenue',
      description: 'Revenue from business operations, projects, or sales.',
      aliases: <String>[
        'business revenue',
        'business income',
        'project revenue',
        'مبيعات',
        'دخل مشروع',
        'ايراد مشروع',
        'إيراد مشروع',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Gift',
      description: 'Money received as a personal gift.',
      aliases: <String>['gift received', 'gift', 'هدية', 'هديه', 'عطاني'],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Allowance',
      description: 'Personal allowance or regular family support.',
      aliases: <String>['allowance', 'مصروف'],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Refund',
      description: 'Money returned for a cancelled or returned purchase.',
      aliases: <String>[
        'refund',
        'returned payment',
        'استرداد',
        'رجعولي',
        'رجعولي فلوسي',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Reimbursement',
      description: 'Repayment of an expense paid on another party’s behalf.',
      aliases: <String>['reimbursement', 'expense repayment', 'تعويض مصروف'],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Sale Proceeds',
      description: 'Money received from selling an owned item.',
      aliases: <String>[
        'sale proceeds',
        'sold item',
        'sold phone',
        'بعت',
        'بعت الحاجة',
        'بعت التلفون',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Rental Income',
      description: 'Income received from renting property or another asset.',
      aliases: <String>[
        'rental income',
        'rent received',
        'دخل ايجار',
        'دخل إيجار',
        'ايجار',
        'إيجار',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Government Support',
      description: 'Government grant, benefit, or support payment.',
      aliases: <String>[
        'government support',
        'government grant',
        'grant',
        'منحة',
        'منحه',
        'دعم',
        'نزلت المنحة',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Scholarship',
      description: 'Education scholarship or study grant.',
      aliases: <String>['scholarship', 'study grant', 'منحة دراسية'],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Prize',
      description: 'Prize or competition winnings.',
      aliases: <String>['prize', 'winnings', 'جائزة', 'جائزه'],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Loan Proceeds',
      description:
          'Liability-related cash received from a loan; not earned income.',
      aliases: <String>[
        'loan proceeds',
        'loan received',
        'loan',
        'قرض',
        'وصل القرض',
        'وصلني قرض',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Transport',
      description: 'General transport and public transit costs.',
      aliases: <String>[
        'transport',
        'bus',
        'public transport',
        'مواصلات',
        'حافله',
      ],
    ),
    CategoryTaxonomyEntry(
      categoryName: 'Taxi',
      description: 'Taxi and ride-hailing trips.',
      aliases: <String>['taxi', 'uber', 'careem', 'تاكسي'],
    ),
  ];

  static CategoryTaxonomyEntry? forCategoryName(String categoryName) {
    final normalizedName = normalize(categoryName);
    for (final entry in entries) {
      if (normalize(entry.categoryName) == normalizedName) {
        return entry;
      }
    }
    return null;
  }

  static CategoryTaxonomyEntry? forHint(String hint) {
    final normalizedHint = normalize(hint);
    for (final entry in entries) {
      if (normalize(entry.categoryName) == normalizedHint ||
          entry.aliases.any((alias) => normalize(alias) == normalizedHint)) {
        return entry;
      }
    }
    return null;
  }

  static String normalize(String value) {
    return CurrencyCatalog.normalizeText(value)
        .replaceAll(RegExp(r'[^a-zA-Z0-9\u0600-\u06FF]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> safeSemanticDescriptions(Iterable<String> names) {
    final available = names.map(normalize).toSet();
    return entries
        .where((entry) => available.contains(normalize(entry.categoryName)))
        .map(
          (entry) =>
              '${entry.categoryName}: ${entry.description} '
              'Examples: ${entry.aliases.take(8).join(', ')}',
        )
        .toList(growable: false);
  }
}
