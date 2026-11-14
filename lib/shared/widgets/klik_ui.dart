import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/local_record.dart';

const sports = LocalRecord.sports;
const sportIcons = [
  'football',
  'basket',
  'billiard',
  'volleyball',
  'padel',
  'badminton',
  'soccer',
];
const accent = Color(0xFFFF8D28);
double navigationHeight(BuildContext context) {
  final width = (MediaQuery.sizeOf(context).width - 44) / 5;
  double height = 20;
  for (final label in ['Beranda', 'Sosial', 'Buat', 'Tanding', 'Profil']) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: textStyle(10, weight: FontWeight.w700),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);
    if (painter.height > height) height = painter.height;
    painter.dispose();
  }
  return height + 52;
}

double navigationBottomInset(BuildContext context) =>
    navigationHeight(context) + MediaQuery.viewPaddingOf(context).bottom + 32;
Color secondary(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;
TextStyle textStyle(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color? color,
}) => TextStyle(
  fontFamily: 'Inter',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: 1.4,
);

class FigmaIcon extends StatelessWidget {
  const FigmaIcon(this.name, {this.color, super.key});
  final String name;
  final Color? color;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/figma/$name.svg',
    colorMapper: name == 'notification'
        ? _IconColors(
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.onSurface,
            Theme.of(context).dividerColor,
          )
        : null,
    colorFilter: color == null
        ? null
        : ColorFilter.mode(color!, BlendMode.srcIn),
  );
}

class _IconColors extends ColorMapper {
  const _IconColors(this.surface, this.text, this.border);
  final Color surface, text, border;
  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color == const Color(0xFFFFFFFF)) return surface;
    if (color == const Color(0xFF171B12)) return text;
    if (color == const Color(0xFFE1DBD3) || color == const Color(0xFFECE7DF)) {
      return border;
    }
    return color;
  }
}

class KCard extends StatelessWidget {
  const KCard({required this.child, this.padding = 16, this.onTap, super.key});
  final Widget child;
  final double padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: Theme.of(context).dividerColor),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    ),
  );
}

class KButton extends StatelessWidget {
  const KButton(
    this.label, {
    required this.onPressed,
    this.secondary = false,
    this.busy = false,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary, busy;
  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label, textAlign: TextAlign.center);
    return SizedBox(
      width: double.infinity,
      child: secondary
          ? OutlinedButton(onPressed: busy ? null : onPressed, child: child)
          : FilledButton(onPressed: busy ? null : onPressed, child: child),
    );
  }
}

class KBadge extends StatelessWidget {
  const KBadge(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: accent,
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      label,
      style: textStyle(
        10,
        weight: FontWeight.w700,
        color: const Color(0xFF663000),
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.action, this.onAction, super.key});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: textStyle(18, weight: FontWeight.w700)),
      ),
      if (action != null)
        TextButton(
          onPressed: onAction,
          child: Text(action!, style: textStyle(11, weight: FontWeight.w700)),
        ),
    ],
  );
}

class KPage extends StatelessWidget {
  const KPage({
    required this.title,
    required this.children,
    this.actions,
    this.subtitle,
    super.key,
  });
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, style: textStyle(20, weight: FontWeight.w800)),
      actions: actions,
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(24, 8, 24, navigationBottomInset(context)),
        children: [
          if (subtitle != null) ...[
            Text(subtitle!, style: textStyle(12, color: secondary(context))),
            const SizedBox(height: 16),
          ],
          for (final child in children) ...[child, const SizedBox(height: 16)],
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.description, {
    this.action,
    this.onAction,
    super.key,
  });
  final String title, description;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => KCard(
    child: Column(
      children: [
        Icon(Icons.sports_outlined, size: 40, color: secondary(context)),
        const SizedBox(height: 16),
        Text(
          title,
          style: textStyle(16, weight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: textStyle(13, color: secondary(context)),
          textAlign: TextAlign.center,
        ),
        if (action != null) ...[
          const SizedBox(height: 16),
          KButton(action!, onPressed: onAction),
        ],
      ],
    ),
  );
}

class LocalNotice extends StatelessWidget {
  const LocalNotice({super.key});
  @override
  Widget build(BuildContext context) => Text(
    'Mode uji coba • Data contoh dan perubahan tersimpan di perangkat ini.',
    style: textStyle(10, color: secondary(context)),
  );
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String description,
) => showDialog<bool>(
  context: context,
  builder: (c) => AlertDialog(
    scrollable: true,
    title: Text(title),
    content: Text(description),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c, false),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(c, true),
        child: const Text('Lanjutkan'),
      ),
    ],
  ),
).then((v) => v ?? false);
Future<void> perform(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message
                : error is ArgumentError
                ? error.message.toString()
                : 'Perubahan belum tersimpan. Coba lagi.',
          ),
        ),
      );
    }
  }
}

void openActivity(BuildContext context, String id) =>
    context.push('/activity/$id');
