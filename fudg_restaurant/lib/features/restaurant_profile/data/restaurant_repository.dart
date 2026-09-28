import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/core/utils/multipart_utils.dart';
import 'package:food_user_application/features/auth/domain/restaurant_model.dart';

/// All Explore-section screens that read/write the restaurant's own profile
/// go through this repository — see restaurant_profile_controller.dart for
/// the caching layer on top.
class RestaurantRepository {
  RestaurantRepository(this._dio);

  final Dio _dio;

  Future<RestaurantModel> getCurrent() async {
    final response = await _dio.get('/food/restaurant/current');
    final data = Map<String, dynamic>.from(response.data as Map);
    return RestaurantModel.fromJson(
      Map<String, dynamic>.from(data['restaurant'] as Map),
    );
  }

  Future<RestaurantModel> updateProfile(Map<String, dynamic> patch) async {
    final response = await _dio.patch('/food/restaurant/profile', data: patch);
    final data = Map<String, dynamic>.from(response.data as Map);
    return RestaurantModel.fromJson(
      Map<String, dynamic>.from(data['restaurant'] as Map),
    );
  }

  Future<RestaurantModel> updateAvailability(bool isAcceptingOrders) async {
    final response = await _dio.patch(
      '/food/restaurant/availability',
      data: {'isAcceptingOrders': isAcceptingOrders},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return RestaurantModel.fromJson(
      Map<String, dynamic>.from(data['restaurant'] as Map),
    );
  }

  /// `{ "Monday": { "isOpen": true, "openingTime": "09:00", "closingTime": "22:00" }, ... }`
  Future<Map<String, dynamic>> getOutletTimings() async {
    final response = await _dio.get('/food/restaurant/outlet-timings');
    final data = Map<String, dynamic>.from(response.data as Map);
    return Map<String, dynamic>.from(data['outletTimings'] as Map);
  }

  Future<Map<String, dynamic>> updateOutletTimings(
    Map<String, dynamic> outletTimings,
  ) async {
    final response = await _dio.put(
      '/food/restaurant/outlet-timings',
      data: {'outletTimings': outletTimings},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return Map<String, dynamic>.from(data['outletTimings'] as Map);
  }

  /// Pre-uploads a document image (PAN/GST/FSSAI/UPI-QR/etc.) and returns its
  /// URL — the caller then folds that URL into an `updateProfile` patch.
  Future<String> uploadAttachment(
    XFile file, {
    String folder = 'others',
  }) async {
    final formData = FormData.fromMap({
      'folder': folder,
      'file': await xFileToMultipart(file),
    });
    final response = await _dio.post(
      '/food/restaurant/upload-attachment',
      data: formData,
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['url'] ?? '').toString();
  }

  /// Uploading a new logo resets the restaurant's approval status to
  /// `pending` server-side — callers must warn the owner before calling this
  /// on an already-approved restaurant.
  Future<String> uploadProfileImage(XFile file) async {
    final formData = FormData.fromMap({'file': await xFileToMultipart(file)});
    final response = await _dio.post(
      '/food/restaurant/profile/profile-image',
      data: formData,
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final profileImage = Map<String, dynamic>.from(data['profileImage'] as Map);
    return (profileImage['url'] ?? '').toString();
  }

  Future<Map<String, dynamic>> getMedia() async {
    final response = await _dio.get('/food/restaurant/media');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> uploadCoverImage(XFile file) async {
    final formData = FormData.fromMap({'file': await xFileToMultipart(file)});
    final response = await _dio.post(
      '/food/restaurant/media/cover-image',
      data: formData,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> uploadGalleryImages(List<XFile> files) async {
    final formData = FormData();
    for (final file in files) {
      formData.files.add(
        MapEntry('files', await xFileToMultipart(file)),
      );
    }
    final response = await _dio.post(
      '/food/restaurant/media/gallery',
      data: formData,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> deleteGalleryImage(String imageUrl) async {
    final response = await _dio.delete(
      '/food/restaurant/media/gallery',
      data: {'imageUrl': imageUrl},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}

final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) {
  return RestaurantRepository(ref.watch(dioProvider));
});
