local color_orange = Color(255, 136, 0)

concommand.Add("js_jbux_check", function(ply, cmd, args)
	BetterChatPrint(ply, "You have ".. tostring(GAMEMODE:GetJBux(ply)) .." JBux!", color_orange)
end, "Shows you your current JBux")

concommand.Add("js_jbux_donate", function(ply, cmd, args)
	if not(ply:Alive()) then return end
	local target = tostring(args[1])
	local amt = tonumber(args[2])
	if not(amt) or (amt <= 0) then return end
	local recipient
	for k, v in player.Iterator() do
		if string.lower(v:Nick()) == string.lower(target) and v:Nick() ~= ply:Nick() then
			recipient = v
			break
		end
	end

	if (recipient) and (recipient:Alive()) then 
		GAMEMODE:SetJBux(recipient, GAMEMODE:GetJBux(recipient) + amt, true)
        GAMEMODE:SetJBux(ply, GAMEMODE:GetJBux(ply) - amt, true)
		BetterChatPrint(recipient, "You got ".. tostring(amt) .." JBux!", color_orange)
		BetterChatPrint(ply, "You donated ".. tostring(amt) .." JBux!", color_orange)
	elseif string.lower(target) == "team" then
		recipient = ply:Team()
		GAMEMODE:SetJBux(recipient, GAMEMODE:GetJBux(recipient) + amt, true)
        GAMEMODE:SetJBux(ply, GAMEMODE:GetJBux(ply) - amt, true)
		BetterChatPrint(ply, "You donated ".. tostring(amt) .." JBux!", color_orange)
	end
end, "Donates JBux to someone or your team")

hook.Add("PlayerSpawn", "JSMOD_ECONPLAYERSPAWN", function(ply, transition)
	if transition then return end
	timer.Simple(1, function()
		if IsValid(ply) then ply:ConCommand("js_jbux_check") end
	end)
end)

local NextStockUpdate = 0
hook.Add("Think", "JSMOD_STOCKSIM", function()
	local Time = CurTime()

	if (Time > NextStockUpdate) then 
		NextStockUpdate = Time + 60

		JSMod.CurrentResourcePrices = JSMod.CurrentResourcePrices or table.FullCopy(JSMod.ResourceToJBux)
		--[[for k, v in pairs(JSMod.CurrentResourcePrices) do
			local BaseAmt = JSMod.ResourceToJBux[k]
			local Low, High = BaseAmt * 0.5, BaseAmt * 1.5
			local CurAmt = JSMod.CurrentResourcePrices[k]
			JSMod.CurrentResourcePrices[k] = math.Clamp(CurAmt + math.Round(math.Rand(-0.01, 0.01), 2), Low, High)
		end--]]
	end
end)
local StandardRate = 200 -- To cover fuel ;)
hook.Add("JMod_CanRadioRequest", "JSMOD_MONEY_CHECK", function(ply, transceiver, pkg)
	local station = JMod.EZ_RADIO_STATIONS[transceiver:GetOutpostID()]

	if pkg == "stocks" then
		timer.Simple(1, function()
			if not(IsValid(transceiver)) then return end
			local Msg, Num = 'current stock prices are:', 1
			local str = ""

			for name, value in pairs(JSMod.CurrentResourcePrices) do
				str = str .. name .. ": " .. tostring(value)

				if Num > 0 and Num % 10 == 0 then
					local newStr = str

					timer.Simple(Num / 10, function()
						if IsValid(transceiver) then
							transceiver:Speak(newStr)
						end
					end)

					str = ""
				else
					str = str .. ", "
				end

				Num = Num + 1
			end

			timer.Simple(Num / 10, function()
				if IsValid(transceiver) then
					transceiver:Speak(str)
				end
			end)
		end)

		return true
	end

	local PackageSpecs = JMod.Config.RadioSpecs.AvailablePackages[pkg]
	if not(PackageSpecs) then return end
	local ReqAmount = PackageSpecs.JBuxPrice or GAMEMODE:AutoCalcPackagePrice(PackageSpecs.results, false)
	if string.find(pkg, "-export") then
		station.plyToCredit = ply
	end
	ReqAmount = ReqAmount + StandardRate
	if (ReqAmount <= 0) or (PackageSpecs.JBuxFree) then return end
	local PlyAmt = GAMEMODE:GetJBux(ply)
	if PlyAmt <= ReqAmount and ReqAmount >= 0 then 
		return false, "Not enough JBux! (You need: "..tostring(ReqAmount - PlyAmt).." more)" 
	else
		GAMEMODE:SetJBux(ply, PlyAmt - ReqAmount)
	end
end)

