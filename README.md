# Factorio Careful Driver



Encourages players to be careful drivers via negative reinforcement.

This is a mod that is still being added too, see the Future Ideas list at the end of this file for plans.



Features
--------

- Cars and tanks that drive in to water take some damage and become stuck in the water. You have to mine the vehicle to recover it.
- Cars and tanks that drive in to void/out-of-map tiles fall off the planet. The vehicle is gone.
- Cars and tanks that drive in to cliffs take damage as the cliff is more solid than the tank.



Random Notes
------------

- When vehicles collide with cliffs they take as much damage as they do when colliding with other indestructible things. This is basically how much damage they would do to other things they hit, but bounced back to them, minus their resistances. So a heavy weight tank hitting a cliff at high speed hurts the tank a lot. Driving in to water does half the base damage to the vehicle as hitting a cliff, as water is a bit more forgiving than solid rock.
- The graphics for the vehicles in water are quick (few hours) in GIMP per vehicle. They aren't a work of art, but should look a bit "off" from the lower vehicle part being in water. The aim was for it to be apparent it wasn't a standard vehicle.



Mod Compatibility
-----------------

- This mod doesn't change any of the collision masks of default entity types. So it should have no impact on other mods actions.
- This mod does make custom graphics from other vehicles in the game. This has been designed around base game vehicles, so may need further additions to be able to handle all the different way modded vehicle graphics can be specified in code.
- The graphics used for when road vehicles end up in the water have to be specifically made. Where these haven't been made for modded vehicles the regular vehicle graphic will be used instead. These graphics are just to help signify the vehicle isn't normal any more, rather than being game critical in some way.



Future Ideas
------------

- Players can walk in to the water or void and treated similar to how vehicles are currently.
- A way for players to appear to stay in the water/void vehicle for a few seconds until the effect finishes, then get ejected. Will need to be done in a way that doesn't confuse other mods in to thinking the player died. Mod option for if players are ejected from void entering cars or not.
- Mod options for if items in vehicle/player are lost on relevant effects (entering void/water).
- Trains that are driven to the end of a rail track will derail.
- Trains won't stop instantly when they loose their path. Instead they will have to slow down at their max breaking speed. This will take effect when a player messes with a trains orders while its moving or removes rail track in a rail network.
- Some feature around spider-vehicles walking in to water and off the map (void tiles). At present nothing is done to spider vehicles.
- Mod settings for damage percent taken by vehicles crashing in to cliffs and water. Not sure needed, but some will probably want to tweak it.
- Add mod settings to disable features, by default all will be on at present.