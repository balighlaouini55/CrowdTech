// Panneau de filtres multi-critères du catalogue (prix, catégories, état,
// marque, note, stock, réputation du vendeur) et choix du tri.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/marketplace/domain/product_item.dart';
import 'package:crowdtech/modules/marketplace/domain/product_search.dart';
import 'package:crowdtech/shared/widgets/gradient_button.dart';
import 'package:flutter/material.dart';

class ProductFilterSheet extends StatefulWidget {
  final List<ProductItem> products;
  final ProductFilter initial;
  const ProductFilterSheet({
    required this.products,
    required this.initial,
    super.key,
  });

  @override
  State<ProductFilterSheet> createState() => _ProductFilterSheetState();
}

class _ProductFilterSheetState extends State<ProductFilterSheet> {
  late ProductFilter filter = widget.initial;
  late final minController = TextEditingController(
    text: widget.initial.minPrice?.toStringAsFixed(0) ?? '',
  );
  late final maxController = TextEditingController(
    text: widget.initial.maxPrice?.toStringAsFixed(0) ?? '',
  );

  @override
  void dispose() {
    minController.dispose();
    maxController.dispose();
    super.dispose();
  }

  Set<String> toggled(Set<String> values, String value) =>
      values.contains(value)
      ? ({...values}..remove(value))
      : {...values, value};

  double? parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  Widget title(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
    ),
  );

  Widget chips(
    Iterable<String> options,
    Set<String> selected,
    ValueChanged<String> onTap,
  ) => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: [
      for (final option in options)
        FilterChip(
          label: Text(option),
          selected: selected.contains(option),
          onSelected: (_) => onTap(option),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final categories = {
      for (final product in widget.products) product.category,
    }.toList()..sort();
    final brands = {
      for (final product in widget.products)
        if (product.brand case final brand? when brand.isNotEmpty) brand,
    }.toList()..sort();
    const conditions = ['Neuf', 'Reconditionné', 'Occasion'];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filtres et tri',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      filter = filter.cleared();
                      minController.clear();
                      maxController.clear();
                    }),
                    child: const Text('Tout effacer'),
                  ),
                ],
              ),
              title('Trier par'),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final sort in ProductSort.values)
                    ChoiceChip(
                      label: Text(sort.label),
                      selected: filter.sort == sort,
                      onSelected: (_) =>
                          setState(() => filter = filter.copyWith(sort: sort)),
                    ),
                ],
              ),
              title('Prix (€)'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: maxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max'),
                    ),
                  ),
                ],
              ),
              title('Catégories'),
              chips(
                categories,
                filter.categories,
                (value) => setState(
                  () => filter = filter.copyWith(
                    categories: toggled(filter.categories, value),
                  ),
                ),
              ),
              title('État'),
              chips(
                conditions,
                filter.conditions,
                (value) => setState(
                  () => filter = filter.copyWith(
                    conditions: toggled(filter.conditions, value),
                  ),
                ),
              ),
              if (brands.isNotEmpty) ...[
                title('Marques'),
                chips(
                  brands,
                  filter.brands,
                  (value) => setState(
                    () => filter = filter.copyWith(
                      brands: toggled(filter.brands, value),
                    ),
                  ),
                ),
              ],
              title(
                'Note minimale : '
                '${filter.minRating == 0 ? 'toutes' : '${filter.minRating.toStringAsFixed(1)} ★'}',
              ),
              Slider(
                value: filter.minRating,
                max: 5,
                divisions: 10,
                activeColor: ModulePalette.store.start,
                onChanged: (value) =>
                    setState(() => filter = filter.copyWith(minRating: value)),
              ),
              title(
                'Réputation du vendeur : '
                '${filter.minSellerScore == 0 ? 'tous' : '≥ ${filter.minSellerScore}/100'}',
              ),
              Slider(
                value: filter.minSellerScore.toDouble(),
                max: 100,
                divisions: 10,
                activeColor: ModulePalette.store.start,
                onChanged: (value) => setState(
                  () => filter = filter.copyWith(minSellerScore: value.round()),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Seulement en stock'),
                value: filter.inStockOnly,
                onChanged: (value) => setState(
                  () => filter = filter.copyWith(inStockOnly: value),
                ),
              ),
              const SizedBox(height: 8),
              GradientButton(
                palette: ModulePalette.store,
                icon: Icons.check_rounded,
                label: 'Appliquer',
                onPressed: () {
                  final min = parse(minController.text);
                  final max = parse(maxController.text);
                  Navigator.pop(
                    context,
                    filter.copyWith(minPrice: () => min, maxPrice: () => max),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
