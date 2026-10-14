# DEAD ENDS

> Append-only. Record a FAILED approach the moment it fails.
> The next agent must be able to skip these without re-investigating.
> If you spent more than 10 minutes on something that did not work, log it here.

## DE-001
- Date: YYYY-MM-DD
- Tried:
- Where: <!-- file, function, command -->
- Result:
- Why it failed:
- Do NOT retry because:
- Logged by: <agent-name>

<!--
### Example

## DE-002
- Date: 2026-10-14
- Tried: Caching session tokens in Redis with a 24h TTL
- Where: src/auth/cache.ts, `storeSession()`
- Result: Users randomly logged out mid-session
- Why it failed: Redis evicts under memory pressure; no LRU protection configured
- Do NOT retry because: upstream instance limits eviction policy config
- Logged by: opencode
-->