hook.Add("JMod_RadioDelivery", "JSMOD_SPEED_MODIFIER", function(ply, transceiver, pkg, DeliveryTime, Pos) 
	local station = JMod.EZ_RADIO_STATIONS[transceiver:GetOutpostID()]
	if pkg == "heli-export" then
		station.plyToCredit = ply
		
		return DeliveryTime * 1.5, Pos
	elseif pkg == "fulton-export" then

		return DeliveryTime * 2, Pos
	end
end)

hook.Add("JMod_OnRadioDeliver", "JSMOD_EXPORT_GOODS", function(stationID, dropPos) 
	local station = JMod.EZ_RADIO_STATIONS[stationID]
	local DeliveryType = station.deliveryType--JMod.Config.RadioSpecs.AvailablePackages[station.deliveryType]

	if DeliveryType == "heli-export" then
		local ExportPos = util.QuickTrace(dropPos, Vector(0, 0, -9e9)).HitPos + Vector(0, 0, 10)
		local AvaliableResources = JMod.CountResourcesInRange(ExportPos, 200)
		--- Helicopter
		local Heli = ents.Create("prop_physics")
		Heli:SetModel(JMod.Config.RadioSpecs.AvailablePackages[station.deliveryType].results)
		Heli:SetPos(dropPos)
		Heli:SetAngles(station.outpostDirection:Angle())
		Heli:Spawn()
		timer.Simple(0, function()
			if not(IsValid(Heli)) then return end
			--Heli:GetPhysicsObject():EnableMotion(false)
			Heli:GetPhysicsObject():SetDragCoefficient(8)
		end)
		----
		timer.Simple(15, function()
			if IsValid(Heli) then
				local JbuxToGain, Exportables = GAMEMODE:CalcJBuxWorth(AvaliableResources)
				
				if (JBuxToGain > 0) and station.plyToCredit then
					GAMEMODE:SetJBux(station.plyToCredit, GAMEMODE:GetJBux(station.plyToCredit) + JBuxToGain)
					JMod.ConsumeResourcesInRange(Exportables, ExportPos, 200, nil, false)
					station.plyToCredit = nil
				end
				local HeliPhys = Heli:GetPhysicsObject()
				HeliPhys:SetDragCoefficient(1)
				HeliPhys:EnableMotion(true)
				HeliPhys:EnableGravity(false)
				HeliPhys:SetVelocity(Vector(0, 0, 1000))
				SafeRemoveEntityDelayed(Heli, 3)
			end
		end)
		return true
	end --[[elseif DeliveryType == "fulton-export" then
		local GoodPackage = nil
		for k, ent in pairs(ents.FindByClass("ent_aboot_jsmod_ezcrate_fulton")) do
			if ent:GetClass() == "ent_aboot_jsmod_ezcrate_fulton" and IsValid(ent.Fulton) and ent.Fulton.ReadyForPickup then
				GoodPackage = ent

				break
			end
		end

		if IsValid(GoodPackage) then
			local PickupVelocity, PickupPos = station.outpostDirection, GoodPackage:GetPos() + Vector(0, 0, GoodPackage.Fulton.DesiredAltitude)
			local Tries = 0
			local HitSky = false
			local DirTr, OtherDirTr
			while not(HitSky) and (Tries < 300) do
				DirTr = util.TraceLine({start = PickupPos, endpos = PickupPos - (PickupVelocity * 9e9), filter = {GoodPackage, GoodPackage.Fulton}, mask = MASK_SOLID_BRUSHONLY})
				OtherDirTr = util.TraceLine({start = PickupPos, endpos = PickupPos + (PickupVelocity * 9e9), filter = {GoodPackage, GoodPackage.Fulton}, mask = MASK_SOLID_BRUSHONLY})
				if DirTr.HitSky and OtherDirTr.HitSky then
					HitSky = true
				else
					Tries = Tries + 1
					PickupVelocity = Vector(math.Rand(-1, 1), math.Rand(-1, 1), 0):GetNormalized()
				end
			end
			
			local CratePos = GoodPackage:GetPos()
			local CargoPlane = ents.Create("ent_aboot_jsmod_ezcargoplane")
			CargoPlane:SetPos(PickupPos + Vector(0, 0, -50) + PickupVelocity * -800)
			CargoPlane:SetAngles(PickupVelocity:Angle())
			CargoPlane.FlightDir = PickupVelocity
			CargoPlane:Spawn()
			sound.Play("@julton/cargo_plane_flyby_mono.wav", PickupPos, 160, 100, 1)

			timer.Simple(10, function()
				if not IsValid(GoodPackage) or not IsValid(GoodPackage.Fulton) or not IsValid(GoodPackage.Cable) then JMod.NotifyAllRadios(stationID, "drop failed") return end
				GoodPackage.Fulton:SetPos(PickupPos)
				GoodPackage.Fulton:OnRecover(PickupVelocity * -2500)
				--
				GoodPackage:GetPhysicsObject():EnableDrag(false)
				GoodPackage:GetPhysicsObject():EnableGravity(false)
				GoodPackage:GetPhysicsObject():SetVelocity(((GoodPackage:GetPos() - CargoPlane:GetPos()):GetNormalized() * 1000))
				sound.Play("ambient/machines/catapult_throw.wav", CratePos + Vector(0, 0, 100), 75, 60, 1)
				timer.Simple(math.random(3, 5), function()
					if not IsValid(GoodPackage) then return end
					GoodPackage:OnFultonRecover()
				end)
				JMod.NotifyAllRadios(stationID, "good drop")
				station.nextReadyTime = CurTime() + (math.random(20, 35) * JMod.Config.RadioSpecs.DeliveryTimeMult)
			end)
			station.nextReadyTime = CurTime() + 20
		else
			JMod.NotifyAllRadios(stationID, "drop failed")
		end
		return true
	end--]]
end)

