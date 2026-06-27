import 'package:flutter/material.dart';

class BodyMap extends StatelessWidget {
  final String muscleGroup;
  const BodyMap({super.key, required this.muscleGroup});

  static const _allGroups = ['Chest', 'Back', 'Shoulders', 'Arms', 'Core', 'Legs', 'Other'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Muscles', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Row(
          children: [
            // Front body
            Expanded(child: _BodyFigure(side: 'front', activeGroup: muscleGroup)),
            const SizedBox(width: 12),
            // Back body
            Expanded(child: _BodyFigure(side: 'back', activeGroup: muscleGroup)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _allGroups.map((g) {
            final isActive = g == muscleGroup;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                g,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? Colors.white : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BodyFigure extends StatelessWidget {
  final String side;
  final String activeGroup;
  const _BodyFigure({required this.side, required this.activeGroup});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;

    return CustomPaint(
      size: const Size(80, 160),
      painter: _BodyPainter(
        side: side,
        activeGroup: activeGroup,
        primaryColor: primary,
        baseColor: surface,
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  final String side, activeGroup;
  final Color primaryColor, baseColor;
  const _BodyPainter({required this.side, required this.activeGroup, required this.primaryColor, required this.baseColor});

  bool get isFront => side == 'front';

  Color _color(String group) => group == activeGroup ? primaryColor : baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..style = PaintingStyle.fill;

    // Head
    paint.color = baseColor;
    canvas.drawCircle(Offset(w / 2, h * 0.06), w * 0.12, paint);

    // Neck
    paint.color = baseColor;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w / 2, h * 0.12), width: w * 0.14, height: h * 0.05),
        const Radius.circular(4)), paint);

    if (isFront) {
      // Chest
      paint.color = _color('Chest');
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * 0.15, h * 0.145, w * 0.7, h * 0.13), 4);

      // Shoulders
      paint.color = _color('Shoulders');
      _drawOval(canvas, paint, Rect.fromLTWH(w * 0.02, h * 0.135, w * 0.18, h * 0.12));
      _drawOval(canvas, paint, Rect.fromLTWH(w * 0.8, h * 0.135, w * 0.18, h * 0.12));

      // Core / Abs
      paint.color = _color('Core');
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * 0.22, h * 0.28, w * 0.56, h * 0.18), 4);

      // Arms (biceps front)
      paint.color = _color('Arms');
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * 0.01, h * 0.26, w * 0.16, h * 0.22), 6);
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * 0.83, h * 0.26, w * 0.16, h * 0.22), 6);

      // Forearms
      paint.color = _color('Arms');
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * -0.02, h * 0.49, w * 0.16, h * 0.18), 6);
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * 0.86, h * 0.49, w * 0.16, h * 0.18), 6);

      // Quads
      paint.color = _color('Legs');
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * 0.18, h * 0.49, w * 0.28, h * 0.26), 6);
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * 0.54, h * 0.49, w * 0.28, h * 0.26), 6);

      // Calves
      paint.color = _color('Legs');
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * 0.2, h * 0.77, w * 0.24, h * 0.2), 6);
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * 0.56, h * 0.77, w * 0.24, h * 0.2), 6);
    } else {
      // Back muscles
      paint.color = _color('Back');
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * 0.15, h * 0.145, w * 0.7, h * 0.22), 4);

      // Shoulders (rear)
      paint.color = _color('Shoulders');
      _drawOval(canvas, paint, Rect.fromLTWH(w * 0.02, h * 0.135, w * 0.18, h * 0.1));
      _drawOval(canvas, paint, Rect.fromLTWH(w * 0.8, h * 0.135, w * 0.18, h * 0.1));

      // Triceps
      paint.color = _color('Arms');
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * 0.01, h * 0.26, w * 0.16, h * 0.22), 6);
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * 0.83, h * 0.26, w * 0.16, h * 0.22), 6);

      // Lower back / glutes
      paint.color = _color('Back');
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * 0.2, h * 0.37, w * 0.6, h * 0.12), 4);

      // Glutes / hamstrings
      paint.color = _color('Legs');
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * 0.18, h * 0.49, w * 0.28, h * 0.26), 6);
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * 0.54, h * 0.49, w * 0.28, h * 0.26), 6);

      // Calves
      paint.color = _color('Legs');
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * 0.2, h * 0.77, w * 0.24, h * 0.2), 6);
      _drawRoundRect(canvas, paint, Rect.fromLTWH(w * 0.56, h * 0.77, w * 0.24, h * 0.2), 6);
    }

    // Label
    final tp = TextPainter(
      text: TextSpan(
        text: isFront ? 'Front' : 'Back',
        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h * 0.98));
  }

  void _drawRoundRect(Canvas canvas, Paint paint, Rect rect, double r) {
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)), paint);
  }

  void _drawOval(Canvas canvas, Paint paint, Rect rect) {
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.activeGroup != activeGroup || old.primaryColor != primaryColor;
}
