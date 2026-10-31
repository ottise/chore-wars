import 'package:flutter/material.dart';

import '../../domain/repositories/supplies_repository.dart';
import 'supplies_ui.dart';

class SupplierContactCard extends StatelessWidget {
  const SupplierContactCard({required this.supplier, super.key});
  final SupplyData supplier;

  @override
  Widget build(BuildContext context) {
    final name = supplier['name']?.toString().trim();
    final area = supplier['deliveryArea']?.toString().trim() ?? '';
    final phone = supplier['phone']?.toString().trim() ?? '';
    final email = supplier['email']?.toString().trim() ?? '';
    final deliveryFee = supplier['deliveryFee'] as num? ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE7FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Color(0xFF7C4DFF),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (name == null || name.isEmpty) ? 'Supplier' : name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      area.isNotEmpty
                          ? '$area · Delivery ${supplyMoney(deliveryFee)}'
                          : 'Delivery ${supplyMoney(deliveryFee)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        phone.isEmpty ? 'Contact number not available' : phone,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: phone.isEmpty
                              ? FontWeight.w500
                              : FontWeight.w600,
                          color: phone.isEmpty
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.mail_outline_rounded,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          email,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ContactActionButton(
                  icon: Icons.call_outlined,
                  label: 'Call',
                  primary: true,
                  onPressed: () =>
                      supplyLaunch(context, Uri(scheme: 'tel', path: phone)),
                ),
                _ContactActionButton(
                  icon: Icons.sms_outlined,
                  label: 'Message',
                  onPressed: () =>
                      supplyLaunch(context, Uri(scheme: 'sms', path: phone)),
                ),
                _ContactActionButton(
                  icon: Icons.copy_rounded,
                  label: 'Copy number',
                  onPressed: () => supplyCopy(context, 'Phone', phone),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactActionButton extends StatelessWidget {
  const _ContactActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: primary
            ? const Color(0xFFEDE7FF)
            : const Color(0xFFF1F5F9),
        foregroundColor: primary
            ? const Color(0xFF6845D6)
            : const Color(0xFF334155),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