hook.Add("InitPostEntity", "JSMOD_SCROUNGEMOD", function()
	--"models/props_canal/boat001b.mdl", "models/props_vehicles/car004a_physics.mdl", "models/props_vehicles/car004b_physics.mdl", "models/props_interiors/refrigerator01a.mdl", "models/props_c17/bench01a.mdl", "models/props_junk/cardboard_box001a.mdl", "models/props_junk/cardboard_box001b.mdl", "models/props_junk/cardboard_box002a.mdl", "models/props_junk/cardboard_box002b.mdl", "models/props_junk/cardboard_box003a.mdl", "models/props_junk/cardboard_box003b.mdl", "models/props_junk/cardboard_box004a.mdl", "models/props_junk/wood_crate001a.mdl", "models/props_junk/wood_crate001a_damaged.mdl", "models/props_junk/wood_crate001a_damagedmax.mdl", "models/props_junk/wood_crate002a.mdl", "models/Items/item_item_crate.mdl", "models/props_c17/furnituredrawer001a.mdl", "models/props_c17/furnituredrawer003a.mdl", "models/props_lab/dogobject_wood_crate001a_damagedmax.mdl", "models/props_c17/canister01a.mdl", "models/props_c17/canister02a.mdl", "models/props_junk/gascan001a.mdl", "models/props_junk/metalgascan.mdl", "models/props_junk/propane_tank001a.mdl", "models/props_junk/propanecanister001a.mdl", "models/props_interiors/pot01a.mdl", "models/props_c17/oildrum001.mdl", "models/props_junk/metal_paintcan001a.mdl", "models/props_wasteland/controlroom_filecabinet001a.mdl", "models/props_junk/metal_paintcan001b.mdl", "models/props_trainstation/trashcan_indoor001a.mdl", "models/props_c17/suitcase001a.mdl", "models/props_c17/suitcase_passenger_physics.mdl", "models/props_c17/briefcase001a.mdl", "models/props_phx/construct/metal_plate1.mdl", "models/props_phx/construct/metal_plate1_tri.mdl", "models/props_phx/construct/glass/glass_plate1x1.mdl", "models/props_phx/construct/glass/glass_plate1x2.mdl", "models/hunter/plates/plate1x1.mdl", "models/hunter/plates/plate1x2.mdl", "models/props_phx/construct/wood/wood_panel1x1.mdl", "models/props_phx/construct/wood/wood_panel1x2.mdl", "models/props_phx/construct/wood/wood_panel2x2.mdl", "models/props_phx/construct/wood/wood_boardx1.mdl", "models/props_phx/construct/wood/wood_boardx2.mdl"
end)

