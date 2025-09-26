local vter = mods.multiverse.vter
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, 
function(shipManager)
    if shipManager:HasAugmentation("SJ_SMALLJAMMER_TIMIDNESS") > 0 then 
        for weapon in vter(shipManager:GetWeaponList()) do 
            if weapon.requiredPower > 2 then 
                weapon.cooldown.first = -1
                weapon.cooldown.second = -1
            end
        end 
    end
end)