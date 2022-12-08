-- Entities of tile types or other things we want to be able to attribute damage/death too.

---@type Prototype.Tile
local tokenWaterTile = {
    type = "simple-entity",
    name = "careful_driver-token_water_entity",
    icons = {
        {
            icon = "__base__/graphics/terrain/water/hr-water-o.png",
            icon_size = 64,
            scale = 0.5
        }
    },
    picture = {
        filename = "__base__/graphics/terrain/water/hr-water-o.png",
        height = 64,
        width = 64,
        scale = 0.5
    },
    collision_mask = {},
    render_layer = "water-tile",
    secondary_draw_order = -127,
    tile_width = 1,
    tile_height = 1
}

---@type Prototype.Tile
local tokenVoidTile = {
    type = "simple-entity",
    name = "careful_driver-token_void_entity",
    icons = {
        {
            icon = "__base__/graphics/terrain/out-of-map.png",
            icon_size = 32
        }
    },
    picture = {
        filename = "__base__/graphics/terrain/out-of-map.png",
        height = 32,
        width = 32,
    },
    collision_mask = {},
    render_layer = "water-tile",
    secondary_draw_order = -127,
    tile_width = 1,
    tile_height = 1
}

data:extend({ tokenWaterTile, tokenVoidTile })
