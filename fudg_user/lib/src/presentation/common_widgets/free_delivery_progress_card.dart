import 'package:flutter/material.dart';

/// Progress banner towards a restaurant's real `freeDeliveryAbove` threshold.
///
/// Callers must only show this when a threshold actually exists — there is no
/// number to invent for a restaurant that doesn't offer free delivery.
class FreeDeliveryProgressCard extends StatelessWidget {
  const FreeDeliveryProgressCard({
    super.key,
    required this.subtotal,
    required this.threshold,
  });

  final double subtotal;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final double needed = (threshold - subtotal).clamp(0.0, threshold);
    final double progress = (subtotal / threshold).clamp(0.0, 1.0);
    final bool unlocked = needed <= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF41222).withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF41222).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFFF41222), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unlocked
                          ? 'You unlocked'
                          : 'Add items worth ₹${needed.toStringAsFixed(0)} more to get',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'FREE DELIVERY',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFFF41222)),
                    ),
                  ],
                ),
              ),
              Text(
                unlocked ? 'Unlocked 🎉' : '₹${needed.toStringAsFixed(0)} to go',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: const Color(0xFFCBD5E1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF41222)),
            ),
          ),
        ],
      ),
    );
  }
}
