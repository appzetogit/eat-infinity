import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/offers/domain/offer_model.dart';

class OfferRepository {
  OfferRepository(this._dio);

  final Dio _dio;

  static const _base = '/food/restaurant/my-offers';

  Future<List<OfferModel>> list() async {
    final response = await _dio.get(_base);
    final data = Map<String, dynamic>.from(response.data as Map);
    final list = (data['offers'] as List? ?? []);
    return list
        .map((e) => OfferModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<OfferModel> get(String id) async {
    final response = await _dio.get('$_base/$id');
    return _doc(response);
  }

  Future<OfferModel> create(OfferDraft draft) async {
    final response = await _dio.post(_base, data: draft.toJson());
    return _doc(response);
  }

  Future<OfferModel> update(String id, OfferDraft draft) async {
    final response = await _dio.put('$_base/$id', data: draft.toJson());
    return _doc(response);
  }

  /// `active` resumes, `paused` pauses, `inactive` ends the offer.
  Future<void> updateStatus(String id, String status) async {
    await _dio.patch('$_base/$id/status', data: {'status': status});
  }

  Future<void> delete(String id) async {
    await _dio.delete('$_base/$id');
  }

  OfferModel _doc(Response response) {
    final data = Map<String, dynamic>.from(response.data as Map);
    return OfferModel.fromJson(Map<String, dynamic>.from(data['doc'] as Map));
  }
}

final offerRepositoryProvider = Provider<OfferRepository>((ref) {
  return OfferRepository(ref.watch(dioProvider));
});
