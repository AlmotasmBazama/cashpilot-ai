import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../application/providers/categories_providers.dart';
import '../../domain/entities/category.dart';
import '../../domain/enums/category_type.dart';
import '../../domain/value_objects/category_color.dart';
import '../../domain/value_objects/category_icon.dart';
import '../support/category_localization.dart';
import '../support/category_visuals.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  CategoryType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categoriesState = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: CPAppBar(
        title: l10n.categoriesTitle,
        subtitle: l10n.categoriesSubtitle,
      ),
      floatingActionButton: CPFloatingActionButton(
        variant: CPFloatingActionButtonVariant.extended,
        icon: Icons.add_rounded,
        label: l10n.createCategory,
        onPressed: () => _openForm(null),
      ),
      body: categoriesState.when(
        data: (result) {
          switch (result) {
            case AppSuccess<List<Category>>(:final data):
              return _CategoriesContent(
                categories: data,
                selectedType: _selectedType,
                onTypeChanged: (type) => setState(() => _selectedType = type),
                onEdit: _openForm,
                onArchive: _archive,
                onRefresh: _refresh,
              );
            case AppFailure<List<Category>>():
              return CPErrorView(
                title: l10n.categoriesErrorTitle,
                message: l10n.categoriesErrorMessage,
                action: CPButton(
                  label: l10n.retry,
                  onPressed: () => unawaited(_refresh()),
                ),
              );
          }
        },
        error: (_, _) => CPErrorView(
          title: l10n.categoriesErrorTitle,
          message: l10n.categoriesErrorMessage,
          action: CPButton(
            label: l10n.retry,
            onPressed: () => unawaited(_refresh()),
          ),
        ),
        loading: () => const CPLoadingIndicator(),
      ),
    );
  }

  Future<void> _openForm(Category? category) async {
    if (category?.isDefault ?? false) {
      return;
    }
    final categoriesResult = await ref.read(categoriesProvider.future);
    if (!mounted) {
      return;
    }

    final categories = switch (categoriesResult) {
      AppSuccess<List<Category>>(:final data) => data,
      AppFailure<List<Category>>() => const <Category>[],
    };
    final didSave = await CategoryFormSheet.show(
      context,
      category: category,
      categories: categories,
    );
    if (mounted && didSave == true) {
      ref.invalidate(categoriesProvider);
    }
  }

  Future<void> _archive(Category category) async {
    if (category.isDefault) {
      return;
    }
    final result = await ref.read(updateCategoryUseCaseProvider)(
      category.copyWith(isArchived: true, updatedAt: DateTime.now().toUtc()),
    );

    if (!mounted) {
      return;
    }

    switch (result) {
      case AppSuccess<Category>():
        ref.invalidate(categoriesProvider);
      case AppFailure<Category>(:final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(categoriesProvider);
    await ref.read(categoriesProvider.future);
  }
}

class _CategoriesContent extends StatelessWidget {
  const _CategoriesContent({
    required this.categories,
    required this.selectedType,
    required this.onTypeChanged,
    required this.onEdit,
    required this.onArchive,
    required this.onRefresh,
  });

  final List<Category> categories;
  final CategoryType? selectedType;
  final ValueChanged<CategoryType?> onTypeChanged;
  final ValueChanged<Category> onEdit;
  final ValueChanged<Category> onArchive;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visible = categories
        .where(
          (category) => selectedType == null || category.type == selectedType,
        )
        .where((category) => !category.isArchived)
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: FinanceScreenBody(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Wrap(
              spacing: CPSpacing.sm,
              runSpacing: CPSpacing.sm,
              children: [
                ChoiceChip(
                  label: Text(l10n.all),
                  selected: selectedType == null,
                  onSelected: (_) => onTypeChanged(null),
                ),
                for (final type in CategoryType.values)
                  ChoiceChip(
                    label: Text(CategoryLocalization.typeLabel(l10n, type)),
                    selected: selectedType == type,
                    onSelected: (_) => onTypeChanged(type),
                  ),
              ],
            ),
            const SizedBox(height: CPSpacing.xl),
            if (visible.isEmpty)
              CPEmptyState(
                icon: Icons.category_outlined,
                title: l10n.emptyCategoriesTitle,
                message: l10n.emptyCategoriesMessage,
              )
            else
              CPCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final category in visible)
                      _CategoryTile(
                        category: category,
                        parentName: _parentName(l10n, category),
                        onEdit: () => onEdit(category),
                        onArchive: () => onArchive(category),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _parentName(AppLocalizations l10n, Category category) {
    final parentId = category.parentCategoryId;
    if (parentId == null) {
      return null;
    }

    for (final parent in categories) {
      if (parent.id == parentId) {
        return CategoryLocalization.name(l10n, parent);
      }
    }
    return null;
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onEdit,
    required this.onArchive,
    this.parentName,
  });

  final Category category;
  final String? parentName;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = Color(category.color.argb);

    return CPListTile(
      title: CategoryLocalization.name(l10n, category),
      subtitle:
          parentName ?? CategoryLocalization.typeLabel(l10n, category.type),
      supportingText: category.isDefault ? l10n.defaultCategory : null,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(CPRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Icon(
          CategoryVisuals.iconForKey(category.icon.key),
          color: color,
        ),
      ),
      trailing: category.isDefault
          ? null
          : PopupMenuButton<_CategoryAction>(
              onSelected: (action) {
                switch (action) {
                  case _CategoryAction.edit:
                    onEdit();
                  case _CategoryAction.archive:
                    onArchive();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _CategoryAction.edit,
                  child: Text(l10n.edit),
                ),
                PopupMenuItem(
                  value: _CategoryAction.archive,
                  child: Text(l10n.archive),
                ),
              ],
            ),
    );
  }
}

