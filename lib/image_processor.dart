import 'dart:typed_data';

import 'package:image/image.dart' as img;

class EdgeDetectionInput {
  const EdgeDetectionInput({
    required this.originalBytes,
    required this.threshold,
  });

  final Uint8List originalBytes;
  final int threshold;
}

class EdgeDetectionResult {
  const EdgeDetectionResult({
    required this.grayscaleBytes,
    required this.edgeBytes,
    required this.width,
    required this.height,
  });

  final Uint8List grayscaleBytes;
  final Uint8List edgeBytes;
  final int width;
  final int height;
}

EdgeDetectionResult processImageIsolate(EdgeDetectionInput input) {
  final decoded = img.decodeImage(input.originalBytes);
  if (decoded == null) {
    throw Exception('Não foi possível decodificar a imagem.');
  }

  final gray = img.grayscale(decoded);
  final edges = _applyEdgeDetection(gray, input.threshold);

  return EdgeDetectionResult(
    grayscaleBytes: Uint8List.fromList(img.encodeJpg(gray, quality: 95)),
    edgeBytes: Uint8List.fromList(img.encodeJpg(edges, quality: 95)),
    width: decoded.width,
    height: decoded.height,
  );
}

img.Image _applyEdgeDetection(img.Image grayImage, int threshold) {
  final width = grayImage.width;
  final height = grayImage.height;
  final output = img.Image(width: width, height: height);

  for (int y = 0; y < height - 1; y++) {
    for (int x = 0; x < width - 1; x++) {
      final p = grayImage.getPixel(x, y);
      final px = grayImage.getPixel(x + 1, y);
      final py = grayImage.getPixel(x, y + 1);

      final v = img.getLuminance(p);
      final vx = img.getLuminance(px);
      final vy = img.getLuminance(py);

      final diffX = (v - vx).abs();
      final diffY = (v - vy).abs();
      final magnitude = diffX + diffY;

      final edgeValue = magnitude > threshold ? 255 : 0;
      output.setPixelRgb(x, y, edgeValue, edgeValue, edgeValue);
    }
  }

  return output;
}
