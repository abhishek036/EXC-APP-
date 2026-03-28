import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static final FirebaseStorageService instance = FirebaseStorageService._();

  FirebaseStorageService._();

  /// Uploads a file to Firebase Storage under a specific folder.
  /// Returns the secure download URL upon success.
  Future<String> uploadFile(File file, String folder) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
      final ref = _storage.ref().child('$folder/$fileName');
      
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() => null);
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  /// Uploads raw bytes to Firebase Storage under a specific folder.
  /// Works across all platforms including Web.
  Future<String> uploadBytes(Uint8List bytes, String folder, String originalName) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${originalName.replaceAll(' ', '_')}';
      final ref = _storage.ref().child('$folder/$fileName');
      
      final uploadTask = ref.putData(bytes);
      final snapshot = await uploadTask.whenComplete(() => null);
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload data: $e');
    }
  }

  /// Deletes a file from Firebase Storage given its reference URL.
  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }
}
