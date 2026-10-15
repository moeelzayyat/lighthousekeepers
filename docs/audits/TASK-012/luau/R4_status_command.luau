-- TASK-012 R4 STATUS COMMAND. Read-only in-memory status, Server DataModel of the Play session.
-- The approved Stop Play may happen only when readyForApprovedStop is true.
-- After a failure, Play may be stopped only when safeToStopAfterFailure is true.
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local T = game:GetService("ServerStorage").TestOnly
return game:GetService("HttpService"):JSONEncode(require(T.R4ShutdownRunner).status())
