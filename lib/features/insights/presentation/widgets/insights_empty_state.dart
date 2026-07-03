import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Empty State (Insights noch nicht verfügbar)
// ---------------------------------------------------------------------------

class InsightsEmptyState extends StatelessWidget {
  final VoidCallback onSimulate;
  final bool loading;

  const InsightsEmptyState({
    super.key,
    required this.onSimulate,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.insights_outlined,
                size: 44, color: Color(0xFF1565C0)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Noch keine Insights',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Insights zeigen dir wie deine Supplements mit deinem Wohlbefinden '
            'zusammenhängen — basierend auf deinen täglichen Check-ins.',
            style: TextStyle(
                fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF90CAF9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'So bekommst du deine ersten Insights:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 12),
                const InsightStep(
                  number: '1',
                  text: 'Füge min. 1 Supplement zu deinem Stack hinzu',
                  icon: Icons.layers_outlined,
                ),
                const SizedBox(height: 8),
                const InsightStep(
                  number: '2',
                  text: 'Mach mindestens 3 tägliche Check-ins (Energie, Schlaf, Fokus, Stimmung)',
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 8),
                const InsightStep(
                  number: '3',
                  text: 'Insights erscheinen automatisch und werden täglich präziser',
                  icon: Icons.auto_graph_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: loading ? null : onSimulate,
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.science_outlined, size: 18),
              label: Text(loading ? 'Wird simuliert…' : 'Demo: 21 Tage simulieren'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Zeigt dir wie Insights mit echten Daten aussehen.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Einzel-Schritt im "So funktioniert es"-Block
// ---------------------------------------------------------------------------

class InsightStep extends StatelessWidget {
  final String number;
  final String text;
  final IconData icon;

  const InsightStep({
    super.key,
    required this.number,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFF1565C0),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 16, color: const Color(0xFF1565C0)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF1565C0), height: 1.4),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tip-Box (wenn Daten vorhanden aber noch keine Korrelationen)
// ---------------------------------------------------------------------------

class InsightTip extends StatelessWidget {
  final int totalCheckins;

  const InsightTip({super.key, required this.totalCheckins});

  @override
  Widget build(BuildContext context) {
    final remaining = math.max(0, 3 - totalCheckins);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20, color: Color(0xFF1565C0)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              remaining > 0
                  ? 'Noch $remaining Check-in${remaining == 1 ? '' : 's'} bis zu deinen ersten Insights. '
                      'Mach täglich deinen Check-in — nach ein paar Tagen siehst du hier Muster.'
                  : 'Füge Supplements zu deinem Stack hinzu und mach weiter Check-ins — '
                      'dann erkenne ich Zusammenhänge zwischen deinen Supplements und deinem Wohlbefinden.',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF1565C0), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
