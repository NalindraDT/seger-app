import 'package:flutter/material.dart';

enum BadgeImageKind { tier, streak }

/// Default badge icons from Twemoji CDN (jsDelivr) when API image is missing or broken.
class BadgeDefaults {
  static const tierUrl =
      'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f3c5.png';
  static const streakUrl =
      'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f525.png';

  static String urlFor(BadgeImageKind kind) =>
      kind == BadgeImageKind.streak ? streakUrl : tierUrl;
}

class BadgeNetworkImage extends StatelessWidget {
  const BadgeNetworkImage({
    super.key,
    this.imageUrl,
    required this.kind,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.opacity = 1.0,
    this.fallbackIcon,
    this.fallbackIconColor,
    this.labelText,
  });

  final String? imageUrl;
  final BadgeImageKind kind;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double opacity;
  final IconData? fallbackIcon;
  final Color? fallbackIconColor;
  final String? labelText;

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      if (labelText != null && labelText!.trim().isNotEmpty) {
        final baseSize = width ?? height ?? 40;
        return Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (fallbackIconColor ?? primaryPurpleFallback()).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            labelText!.trim().substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: fallbackIconColor ?? primaryPurpleFallback(),
              fontWeight: FontWeight.bold,
              fontSize: baseSize * 0.4,
            ),
          ),
        );
      }
      return _iconFallback();
    }

    final defaultUrl = BadgeDefaults.urlFor(kind);
    final primaryUrl = trimmed;

    Widget image = Image.network(
      primaryUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        if (primaryUrl != defaultUrl) {
          return Image.network(
            defaultUrl,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _iconFallback(),
          );
        }
        return _iconFallback();
      },
    );

    if (opacity < 1) {
      image = Opacity(opacity: opacity, child: image);
    }

    return image;
  }

  Widget _iconFallback() {
    final icon = fallbackIcon ??
        (kind == BadgeImageKind.streak
            ? Icons.local_fire_department
            : Icons.military_tech);
    final baseSize = width ?? height ?? 40;
    return Icon(
      icon,
      color: fallbackIconColor ??
          (kind == BadgeImageKind.streak ? Colors.orange : Colors.deepPurple),
      size: baseSize * 0.75,
    );
  }

  Color primaryPurpleFallback() => Colors.deepPurple;
}
