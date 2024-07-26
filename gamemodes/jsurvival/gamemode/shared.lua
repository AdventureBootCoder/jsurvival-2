DeriveGamemode("sandbox")
GM.Name = "JSurvival"
GM.Author = "AdventureBoots"
GM.Email = ""
GM.Website = ""
local Cheats = GetConVar("sv_cheats")
JSMod = JSMod or {}
hook.Add("PlayerNoClip", "js-noclip", function(ply, desiredState)
	if Cheats:GetBool() or JMod.IsAdmin(ply) then return true end

	return false
end)
local color_orange = Color(255, 136, 0)

JSMod.JBuxList = JSMod.JBuxList or {}

if SERVER then
	util.AddNetworkString("betterchatprint")
	function BetterChatPrint(ply, msg, color)
		if not (ply or msg or color) then return end
		net.Start("betterchatprint")
		net.WriteColor(color)
		net.WriteString(msg)
		net.Send(ply)
	end
elseif CLIENT then
	net.Receive("betterchatprint", function()
		chat.AddText(net.ReadColor(), net.ReadString())
	end)
end

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
	local amt = math.floor(amt)
	JSMod.JBuxList[ply:SteamID()] = amt

	if silent then return end

	if (amt < OldAmt) then
		BetterChatPrint(ply, "That cost you ".. tostring(OldAmt - amt) .." JBux!", color_orange)
	elseif (amt > OldAmt) then
		BetterChatPrint(ply, "You have gained ".. tostring(amt - OldAmt) .." JBux!", color_orange)
	end
end

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
			JBuxToGain = JBuxToGain + GM:CalcJBuxWorth(typ, amt)
		end
	end
	return JBuxToGain, Exportables
end