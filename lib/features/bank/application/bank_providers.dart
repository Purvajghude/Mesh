import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/models/wallet.dart';

/// The signed-in user's credit wallet (balance, escrow, grant state).
final walletProvider = FutureProvider<Wallet>((ref) {
  return ref.watch(economyRepositoryProvider).wallet();
});

/// Open help requests from other builders.
final helpBoardProvider = FutureProvider<List<BoardRequest>>((ref) {
  return ref.watch(economyRepositoryProvider).board();
});

/// Your own requests (as requester and as helper).
final myRequestsProvider = FutureProvider<List<MyRequest>>((ref) {
  return ref.watch(economyRepositoryProvider).myRequests();
});
