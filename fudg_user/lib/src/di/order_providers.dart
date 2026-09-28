import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/order_remote_datasource.dart';
import '../data/datasources/order_rtdb_datasource.dart';
import 'network_providers.dart';

final orderRemoteDataSourceProvider = Provider<OrderRemoteDataSource>((ref) {
  return OrderRemoteDataSource(ref.watch(apiClientProvider));
});

final orderRtdbDataSourceProvider = Provider<OrderRtdbDataSource>((ref) {
  return OrderRtdbDataSource();
});
