-- TASK-010 R3 STATUS COMMAND (final). Read-only in-memory status, Server DataModel of the Play session.
-- Play may be stopped only when the returned safeToStopPlay is true
-- (terminal, approval flag reset, and the synthetic session released in the stored record, or never started).
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local T = game:GetService("ServerStorage").TestOnly
return game:GetService("HttpService"):JSONEncode(require(T.R3ServerRunner).status())
