import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// Shown when there is no repository: brand art and the first quest steps.
class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key, required this.onAddRepository, this.completedSteps = 0});

  final VoidCallback onAddRepository;

  /// 0..3 of: add repository, first commit, first push.
  final int completedSteps;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = L10n.of(context);
    final steps = [l.questAddRepo, l.questFirstCommit, l.questFirstPush];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset('assets/brand/logo_background.png', width: 260, height: 260),
              ),
              const SizedBox(width: Space.xxl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.welcomeTitle, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c.text)),
                    const SizedBox(height: Space.md),
                    Text(l.welcomeBody, style: TextStyle(fontSize: 14, height: 1.5, color: c.muted)),
                    const SizedBox(height: Space.xl),
                    Container(
                      padding: const EdgeInsets.all(Space.lg),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(Radii.lg),
                        border: Border.all(color: c.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.flag_rounded, size: 16, color: c.warning),
                              const SizedBox(width: Space.sm),
                              Text(l.questFirstTitle, style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                              const Spacer(),
                              Text('$completedSteps / ${steps.length}', style: TextStyle(color: c.muted, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: Space.md),
                          for (var i = 0; i < steps.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Icon(
                                    i < completedSteps ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    size: 18,
                                    color: i < completedSteps ? c.success : (i == completedSteps ? c.accent : c.muted),
                                  ),
                                  const SizedBox(width: Space.sm),
                                  Text(
                                    steps[i],
                                    style: TextStyle(
                                      color: i == completedSteps ? c.text : c.muted,
                                      fontWeight: i == completedSteps ? FontWeight.w600 : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.xl),
                    FilledButton.icon(
                      onPressed: onAddRepository,
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l.addExisting),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
