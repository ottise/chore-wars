import 'package:flutter/material.dart';

typedef ShopPreset = ({String name, String unit, int price, IconData icon});

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
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFE8ECF2)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                size: 16,
                color: Color(0xFF7C4DFF),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Quick add',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in shopPresets)
                OutlinedButton.icon(
                  onPressed: onSelect == null ? null : () => onSelect!(preset),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    backgroundColor: const Color(0xFFF8FAFC),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(
                    preset.icon,
                    size: 16,
                    color: const Color(0xFF7C4DFF),
                  ),
                  label: Text(
                    preset.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
