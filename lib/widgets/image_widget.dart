import 'package:flutter/material.dart';

class SafeImage extends StatelessWidget {
  final String imagePath;
  final double width;
  final double height;
  final BoxFit fit;
  final Color fallbackColor;
  final IconData fallbackIcon;
  final String fallbackText;

  const SafeImage({
    Key? key,
    required this.imagePath,
    this.width = 100,
    this.height = 100,
    this.fit = BoxFit.cover,
    this.fallbackColor = Colors.blue,
    this.fallbackIcon = Icons.image,
    this.fallbackText = 'Image not found',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      imagePath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Return a fallback widget when the image fails to load
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: fallbackColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  fallbackIcon,
                  color: fallbackColor,
                  size: width * 0.3,
                ),
                const SizedBox(height: 8),
                Text(
                  fallbackText,
                  style: TextStyle(
                    color: fallbackColor,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 