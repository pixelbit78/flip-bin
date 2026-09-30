import 'package:flutter/material.dart';
import 'package:flipbin/models/enums.dart';
import 'package:flipbin/utils/proxied_image_url.dart';

/// Bundled dark-theme placeholder asset for [type] when no cover URL is available.
String defaultCoverAssetFor(ItemType type) {
  switch (type) {
    case ItemType.dvd:
      return 'assets/covers/dvd.png';
    case ItemType.game:
      return 'assets/covers/game.png';
    case ItemType.bluray:
      return 'assets/covers/bluray.png';
    case ItemType.vhs:
      return 'assets/covers/vhs.png';
    case ItemType.cd:
      return 'assets/covers/cd.png';
    case ItemType.book:
      return 'assets/covers/book.png';
    case ItemType.other:
      return 'assets/covers/other.png';
  }
}

/// Cover thumbnail: network image when available, otherwise type-specific asset.
///
/// Used by inventory list thumbs and Edit Item cover (errorBuilder / empty).
class ItemCoverImage extends StatelessWidget {
  final String? imageUrl;
  final ItemType type;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ItemCoverImage({
    super.key,
    required this.imageUrl,
    required this.type,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final asset = defaultCoverAssetFor(type);
    final displayUrl = proxiedImageUrl(imageUrl);
    final radius = borderRadius ?? BorderRadius.circular(8);

    Widget assetCover() => Image.asset(
          asset,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _fallbackBox(),
        );

    final child = displayUrl != null
        ? Image.network(
            displayUrl,
            width: width,
            height: height,
            fit: fit,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            errorBuilder: (_, __, ___) => assetCover(),
          )
        : assetCover();

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: child,
      ),
    );
  }

  Widget _fallbackBox() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF252830),
      alignment: Alignment.center,
      child: Text(
        type.label,
        style: const TextStyle(
          color: Color(0xFF2196F3),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
