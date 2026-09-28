import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

/// Converts a picked image into a Dio [MultipartFile] using in-memory bytes
/// (works uniformly on web and mobile, unlike `MultipartFile.fromFile`).
Future<MultipartFile> xFileToMultipart(XFile file) async {
  final bytes = await file.readAsBytes();
  return MultipartFile.fromBytes(bytes, filename: file.name);
}