class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({required this.categories, this.category, super.key});

  final Category? category;
  final List<Category> categories;

  static Future<bool?> show(
    BuildContext context, {
    required List<Category> categories,
    Category? category,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          CategoryFormSheet(category: category, categories: categories),
    );
  }

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  final _nameController = TextEditingController();
  late CategoryType _type;
  late String _iconKey;
  late int _color;
  Category? _parentCategory;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController.text = category?.name ?? '';
    _type = category?.type ?? CategoryType.expense;
    _iconKey = category?.icon.key ?? CategoryVisuals.iconKeys.first;
    _color = category?.color.argb ?? CategoryVisuals.colors.first;
    _parentCategory = widget.categories
        .where((item) => item.id == category?.parentCategoryId)
        .firstOrNull;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEditing = widget.category != null;

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: CPSpacing.lg,
        end: CPSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + CPSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CPSectionTitle(
              title: isEditing ? l10n.editCategory : l10n.createCategory,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: CPSpacing.lg),
            CPTextField(
              controller: _nameController,
              labelText: l10n.categoryName,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: CPSpacing.md),
            Wrap(
              spacing: CPSpacing.sm,
              runSpacing: CPSpacing.sm,
              children: [
                for (final type in CategoryType.values)
                  ChoiceChip(
                    label: Text(CategoryLocalization.typeLabel(l10n, type)),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: CPSpacing.md),
            _ParentCategoryField(
              categories: widget.categories
                  .where((category) => category.id != widget.category?.id)
                  .toList(growable: false),
              value: _parentCategory,
              onChanged: (category) =>
                  setState(() => _parentCategory = category),
            ),
            const SizedBox(height: CPSpacing.lg),
            Wrap(
              spacing: CPSpacing.sm,
              runSpacing: CPSpacing.sm,
              children: [
                for (final key in CategoryVisuals.iconKeys)
                  ChoiceChip(
                    avatar: Icon(CategoryVisuals.iconForKey(key), size: 18),
                    label: Text(key),
                    selected: _iconKey == key,
                    onSelected: (_) => setState(() => _iconKey = key),
                  ),
              ],
            ),
            const SizedBox(height: CPSpacing.lg),
            Wrap(
              spacing: CPSpacing.sm,
              runSpacing: CPSpacing.sm,
              children: [
                for (final color in CategoryVisuals.colors)
                  InkWell(
                    onTap: () => setState(() => _color = color),
                    borderRadius: BorderRadius.circular(CPRadius.full),
                    child: AnimatedContainer(
                      duration: CPDurations.fast,
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == color
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: CPSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: CPButton(
                    label: l10n.cancel,
                    variant: CPButtonVariant.ghost,
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: CPSpacing.sm),
                Expanded(
                  child: CPButton(
                    label: l10n.save,
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.categoryNameRequired)));
      return;
    }

    setState(() => _isSubmitting = true);
    final existing = widget.category;
    final category = existing == null
        ? Category.create(
            name: name,
            type: _type,
            icon: CategoryIcon(key: _iconKey),
            color: CategoryColor(argb: _color),
            parentCategoryId: _parentCategory?.id,
          )
        : existing.copyWith(
            name: name,
            type: _type,
            icon: CategoryIcon(key: _iconKey),
            color: CategoryColor(argb: _color),
            parentCategoryId: _parentCategory?.id,
            updatedAt: DateTime.now().toUtc(),
          );

    final result = existing == null
        ? await ref.read(createCategoryUseCaseProvider)(category)
        : await ref.read(updateCategoryUseCaseProvider)(category);

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);
    switch (result) {
      case AppSuccess<Category>():
        Navigator.of(context).pop(true);
      case AppFailure<Category>(:final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _ParentCategoryField extends StatelessWidget {
  const _ParentCategoryField({
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  final List<Category> categories;
  final Category? value;
  final ValueChanged<Category?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return CPTextField(
      key: ValueKey(value?.id ?? 'none'),
      initialValue: value == null
          ? l10n.noParentCategory
          : CategoryLocalization.name(l10n, value!),
      labelText: l10n.parentCategory,
      prefix: const Icon(Icons.account_tree_outlined),
      suffix: const Icon(Icons.keyboard_arrow_down_rounded),
      readOnly: true,
      onTap: () async {
        final selected = await showModalBottomSheet<Category?>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsetsDirectional.all(CPSpacing.lg),
              children: [
                CPSectionTitle(
                  title: l10n.parentCategory,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: CPSpacing.md),
                CPListTile(
                  title: l10n.noParentCategory,
                  onTap: () => Navigator.of(context).pop(null),
                ),
                for (final category in categories)
                  CPListTile(
                    title: CategoryLocalization.name(l10n, category),
                    subtitle: CategoryLocalization.typeLabel(
                      l10n,
                      category.type,
                    ),
                    onTap: () => Navigator.of(context).pop(category),
                  ),
              ],
            ),
          ),
        );
        onChanged(selected);
      },
    );
  }
}

enum _CategoryAction { edit, archive }

extension on Iterable<Category> {
  Category? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}
