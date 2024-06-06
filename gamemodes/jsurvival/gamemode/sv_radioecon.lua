local color_orange = Color(255, 136, 0)
JSMod = JSMod or {}

JSMod.ResourceToJBux = {
	[JMod.EZ_RESOURCE_TYPES.BASICPARTS] = 4,
	[JMod.EZ_RESOURCE_TYPES.PRECISIONPARTS] = 10,
	[JMod.EZ_RESOURCE_TYPES.OIL] = .75,
	[JMod.EZ_RESOURCE_TYPES.RUBBER] = .5,
	[JMod.EZ_RESOURCE_TYPES.PLASTIC] = .3,
	[JMod.EZ_RESOURCE_TYPES.FUEL] = .6,
	[JMod.EZ_RESOURCE_TYPES.CHEMICALS] = 1,
	[JMod.EZ_RESOURCE_TYPES.STEEL] = .4,
	[JMod.EZ_RESOURCE_TYPES.LEAD] = .4,
	[JMod.EZ_RESOURCE_TYPES.ALUMINUM] = .5,
	[JMod.EZ_RESOURCE_TYPES.COPPER] = .6,
	[JMod.EZ_RESOURCE_TYPES.URANIUM] = 5,
	[JMod.EZ_RESOURCE_TYPES.GOLD] = 25,
	[JMod.EZ_RESOURCE_TYPES.DIAMOND] = 100,
	[JMod.EZ_RESOURCE_TYPES.SILVER] = 15,
	[JMod.EZ_RESOURCE_TYPES.ORGANICS] = .25,
	[JMod.EZ_RESOURCE_TYPES.WOOD] = .1
}
JSMod.ItemToJBux = {
	["ent_jack_gmod_ezanomaly_gnome"] = 10000,
	["ent_jack_gmod_ezarmor"] = 200,
	["ent_jack_gmod_ezatmine"] = 300,
	["ent_jack_gmod_ezfragnade"] = 25,
	["ent_jack_gmod_ezfumigator"] = 1000,
}
JSMod.CurrentResourcePrices = table.FullCopy(JSMod.ResourceToJBux)
JSMod.JBuxList = JSMod.JBuxList or {}

function JSMod.GetJBux(ply)
	local JBuckaroos = JSMod.JBuxList[ply:SteamID()]
	if not JBuckaroos then
		JSMod.JBuxList[ply:SteamID()] = 0
		return 0
	end
	return JBuckaroos
end

function JSMod.SetJBux(ply, amt, silent)
	if not(IsValid(ply)) then return end
	local OldAmt = JSMod.GetJBux(ply)
	local amt = math.floor(amt)
	JSMod.JBuxList[ply:SteamID()] = amt

	if silent then return end

	if (amt < OldAmt) then
		BetterChatPrint(ply, "That cost you ".. tostring(OldAmt - amt) .." JBux!", color_orange)
	elseif (amt > OldAmt) then
		BetterChatPrint(ply, "You have gained ".. tostring(amt - OldAmt) .." JBux!", color_orange)
	end
end

function JSMod.CalcJBuxWorth(item, amount)
	if not(item) then return 0 end
	amount = amount or 1

	local typToCheck = type(item)
	local JBuxToGain = 0
	local Exportables = {}

	if typToCheck == "Entity" then
		if IsValid(item) and JSMod.ItemToJBux[item:GetClass()] then
			JBuxToGain = JSMod.ItemToJBux[item:GetClass()] * amount
		end
	elseif typToCheck == "string" then
		if JSMod.CurrentResourcePrices[item] then
			JBuxToGain = JSMod.CurrentResourcePrices[item] * amount
		elseif JSMod.ItemToJBux[item] then
			JBuxToGain = JSMod.ItemToJBux[item] * amount
		end
	elseif typToCheck == "table" then
		for typ, amt in pairs(item) do
			JBuxToGain = JBuxToGain + JSMod.CalcJBuxWorth(typ, amt)
		end
	end
	return JBuxToGain, Exportables
end

local function FindItemJBuxPrice(item)
	for pkg, info in pairs(JMod.Config.RadioSpecs.AvailablePackages) do
		if info.JBuxPrice and (isstring(info.results) and info.results == item) or (info.results[1] == item) then
			price = info.JBuxPrice

			return price
		end
	end

	return 0
