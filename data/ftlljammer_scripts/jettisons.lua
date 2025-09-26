--- This script handles Jettison weapons, which are weapons that fire a random number of projectiles.
---@type { [string]: fun(): integer } A map of weapon blueprint names to functions that return an integer indicating how many shots this weapon should fire. Currently only implemented properly for BURST type weapons.
local jettisons = {
    SJ_SMALL_JETTISON = function() 
        return math.random(4)
    end,
    SJ_MEDIUM_JETTISON = function()
        return math.random(4) + math.random(4)
    end,
    SJ_LARGE_JETTISON = function() 
        return math.random(4) + math.random(4) + math.random(4)
    end,
}
---@param weaponBlueprint Hyperspace.WeaponBlueprint The blueprint to initialize the projectile with. Responsible for the projectile's damage, speed, and other such parameters.
---@param image String The image to use for the projectile. This is the same as what you would put in the <projectiles> tag in the weaponBlueprint in order to define a projectile's appearance.
---@param fake boolean Whether or not the projectile is a fake projectile. Fake projectiles are smaller and do not deal damage.
---@param position Hyperspace.Pointf The position to spawn the projectile at.
---@param startingSpace integer The space to spawn the projectile in. 0 is the space of the player ship, 1 is the space of the enemy ship.
---@param ownerId integer The ID of the projectile's owner. This is used to determine if friendly fire is occuring or not. 0 indicates the player, 1 indicates the enemy, -1 indicates neutral.
---@param target Hyperspace.Pointf The target position of the projectile. This is where the projectile will move towards.
---@param targetSpace integer The space of the target. 0 is the space of the player ship, 1 is the space of the enemy ship.
---@param heading integer Determines the direction the projectile will travel in. The value is an angle in degrees, clockwise from the right. This parameter is ignored if targetSpace is the same as startingSpace.
---@return Hyperspace.LaserBlast The projectile that was created. This is a reference to the projectile, and can be used to edit attributes of the projectile after its creation.
local function create_burst_projectile(weaponBlueprint, image, fake, position, startingSpace, ownerId, target, targetSpace, heading)
    ---@type Hyperspace.SpaceManager The instance of the space manager for the game. This class is responsible for managing projectiles, drones, and collisions in space.
    local space = Hyperspace.App.world.space
    return space:CreateBurstProjectile(weaponBlueprint, image, fake, position, startingSpace, ownerId, target, targetSpace, heading)
end

---@param center Hyperspace.Pointf The center of the circle within which to generate a random point.
---@param radius number The radius of the circle within which to generate a random point.
---@return Hyperspace.Pointf A random point within the circle defined by the center and radius.
local function get_random_point_in_circle(center, radius)
    ---@type number A random angle in radians.
    local angle = math.random() * 2 * math.pi
    ---@type number A random distance from the center, uniformly distributed between 0 and the radius.
    local distance = math.sqrt(math.random()) * radius
    ---@type Hyperspace.Pointf The random point within the circle defined by the center and radius.
    return Hyperspace.Pointf(center.x + distance * math.cos(angle), center.y + distance * math.sin(angle))
end

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function (projectile, weapon)
    ---@type fun(): integer A function that returns a random integer indicating how many projectiles this weapon should fire.
    local roll_function = jettisons[weapon.blueprint.name]
    if roll_function ~= nil then
        ---@type integer How many shots to fire.
        local shots = roll_function()
        ---@type Hyperspace.Pointf The position at the center of the weapon's current targeting radius.
        local center = weapon.lastTargets[0]
        ---@type integer The radius of the current weapons.
        local radius = weapon.blueprint.radius
        for i = 1, shots do
            ---@type Hyperspace.Pointf A random point within the circle defined by the center and radius of the weapon's current targeting radius.
            local target = get_random_point_in_circle(center, radius)
            ---@type Hyperspace.Projectile The newly created projectile.
            local newProjectile = create_burst_projectile(
                weapon.blueprint,
                projectile.flight_animation.animName,
                false,
                projectile.position,
                projectile.currentSpace,
                projectile.ownerId,
                target,
                projectile.destinationSpace,
                projectile.heading
            )
            newProjectile.entryAngle = projectile.entryAngle --entryAngle is the angle at which the projectile enters the new space.
        end
        projectile:Kill() --Kill the fired projectile now that new projectiles have been spawned.
    end
end)