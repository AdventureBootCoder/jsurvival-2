JSMod = JSMod or {}

JSMod.ResourceToJBux = {
	[JMod.EZ_RESOURCE_TYPES.BASICPARTS] = 4,
	[JMod.EZ_RESOURCE_TYPES.PRECISIONPARTS] = 10,
	[JMod.EZ_RESOURCE_TYPES.OIL] = .75,
	[JMod.EZ_RESOURCE_TYPES.RUBBER] = .5,
	[JMod.EZ_RESOURCE_TYPES.ORGANICS] = .25,
	[JMod.EZ_RESOURCE_TYPES.WOOD] = .1,
	[JMod.EZ_RESOURCE_TYPES.PLASTIC] = .3,
	[JMod.EZ_RESOURCE_TYPES.FUEL] = .6,
	[JMod.EZ_RESOURCE_TYPES.CHEMICALS] = 1,
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
	[JMod.EZ_RESOURCE_TYPES.ANTIMATTER] = 1000
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

function GM:CalcJBuxWorth(item, amount)
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
			JBuxToGain = JBuxToGain + GAMEMODE:CalcJBuxWorth(typ, amt)
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

function GM:AutoCalcPrice(contents, searchRadioManifest)
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