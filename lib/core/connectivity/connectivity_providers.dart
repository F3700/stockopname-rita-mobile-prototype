import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ONLINE/OFFLINE untuk banner + gerbang upload. Scan tidak memakainya.
final connectivityProvider =
    StreamProvider<List<ConnectivityResult>>((ref) {
  final sub = Connectivity().onConnectivityChanged;
  return sub;
});

final isOnlineProvider = Provider<bool>((ref) {
  final async = ref.watch(connectivityProvider);
  return async.maybeWhen(
    data: (results) => !results.contains(ConnectivityResult.none),
    orElse: () => true,
  );
});
