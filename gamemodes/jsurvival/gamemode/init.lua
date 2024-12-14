JMod = JMod or {}
JSMod = JSMod or {}
AddCSLuaFile("cl_init.lua") -- This is client only stuff
AddCSLuaFile("shared.lua")
include("shared.lua")
include("spawns.lua")
include("sv_radioecon.lua") -- This is server only stuff
include("sh_econ.lua")
resource.AddWorkshop("1919689921")
function GM:Initialize()
end

local color_yellow = Color(255, 170, 0)
hook.Add("PlayerInitialSpawn", "JS_INITIAL_PLAYERSPAWN", function(ply)
	timer.Simple(5, function()
		BetterChatPrint(ply, "Welcome to JSurvival! To start surviving, press F3 to open your inventory.", color_yellow)
		BetterChatPrint(ply, "Then in the inventory menu, press the 'scrounge' button or 4 on your keyboard.", color_yellow)
		BetterChatPrint(ply, "This will spawn some props that you need to pile up for handcrafting a crafting table.", color_yellow)
        BetterChatPrint(ply, "You can also ask any online players or Discord members for more info on how to play.", color_yellow)
		if ply:IsListenServerHost() or ply:IsSuperAdmin() then
			BetterChatPrint(ply, "Also you can edit the JMod config in inventory", color_yellow)
			BetterChatPrint(ply, "To enable some useful features for improving realism gameplay.", color_yellow)
		end
	end)
	JSMod.JBuxListInfo(ply)
	if ply:GetPData("JBux") then GAMEMODE:SetJBux(ply, ply:GetPData("JBux"), false) end
end)

local function IsPlayerRunning(ply) 
	return  not(ply:GetMoveType() == MOVETYPE_NOCLIP) and not(IsValid(ply:GetVehicle())) and ply:IsSprinting() and ply:OnGround()
end

hook.Add("PlayerSpawn", "JS_SPAWN", function(ply) ply:SetNW2Float("JS_Stamina", 100) end)
local PlayerThinkTime = 0
local PlayerThinkRate = 3
hook.Add("Think", "JS_SPRINT_STAMINA", function()
	local Time = CurTime()
	if Time > PlayerThinkTime then
		PlayerThinkTime = Time + PlayerThinkRate
		for _, ply in player.Iterator() do
			local Stamina = ply:GetNW2Float("JS_Stamina", 0)
			if not IsPlayerRunning(ply) and (Stamina < 100) then
				ply:SetNW2Float("JS_Stamina", math.Clamp(Stamina + 2 * JMod.GetPlayerStrength(ply) * PlayerThinkRate, 0, 100))
				if Stamina >= 5 then ply:SprintEnable() end
			end
			if Stamina < 15 then
				sound.Play("snds_jack_gmod/drown_gasp.ogg", ply:GetShootPos(), 60, math.random(90, 110))
			end
		end
	end
end)

hook.Add("SetupMove", "JS_SPRINT", function(ply, mv, cmd)
	if not IsFirstTimePredicted() then return end
	if IsPlayerRunning(ply) then
		local Stamina = ply:GetNW2Float("JS_Stamina", 0)
		ply:SetNW2Float("JS_Stamina", math.Clamp((Stamina or 0) - 0.05, 0, 100))
		if Stamina < 5 then ply:SprintDisable() end
	end

	if ply:OnGround() and ply:KeyPressed(IN_JUMP) then -- Check if the player jumped and subtract stamina if so
		local Stamina = ply:GetNW2Float("JS_Stamina", 0)
		ply:SetNW2Float("JS_Stamina", math.Clamp((Stamina or 0) - 5, 0, 100))
	end
end)

hook.Add("PlayerSwitchFlashlight", "JS_SWITCH_FLASHLIGHT", function(ply, enabled) if not JMod.PlyHasArmorEff(ply, "HEVsuit") and not JMod.PlyHasArmorEff(ply, "flashlight") and enabled then return false end end)
hook.Add("PlayerSwitchWeapon", "JS_INTERRUPT_WEAPON_SWITCH", function(ply, oldWep, newWep) if ply:IsValid() and newWep:IsValid() then 
	--JMod.AddToInventory(ply, oldWep) 
	end end)
function GM:PlayerLoadout(ply) 
	local walkspeed = GetConVar("js_walkspeed")
	local runspeed = GetConVar("js_runspeed")
	ply:Give("wep_jack_gmod_hands") --ply:Give("wep_jack_gmod_eztoolbox")
	ply:SetWalkSpeed(walkspeed:GetInt() or 160)
	ply:SetRunSpeed(runspeed:GetInt() or 280)
end
if SERVER then
	function GM:PlayerSpawnProp(ply, model)
		if JMod.IsAdmin(ply) then 
			return true 
		else
			return false
		end
	end
	function GM:PlayerSpawnRagdoll(ply, model)
		if JMod.IsAdmin(ply) then 
			return true 
		else
			return false
		end
	end
	function GM:PlayerSpawnSENT(ply, class)
		if JMod.IsAdmin(ply) then 
			return true 
		else
			return false
		end
	end
	function GM:PlayerSpawnSWEP(ply, class, info)
		if JMod.IsAdmin(ply) then 
			return true 
		else
			return false
		end
	end
	function GM:PlayerSpawnObject(ply)
		if JMod.IsAdmin(ply) then 
			return true 
		else
			return false
		end
	end
	function GM:PlayerGiveSWEP(ply, class, swep)
		if JMod.IsAdmin(ply) then 
			return true 
		else
			return false
		end
	end
	function GM:PlayerSpawnNPC(ply, npc_type, weapon)
		if JMod.IsAdmin(ply) then 
			return true 
		else
			return false
		end
	end
	function GM:PlayerSpawnVehicle(ply, model, name, table)
		if JMod.IsAdmin(ply) then 
			return true 
		else
			return false
		end
	end
	function GM:CanProperty( ply, property, ent)
		if JMod.IsAdmin(ply) then 
			return true 
		else
			return false
		end
	end
	function GM:PlayerUse(ply, ent)
        if ent.EZradio == true then
            JSMod.JBuxListInfo(ply)
       	end
    end
   	function GM:PlayerNoClip(ply, desiredState)
    	if not JMod.IsAdmin(ply) then -- the player wants to turn noclip off
        	return false -- always allow
    	elseif JMod.IsAdmin(ply) then
        	return true -- allow administrators to enter noclip
    	end
	end
end