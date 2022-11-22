data:extend(
    {
        {
            name = "careful_driver-car_cliff_collision",
            type = "bool-setting",
            default_value = true,
            setting_type = "runtime-global",
            order = "1001"
        },
        {
            name = "careful_driver-car_cliff_damage_multiplier",
            type = "double-setting",
            default_value = 100,
            minimum_value = 0,
            setting_type = "runtime-global",
            order = "1002"
        },
        {
            name = "careful_driver-car_water_collision",
            type = "bool-setting",
            default_value = true,
            setting_type = "runtime-global",
            order = "1101"
        },
        {
            name = "careful_driver-car_water_damage_multiplier",
            type = "double-setting",
            default_value = 50,
            minimum_value = 0,
            setting_type = "runtime-global",
            order = "1102"
        },
        {
            name = "careful_driver-car_void_collision",
            type = "bool-setting",
            default_value = true,
            setting_type = "runtime-global",
            order = "1201"
        }
    }
)
