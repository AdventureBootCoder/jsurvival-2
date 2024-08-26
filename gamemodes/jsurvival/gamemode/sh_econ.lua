JSMod = JSMod or {}

JSMod.ResourceToJBux = {
	[JMod.EZ_RESOURCE_TYPES.BASICPARTS] = 4,
	[JMod.EZ_RESOURCE_TYPES.PRECISIONPARTS] = 11,
	[JMod.EZ_RESOURCE_TYPES.ADVANCEDPARTS] = 200,
	[JMod.EZ_RESOURCE_TYPES.OIL] = .75,
	[JMod.EZ_RESOURCE_TYPES.RUBBER] = .5,
	[JMod.EZ_RESOURCE_TYPES.ORGANICS] = .25,
	[JMod.EZ_RESOURCE_TYPES.WOOD] = .1,
	[JMod.EZ_RESOURCE_TYPES.PAPER] = .25,
	[JMod.EZ_RESOURCE_TYPES.PLASTIC] = .3,
	[JMod.EZ_RESOURCE_TYPES.GLASS] = .5,
	[JMod.EZ_RESOURCE_TYPES.FUEL] = .6,
	[JMod.EZ_RESOURCE_TYPES.CHEMICALS] = 1,
	[JMod.EZ_RESOURCE_TYPES.EXPLOSIVES] = 3,
	[JMod.EZ_RESOURCE_TYPES.STEEL] = .4,
	[JMod.EZ_RESOURCE_TYPES.LEAD] = .4,
	[JMod.EZ_RESOURCE_TYPES.ALUMINUM] = .5,
	[JMod.EZ_RESOURCE_TYPES.COPPER] = .6,
	[JMod.EZ_RESOURCE_TYPES.URANIUM] = 5,
	[JMod.EZ_RESOURCE_TYPES.TITANIUM] = 7.5,
	[JMod.EZ_RESOURCE_TYPES.GOLD] = 25,
	[JMod.EZ_RESOURCE_TYPES.SILVER] = 15,
	[JMod.EZ_RESOURCE_TYPES.DIAMOND] = 100,
	[JMod.EZ_RESOURCE_TYPES.PLATINUM] = 150,
	[JMod.EZ_RESOURCE_TYPES.ANTIMATTER] = 1000,
	[JMod.EZ_RESOURCE_TYPES.TUNGSTEN] = 3
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
local color_orange = Color(255, 136, 0)

function GM:GetJBux(ply)
	local JBuckaroos = JSMod.JBuxList[ply:SteamID()]
	if not JBuckaroos then
		JSMod.JBuxList[ply:SteamID()] = 0
		return 0
	end
	return JBuckaroos
end

function GM:SetJBux(ply, amt, silent)
	if not(IsValid(ply)) then return end
	local OldAmt = GAMEMODE:GetJBux(ply)
	local NewAmt = math.floor(amt)
	JSMod.JBuxList[ply:SteamID()] = NewAmt
	ply:SetPData("JBux", NewAmt)
	if silent then return end

	if (NewAmt < OldAmt) then
		BetterChatPrint(ply, "That cost you ".. tostring(OldAmt - amt) .." JBux!", color_orange)
	elseif (NewAmt > OldAmt) then
		BetterChatPrint(ply, "You have gained ".. tostring(amt - OldAmt) .." JBux!", color_orange)
	end
end

function GM:CalcJBuxWorth(item, amount, curDepth)
	if not(item) then return 0 end
	amount = amount or 1

	if curDepth and curDepth > 5 then return 0 end

	local typToCheck = type(item)
	local JBuxToGain = 0
	local Exportables = {}

	if typToCheck == "Entity" then
		if IsValid(item) and JSMod.ItemToJBux[item:GetClass()] then
			JBuxToGain = JSMod.ItemToJBux[item:GetClass()] * amount
			table.insert(Exportables, item)
		end
	elseif typToCheck == "string" then
		if JSMod.CurrentResourcePrices[item] then
			JBuxToGain = JSMod.CurrentResourcePrices[item] * amount
		elseif JSMod.ItemToJBux[item] then
			JBuxToGain = JSMod.ItemToJBux[item] * amount
		end
	elseif typToCheck == "table" then
		for typ, amt in pairs(item) do
			JBuxToGain = JBuxToGain + GAMEMODE:CalcJBuxWorth(typ, amt, (curDepth or 0) + 1)
		end
	end
	return JBuxToGain, Exportables
end

local function FindPackagePrice(item)
	local price = 0
	for pkg, info in pairs(JMod.Config.RadioSpecs.AvailablePackages) do
		if info.JBuxPrice and (isstring(info.results) and info.results == item) or (info.results[1] == item) then
			price = info.JBuxPrice

			break
		end
	end

	return price
end

function GM:AutoCalcPackagePrice(contents, searchRadioManifest)
	local typ = type(contents)
	local price = 0

	if typ == "string" then
		local RadioPrice = (searchRadioManifest and FindPackagePrice(contents)) or 0
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
				local RadioPrice = (searchRadioManifest and FindPackagePrice(v)) or 0
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