end

local function AutoCalcPrice(contents, searchRadioManifest)
	local typ = type(contents)
	local price = 0

	if typ == "string" then
		local RadioPrice = (searchRadioManifest and FindItemJBuxPrice(contents)) or 0
		if RadioPrice <= 0 and JSMod.ItemToJBux[contents] then
			price = JSMod.ItemToJBux[contents]
		else
			price = RadioPrice
		end
	end

	if typ == "table" then
		for k, v in pairs(contents) do
			typ = type(v)

			if typ == "string" then
				local RadioPrice = (searchRadioManifest and FindItemJBuxPrice(v)) or 0
				if RadioPrice <= 0 and JSMod.ItemToJBux[v] then
					price = price + JSMod.ItemToJBux[v]
				else
					price = price + RadioPrice
				end
			elseif typ == "table" then
				-- special case, this is a randomized table
				if v[1] == "RAND" then
					local Amt = v[#v]
					local Items = {}

					for i = 2, #v - 1 do
						if JSMod.ItemToJBux[v[i]] then
							table.insert(Items, v[i])
							price = price + JSMod.ItemToJBux[v[i]]
						elseif JSMod.CurrentResourcePrices[v[i]] then
							price = price + JSMod.CurrentResourcePrices[v[i]] * 100 * JSMod.Config.ResourceEconomy.MaxResourceMult
						end
					end

					price = price / Amt
				elseif JSMod.CurrentResourcePrices[v[1]] then
					-- the only other supported table contains a count as [2] and potentially a resourceAmt as [3]
					for i = 1, v[2] or 1 do
						price = price + JSMod.CurrentResourcePrices[v[1]] * (v[3] or 100 * JSMod.Config.ResourceEconomy.MaxResourceMult)
					end
				end
			end
		end
	end

	return price
end

concommand.Add("js_jbux_check", function(ply, cmd, args)
	BetterChatPrint(ply, "You have ".. tostring(JSMod.GetJBux(ply)) .." JBux!", color_orange)
end, "Shows you your current JBux")

concommand.Add("js_jbux_donate", function(ply, cmd, args)
	if not(ply:Alive()) then return end
	local target = tostring(args[1])
	local amt = tonumber(args[2])
	if not(amt) or (amt == 0) then return end
	local recipient
	for k, v in player.Iterator() do
		if string.lower(v:Nick()) == string.lower(target) then
			recipient = v
			break
		end
	end

	if (recipient) and (recipient:Alive()) then 
		JSMod.SetJBux(recipient, JSMod.GetJBux(recipient) + amt, true)
		BetterChatPrint(recipient, "You got ".. tostring(amt) .." JBux!", color_orange)
		BetterChatPrint(ply, "You donated ".. tostring(amt) .." JBux!", color_orange)
	elseif string.lower(target) == "team" then
		recipient = ply:Team()
		JSMod.SetJBux(recipient, JSMod.GetJBux(recipient) + amt, true)
		BetterChatPrint(ply, "You donated ".. tostring(amt) .." JBux!", color_orange)
	end
end, "Donates JBux to someone or your team")

hook.Add("PlayerSpawn", "JSMOD_ECONPLAYERSPAWN", function(ply, transition)
	if transition then return end
	timer.Simple(1, function()
		if IsValid(ply) then ply:ConCommand("js_jbux_check") end
	end)
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
	local ReqAmount = PackageSpecs.JBuxPrice or AutoCalcPrice(PackageSpecs.results, false)
	if string.find(pkg, "-export") then
		station.plyToCredit = ply
	end
	ReqAmount = ReqAmount + StandardRate
	if (ReqAmount <= 0) or (PackageSpecs.JBuxFree) then return end
	local PlyAmt = JSMod.GetJBux(ply)
	if PlyAmt <= ReqAmount then 
		return false, "Not enough JBux! (You need: "..tostring(ReqAmount - PlyAmt).." more)" 
	else
		JSMod.SetJBux(ply, PlyAmt - ReqAmount)
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
				local JbuxToGain, Exportables = JSMod.CalcJBuxWorth(AvaliableResources)
				
				if (JBuxToGain > 0) and station.plyToCredit then
					JSMod.SetJBux(station.plyToCredit, JSMod.GetJBux(station.plyToCredit) + JBuxToGain)
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
	elseif DeliveryType == "fulton-export" then
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
	end
end)

hook.Add("InitPostEntity", "JSMOD_SCROUNGEMOD", function()
	--"models/props_canal/boat001b.mdl", "models/props_vehicles/car004a_physics.mdl", "models/props_vehicles/car004b_physics.mdl", "models/props_interiors/refrigerator01a.mdl", "models/props_c17/bench01a.mdl", "models/props_junk/cardboard_box001a.mdl", "models/props_junk/cardboard_box001b.mdl", "models/props_junk/cardboard_box002a.mdl", "models/props_junk/cardboard_box002b.mdl", "models/props_junk/cardboard_box003a.mdl", "models/props_junk/cardboard_box003b.mdl", "models/props_junk/cardboard_box004a.mdl", "models/props_junk/wood_crate001a.mdl", "models/props_junk/wood_crate001a_damaged.mdl", "models/props_junk/wood_crate001a_damagedmax.mdl", "models/props_junk/wood_crate002a.mdl", "models/Items/item_item_crate.mdl", "models/props_c17/furnituredrawer001a.mdl", "models/props_c17/furnituredrawer003a.mdl", "models/props_lab/dogobject_wood_crate001a_damagedmax.mdl", "models/props_c17/canister01a.mdl", "models/props_c17/canister02a.mdl", "models/props_junk/gascan001a.mdl", "models/props_junk/metalgascan.mdl", "models/props_junk/propane_tank001a.mdl", "models/props_junk/propanecanister001a.mdl", "models/props_interiors/pot01a.mdl", "models/props_c17/oildrum001.mdl", "models/props_junk/metal_paintcan001a.mdl", "models/props_wasteland/controlroom_filecabinet001a.mdl", "models/props_junk/metal_paintcan001b.mdl", "models/props_trainstation/trashcan_indoor001a.mdl", "models/props_c17/suitcase001a.mdl", "models/props_c17/suitcase_passenger_physics.mdl", "models/props_c17/briefcase001a.mdl", "models/props_phx/construct/metal_plate1.mdl", "models/props_phx/construct/metal_plate1_tri.mdl", "models/props_phx/construct/glass/glass_plate1x1.mdl", "models/props_phx/construct/glass/glass_plate1x2.mdl", "models/hunter/plates/plate1x1.mdl", "models/hunter/plates/plate1x2.mdl", "models/props_phx/construct/wood/wood_panel1x1.mdl", "models/props_phx/construct/wood/wood_panel1x2.mdl", "models/props_phx/construct/wood/wood_panel2x2.mdl", "models/props_phx/construct/wood/wood_boardx1.mdl", "models/props_phx/construct/wood/wood_boardx2.mdl"
end)

local NextStockUpdate = 0
hook.Add("Think", "JSMOD_STOCKSIM", function()
	local Time = CurTime()

	if (Time > NextStockUpdate) then 
		NextStockUpdate = Time + 60

		JSMod.CurrentResourcePrices = JSMod.CurrentResourcePrices or table.FullCopy(JSMod.ResourceToJBux)
		for k, v in pairs(JSMod.CurrentResourcePrices) do
			local BaseAmt = JSMod.ResourceToJBux[k]
			local Low, High = BaseAmt * 0.5, BaseAmt * 1.5
			local CurAmt = JSMod.CurrentResourcePrices[k]
			JSMod.CurrentResourcePrices[k] = math.Clamp(CurAmt + math.Round(math.Rand(-0.01, 0.01), 2), Low, High)
		end
	end
end)

local RequiredPackages = {
	["heli-export"] = {
		description = "Helicopter Export of resources.",
		category = "JSurvival",
		JBuxPrice = 200,
		results = {
			"npc_manhack",
		}
	},
	["fulton-export"] = {
		description = "Calls in plane to pick up resources from Fulton Crates.",
		category = "JSurvival",
		JBuxFree = true,
		results = {
			"ent_aboot_jsmod_ezcrate_fulton"
		}
	},
	["fulton-crate"] = {
		description = "Fulton balloon crate for exporting resources.",
		category = "JSurvival",
		JBuxFree = true,
		results = {
			"ent_aboot_jsmod_ezcrate_fulton"
		}
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
