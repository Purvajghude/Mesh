-- Tighten the economy functions to match the project's security posture.

-- credit_balance is a backend-internal helper (called only inside other
-- SECURITY DEFINER functions). Supabase grants EXECUTE to anon/authenticated by
-- default, so revoke explicitly — internal definer calls are unaffected.
revoke all on function credit_balance(uuid) from anon, authenticated;

-- Pin search_path on the pricing helper (security plan: set on every function).
alter function help_request_price(text, text) set search_path to 'public';

-- The feed reader should require sign-in, like the rest of the API.
revoke all on function get_feed(text, integer) from anon;
