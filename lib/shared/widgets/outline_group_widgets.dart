import 'package:flutter/material.dart';
import 'package:ielts_assistant/core/text/text_direction.dart';
import 'package:ielts_assistant/features/audio/domain/audio_skill.dart';
import 'package:ielts_assistant/features/reader/presentation/book_outline_navigator.dart';

// 🌟 S-18/AU-13 (RULES-rendering.md): اجزای مشترکِ فهرست‌هایی که موردها را زیرِ سرعنوانِ درس دسته
// می‌کنند — نتایجِ جستجو و پلی‌لیستِ پلیر. رنگ‌ها از بیرون می‌آیند (پلیر تیره است، جستجو روشن).

/// مربعِ گردگوشه به رنگِ مهارت با آیکونش (یا [child]، مثلاً نمایشگرِ صوتیِ متحرک).
class SkillBadge extends StatelessWidget {
  final AudioSkill skill;
  final Color color;
  final double size;
  final IconData? icon;
  final Widget? child;

  const SkillBadge({
    super.key,
    required this.skill,
    required this.color,
    this.size = 42,
    this.icon,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child:
          child ??
          Icon(icon ?? audioSkillIcon(skill), size: size * 0.52, color: color),
    );
  }
}

/// سرعنوانِ یک درس: «درس 4» (برچسبِ رنگی) + نامِ درس + شمارِ موردها.
class UnitGroupHeader extends StatelessWidget {
  static const double height = 48;

  final OutlinePlace? place;
  final String countLabel;
  final Color accent;
  final Color textColor;
  final Color mutedColor;

  const UnitGroupHeader({
    super.key,
    required this.place,
    required this.countLabel,
    required this.accent,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final OutlinePlace? p = place;
    final String title = p?.unitTitle ?? 'سایر';
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
        child: Row(
          children: [
            if (p?.unitNumber != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  p!.unitLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: textDirectionOf(title),
                textAlign: textAlignToStartOf(context),
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(countLabel, style: TextStyle(color: mutedColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
