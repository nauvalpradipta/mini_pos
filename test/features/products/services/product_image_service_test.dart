import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'package:mini_pos/features/products/services/product_image_service.dart';

void main() {
  late Directory temporaryDirectory;
  late ProductImageService imageService;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'product_image_test_',
    );

    imageService = ProductImageService(
      documentsDirectoryProvider: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  group('ProductImageService', () {
    test('saves selected image into product_images directory', () async {
      final sourceFile = File(p.join(temporaryDirectory.path, 'source.jpg'));

      final imageBytes = [1, 2, 3, 4, 5];

      await sourceFile.writeAsBytes(imageBytes);

      final savedPath = await imageService.savePickedImage(
        XFile(sourceFile.path),
      );

      final savedFile = File(savedPath);

      expect(await savedFile.exists(), isTrue);
      expect(
        p.dirname(savedPath),
        p.join(temporaryDirectory.path, 'product_images'),
      );
      expect(await savedFile.readAsBytes(), imageBytes);
      expect(p.extension(savedPath), '.jpg');
    });

    test('deletes an image inside product_images directory', () async {
      final sourceFile = File(p.join(temporaryDirectory.path, 'source.png'));

      await sourceFile.writeAsBytes([1, 2, 3]);

      final savedPath = await imageService.savePickedImage(
        XFile(sourceFile.path),
      );

      expect(await File(savedPath).exists(), isTrue);

      await imageService.deleteImage(savedPath);

      expect(await File(savedPath).exists(), isFalse);
    });

    test('does not delete files outside product_images directory', () async {
      final externalFile = File(
        p.join(temporaryDirectory.path, 'external.jpg'),
      );

      await externalFile.writeAsBytes([1, 2, 3]);

      await imageService.deleteImage(externalFile.path);

      expect(await externalFile.exists(), isTrue);
    });

    test('does nothing when image path is null', () async {
      await expectLater(imageService.deleteImage(null), completes);
    });

    test('does nothing when image path is empty', () async {
      await expectLater(imageService.deleteImage(''), completes);
    });
  });
}
