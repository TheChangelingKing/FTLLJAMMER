local vter = mods.multiverse.vter
local userdata_table = mods.multiverse.userdata_table
local COLOR_WHITE = Graphics.GL_Color(1, 1, 1, 1)

local customBeams =
{
   SJ_FLAME_PROJECTOR = {
        beam = "sj_flamethrower_beam",
        impact="sj_flamethrower_beam_end",
        offset = 30
    }
}

local function has_custom_rendering(projectile)
    return projectile:GetType() == 5 and customBeams[projectile.extend.name]
end

local function normalize(color)
    local ret = Graphics.GL_Color()
    ret.r = color.r / 255
    ret.g = color.g / 255
    ret.b = color.b / 255
    ret.a = color.a
    return ret
end

local function draw_beam(start, finish, beam, width, renderImpact)
    local diff = finish - start
    local beamAngle = math.deg(math.atan(diff.y, diff.x))
    local beamLength = math.sqrt(diff.x ^ 2 + diff.y ^ 2)
    local beamTable = userdata_table(beam, "mods.sj.beamVisuals")
    local impactAnim = beamTable.impactAnim
    if renderImpact then
        beamLength = beamLength - impactAnim.info.frameHeight + beamTable.offset
    end

    local beamAnim = beamTable.beamAnim
    local segmentLength = beamAnim.info.frameHeight
    local segmentsNeeded = math.ceil(beamLength / segmentLength)
    Graphics.CSurface.GL_PushMatrix()    
    Graphics.CSurface.GL_Translate(start.x, start.y, 0)
    Graphics.CSurface.GL_Rotate(beamAngle, 0, 0)
    Graphics.CSurface.GL_Rotate(-90, 0, 0)
    Graphics.CSurface.GL_Scale(width, 1, 1)
    Graphics.CSurface.GL_Translate(-beamAnim.info.frameWidth / 2, 0)
    for i = 1, segmentsNeeded do
        local isLastSegment = i == segmentsNeeded
        local lastSegmentLength = beamLength % segmentLength
        if isLastSegment and not renderImpact and false then
            Graphics.CSurface.GL_PushStencilMode()
            Graphics.CSurface.GL_SetStencilMode(Graphics.STENCIL_SET, 0x80, 0x80)
            Graphics.CSurface.GL_DrawRect(-beamAnim.info.frameWidth / 2, lastSegmentLength, beamAnim.info.frameWidth, segmentLength - lastSegmentLength, COLOR_WHITE)
            Graphics.CSurface.GL_PopStencilMode()
        end
        beamAnim:OnRender(1, COLOR_WHITE, false)
        Graphics.CSurface.GL_Translate(0, isLastSegment and lastSegmentLength or segmentLength)
    end
    
    if renderImpact then
        Graphics.CSurface.GL_Translate(beamAnim.info.frameWidth / 2, 0)
        Graphics.CSurface.GL_Scale(1 / width, 1, 1)
        Graphics.CSurface.GL_Translate(-impactAnim.info.frameWidth / 2, 0)
        impactAnim:OnRender(1, COLOR_WHITE, false)
    end

    Graphics.CSurface.GL_PopMatrix()
end
local checkedCollision = {}
local function looped_anim(name)
    local anim = Hyperspace.Animations:GetAnimation(name)
    anim:Start(true)
    anim.tracker.loop = true
    return anim
end
local function render_custom_beam(beam, spaceId)
    if checkedCollision[beam.selfId] == false then return end
    if beam.movingTarget == nil then return end
    if beam.lifespan < 0 then return end

    local beamTable = userdata_table(beam, "mods.sj.beamVisuals")
    if not beamTable.inited then
        beamTable.beamAnim = looped_anim(customBeams[beam.extend.name].beam)
        beamTable.impactAnim = looped_anim(customBeams[beam.extend.name].impact)
        beamTable.offset = customBeams[beam.extend.name].offset or 0
        beamTable.inited = true
    end
    
    if beam.destinationSpace == spaceId then
        local shipImpact = beam.piercedShield
        local shieldImpact = beam.lastDamage < beam.damage.iDamage or not shipImpact
        if shipImpact then
            --NOTE: This iteration indexes by value and not by reference, which shouldn't be an issue for rendering but is if edits are made to the animations
            for anim in vter(beam.smokeAnims) do
                anim:OnRender(1, COLOR_WHITE, false)
            end
            draw_beam(beam.sub_start, beam.final_end, beam, math.max(beam.lastDamage, 1), true)
            --NOTE: This iteration indexes by value and not by reference, which shouldn't be an issue for rendering but is if edits are made to the animations
            --[[
                Graphics.CSurface.GL_PushMatrix()
                Graphics.CSurface.GL_Translate(beam.final_end.x - 24, beam.final_end.y - 33)
                for anim in vter(beam.contactAnimations) do
                    anim:OnRender(1, normalize(beam.color), false)
                end
                Graphics.CSurface.GL_PopMatrix()
            ]]
        end

        if shieldImpact then
            local stencilMask, stencilRef
            if beam.destinationSpace == 0 then
                stencilMask = 0x10
                stencilRef = 0
            else
                stencilMask = 0x30
                stencilRef = 0x20
            end
            Graphics.CSurface.GL_PushStencilMode()
            Graphics.CSurface.GL_SetStencilMode(Graphics.STENCIL_SET, stencilMask, stencilMask)
            local ellipse = beam.movingTarget:GetShieldShape()
            Graphics.CSurface.GL_DrawEllipse(ellipse.center.x, ellipse.center.y, ellipse.a, ellipse.b, Graphics.GL_Color(1, 0, 0, 1))
            Graphics.CSurface.GL_SetStencilMode(Graphics.STENCIL_USE, stencilRef, stencilMask)
            draw_beam(beam.sub_start, beam.final_end, beam, math.max(beam.damage.iDamage, 1))
            Graphics.CSurface.GL_PopStencilMode()
        end
    elseif beam.currentSpace == spaceId and not beam.oneSpace then
        draw_beam(beam.position, beam.sub_end, beam, math.max(beam.damage.iDamage, 1))
    end
end

--Best match for where Projectile::OnRender is called, replace this code when a render event for this is implemented
script.on_render_event(Defines.RenderEvents.SHIP,
function (shipManager)
    for projectile in vter(Hyperspace.App.world.space.projectiles) do
        if has_custom_rendering(projectile) then
            --Block vanilla rendering
            checkedCollision[projectile.selfId] = projectile.checkedCollision
            projectile.checkedCollision = false
            --Match vanilla conditions for rendering on this layer
            if projectile:GetOwnerId() == shipManager.iShipId then
                render_custom_beam(projectile, shipManager.iShipId)
            end
        end
    end
    return Defines.Chain.CONTINUE
end,
function (shipManager)
    for projectile in vter(Hyperspace.App.world.space.projectiles) do
        if has_custom_rendering(projectile) then
            --Restore projectile values
            projectile.checkedCollision = checkedCollision[projectile.selfId]
            --Match vanilla conditions for rendering on this layer
            if projectile:GetOwnerId() ~= shipManager.iShipId or shipManager.iShipId == projectile.destinationSpace then
                render_custom_beam(projectile, shipManager.iShipId)
            end
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_UPDATE_POST,
function (projectile, preempted)
    if not preempted and has_custom_rendering(projectile) then
        local beamTable = userdata_table(projectile, "mods.sj.beamVisuals")
        if beamTable.inited then --Not true on reload
            beamTable.beamAnim:Update()
            beamTable.impactAnim:Update()
        end
    end
end)