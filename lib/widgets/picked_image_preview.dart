import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PickedImagePreview extends StatelessWidget {
  final XFile file;
  final double height;

  const PickedImagePreview({
    super.key,
    required this.file,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return SizedBox(
            height: height,
            child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
          );
        }

        return Image.memory(
          snapshot.data!,
          height: height,
          fit: BoxFit.contain,
        );
      },
    );
  }
}
