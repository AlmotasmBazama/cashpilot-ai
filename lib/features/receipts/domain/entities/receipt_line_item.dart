import 'package:decimal/decimal.dart';
import 'package:uuid/uuid.dart';

import '../../../categories/domain/entities/category_suggestion.dart';
import '../enums/receipt_warning.dart';

class ReceiptLineItem {
  const ReceiptLineItem({
    required this.id,
    required this.receiptId,
    required this.description,
    required this.normalizedDescription,
    required this.categoryConfidence,
    required this.categorySuggestionSource,
    required this.sortOrder,
    this.quantity,
    this.unit,
    this.unitPrice,
    this.discount,
    this.tax,
    this.totalPrice,
    this.categoryId,
    this.categoryHint,
    this.categoryAlternatives = const <String>[],
    this.skuOrBarcode,
    this.warnings = const <ReceiptWarning>[],
  });

  factory ReceiptLineItem.create({
    required String receiptId,
    required String description,
    required String normalizedDescription,
    int sortOrder = 0,
    Decimal? quantity,
    String? unit,
    Decimal? unitPrice,
    Decimal? discount,
    Decimal? tax,
    Decimal? totalPrice,
    String? categoryId,
    String? categoryHint,
    int categoryConfidence = 0,
    CategorySuggestionSource categorySuggestionSource =
        CategorySuggestionSource.fallback,
    List<String> categoryAlternatives = const <String>[],
    String? skuOrBarcode,
    List<ReceiptWarning> warnings = const <ReceiptWarning>[],
    String? id,
  }) {
    return ReceiptLineItem(
      id: id ?? const Uuid().v7(),
      receiptId: receiptId,
      description: description.trim(),
      normalizedDescription: normalizedDescription.trim(),
      quantity: quantity,
      unit: unit?.trim(),
      unitPrice: unitPrice,
      discount: discount,
      tax: tax,
      totalPrice: totalPrice,
      categoryId: categoryId,
      categoryHint: categoryHint?.trim(),
      categoryConfidence: categoryConfidence.clamp(0, 100),
      categorySuggestionSource: categorySuggestionSource,
      categoryAlternatives: List.unmodifiable(categoryAlternatives),
      skuOrBarcode: skuOrBarcode?.trim(),
      warnings: List.unmodifiable(warnings),
      sortOrder: sortOrder,
    );
  }

  final String id;
  final String receiptId;
  final String description;
  final String normalizedDescription;
  final Decimal? quantity;
  final String? unit;
  final Decimal? unitPrice;
  final Decimal? discount;
  final Decimal? tax;
  final Decimal? totalPrice;
  final String? categoryId;
  final String? categoryHint;
  final int categoryConfidence;
  final CategorySuggestionSource categorySuggestionSource;
  final List<String> categoryAlternatives;
  final String? skuOrBarcode;
  final List<ReceiptWarning> warnings;
  final int sortOrder;

  ReceiptLineItem copyWith({
    String? description,
    String? normalizedDescription,
    Decimal? quantity,
    String? unit,
    Decimal? unitPrice,
    Decimal? discount,
    Decimal? tax,
    Decimal? totalPrice,
    String? categoryId,
    String? categoryHint,
    int? categoryConfidence,
    CategorySuggestionSource? categorySuggestionSource,
    List<String>? categoryAlternatives,
    String? skuOrBarcode,
    List<ReceiptWarning>? warnings,
    int? sortOrder,
  }) {
    return ReceiptLineItem(
      id: id,
      receiptId: receiptId,
      description: description ?? this.description,
      normalizedDescription:
          normalizedDescription ?? this.normalizedDescription,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      totalPrice: totalPrice ?? this.totalPrice,
      categoryId: categoryId ?? this.categoryId,
      categoryHint: categoryHint ?? this.categoryHint,
      categoryConfidence: categoryConfidence ?? this.categoryConfidence,
      categorySuggestionSource:
          categorySuggestionSource ?? this.categorySuggestionSource,
      categoryAlternatives: categoryAlternatives ?? this.categoryAlternatives,
      skuOrBarcode: skuOrBarcode ?? this.skuOrBarcode,
      warnings: warnings ?? this.warnings,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
