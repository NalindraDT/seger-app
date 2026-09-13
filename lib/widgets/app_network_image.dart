import 'package:flutter/material.dart';

/// Bounds for the width the backend is asked to resize to.
const int kMinSizedImagePx = 32;
const int kMaxSizedImagePx = 2048;

/// Appends a `?w=<widthPx>` hint so the backend serves an on-the-fly resized
/// WebP variant of a remote image. Returns [url] unchanged for empty strings
/// and inline `data:` URIs. Existing query strings and `#fragment`s are kept.
String sizedImageUrl(String url, int widthPx) {
  if (url.isEmpty || url.startsWith('data:')) return url;
  final int fragmentIndex = url.indexOf('#');
  final String base =
      fragmentIndex >= 0 ? url.substring(0, fragmentIndex) : url;
  final String fragment =
      fragmentIndex >= 0 ? url.substring(fragmentIndex) : '';
  final String separator = base.contains('?') ? '&' : '?';
  return '$base${separator}w=$widthPx$fragment';
}

/// Pixel width to request for a logical [cssWidth] (2x for high-DPI screens),
/// clamped to the backend's supported range.
int sizedImagePx(double cssWidth) =>
    (cssWidth * 2).round().clamp(kMinSizedImagePx, kMaxSizedImagePx).toInt();

/// Sized [NetworkImage], for `CircleAvatar(backgroundImage:)` and
/// `DecorationImage(image:)`.
ImageProvider sizedImageProvider(String url, double cssWidth) =>
    NetworkImage(sizedImageUrl(url, sizedImagePx(cssWidth)));

/// Drop-in replacement for `Image.network` that requests a backend-resized
/// variant sized to [cssWidth] and caps the decoded resolution via
/// `cacheWidth`, cutting both transfer and decode memory.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.cssWidth,
    this.width,
    this.height,
    this.fit = BoxFit.scaleDown,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final String url;

  /// Intended on-screen width in logical pixels; the request asks for 2x.
  final double? cssWidth;

  final double? width;
  final double? height;
  final BoxFit fit;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final int? px = cssWidth == null ? null : sizedImagePx(cssWidth!);
    return Image.network(
      px == null ? url : sizedImageUrl(url, px),
      width: width,
      height: height,
      fit: fit,
      cacheWidth: px,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
    );
  }
}
