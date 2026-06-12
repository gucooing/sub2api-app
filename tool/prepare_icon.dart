// Generates app icon variants from assets/branding/logo.png.
//
// Usage: dart run tool/prepare_icon.dart
//
// Outputs:
//   assets/icon/app_icon.png            1024x1024, transparent corners (Windows/macOS/general)
//   assets/icon/app_icon_ios.png        1024x1024, full-bleed background (iOS)
//   assets/icon/app_icon_foreground.png 1024x1024, logo in adaptive safe zone (Android adaptive)
// Prints the sampled background color for adaptive_icon_background in pubspec.yaml.

import 'dart:io';

import 'package:image/image.dart' as img;

const int canvasSize = 1024;

void main() {
  final src = img.decodePng(File('assets/branding/logo.png').readAsBytesSync());
  if (src == null) {
    stderr.writeln('Failed to decode assets/branding/logo.png');
    exit(1);
  }

  final rgba = src.convert(numChannels: 4);

  // Sample the icon's own background color (inside the rounded rect, away from the glyph).
  final probe = rgba.getPixel(rgba.width ~/ 2, (rgba.height * 0.07).round());
  final bgHex = '#'
      '${probe.r.toInt().toRadixString(16).padLeft(2, '0')}'
      '${probe.g.toInt().toRadixString(16).padLeft(2, '0')}'
      '${probe.b.toInt().toRadixString(16).padLeft(2, '0')}';

  // Pad to square on a transparent canvas, then upscale to 1024.
  final side = rgba.width > rgba.height ? rgba.width : rgba.height;
  final square = img.Image(width: side, height: side, numChannels: 4);
  img.compositeImage(
    square,
    rgba,
    dstX: (side - rgba.width) ~/ 2,
    dstY: (side - rgba.height) ~/ 2,
  );
  final appIcon = img.copyResize(
    square,
    width: canvasSize,
    height: canvasSize,
    interpolation: img.Interpolation.cubic,
  );
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(appIcon));

  // iOS: fill the entire square with the sampled background so corners are full-bleed.
  final ios = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  img.fill(
    ios,
    color: img.ColorRgba8(probe.r.toInt(), probe.g.toInt(), probe.b.toInt(), 255),
  );
  img.compositeImage(ios, appIcon);
  File('assets/icon/app_icon_ios.png').writeAsBytesSync(img.encodePng(ios));

  // Android adaptive foreground: logo scaled into the 66/108 safe zone, transparent elsewhere.
  const safe = (canvasSize * 66 / 108);
  final fgLogo = img.copyResize(
    square,
    width: safe.round(),
    height: safe.round(),
    interpolation: img.Interpolation.cubic,
  );
  final foreground = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  img.compositeImage(
    foreground,
    fgLogo,
    dstX: (canvasSize - fgLogo.width) ~/ 2,
    dstY: (canvasSize - fgLogo.height) ~/ 2,
  );
  File('assets/icon/app_icon_foreground.png')
      .writeAsBytesSync(img.encodePng(foreground));

  stdout.writeln('Generated assets/icon/{app_icon,app_icon_ios,app_icon_foreground}.png');
  stdout.writeln('Sampled background color: $bgHex');
}
