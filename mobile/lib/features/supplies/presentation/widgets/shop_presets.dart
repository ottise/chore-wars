import 'package:flutter/material.dart';

typedef ShopPreset = ({String name, String unit, int price, IconData icon});

// Editable starting points, never advertised as confirmed supplier prices.
const shopPresets = <ShopPreset>[
  (
    name: 'Gas',
    unit: '12 kg cylinder',
    price: 400000,
    icon: Icons.propane_tank_outlined,
  ),
  (
    name: 'Rice',
    unit: '5 kg bag',
    price: 160000,
    icon: Icons.rice_bowl_outlined,
  ),
  (
    name: 'Fish sauce',
    unit: '500 ml bottle',
    price: 40000,
    icon: Icons.water_drop_outlined,
  ),
  (name: 'Salt', unit: '1 kg bag', price: 10000, icon: Icons.kitchen_outlined),
];

class ShopPresets extends StatelessWidget {
  const ShopPresets({required this.onSelect, super.key});
  final ValueChanged<ShopPreset>? onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Quick add', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final preset in shopPresets)
            OutlinedButton.icon(
              onPressed: onSelect == null ? null : () => onSelect!(preset),
              icon: Icon(preset.icon, size: 18),
              label: Text(preset.name),
            ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Suggested prices. Edit the item, unit and price, then add a contact number before saving.',
      ),
    ],
  );
}
