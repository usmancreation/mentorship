import 'dart:io'; // File support k liye zaroori ha
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart'; 

class CloudinaryService {
  final CloudinaryPublic cloudinary = CloudinaryPublic(
    'dvtqwxtko', 
    'mentorship_app', 
    cache: false,
  );

  // 1. UPLOAD IMAGE
  Future<String?> uploadImage(XFile imageFile) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
          folder: "mentorship_images",
        ),
      );
      return response.secureUrl;
    } catch (e) {
      print("Image Upload Error: $e");
      return null;
    }
  }

  // 2. UPLOAD VIDEO
  Future<String?> uploadVideo(XFile videoFile) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          videoFile.path,
          resourceType: CloudinaryResourceType.Video,
          folder: "mentorship_videos",
        ),
      );
      return response.secureUrl;
    } catch (e) {
      print("Video Upload Error: $e");
      return null;
    }
  }

  // 3. UPLOAD DOCUMENT (UPDATED)
  // Ab ye 'File' accept karega jo ChatScreen bhej rahi hai
  Future<String?> uploadDocument(File docFile) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          docFile.path,
          resourceType: CloudinaryResourceType.Auto, // Auto for PDF/Docs
          folder: "mentorship_docs",
        ),
      );
      print("Document Uploaded: ${response.secureUrl}");
      return response.secureUrl;
    } catch (e) {
      print("Document Upload Error: $e");
      return null;
    }
  }
}