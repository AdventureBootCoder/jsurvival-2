DeriveGamemode("sandbox")
GM.Name = "JSurvival"
GM.Author = "плыв, AdventureBoots"
GM.Email = "плыв"
GM.Website = "плыв"
local Cheats = GetConVar("sv_cheats")

hook.Add("PlayerNoClip", "js-noclip", function(ply, desiredState)
	if Cheats:GetInt() == 1 then return true end

	return false
end)

if SERVER then
	util.AddNetworkString("betterchatprint")
	function BetterChatPrint(ply, msg, color)
		if not (ply or msg or color) then return end
		net.Start("betterchatprint")
		net.WriteColor(color)
		net.WriteString(msg)
		net.Send(ply)
	end

	hook.Add("PlayerSpawnObject", "JS_SPAWN_BLOCK", function(ply)
		if Cheats:GetInt() == 0 then return false end
	end)

	hook.Add( "PlayerGiveSWEP", "JS_BLOCK_GIVESWEP", function(ply, class, swep)
		if Cheats:GetInt() == 0 then return false end
	end)
elseif CLIENT then
	net.Receive("betterchatprint", function()
		chat.AddText(net.ReadColor(), net.ReadString())
	end)
end