import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/offers/data/offer_repository.dart';
import 'package:food_user_application/features/offers/domain/offer_model.dart';

class OfferController extends AsyncNotifier<List<OfferModel>> {
  @override
  Future<List<OfferModel>> build() {
    return ref.read(offerRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(offerRepositoryProvider).list(),
    );
  }

  Future<void> create(OfferDraft draft) async {
    await ref.read(offerRepositoryProvider).create(draft);
    await refresh();
  }

  Future<void> save(String id, OfferDraft draft) async {
    await ref.read(offerRepositoryProvider).update(id, draft);
    await refresh();
  }

  /// `active` resumes, `paused` pauses, `inactive` ends the offer for good.
  Future<void> setStatus(String id, String status) async {
    await ref.read(offerRepositoryProvider).updateStatus(id, status);
    await refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(offerRepositoryProvider).delete(id);
    await refresh();
  }
}

final offerControllerProvider =
    AsyncNotifierProvider<OfferController, List<OfferModel>>(
      OfferController.new,
    );
