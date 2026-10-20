-- Interaction ids of plain locked doors. Drill, keycard, and deposit-box locks are deliberately not listed.
local SHOOTABLE_LOCKS = {
	pick_lock = true,
	pick_lock_easy = true,
	pick_lock_easy_no_skill = true,
	pick_lock_hard = true,
	pick_lock_hard_no_skill = true
}

-- Used when the menu mod settings are unavailable. Every bullet that hits the lock counts as one hit, so a shotgun blast (many pellets) breaks it faster.
local DEFAULT_HITS = 3
-- How far an unsuppressed lock break is heard in stealth, in cm.
local LOUD_BREAK_RADIUS = 1500
local SPARKS = Idstring("effects/payday2/particles/impacts/steel_no_decal_impact_pd2")

local lock_hits = {}

local function is_suppressed(weapon_unit)
	local base = alive(weapon_unit) and weapon_unit:base()
	return base and base.got_silencer and base:got_silencer() or false
end

local function on_lock_broken(player, unit, col_ray, weapon_unit)
	pcall(function()
		World:effect_manager():spawn({
			effect = SPARKS,
			position = col_ray.position,
			normal = col_ray.normal
		})
	end)

	-- Stealth: a suppressed weapon breaks the lock quietly, anything else is heard nearby.
	local groupai = managers.groupai and managers.groupai:state()
	if groupai and groupai:whisper_mode() and not is_suppressed(weapon_unit) then
		pcall(function()
			groupai:propagate_alert({
				"vo_cbt",
				col_ray.position,
				LOUD_BREAK_RADIUS,
				groupai:get_unit_type_filter("civilians_enemies"),
				player
			})
		end)
	end

	-- Completes the interaction exactly as a finished lockpick would (sequence, sync, deactivation).
	unit:interaction():interact(player)
end

Hooks:PostHook(InstantBulletBase, "on_collision", "ShootLocksOpen_on_collision", function(self, col_ray, weapon_unit, user_unit, damage, blank)
	if blank or not col_ray then
		return
	end

	local player = managers.player and managers.player:player_unit()
	if not alive(player) or user_unit ~= player then
		return
	end

	local unit = col_ray.unit
	if not alive(unit) or not unit:interaction() then
		return
	end

	local interaction = unit:interaction()
	if not SHOOTABLE_LOCKS[interaction.tweak_data] or not interaction:active() then
		return
	end

	local hits_required = DEFAULT_HITS
	if ShootLocksOpen then
		hits_required = ShootLocksOpen:GetHitsRequired(weapon_unit)
	end
	if not hits_required then
		return
	end

	-- Each hit adds 1 / hits_required, so a lock worn down by different weapon classes still breaks at 100%.
	local key = unit:key()
	local progress = (lock_hits[key] or 0) + 1 / hits_required
	if progress >= 0.999 then
		lock_hits[key] = nil
		on_lock_broken(player, unit, col_ray, weapon_unit)
	else
		lock_hits[key] = progress
	end
end)
