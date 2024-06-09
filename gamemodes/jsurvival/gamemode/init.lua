JMod = JMod or {}
JSMod = JSMod or {}
AddCSLuaFile("cl_init.lua") -- This is client only stuff
AddCSLuaFile("shared.lua")
include("shared.lua")
include("spawns.lua")
include("sv_radioecon.lua") -- This is server only stuff
resource.AddWorkshop("1919689921")
function GM:Initialize()
end

local color_yellow = Color(255, 170, 0)
hook.Add("PlayerInitialSpawn", "JS_INITIAL_PLAYERSPAWN", function(ply)
	timer.Simple(5, function()
		BetterChatPrint(ply, "Welcome to JSurvival! To start surviving, you better bind 'jmod_ez_inv' to I or other key.", color_yellow)
		BetterChatPrint(ply, "Then in inventory menu, press the 'scrounge' button", color_yellow)
		BetterChatPrint(ply, "This will spawn some props that you need to collect for creating crafting table.", color_yellow)
		if ply:IsListenServerHost() or ply:IsSuperAdmin() then
			BetterChatPrint(ply, "Also you can edit the JMod config in inventory", color_yellow)
			BetterChatPrint(ply, "To enable some useful features for improving realism gameplay.", color_yellow)
		end
	end)
end)

hook.Add("PlayerSpawn", "JS_SPAWN", function(ply)
	ply:SetNW2Float("JS_Stamina", 100)
end)

local PlayerThinkTime = 0
hook.Add("Think", "JS_SPRINT_STAMINA", function()
	local Time = CurTime()
	if Time > PlayerThinkTime then
		PlayerThinkTime = Time + 1
		for _, ply in player.Iterator() do
			local Stamina = ply:GetNW2Float("JS_Stamina", 0)
			if not(ply:IsSprinting()) and (Stamina < 100) then
				ply:SetNW2Float("JS_Stamina", math.Clamp(Stamina + 3 * JMod.GetPlayerStrength(ply), 0, 100))
				if Stamina >= 5 then
					ply:SprintEnable()
				end
			end
		end
	end
end)

hook.Add("SetupMove", "JS_SPRINT", function(ply, mv, cmd)
	if ply:InVehicle() then return end
	if ply:GetMoveType() == MOVETYPE_NOCLIP then return end
	if ply:IsSprinting() then
		local Stamina = ply:GetNW2Float("JS_Stamina", 0)
		ply:SetNW2Float("JS_Stamina", math.Clamp((Stamina or 0) - 0.05, 0, 100))
		if Stamina < 5 then
			ply:SprintDisable()
		end
	end
	-- Check if the player jumped and subtract stamina if so
	if ply:KeyPressed(IN_JUMP) then
		local Stamina = ply:GetNW2Float("JS_Stamina", 0)
		ply:SetNW2Float("JS_Stamina", math.Clamp((Stamina or 0) - 2, 0, 100))
	end
end)

hook.Add("PlayerSwitchFlashlight", "JS_SWITCH_FLASHLIGHT", function(ply, enabled)
	if not(JMod.PlyHasArmorEff(ply, "HEVsuit")) and not(JMod.PlyHasArmorEff(ply, "flashlight")) and enabled then
		return false
	end
end)

hook.Add("PlayerSwitchWeapon", "JS_INTERRUPT_WEAPON_SWITCH", function(ply, oldWep, newWep)
	if ply:IsValid() and newWep:IsValid() then
		--JMod.AddToInventory(ply, oldWep)
	end
end)

function GM:PlayerLoadout(ply)
	local walkspeed = GetConVar("js_walkspeed")
	local runspeed = GetConVar("js_runspeed")
	--ply:Give("wep_jack_gmod_eztoolbox")
	ply:Give("wep_jack_gmod_hands")
	ply:SetWalkSpeed(walkspeed:GetInt() or 160)
	ply:SetRunSpeed(runspeed:GetInt() or 280)
end