# REF-code-samples
Some parts of the code of Research Expeditionary Force, a top-down 3D shooter in Godot, which drive major parts of the game. These cover AI behavior and the weapon system. These files do not run standalone but they help to illustrate some of the features you can see in the gameplay demo, which is here: https://www.youtube.com/watch?v=fEul8af8hRo 

**ENEMY_ATTACK_SUBSTATES.GD**
This is one of 3 scripts that make up the enemy's behavior, alongside a script for their idle state and alert state. It works with the squad to decide its current role. Enemies have two squad roles, attack and cover. They request role changes through the squad, which limits how many can attack at once. The substates are attack delay, warn, hold, chase, cover, and cover-close. This script shows how enemies decide when to break off an attack, push in, or reposition while staying in cover, and how they call out information through the speech module.

**LOS_MODULE.GD**
The los_module handles how enemies see the world. Enemies see the player in three tiers: none, partial, and center. A raycast to the player’s center, followed by a shapecast to check for obstruction, determines CENTER (clear) or PARTIAL (something blocks part of the path). If the center ray is blocked, a sweep of angled raycasts looks for a sliver of the player, such as a shoulder around a corner. A reaction_time counter adds a short delay before enemies react, and it counts back down after the player is lost. That means enemies don’t snap to the player instantly, and they briefly keep tracking the player’s position after losing sight, like a person guessing where someone just went.

**EQS_TESTER.GD**
The Environment Query System I've built within this script is how the enemies in REF decide where to move when searching, taking cover and attacking. It works on a set of inputs where the center of the grid is set and a number of points are placed around it. These points are then tested against parameters to see if they fit a description; e.g. a query for an enemy taking cover from the player would check points that have a raycast hitting a wall between them. There are parameters for pathfinding, raycasting and shapecasting, and distance. Currently it returns a list of unweighted points; any weighting (e.g. pick the closest point from the list) is handled by the enemy when they receive the list. This is a very critical system and allows much of the enemy to do things besides stand and shoot, and is also used to enforce spacing so enemies don't clump up too much in their destinations.

**RANGED_WEAPONS.GD**
This script acts as a template for Godot's resource system. It can be instantiated and any export variable can be modified to change the functionality of a gun. It's used by ranged_weapon_node.gd.

**RANGED_WEAPON_NODE.GD**
This script takes the resource instance created from ranged_weapons.gd and actually executes based on the latter's parameters. It involves things like handling if the weapon fires in burst, how accurate the gun is, how many pellets are released on each shot (good for shotguns), fire rate and other things. It also provides setup for placing the weapon model as a child of the player's hand so it can move with the animations.
