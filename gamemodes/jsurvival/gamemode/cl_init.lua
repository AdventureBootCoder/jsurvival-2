include("shared.lua")

local VignetteMat = Material("mats_jack_gmod_sprites/hard_vignette.png")
local OldHealth, NewHealth = -1, -1
local SmoothTime = 0.5
local StartTime = 0
hook.Add("RenderScreenspaceEffects", "JS_LOW_HEALTH_EFFECT", function()
	local Ply = LocalPlayer()
	if not IsValid(Ply) or not Ply:Alive() then return end
	local Healthy = Ply:Health()
	local MaxHealth = Ply:GetMaxHealth()

	if ( OldHealth == -1 and NewHealth == -1 ) then
		OldHealth = Healthy
		NewHealth = Healthy
	end

	local SmoothHealth = Lerp( ( SysTime() - StartTime ) / SmoothTime, OldHealth, NewHealth )

	if NewHealth ~= Healthy then
		if ( SmoothHealth ~= Healthy ) then
			NewHealth = SmoothHealth
		end

		OldHealth = NewHealth
		StartTime = SysTime()
		NewHealth = Healthy
	end

	if SmoothHealth <= MaxHealth * 0.5 then

		local Percent = 1 - (SmoothHealth / (MaxHealth * 0.5))
		DrawColorModify({
			["$pp_colour_addr"] = 0,
			["$pp_colour_addg"] = 0,
			["$pp_colour_addb"] = 0,
			["$pp_colour_brightness"] = 0 - Percent * 0.1,
			["$pp_colour_contrast"] = 1,
			["$pp_colour_colour"] = 1 - Percent,
			["$pp_colour_mulr"] = Percent,
			["$pp_colour_mulg"] = Percent * 0.25,
			["$pp_colour_mulb"] = 0
		})
		surface.SetMaterial(VignetteMat)
		surface.SetDrawColor(255, 255, 255, 255 * Percent) -- Adjust the alpha based on the Percent value
		surface.DrawTexturedRect(-5, -5, ScrW()+5, ScrH()+5)
		--DrawMotionBlur(0.1, Percent, 0.01)
		
	end
end)

local CurrentStamina = 0
hook.Add("HUDPaint", "JS_Display_Stamina", function()
	local Ply, W, H = LocalPlayer(), ScrW(), ScrH()
	local PlyStamina = Ply:GetNW2Float("JS_Stamina", 0)
	CurrentStamina = Lerp(0.02, CurrentStamina, math.Clamp(PlyStamina, 0, 100))
	local BarWidth = W * (CurrentStamina / 100)
	local BarHeight = 10 -- Change the height of the stamina bar here

	--jprint(1 / CurrentStamina * 100)
	local InverseModifier = (1 / CurrentStamina * 300)
	surface.SetDrawColor(40 + InverseModifier, 120 - InverseModifier, 140 - InverseModifier, 120) -- Blue color
	--surface.SetDrawColor(0, 0, 0, 120)
	surface.DrawRect(W / 2 - BarWidth / 2, H - BarHeight, BarWidth, BarHeight) -- Draw the stamina bar at the bottom
end)
