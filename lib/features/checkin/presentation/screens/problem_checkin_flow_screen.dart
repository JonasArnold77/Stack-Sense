/// Problemfeld-Check-in Flow
///
/// Zeigt die 4 Fragen eines Problemfelds nacheinander (eine pro Seite),
/// mit 1–5 Stern-Bewertung und Auto-Advance nach Auswahl.
/// Am Ende eine kurze Erfolgs-Animation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/problem_checkin_provider.dart';
import '../../data/problem_checkin_questions.dart';
import '../../domain/models/problem_checkin.dart';

class ProblemCheckinFlowScreen extends ConsumerStatefulWidget {
  final String problemFieldId;

  const ProblemCheckinFlowScreen({
    super.key,
    required this.problemFieldId,
  });

  @override
  ConsumerState<ProblemCheckinFlowScreen> createState() =>
      _ProblemCheckinFlowScreenState();
}

class _ProblemCheckinFlowScreenState
    extends ConsumerState<ProblemCheckinFlowScreen>
    with SingleTickerProviderStateMixin {
  late final List<ProblemCheckinQuestion> _questions;
  final _answers = <int, int>{}; // question_id → score
  int _currentIndex = 0;
  bool _completed = false;
  bool _advancing = false; // verhindert Doppel-Taps während Feedback-Pause

  // Erfolgs-Animation Controller
  late final AnimationController _successCtrl;
  late final Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    _questions = getQuestionsForField(widget.problemFieldId);

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = CurvedAnimation(
      parent: _successCtrl,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRate(int score) async {
    if (_advancing) return; // Doppel-Tap ignorieren
    _advancing = true;

    final q = _questions[_currentIndex];
    // Score sofort eintragen → Sterne leuchten gelb auf
    setState(() => _answers[q.id] = score);

    // Kurze Pause damit der Nutzer sein Rating sieht
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    if (_currentIndex < _questions.length - 1) {
      // Auto-advance zur nächsten Frage
      setState(() {
        _currentIndex++;
        _advancing = false;
      });
    } else {
      // Alle Fragen beantwortet → speichern
      _save();
    }
  }

  Future<void> _save() async {
    final answerList = _answers.entries
        .map((e) => ProblemCheckinAnswer(questionId: e.key, score: e.value))
        .toList();

    await ref.read(problemCheckinProvider.notifier).submit(
          problemFieldId: widget.problemFieldId,
          answers: answerList,
        );

    setState(() => _completed = true);
    _successCtrl.forward();

    // Nach kurzer Verzögerung zurücknavigieren
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final fieldLabel =
        kProblemFieldLabel[widget.problemFieldId] ?? widget.problemFieldId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          fieldLabel,
          style: AppTextStyles.labelLarge
              .copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: _completed ? _buildSuccess() : _buildFlow(fieldLabel),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Check-in Flow — Fortschrittsbalken + aktuelle Frage
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFlow(String fieldLabel) {
    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Column(
      children: [
        // Fortschrittsbalken
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppConstants.spaceS),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Frage ${_currentIndex + 1} von ${_questions.length}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceXS),
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusRound),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary),
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Frage
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingH),
          child: AnimatedSwitcher(
            duration: AppConstants.animFast,
            child: Text(
              q.questionText,
              key: ValueKey(q.id),
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spaceXL),

        // Stern-Bewertung
        _StarRating(
          current: _answers[q.id],
          onRate: _onRate,
        ),

        const SizedBox(height: AppConstants.spaceM),

        // Label-Zeile
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingH),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sehr schlecht',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textTertiary)),
              Text('Sehr gut',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textTertiary)),
            ],
          ),
        ),

        const Spacer(flex: 2),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Erfolgs-Screen
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _successScale,
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: AppColors.evidenceGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 52,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spaceL),
          Text(
            'Check-in abgeschlossen!',
            style: AppTextStyles.headlineMedium
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppConstants.spaceS),
          Text(
            '+${AppConstants.xpCheckin} XP',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stern-Bewertungs-Widget
// ---------------------------------------------------------------------------

class _StarRating extends StatefulWidget {
  final int? current;
  final void Function(int score) onRate;

  const _StarRating({this.current, required this.onRate});

  @override
  State<_StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<_StarRating> {
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    const starSize = 46.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final score = i + 1;
        final filled =
            (_hovered ?? widget.current ?? 0) >= score;

        return GestureDetector(
          onTap: () => widget.onRate(score),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = score),
            onExit: (_) => setState(() => _hovered = null),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  key: ValueKey('$score-$filled'),
                  size: starSize,
                  color: filled ? const Color(0xFFF4B400) : AppColors.border,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
