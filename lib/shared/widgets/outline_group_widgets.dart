import 'package:flutter/material.dart';
import 'package:ielts_assistant/core/text/text_direction.dart';
import 'package:ielts_assistant/features/audio/domain/audio_skill.dart';
import 'package:ielts_assistant/features/reader/presentation/book_outline_navigator.dart';

// 🌟 S-18/AU-13 (RULES-rendering.md): اجزای مشترکِ فهرست‌هایی که موردها را سه‌سطحی دسته می‌کنند —
// درس ← مهارت ← مورد — یعنی نتایجِ جستجو و پلی‌لیستِ پلیر. رنگ‌ها از بیرون می‌آیند (پلیر تیره
// است، جستجو روشن).
//
// 🌟 S-19/AU-15: **رنگ فقط یعنی مهارت.** سرعنوانِ درس خنثی است (خاکستری)؛ زیرِ هر مهارت یک
// «ریل»ِ عمودیِ رنگیِ تورفته موردهای همان مهارت را به هم می‌چسباند؛ میانِ درس‌ها خطِ جداکننده.

/// فاصله‌ی ریل از لبه‌ی شروع.
const double kRailIndent = 18;

/// مربعِ گردگوشه به رنگِ مهارت با آیکونش (یا [child]، مثلاً نمایشگرِ صوتیِ متحرک).
class SkillBadge extends StatelessWidget {
  final AudioSkill skill;
  final Color color;
  final double size;
  final IconData? icon;
  final Widget? child;
  final double fillOpacity;

  const SkillBadge({
    super.key,
    required this.skill,
    required this.color,
    this.size = 42,
    this.icon,
    this.child,
    this.fillOpacity = 0.14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(fillOpacity),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child:
          child ??
          Icon(icon ?? audioSkillIcon(skill), size: size * 0.52, color: color),
    );
  }
}

/// سرعنوانِ یک درس: «درس 4» (برچسبِ خنثی) + نامِ درس + شمارِ موردها؛ [divider]: خطِ جداکننده
/// بالایش (همه جز اولین درس).
class UnitGroupHeader extends StatelessWidget {
  static const double height = 56;

  final OutlinePlace? place;
  final String countLabel;
  final Color textColor;
  final Color mutedColor;
  final Color dividerColor;
  final bool divider;

  const UnitGroupHeader({
    super.key,
    required this.place,
    required this.countLabel,
    required this.textColor,
    required this.mutedColor,
    required this.dividerColor,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    final OutlinePlace? p = place;
    final String title = p?.unitTitle ?? 'سایر';
    return SizedBox(
      height: height,
      child: Column(
        children: [
          if (divider)
            Divider(height: 1, thickness: 1, color: dividerColor)
          else
            const SizedBox(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 2),
              child: Row(
                children: [
                  if (p?.unitNumber != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: mutedColor.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p!.unitLabel,
                        style: TextStyle(
                          color: textColor,
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
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    countLabel,
                    style: TextStyle(color: mutedColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ریلِ عمودیِ رنگیِ تورفته: موردهای یک مهارت کنارِ همین خط. با CustomPaint (نه Rowِ کشیده)
/// تا در فهرستِ بی‌ارتفاعِ ثابت (جستجو) هم کار کند.
class SkillRail extends StatelessWidget {
  final Color color;
  final Widget child;

  /// اولین/آخرین تکه‌ی ریل کمی کوتاه‌تر و سرگرد است.
  final bool first;
  final bool last;

  const SkillRail({
    super.key,
    required this.color,
    required this.child,
    this.first = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: kRailIndent),
      child: CustomPaint(
        painter: _RailPainter(
          color: color.withOpacity(0.7),
          first: first,
          last: last,
          rtl: Directionality.of(context) == TextDirection.rtl,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 3),
          child: child,
        ),
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  final Color color;
  final bool first;
  final bool last;
  final bool rtl;

  const _RailPainter({
    required this.color,
    required this.first,
    required this.last,
    required this.rtl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double w = 3;
    final double x = rtl ? size.width - w : 0;
    final double top = first ? 8 : 0;
    final double bottom = size.height - (last ? 8 : 0);
    if (bottom <= top) return;
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        x,
        top,
        x + w,
        bottom,
        topLeft: first ? const Radius.circular(2) : Radius.zero,
        topRight: first ? const Radius.circular(2) : Radius.zero,
        bottomLeft: last ? const Radius.circular(2) : Radius.zero,
        bottomRight: last ? const Radius.circular(2) : Radius.zero,
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.color != color || old.first != first || old.last != last || old.rtl != rtl;
}

/// سرعنوانِ یک مهارت داخلِ درس: آیکون + نام (به رنگِ مهارت) + شمار؛ سرِ ریل.
class SectionGroupHeader extends StatelessWidget {
  static const double height = 36;

  final AudioSkill skill;
  final String title;
  final String countLabel;
  final Color color;
  final Color mutedColor;
  final IconData? icon;

  const SectionGroupHeader({
    super.key,
    required this.skill,
    required this.title,
    required this.countLabel,
    required this.color,
    required this.mutedColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: SkillRail(
        color: color,
        first: true,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 16, 0),
          child: Row(
            children: [
              Icon(icon ?? audioSkillIcon(skill), size: 17, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: textDirectionOf(title),
                  textAlign: textAlignToStartOf(context),
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                countLabel,
                style: TextStyle(color: mutedColor, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
