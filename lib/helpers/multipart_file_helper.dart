import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

MediaType mediaTypeFromFileName(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  switch (extension) {
    case 'png':
      return MediaType('image', 'png');
    case 'webp':
      return MediaType('image', 'webp');
    case 'gif':
      return MediaType('image', 'gif');
    case 'jpg':
    case 'jpeg':
      return MediaType('image', 'jpeg');
    default:
      return MediaType('image', 'jpeg');
  }
}

Future<http.MultipartFile> multipartFileFromXFile(
  String fieldName,
  XFile file, {
  MediaType? contentType,
}) async {
  final bytes = await file.readAsBytes();
  final resolvedContentType = contentType ?? mediaTypeFromFileName(file.name);

  return http.MultipartFile.fromBytes(
    fieldName,
    bytes,
    filename: file.name.isNotEmpty ? file.name : '$fieldName.jpg',
    contentType: resolvedContentType,
  );
}
