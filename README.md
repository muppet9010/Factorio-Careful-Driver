# Factorio Careful Driver



Encourages players to be careful drivers via negative reinforcement.



Features
--------

- Cars and tanks that drive in to water take some damage and become stuck in the water. You have to mine the vehicle to recover it.
- Cars and tanks that drive in to void/out-of-map tiles fall off the planet. The vehicle is gone.
- Cars and tanks that drive in to cliffs take damage as the cliff is more solid than the tank.


Mod Compatibility
-----------------

- This mod doesn't change any of the collision masks of default entity types. So it should have no impact on other mods actions.
- This mod does make custom graphics from other vehicles in the game. This has been designed around base game vehicles, so may need further additions to be able to handle all the different way modded vehicle graphics can be specified in code.
- The graphics used for when road vehicles end up in the water have to be specifically made. I am no artist so they are a bit crude and the entire vehicle has an alternative graphic, despite sometimes only part of the vehicle being in the water. Where these haven't been made for modded vehicles the regular vehicle graphic will be used instead. These graphics are just to help signify the vehicle isn't normal any more.


Future Ideas
------------

- Players can walk in to the water or void and treated similar to how vehicles are currently.
- Trains that are driven to the end of a rail track will derail.
- Add mod settings to disable features, by default all will be on at present.
- Trains won't stop instantly when they loose their path. Instead they will have to slow down at their max breaking speed. This will take effect when a player messes with a trains orders while its moving or removes rail track in a rail network.
- Some feature around spider-vehicles walking in to water and off the map (void tiles). At present nothing is done to spider vehicles.