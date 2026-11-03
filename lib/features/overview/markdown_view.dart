import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/content/repo_content.dart';
import '../../l10n/app_localizations.dart';
import '../../state/content_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/feedback.dart';

const _browserSchemes = {'http', 'https', 'mailto'};

/// Renders a repository markdown file (README) with a strict link policy:
/// web links open in the browser, repository links stay inside the page,
/// everything else (file:, custom protocols, paths outside the repository)
/// is ignored. Images load only from the repository; remote images are
/// shown as a placeholder so opening a README never contacts a server.
class RepoMarkdown extends StatelessWidget {
  const RepoMarkdown({
    super.key,
    required this.text,
    required this.contentKey,
    required this.baseDir,
    required this.onNavigate,
  });

  final String text;
  final ContentKey contentKey;

  /// Folder of the markdown file, for relative links.
  final String baseDir;
  final ValueChanged<String> onNavigate;

  void _openLink(BuildContext context, String? href) {
    if (href == null || href.startsWith('#')) return;
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    if (uri.hasScheme) {
      if (_browserSchemes.contains(uri.scheme.toLowerCase())) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    final target = resolveRepoLink(baseDir, href);
    if (target == null) {
      showGhpToast(context, L10n.of(context).overviewBlocked, tone: ToastTone.error);
      return;
    }
    onNavigate(target);
  }

  Widget _image(Uri uri, String? alt) {
    if (uri.hasScheme) return _ImagePlaceholder(alt: alt, remote: true);
    final target = resolveRepoLink(baseDir, uri.toString());
    if (target == null) return _ImagePlaceholder(alt: alt);
    return _RepoImage(contentKey: contentKey, path: target, alt: alt);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    final mono = TextStyle(fontFamily: 'Consolas', fontSize: 13, color: c.text, backgroundColor: c.raised);
    final sheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: TextStyle(fontSize: 14, height: 1.6, color: c.text),
      a: TextStyle(color: c.accent),
      code: mono,
      codeblockDecoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(Radii.sm)),
      codeblockPadding: const EdgeInsets.all(Space.md),
      blockquoteDecoration: BoxDecoration(border: Border(left: BorderSide(color: c.border, width: 3))),
      blockquotePadding: const EdgeInsets.only(left: Space.md),
      horizontalRuleDecoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
      h1: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c.text),
      h2: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: c.text),
      h3: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.text),
      tableBorder: TableBorder.all(color: c.border),
      tableHead: TextStyle(fontWeight: FontWeight.w700, color: c.text),
      tableBody: TextStyle(color: c.text),
    );
    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: sheet,
      onTapLink: (_, href, _) => _openLink(context, href),
      imageBuilder: (uri, _, alt) => _image(uri, alt),
    );
  }
}

class _RepoImage extends ConsumerWidget {
  const _RepoImage({required this.contentKey, required this.path, this.alt});
  final ContentKey contentKey;
  final String path;
  final String? alt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blob = ref.watch(blobProvider((key: contentKey, path: path))).value;
    if (blob is! ImageBlob) return _ImagePlaceholder(alt: alt);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 480),
      child: Image.memory(
        Uint8List.fromList(blob.bytes),
        // Decoding at display size keeps oversized images from eating memory.
        cacheWidth: 1600,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _ImagePlaceholder(alt: alt),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.alt, this.remote = false});
  final String? alt;
  final bool remote;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = alt == null || alt!.isEmpty ? '' : alt!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
      decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(Radii.sm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(remote ? Icons.public_rounded : Icons.broken_image_outlined, size: 14, color: c.muted),
          const SizedBox(width: Space.xs),
          Text(
            remote ? L10n.of(context).overviewRemoteImage(label) : label,
            style: TextStyle(fontSize: 12, color: c.muted),
          ),
        ],
      ),
    );
  }
}
