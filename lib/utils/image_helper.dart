import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_helper;

class ImageHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Hàm chọn ảnh từ Thư viện và lưu vào bộ nhớ trong của App.
  /// Trả về đường dẫn file ảnh đã lưu, hoặc null nếu không chọn.
  static Future<String?> pickAndSaveImageFromGallery() async {
    try {
      // 1. Chọn ảnh từ thư viện
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Giảm chất lượng xuống 70% để tiết kiệm bộ nhớ
      );

      if (image == null) return null; // Người dùng không chọn ảnh

      // 2. Lấy đường dẫn thư mục an toàn của App
      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final String appFolderPath = appDirectory.path;

      // 3. Tạo tên file duy nhất (để không bị trùng)
      final String fileName = 'goal_${DateTime.now().millisecondsSinceEpoch}${path_helper.extension(image.path)}';

      // 4. Di chuyển/Lưu file ảnh vào thư mục App
      final File savedImage = await File(image.path).copy('$appFolderPath/$fileName');

      // Trả về đường dẫn file ảnh đã lưu thành công
      return savedImage.path;
    } catch (e) {
      print('Lỗi khi chọn/lưu ảnh: $e');
      return null;
    }
  }

  /// Hàm kiểm tra xem file ảnh có tồn tại thực sự không.
  static bool isFileExists(String? filePath) {
    if (filePath == null || filePath.isEmpty) return false;
    return File(filePath).existsSync();
  }
}