PropSpawnTable = {}
local PropLoot = {
	[1] = {
		Type = "zombies",
		Loot = {"npc_zombie", "npc_headcrab", "npc_zombie_torso", "npc_antlion"}
	},
	[2] = {
		Type = "loot",
		Loot = {"ent_jack_gmod_ezacorn"}
	},
	[3] = {
		Type = "prop_physics",
		Loot = {"models/props_canal/boat001b.mdl", "models/props_vehicles/car004a_physics.mdl", "models/props_vehicles/car004b_physics.mdl", "models/props_interiors/refrigerator01a.mdl", "models/props_c17/bench01a.mdl", "models/props_junk/cardboard_box001a.mdl", "models/props_junk/cardboard_box001b.mdl", "models/props_junk/cardboard_box002a.mdl", "models/props_junk/cardboard_box002b.mdl", "models/props_junk/cardboard_box003a.mdl", "models/props_junk/cardboard_box003b.mdl", "models/props_junk/cardboard_box004a.mdl", "models/props_junk/wood_crate001a.mdl", "models/props_junk/wood_crate001a_damaged.mdl", "models/props_junk/wood_crate001a_damagedmax.mdl", "models/props_junk/wood_crate002a.mdl", "models/Items/item_item_crate.mdl", "models/props_c17/furnituredrawer001a.mdl", "models/props_c17/furnituredrawer003a.mdl", "models/props_lab/dogobject_wood_crate001a_damagedmax.mdl", "models/props_c17/canister01a.mdl", "models/props_c17/canister02a.mdl", "models/props_junk/gascan001a.mdl", "models/props_junk/metalgascan.mdl", "models/props_junk/propane_tank001a.mdl", "models/props_junk/propanecanister001a.mdl", "models/props_interiors/pot01a.mdl", "models/props_c17/oildrum001.mdl", "models/props_junk/metal_paintcan001a.mdl", "models/props_wasteland/controlroom_filecabinet001a.mdl", "models/props_junk/metal_paintcan001b.mdl", "models/props_trainstation/trashcan_indoor001a.mdl", "models/props_c17/suitcase001a.mdl", "models/props_c17/suitcase_passenger_physics.mdl", "models/props_c17/briefcase001a.mdl", "models/props_phx/construct/metal_plate1.mdl", "models/props_phx/construct/metal_plate1_tri.mdl", "models/props_phx/construct/glass/glass_plate1x1.mdl", "models/props_phx/construct/glass/glass_plate1x2.mdl", "models/hunter/plates/plate1x1.mdl", "models/hunter/plates/plate1x2.mdl", "models/props_phx/construct/wood/wood_panel1x1.mdl", "models/props_phx/construct/wood/wood_panel1x2.mdl", "models/props_phx/construct/wood/wood_panel2x2.mdl", "models/props_phx/construct/wood/wood_boardx1.mdl", "models/props_phx/construct/wood/wood_boardx2.mdl"}
	},
}

