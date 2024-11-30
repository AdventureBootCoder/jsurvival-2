DeriveGamemode("sandbox")
GM.Name = "JSurvival"
GM.Author = "AdventureBoots"
GM.Email = ""
GM.Website = ""
local Cheats = GetConVar("sv_cheats")
JSMod = JSMod or {}
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
	
	util.AddNetworkString("jbuxlist")

	function JSMod.JBuxListInfo(ply)
		net.Start("jbuxlist")
		net.WriteTable(JSMod.JBuxList)
		net.Send(ply)
		--print("JBux List Networking")
	end
elseif CLIENT then
	net.Receive("betterchatprint", function() chat.AddText(net.ReadColor(), net.ReadString()) end)
	net.Receive("jbuxlist", function(ply) JSMod.JBuxList = net.ReadTable() end)
end