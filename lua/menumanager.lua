_G.ShootLocksOpen = _G.ShootLocksOpen or {}
local SLO = _G.ShootLocksOpen
SLO.mod_path = ModPath
SLO.save_path = SavePath .. "shoot_locks_open.txt"

-- Weapon classes (weapon tweak_data categories), in menu order.
SLO.classes = { "assault_rifle", "smg", "snp", "shotgun", "lmg", "pistol", "akimbo", "minigun", "saw" }
SLO.default_hits = 3

-- For each class: whether it may shoot locks open, and how many hits it takes ("hits_<class>").
SLO.settings = {}
for _, class in ipairs(SLO.classes) do
	SLO.settings[class] = true
	SLO.settings["hits_" .. class] = SLO.default_hits
end

function SLO:Load()
	local file = io.open(self.save_path, "r")
	if file then
		local data = json.decode(file:read("*all"))
		file:close()
		for k, v in pairs(data or {}) do
			if self.settings[k] ~= nil then
				self.settings[k] = v
			end
		end
	end
end

function SLO:Save()
	local file = io.open(self.save_path, "w")
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end

-- Hits needed for this weapon to break a lock, or nil if none of its classes may.
-- A weapon in several classes (e.g. akimbo pistols) uses the lowest count among its enabled classes.
-- Weapons with no known class use the default count.
function SLO:GetHitsRequired(weapon_unit)
	local base = alive(weapon_unit) and weapon_unit:base()
	local tweak = base and base.weapon_tweak_data and base:weapon_tweak_data()
	local known, hits = false, nil
	for _, category in ipairs(tweak and tweak.categories or {}) do
		if self.settings[category] ~= nil then
			known = true
			if self.settings[category] then
				local needed = self.settings["hits_" .. category]
				hits = hits and math.min(hits, needed) or needed
			end
		end
	end
	if not known then
		return self.default_hits
	end
	return hits
end

Hooks:Add("LocalizationManagerPostInit", "ShootLocksOpen_loc", function(loc)
	loc:load_localization_file(SLO.mod_path .. "loc/en.txt")
end)

Hooks:Add("MenuManagerInitialize", "ShootLocksOpen_menu", function(menu_manager)
	MenuCallbackHandler.callback_slo_toggle = function(self, item)
		SLO.settings[item:name():gsub("^slo_toggle_", "")] = item:value() == "on"
		SLO:Save()
	end

	MenuCallbackHandler.callback_slo_hits = function(self, item)
		SLO.settings["hits_" .. item:name():gsub("^slo_hits_", "")] = math.floor(item:value() + 0.5)
		SLO:Save()
	end

	SLO:Load()
	MenuHelper:LoadFromJsonFile(SLO.mod_path .. "menu/options.txt", SLO, SLO.settings)
end)
