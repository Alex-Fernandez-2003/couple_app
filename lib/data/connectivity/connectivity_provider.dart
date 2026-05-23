import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/legacy.dart';

enum ConnectionStatus { unknown, online, offline }

class ConnectivityNotifier extends StateNotifier<ConnectionStatus> {
  ConnectivityNotifier() : super(ConnectionStatus.unknown) {
    _initialize();
  }

  StreamSubscription<ConnectivityResult>? _subscription;

  Future<void> _initialize() async {
    final result = await Connectivity().checkConnectivity();
    state = _map(result);

    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      state = _map(result);
    });
  }

  ConnectionStatus _map(ConnectivityResult result) {
    return result == ConnectivityResult.none
        ? ConnectionStatus.offline
        : ConnectionStatus.online;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectionStatus>(
      (ref) => ConnectivityNotifier(),
    );
