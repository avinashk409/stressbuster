import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A utility class to generate placeholder images at runtime
class PlaceholderGenerator {
  /// Generates a simple placeholder image with text
  static Future<ui.Image> generatePlaceholderImage({
    required String text,
    Size size = const Size(300, 300),
    Color backgroundColor = Colors.blue,
    Color textColor = Colors.white,
    double fontSize = 24,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Draw background
    final paint = Paint()
      ..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    // Draw text
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: size.width - 40);
    
    // Position text in center
    final position = Offset(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, position);
    
    // Draw icon/pattern
    final iconSize = size.width / 8;
    final iconPaint = Paint()
      ..color = textColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Draw a pattern of circles
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        iconSize * (i + 1),
        iconPaint,
      );
    }
    
    // Convert to image
    final picture = recorder.endRecording();
    return picture.toImage(size.width.toInt(), size.height.toInt());
  }
  
  /// Converts a ui.Image to ImageProvider for use in Image widgets
  static ImageProvider imageToImageProvider(ui.Image image) {
    // This is a simplified implementation - in a real app, you would 
    // implement a custom ImageProvider that handles the ui.Image
    return MemoryImage(image.toByteData(format: ui.ImageByteFormat.png)!.buffer.asUint8List());
  }
} 