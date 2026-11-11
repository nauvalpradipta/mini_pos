import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ProductImageService {
  ProductImageService({
    ImagePicker? imagePicker,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final ImagePicker _imagePicker;
  final Future<Directory> Function() _documentsDirectoryProvider;

  /// Opens the device gallery and saves the selected image locally.
  ///
  /// Returns null when the user cancels the picker.
  Future<String?> pickAndSaveImage() async {
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );

    if (pickedImage == null) {
      return null;
    }

    return savePickedImage(pickedImage);
  }

  /// Copies a selected image into the application's product_images folder.
  Future<String> savePickedImage(XFile pickedImage) async {
    final documentsDirectory = await _documentsDirectoryProvider();

    final imagesDirectory = Directory(
      p.join(documentsDirectory.path, 'product_images'),
    );

    await imagesDirectory.create(recursive: true);

    final extension = p.extension(pickedImage.path).toLowerCase();
    final safeExtension = extension.isEmpty ? '.jpg' : extension;

    final fileName =
        'product_${DateTime.now().microsecondsSinceEpoch}$safeExtension';

    final destinationPath = p.join(imagesDirectory.path, fileName);

    final savedFile = await File(pickedImage.path).copy(destinationPath);

    return savedFile.path;
  }

  /// Deletes an image only if it belongs to the application's product folder.
  Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return;
    }

    final documentsDirectory = await _documentsDirectoryProvider();

    final imagesDirectoryPath = p.normalize(
      p.absolute(p.join(documentsDirectory.path, 'product_images')),
    );

    final targetPath = p.normalize(p.absolute(imagePath));

    // Prevent deleting files outside the application's product image folder.
    if (p.dirname(targetPath) != imagesDirectoryPath) {
      return;
    }

    final imageFile = File(targetPath);

    if (await imageFile.exists()) {
      await imageFile.delete();
    }
  }
}
