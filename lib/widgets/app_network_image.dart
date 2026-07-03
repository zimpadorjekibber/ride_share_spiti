import 'package:flutter/material.dart';

/// [Image.network] with a loading placeholder and an error fallback.
///
/// On Spiti's slow / flaky connections a bare Image.network shows nothing
/// while loading and an ugly broken-image glyph on failure. This shows a
/// subtle progress spinner while bytes arrive and a quiet icon if the photo
/// can't load — same size as the image, so layouts never jump.
class AppNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    Widget box(Widget child) => Container(
          width: width,
          height: height,
          color: onSurface.withValues(alpha: 0.05),
          alignment: Alignment.center,
          child: child,
        );

    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return box(
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: onSurface.withValues(alpha: 0.35),
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stack) => box(
        Icon(
          Icons.landscape_outlined,
          size: (height != null && height! < 60) ? 18 : 26,
          color: onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
