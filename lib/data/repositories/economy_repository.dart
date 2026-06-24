import '../models/wallet.dart';
import '../services/supabase_service.dart';

/// The credit economy: wallet, the onboarding grant, the help-request board,
/// and the escrow lifecycle (post → accept → confirm).
///
/// All credit movement happens through SECURITY DEFINER RPCs that enforce the
/// conservation + non-negative-balance invariants server-side — the client only
/// names the action.
class EconomyRepository {
  const EconomyRepository();

  Future<Wallet> wallet() async {
    final res = await SupabaseService.client.rpc('get_wallet');
    return Wallet.fromJson(res as Map<String, dynamic>);
  }

  /// Claim the one-time, identity-gated 5-credit onboarding grant.
  /// Returns the new balance. Throws if already claimed / not onboarded.
  Future<int> claimGrant() async {
    final res = await SupabaseService.client.rpc('claim_onboarding_grant')
        as Map<String, dynamic>;
    return (res['credits'] as num?)?.round() ?? 0;
  }

  /// Open requests posted by other builders.
  Future<List<BoardRequest>> board() async {
    final rows =
        await SupabaseService.client.rpc('get_help_board') as List<dynamic>;
    return [
      for (final r in rows) BoardRequest.fromJson(r as Map<String, dynamic>),
    ];
  }

  /// Your own requests — both ones you posted and ones you're helping with.
  Future<List<MyRequest>> myRequests() async {
    final rows =
        await SupabaseService.client.rpc('get_my_requests') as List<dynamic>;
    return [
      for (final r in rows) MyRequest.fromJson(r as Map<String, dynamic>),
    ];
  }

  /// Post a help request. The price is computed server-side from size + urgency.
  /// Returns the credits it will cost (escrowed when a helper accepts).
  Future<int> post({
    required String title,
    String? description,
    String? skillId,
    required String size,
    required bool urgent,
  }) async {
    final res = await SupabaseService.client.rpc('post_help_request', params: {
      'p_title': title,
      'p_description': description,
      'p_skill_id': skillId,
      'p_size': size,
      'p_urgency': urgent ? 'urgent' : 'normal',
    }) as Map<String, dynamic>;
    return (res['credits'] as num?)?.toInt() ?? 0;
  }

  /// Accept someone's request — escrows their credits until they confirm.
  Future<void> accept(String requestId) async {
    await SupabaseService.client
        .rpc('accept_help_request', params: {'p_request': requestId});
  }

  /// Confirm a helper delivered — releases the escrow to them.
  Future<void> confirm(String requestId) async {
    await SupabaseService.client
        .rpc('confirm_help_request', params: {'p_request': requestId});
  }

  /// Cancel one of your still-open requests.
  Future<void> cancel(String requestId) async {
    await SupabaseService.client
        .rpc('cancel_help_request', params: {'p_request': requestId});
  }
}
