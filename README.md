# Factorio Careful Driver



Encourages players to be careful drivers via negative reinforcement.

This is a mod that is still being added too, see the Future Ideas list at the end of this file for plans.



Features
--------

- Cars and tanks that drive in to cliffs take damage as the cliff is more solid than the tank.
- Cars and tanks that drive in to water take some damage and become stuck in the water. You have to mine the vehicle to recover it.
- Cars and tanks that drive in to void/out-of-map tiles fall off the planet. The vehicle is gone.
- All features can be disabled and controlled via mod settings.



Random Notes
------------

- When vehicles collide with cliffs they take as much damage as they do when colliding with other indestructible things. This is basically how much damage they would do to other things they hit, but bounced back to them, minus their resistances. So a heavy weight tank hitting a cliff at high speed hurts the tank a lot. Driving in to water does half the base damage to the vehicle as hitting a cliff, as water is a bit more forgiving than solid rock.
- The graphics for the vehicles in water are quick (few hours) in GIMP per vehicle. They aren't a work of art, but should look different enough from the lower vehicle part being in water. The aim was for it to be apparent it wasn't a standard vehicle.



Mod Compatibility
-----------------

- This mod doesn't change any of the collision masks of default entity types. So it should have no impact on other mods.
- This mod does make custom graphics from other vehicles in the game. This has been designed around base game vehicles, so may need further additions to be able to handle all the different way modded vehicle graphics can be specified in code.
- The graphics used for when road vehicles end up in the water have to be specifically made. Where these haven't been made for modded vehicles the regular vehicle graphic will be used instead. These graphics are just to help signify the vehicle isn't normal any more, rather than being game critical in some way.
- The collision with water and void tiles features use collision_masks to detect if a collision has occurred. So this should work with any modded tiles.
- Vehicles stuck in the water are made inactive, to both stop them being used as glitchy gun emplacements and so that other mods can recognise these vehicles as not being drivable.



Future Ideas
------------

- Players can walk in to the water or void and treated similar to how vehicles are currently. Also player walk in to water would tie in to getting out of a car stuck in the water.
- Players can walk down cliffs going high to low side of the cliff. Does a percentage of max health damage, ignoring shields.
- Trains that are driven to the end of a rail track will derail.
- Trains won't stop instantly when they loose their path. Instead they will have to slow down at their max breaking speed. This will take effect when a player messes with a trains orders while its moving or removes rail track in a rail network.
- No plans for spider-vehicles walking in to water or off the map (void tiles). As the vehicle is "smart" due to its fish brain and only puts feet where they are safe. They also don't try to over reach with feet in to unstable positions.