local RequiredPackages = {
	["heli-export"] = {
		description = "Helicopter Export of resources.",
		category = "JSurvival",
		JBuxPrice = 200,
		results = "npc_manhack"
	},
	["fulton-crate"] = {
		description = "Fulton balloon crate for exporting resources.",
		category = "JSurvival",
		JBuxFree = true,
		results = "ent_aboot_jsmod_ezcrate_fulton"
	}
}

hook.Add("JMod_PostLuaConfigLoad", "JSMOD_RADIOECON", function(config)
	table.Merge(JMod.Config.RadioSpecs.AvailablePackages, RequiredPackages, true)
end)

local Airstrikes = {
	["smallbombs"] = { func = function(station, dropPos, DropVelocity) 
			local delay = .5
			local PlanePos = dropPos - (station.outpostDirection * 1500 * (5 * delay)) - Vector(0, 0, 10)
			for i = 1, 5 do
				timer.Simple(i * delay, function()
					local Bomb = ents.Create("ent_jack_gmod_ezsmallbomb")
					Bomb:SetPos(PlanePos)
					Bomb:SetAngles(station.outpostDirection:Angle())
					Bomb:Spawn()
					Bomb:Activate()
					timer.Simple(0, function()
						if IsValid(Bomb) then
							Bomb:GetPhysicsObject():SetVelocity(DropVelocity)
							Bomb:GetPhysicsObject():SetMass(500)
							Bomb:SetState(1)
						end
					end)
					Bomb.DropOwner = game.GetWorld()
					PlanePos = PlanePos + DropVelocity * delay
				end)
			end
		end
	},
	["bombs"] = { func = function(station, dropPos, DropVelocity)
			local PlanePos = dropPos - station.outpostDirection * 800 - Vector(0, 0, 10)
			for i = 1, 1 do
				timer.Simple(i * .5, function()
					local Bomb = ents.Create("ent_jack_gmod_ezbomb")
					Bomb:SetPos(PlanePos)
					Bomb:SetAngles(station.outpostDirection:Angle())
					Bomb:Spawn()
					Bomb:Activate()
					timer.Simple(0, function()
						if IsValid(Bomb) then
							Bomb:GetPhysicsObject():SetVelocity(DropVelocity)
							Bomb:GetPhysicsObject():SetMass(500)
							Bomb:SetState(1)
						end
					end)
					Bomb.DropOwner = game.GetWorld()
					PlanePos = PlanePos + station.outpostDirection * 1000
				end)
			end
		end
	},
	["rockets"] = { func = function(station, dropPos, DropVelocity) 
		for i = 1, 25 do
			timer.Simple(math.Rand(.5, 10), function()
				local Rocket = ents.Create("ent_jack_gmod_ezherocket")
				local AreaRadius = 500
				Rocket:SetPos(dropPos + Vector(math.random(-AreaRadius, AreaRadius), math.random(-AreaRadius, AreaRadius), 0))
				Rocket:SetAngles(Angle(0, 0, -90))
				Rocket:Spawn()
				Rocket:Activate()
				Rocket:SetState(1)
				timer.Simple(.1, function()
					if IsValid(Rocket) then
						Rocket:Launch()
					end
				end)
			end)
		end
	end},
}

