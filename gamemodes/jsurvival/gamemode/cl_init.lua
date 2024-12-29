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

local HeartBeatInfo = {
	resolution = 30,
	points = {},
	time = 2.5,
	pattern = {[0] = 0, [1] = 0, [2] = 1, [3] = -1, [4] = 2, [5] = -2, [6] = 1, [7] = 0, [8] = 0},
}

local HealthRectColor = Color(0, 0, 0, 150)
local StanimaAnimStart, StanimaAnimTime = CurTime(), .5
local OldStamina, NewStamina, MaxStamina = 0, 100, 100

hook.Add("HUDPaint", "JS_Display_Stats", function()
	if not IsValid(LocalPlayer()) then return end

	local Ply, W, H = LocalPlayer(), ScrW(), ScrH()
	local Time = CurTime()
	local PlyStamina = math.Clamp(Ply:GetNW2Float("JS_Stamina", 0), 0, MaxStamina)

	local StanimaAnimProgress = (SysTime() - StanimaAnimStart) / StanimaAnimTime
	local SmoothStamina = Lerp(StanimaAnimProgress, OldStamina, NewStamina)

	if NewStamina ~= PlyStamina then
		if SmoothStamina ~= PlyStamina then
			NewStamina = SmoothStamina
		end

		OldStamina = NewStamina
		StanimaAnimStart = SysTime()
		NewStamina = PlyStamina
	end

	local StanimFrac = SmoothStamina / MaxStamina
	local BarWidth = W * (StanimFrac)
	local BarHeight = 10 -- Change the height of the stamina bar here

	--jprint(1 / OldStamina * MaxStamina)
	local InverseModifier = (1 / SmoothStamina * 300)
	surface.SetDrawColor(40 + InverseModifier, 120 - InverseModifier, 140 - InverseModifier, 120) -- Blue color
	surface.SetDrawColor(0, 0, 0, 120)
	--surface.DrawRect(W / 2 - BarWidth / 2, H - BarHeight, BarWidth, BarHeight) -- Draw the stamina bar at the bottom

	-- Health and shield stuff --
	local healthRectWidth, healthRectHeight = 200, 100
	--local healthRectWidth, healthRectHeight = 400, 200 -- Debug
	local healthPosX, healthPosY = 15, H - healthRectHeight - 50

	-- Draw default health value
	local Health = Ply:Health()
	local HelfFrac = Health / Ply:GetMaxHealth()
	local HealthColor = JMod.GoodBadColor(Health / Ply:GetMaxHealth(), true, 150)
	-- Draw a small curved rectangle
	draw.RoundedBox(8, healthPosX, healthPosY, healthRectWidth, healthRectHeight, HealthRectColor)
	--draw.DrawText("Health: \n" .. Health, "JMod-Stencil-MS", healthPosX + healthRectWidth / 2, healthPosY + healthRectHeight / 8, HealthColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.DrawText("Blood Pressure: ", "JMod-Stencil-S", healthPosX + 10, healthPosY + 10, HealthColor, TEXT_ALIGN_LEFT)
	local PressureMod = math.Round(10 * (1 - StanimFrac))
	local DystolicBloodPressure = 40 + math.Round(HelfFrac * 40) + PressureMod
	local SystolicBloodPressure = 60 + math.Round(HelfFrac * 60) - PressureMod
	local BloodReadingText = tostring(SystolicBloodPressure).."/"..tostring(DystolicBloodPressure)
	if not Ply:Alive() then
		BloodReadingText = "NO SIGNAL"
	end
	--"JMod-NumberLCD"
	draw.DrawText(BloodReadingText, "JMod-Stencil-MS", healthPosX + healthRectWidth / 2, healthPosY + healthRectHeight / 4, HealthColor, TEXT_ALIGN_CENTER)
	draw.DrawText("mmHg", "JMod-Stencil-XS", healthPosX + healthRectWidth / 1.2, healthPosY + healthRectHeight / 6, HealthColor, TEXT_ALIGN_LEFT)

	local PatternLength = #HeartBeatInfo.pattern
	local PatternStep = HeartBeatInfo.resolution / PatternLength
	for i = 0, HeartBeatInfo.resolution do
		LastPointInfo = HeartBeatInfo.points[i - 1]
		local TimeIndex = i + (CurTime()) * 3
		if TimeIndex > PatternLength then
			TimeIndex = TimeIndex % PatternLength
		end

		local CurrentPoint = HeartBeatInfo.pattern[math.Round(TimeIndex)]
		local NextPoint = HeartBeatInfo.pattern[math.floor(math.Clamp(TimeIndex + PatternStep, CurrentPoint, PatternLength))]
		local PatternYFrac = CurrentPoint

		HeartBeatInfo.points[i] = {
			x = 0,
			y = PatternYFrac * (HelfFrac * healthRectHeight / 16)
		}
		local SegmentLength = healthRectWidth / HeartBeatInfo.resolution
		local DrawX = healthPosX + SegmentLength * i
		local DrawY = healthPosY + healthRectHeight - (healthRectHeight / 4)

		if LastPointInfo then
			surface.SetDrawColor(HealthColor)
			local LastPointDrawX = DrawX + LastPointInfo.x - SegmentLength
			local LastPointDrawY = DrawY + LastPointInfo.y
			surface.DrawLine(LastPointDrawX, LastPointDrawY, DrawX + HeartBeatInfo.points[i].x, DrawY + HeartBeatInfo.points[i].y)
			--draw.DrawText(tostring(math.Round(PatternYFrac, 2)), "JMod-Stencil-XS", DrawX + HeartBeatInfo.points[i].x, DrawY + HeartBeatInfo.points[i].y, HealthColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	local Armor = Ply:Armor()
	if Armor > 0 then
		local armorRectWidth, armorRectHeight = healthRectWidth, healthRectHeight / 3
		local armorPosX, armorPosY = healthPosX, healthPosY - armorRectHeight
		-- Draw a small curved rectangle
		draw.RoundedBox(8, armorPosX, armorPosY, armorRectWidth, armorRectHeight, HealthRectColor)
		
		local ArmorFrac = Armor / Ply:GetMaxArmor()
		local ArmorColor = JMod.GoodBadColor(Armor / Ply:GetMaxArmor(), true, 150)
		draw.DrawText("Shields: " .. Armor, "JMod-Stencil-S", armorPosX + (armorRectWidth - armorRectWidth / 2), armorPosY + armorRectHeight / 8, ArmorColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end)

local PngPath = "materials/sprites/player_stats/"
local BodyPartPngs = {
	eyes = "eyes",
	mouthnose = "mouth_nose",
	--ears = "ears",
	head = "head",
	chest = "chest",
	--back = "back",
	abdomen = "abdomen",
	pelvis = "pelvis",
	--waist = "waist",
	leftthigh = "thigh_left",
	leftcalf = "calf_left",
	rightthigh = "thigh_right",
	rightcalf = "calf_right",
	rightshoulder = "shoulder_right",
	rightforearm = "forearm_right",
	leftshoulder = "shoulder_left",
	leftforearm = "forearm_left",
	lefthand = "hand_left",
	righthand = "hand_right",
	heart = "heart",
	lungs = "lungs",
	stomach = "stomach"
}
local DrawOnTop = {
	heart = true,
	lungs = true,
	stomach = true
}
local BodyPartInfo = {}
for k, fileName in pairs(BodyPartPngs) do
	local BodyPartPng = Material(PngPath .. fileName .. ".png", "smooth")
	local BodyPartTable = {name = k, png = BodyPartPng}
	if DrawOnTop[k] then
		table.insert(BodyPartInfo, BodyPartTable)
	else
		table.insert(BodyPartInfo, 1, BodyPartTable)
	end
end

local DisplaySize = 350
local HeartBeat = 0
local LungBreathe = 0

hook.Add("HUDPaint", "JS_Display_Character", function()
	local Ply = LocalPlayer()
	if not IsValid(Ply) then return end

	local W, H = ScrW(), ScrH()

	for k, v in pairs(BodyPartInfo) do
		local Wide, High = 0, 0
		local MoveX, MoveY = 0, 0
		surface.SetMaterial(v.png)
		if v.name == "lungs" then
			--surface.SetDrawColor(253, 185, 185, 120)
			local StanimaColor = JMod.GoodBadColor(Ply:GetNW2Float("JS_Stamina", 0) / MaxStamina, true, 120)
			surface.SetDrawColor(StanimaColor)
			Wide = math.sin(CurTime()) * 10
		elseif v.name == "heart" then
			local LerpedCol = Color(255, 0, 0, 120):Lerp(Color(0, 0, 0, 120), 1 - (Ply:Health() / Ply:GetMaxHealth()))
			surface.SetDrawColor(LerpedCol.r, LerpedCol.g, LerpedCol.b, 150)
			Wide = math.sin(CurTime() * 10) * 100
			MoveX = math.abs(math.sin(CurTime() * 10) * 1)
		elseif v.name == "stomach" then

			surface.SetDrawColor(255, 255, 0, 120)
		else
			ItemID, ItemData, ItemInfo = JMod.GetItemInSlot(Ply.EZarmor, v.name)
			if ItemID then
				local DuribilityFrac = ItemData.dur / ItemInfo.dur
				local DurR, DurB, DurG, DurA = JMod.GoodBadColor(DuribilityFrac, false, 100)
				surface.SetDrawColor(DurR, DurB, DurG, DurA)
			else
				surface.SetDrawColor(201, 201, 201, 100)
			end
		end
		surface.DrawTexturedRect(0 - (Wide / 2) + (MoveX) - DisplaySize / 6, (H * .7) + (High / 2) - DisplaySize / 2, DisplaySize + Wide, DisplaySize + High)
	end
end)

local hide = {
	["CHudHealth"] = true,
	["CHudBattery"] = true
}

hook.Add("HUDShouldDraw", "HideDefaultHealthArmor", function(name)
	if hide[name] then
		return false
	end
end)