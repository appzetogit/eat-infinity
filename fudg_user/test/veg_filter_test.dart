import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/src/presentation/home/viewmodels/veg_filter_provider.dart';

/// The Home switch and the screens that read it must agree, so this pins the
/// shared state rather than any one widget: a toggle that does not flip, or
/// does not start off, is the whole "the button does nothing" bug.
void main() {
  test('veg mode starts off and flips on toggle', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(vegFilterProvider), isFalse);

    container.read(vegFilterProvider.notifier).toggle();
    expect(container.read(vegFilterProvider), isTrue);

    container.read(vegFilterProvider.notifier).toggle();
    expect(container.read(vegFilterProvider), isFalse);
  });

  test('set is idempotent, so Profile and Home cannot fight', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(vegFilterProvider.notifier).set(true);
    container.read(vegFilterProvider.notifier).set(true);
    expect(container.read(vegFilterProvider), isTrue);
  });
}