local function StartAirstrike(pkg, transceiver, id, ply)
	local Station = JMod.EZ_RADIO_STATIONS[id]
	Station.lastCaller = transceiver
	local Time = CurTime()
	local DeliveryTime, Pos = math.ceil(JMod.Config.RadioSpecs.DeliveryTimeMult * math.Rand(3, 6)), ply:GetPos()
	local newTime, newPos = hook.Run("JMod_RadioDelivery", ply, transceiver, pkg, DeliveryTime, Pos)
	DeliveryTime = newTime or DeliveryTime
	Pos = newPos or Pos
	JMod.Hint(ply, "aid wait")
	Station.state = JMod.EZ_STATION_STATE_DELIVERING
	Station.nextDeliveryTime = Time + DeliveryTime
	Station.deliveryLocation = Pos
	Station.deliveryType = pkg
	Station.notified = false
	Station.nextNotifyTime = Time + (DeliveryTime - 5)
	JMod.NotifyAllRadios(id) -- do a notify to update all radio states
end

hook.Add("JMod_CanRadioRequest", "JSMOD_AIRSTRIKE_CHECK", function(ply, transceiver, pkg)
	local SplitString = string.Split(pkg, " ")
	if (SplitString[1] == "airstrike") and (SplitString[2] and Airstrikes[SplitString[2]]) then
		StartAirstrike(pkg, transceiver, transceiver:GetOutpostID(), ply)
		return true, "Calling in Airstrike!"
	end
end)

hook.Add("JMod_RadioDelivery", "JSMOD_AIRSTRIKE_START", function(ply, transceiver, pkg, DeliveryTime, Pos) 
	local station = JMod.EZ_RADIO_STATIONS[transceiver:GetOutpostID()]
	local ExplodedString = string.Split(pkg, " ")
	if ExplodedString[1] == "airstrike" and Airstrikes[ExplodedString[2]] then

		station.airstrikeType = ExplodedString[2]

		local StrikePos = ply:GetEyeTrace().HitPos
		for k, nade in ipairs(ents.FindByClass("ent_jack_gmod_ezsignalnade")) do
			--print(nade, nade:GetState())
			if (nade:GetState() == JMod.EZ_STATE_ARMED) then
				StrikePos = nade:GetPos()
			end
		end
		return DeliveryTime * 1, StrikePos
	end
end)

hook.Add("JMod_OnRadioDeliver", "JSMOD_AIRSTRIKE", function(stationID, dropPos) 
	local station = JMod.EZ_RADIO_STATIONS[stationID]
	if station.airstrikeType then
		--
		local DropVelocity = station.outpostDirection * 1000
		local Eff = EffectData()
		Eff:SetOrigin(dropPos)
		Eff:SetStart(-DropVelocity * .4)
		util.Effect("eff_jack_gmod_jetflyby", Eff, true, true)
		--
		local StrikeType = station.airstrikeType
		timer.Simple(.1, function()
			if not(StrikeType) then return end
			
			Airstrikes[StrikeType].func(station, dropPos, DropVelocity)
		end)

		station.airstrikeType = nil
		JMod.NotifyAllRadios(stationID, "good drop")
		return true
	end
end)
