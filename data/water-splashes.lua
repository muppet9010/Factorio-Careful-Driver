local TableUtils = require("utility.helper-utils.table-utils")

local offGridWaterSplash = TableUtils.DeepCopy(data.raw["explosion"]["water-splash"]) --[[@as Prototype.Explosion]]
offGridWaterSplash.name = "careful_driver-water_splash-off_grid"
offGridWaterSplash.flags[#offGridWaterSplash.flags + 1] = "placeable-off-grid"

data:extend({ offGridWaterSplash })
