-- Forecasts: storm variations the crew votes on before sailing (launch R9, owner-approved Oct 12 2026).
-- Each changes ONE thing about the voyage so run #5 doesn't feel like run #1. Rewards never change.
-- The server publishes the active values on GameState as attributes:
--   Forecast (id or ""), ForecastWideMult, ForecastCrabMult, ForecastCrabHpMult, ForecastFuelMult
-- Switch off with Config.FORECASTS_ENABLED = false.

local Forecasts = {
	ORDER = { "FogBank", "SpringTide", "LeakyStores" },

	FogBank = {
		displayName = "Fog bank",
		summary = "The wide beam is 30% narrower. Aim carefully; focus still cuts through.",
		short = "Narrow wide beam",
		wideMult = 0.7,
	},
	SpringTide = {
		displayName = "Spring tide",
		summary = "40% more crabs come ashore, but each is 20% weaker. Sweep the crowds.",
		short = "More, weaker crabs",
		crabMult = 1.4,
		crabHpMult = 0.8,
	},
	LeakyStores = {
		displayName = "Leaky stores",
		summary = "The lamp drinks 25% more oil. Keep the barrels moving.",
		short = "Lamp burns more oil",
		fuelMult = 1.25,
	},
}

return Forecasts