function SpawnPropTimer()
	local zombus = GetConVar("js_zombies")
	local maxcount = GetConVar("js_maxloot")
	local navmeshareas = navmesh.GetAllNavAreas()
	if table.IsEmpty(navmeshareas) then return end
	if not (#PropSpawnTable >= (maxcount:GetInt() or 128)) then
		local Randompos = navmeshareas[math.random(#navmeshareas)]:GetCenter()
		local rand = math.random(1, 3) -- если добавляешь новые таблицы в PropLoot, то прибавляешь число..надо будет это всё автоматизировать как-то
		local RandTable = PropLoot[rand]
		local prop
		if RandTable.Type == "zombies" and zombus:GetBool() == false then return end
		if RandTable.Type == "zombies" and math.random(1, 4) == 2 then return end -- pridurok

		if RandTable.Type == "prop_physics" then
			prop = ents.Create(RandTable.Type)
			prop:SetModel(RandTable.Loot[math.random(#RandTable.Loot)])
		else
			prop = ents.Create(RandTable.Loot[math.random(#RandTable.Loot)])
		end

		--print(RandTable.Type)
		prop:Spawn()
		local mins = prop:OBBMins()
		local maxs = prop:OBBMaxs()
		local dir = prop:GetUp()
		local len = 60
		local tr = util.TraceHull(
			{
				start = Randompos + dir * len,
				endpos = vector_origin,
				mins = mins,
				maxs = maxs,
			}
		)

		if tr.HitWorld then
			prop:Remove()
			SpawnPropTimer()

			return
		end

		local SpawnPos = Randompos + Vector(0, 0, maxs.z - mins.z)
		prop:SetPos(SpawnPos)
		table.insert(PropSpawnTable, prop)
		prop:CallOnRemove(
			"TableRemove",
			function()
				table.RemoveByValue(PropSpawnTable, prop)
			end
		)
	else
		timer.Remove("prop_spawn")
		timer.Create("prop_remove", 60, 0, RemovePropTimer)
	end
end

function RemovePropTimer()
	if #PropSpawnTable >= 90 then
		local prop = table.Random(PropSpawnTable)
		prop:Remove()
	else
		timer.Remove("prop_remove")
		timer.Create("prop_spawn", 3, 0, SpawnPropTimer)
	end
end

hook.Add("PostCleanupMap", "RandomLootDelete", function()
	PropSpawnTable = {}
	timer.Remove("prop_remove")
	timer.Remove("prop_spawn")
	timer.Create("prop_spawn", 3, 0, SpawnPropTimer)
end)

timer.Create("prop_spawn", 3, 0, SpawnPropTimer)

hook.Add("PlayerSpawn", "JS_RANDOM_SPAWN_DROP", function(ply)
	local Navmeshareas = navmesh.GetAllNavAreas()
	if not table.IsEmpty(Navmeshareas) then
		local Randompos = Navmeshareas[math.random(#Navmeshareas)]:GetCenter()
		local SpawnPos = util.QuickTrace(Randompos, Vector(0, 0, 128)).HitPos - Vector(0, 0, 64)

		local DropPos = JMod.FindDropPosFromSignalOrigin(SpawnPos)

		if DropPos then
			ply:SetPos(DropPos)
			ply:SetNoDraw(true)
			local DropVelocity = VectorRand()
			DropVelocity.z = 0
			DropVelocity:Normalize()
			DropVelocity = DropVelocity * 400
			local Eff = EffectData()
			Eff:SetOrigin(DropPos)
			Eff:SetStart(DropVelocity)
			util.Effect("eff_jack_gmod_jetflyby", Eff, true, true)
	
			timer.Simple(0.9, function()
				if not IsValid(ply) or not ply:Alive() or (ply:InVehicle()) then return end
				local Box = ents.Create("ent_jack_aidbox")
				Box:SetPos(DropPos)
				Box.InitialVel = -DropVelocity * 10
				Box.Contents = {}
				Box.NoFadeIn = true
				Box:SetDTBool(0, "true")
				Box:Spawn()
				----- Create the chair
				Box.Pod = ents.Create("prop_vehicle_prisoner_pod")
				Box.Pod:SetModel("models/vehicles/prisoner_pod_inner.mdl")
				local Ang, Up, Right, Forward = Box:GetAngles(), Box:GetUp(), Box:GetRight(), Box:GetForward()
				Box.Pod:SetPos(Box:GetPos() - Up * 30)
				Ang:RotateAroundAxis(Up, 0)
				Ang:RotateAroundAxis(Forward, 0)
				Box.Pod:SetAngles(Ang)
				Box.Pod:Spawn()
				Box.Pod:Activate()
				Box.Pod:SetParent(Box)
				Box.Pod:SetNoDraw(true)
				Box.Pod:SetThirdPersonMode(true)
				------
				Box:SetPackageName(ply:Nick())
				ply:EnterVehicle(Box.Pod)
				---
				sound.Play("snd_jack_flyby_drop.mp3", DropPos, 150, 100)
	
				for k, playa in pairs(ents.FindInSphere(DropPos, 6000)) do
					if playa:IsPlayer() then
						sound.Play("snd_jack_flyby_drop.mp3", playa:GetShootPos(), 50, 100)
					end
				end
			end)
		else
			ply:SetPos(SpawnPos)
		end
	end
end)