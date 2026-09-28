import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaymentMethodModel {
  final String id;
  final String type; // 'Card', 'UPI', 'Wallet', 'NetBanking'
  final String title;
  final String subtitle;
  final bool isDefault;

  const PaymentMethodModel({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.isDefault = false,
  });

  PaymentMethodModel copyWith({
    String? id,
    String? type,
    String? title,
    String? subtitle,
    bool? isDefault,
  }) {
    return PaymentMethodModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

final paymentViewModelProvider = NotifierProvider<PaymentViewModel, List<PaymentMethodModel>>(() {
  return PaymentViewModel();
});

class PaymentViewModel extends Notifier<List<PaymentMethodModel>> {
  @override
  List<PaymentMethodModel> build() {
    // Empty by design. This used to seed three fabricated instruments (a
    // real-looking UPI handle, an "HDFC card ending 4921"). This backend stores
    // no saved payment methods — Razorpay is invoked per order — so there is
    // nothing truthful to list until such an endpoint exists.
    return const [];
  }

  void addPaymentMethod(PaymentMethodModel method) {
    if (method.isDefault) {
      state = state.map((m) => m.copyWith(isDefault: false)).toList();
    }
    state = [...state, method];
  }

  void removePaymentMethod(String id) {
    state = state.where((m) => m.id != id).toList();
    if (state.isNotEmpty && !state.any((m) => m.isDefault)) {
      state = [
        state.first.copyWith(isDefault: true),
        ...state.sublist(1),
      ];
    }
  }

  void setDefaultPaymentMethod(String id) {
    state = state.map((m) => m.copyWith(isDefault: m.id == id)).toList();
  }
}
