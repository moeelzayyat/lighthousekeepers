-- TASK-009 R2 STATUS COMMAND (read-only; polls the in-memory status of the running test; makes no DataStore call)
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local T = game.ServerStorage.TestOnly
return game:GetService("HttpService"):JSONEncode(require(T.R2SaveLoad).status())
