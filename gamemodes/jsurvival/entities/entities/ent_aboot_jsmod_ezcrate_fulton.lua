-- AdventureBoots 2024
AddCSLuaFile()
ENT.Type = "anim"
ENT.Author = "AdventureBoots"
ENT.Category = "JMod - EZ Misc."
ENT.Information = ""
ENT.PrintName = "EZ Fulton Crate"
ENT.NoSitAllowed = true
ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.JModPreferredCarryAngles = Angle(0, 0, 0)
ENT.DamageThreshold = 120
ENT.MaxItems = 1000
ENT.KeepJModInv = true

---
function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "ItemCount")
end

---
if SERVER then
	function ENT:SpawnFunction(ply, tr)
		local SpawnPos = tr.HitPos + tr.HitNormal * 40
		local ent = ents.Create(self.ClassName)
		ent:SetAngles(Angle(0, 0, 0))
		ent:SetPos(SpawnPos)
		JMod.SetEZowner(ent, ply)
		ent:Spawn()
		ent:Activate()
		JMod.Hint(ply, self.ClassName)

		return ent
	end

	function ENT:Initialize()
		self:SetModel("models/props_junk/wood_crate001a.mdl")
		self:SetMaterial("models/mat_jack_aidbox")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:DrawShadow(true)
		self:SetUseType(SIMPLE_USE)
		self:SetItemCount(0)

		self.EZconsumes = {self.ItemType}

		self.NextLoad = 0
		self.Items = {}

		timer.Simple(.01, function()
			self:CalcWeight()
		end)
	end

	function ENT:CalcWeight()
		JMod.UpdateInv(self)
		self:GetPhysicsObject():SetMass(50 + self.JModInv.weight)
		self:GetPhysicsObject():Wake()
		self:SetItemCount(self.JModInv.volume)
	end

	JMod.GetItemVolumeWeight = JMod.GetItemVolumeWeight or function(ent)
		if not IsValid(ent) then return nil end
		local Phys = ent:GetPhysicsObject()
		if not IsValid(Phys) then return nil end
	
		local Vol = Phys:GetVolume()
		local Mass = 0
		if Vol == nil then
			local Mins, Maxs = ent:GetCollisionBounds()
			local X = math.abs(Maxs.x - Mins.x)
			local Y = math.abs(Maxs.y - Mins.y)
			local Z = math.abs(Maxs.z - Mins.z)
			Vol = X * Y * Z
		end
		Vol = ent.EZstorageVolumeOverride or math.Round(Vol / JMod.VOLUMEDIV, 2)
		Mass = math.ceil(Phys:GetMass())
		if ent.IsJackyEZresource then
			Vol = 1
			Mass = 1
		end
	
		return Vol, Mass
	end

	function ENT:PhysicsCollide(data, physobj)
		if (data.DeltaTime > 0.2) and (data.Speed > 100) then
			self:EmitSound("Wood_Crate.ImpactHard")
			self:EmitSound("Wood_Box.ImpactHard")
		end

		if self.PlaneComing then
			local SkyTr = util.TraceLine({start = self:GetPos(), endpos = self:GetPos() - (data.OurOldVelocity), filter = {self, self.Fulton}, mask = MASK_SOLID_BRUSHONLY})
			if SkyTr.HitSky then
				timer.Simple(0, function() if IsValid(self) then self:OnFultonRecover() end end)
			end
		end

		if self.NextLoad > CurTime() then return end
		local ent = data.HitEntity

		if IsValid(ent) then
			local Vol, Mass = JMod.GetItemVolumeWeight(ent)
			if Vol ~= nil then
				if JSMod.ItemToJBux[ent:GetClass()] and ent:IsPlayerHolding() then
					self.NextLoad = CurTime() + 0.5
					timer.Simple(0, function()
						if IsValid(self) and IsValid(ent) then
							JMod.AddToInventory(self, ent)
							self:CalcWeight()
						end
					end)
				elseif ent.IsJackyEZresource and JSMod.CurrentResourcePrices[ent.EZsupplies] and ent:IsPlayerHolding() then
					self.NextLoad = CurTime() + 0.5
					timer.Simple(0, function()
						if IsValid(self) and IsValid(ent) then
							JMod.AddToInventory(self, {ent})
							self:CalcWeight()
						end
					end)
				end
			end
		end
	end

	function ENT:OnTakeDamage(dmginfo)
		self:TakePhysicsDamage(dmginfo)

		if dmginfo:GetDamage() > self.DamageThreshold then
			local Pos = self:GetPos()
			sound.Play("Wood_Crate.Break", Pos)
			sound.Play("Wood_Box.Break", Pos)

			--[[for class, tbl in pairs(self.Items) do
				for i = 1, tbl[1] do
					local ent = ents.Create(class)
					ent:SetPos(self:GetPos() + VectorRand() * 10)
					ent:SetAngles(AngleRand())
					ent:Spawn()
					ent:Activate()
				end
			end--]]

			self:Remove()
		end
	end

	function ENT:ReleaseFulton(activator)
		if not IsValid(activator) then return end
		local AltTr = util.QuickTrace(self:GetPos(), Vector(0, 0, 9e9), self)
		if not AltTr.HitSky then activator:PrintMessage(HUD_PRINTCENTER, "No sky above crate") return end
		local SelfPos = self:LocalToWorld(self:OBBCenter())
		local HitHeight = math.min((SelfPos - AltTr.HitPos):Length(), 4000)

		local Fulton = ents.Create("ent_aboot_jsmod_ezfulton")
		Fulton:SetPos(SelfPos + Vector(0, 0, 100))
		Fulton:SetAngles(Angle(0, 0, 0))
		Fulton.DesiredAltitude = HitHeight - 150
		Fulton.AttachedCargo = self
		self.Fulton = Fulton
		Fulton:Spawn()
		Fulton:Activate()
		JMod.SetEZowner(Fulton, activator)
		--
		Fulton:EmitSound("julton/weather_balloon_inflat.wav", 75, 100, 1)

		local Cable, Vrope = constraint.Elastic(self, Fulton, 0, 0, Vector(0, 0, 20), Vector(0, 0, 0), 100, 10, 2, "cable/cable2", 2, true)
		if IsValid(Cable) then
			Cable:Fire("SetSpringLength", tostring(Fulton.DesiredAltitude + 50), 0)
			--self.PickupPos = SelfPos + Vector(0, 0, Fulton.DesiredAltitude)
			self.Cable = Cable
			self.PlaneComing = false
		end
	end

	local ClipTextures = {
		"TOOLS/TOOLSINVISIBLE"
	}

	local function CheckForMapClip(traceData)
		local HitTexture = traceData.HitTexture
		if table.HasValue(ClipTextures, HitTexture) then
			local NewStart = traceData.HitPos + traceData.Normal * 5
			local NewTrace = util.TraceLine({start = NewStart, endpos = NewStart + (traceData.Normal * 9e9), filter = traceData.filter, mask = traceData.mask})
			--debugoverlay.Line(NewStart, NewTrace.HitPos, 1, Color(255, 0, 0), true)

			return NewTrace
		end

		return traceData
	end

	function ENT:OnFultonReady()
		if self.PlaneComing then return end
		local PickupPos, PickupVelocity = self:GetPos() + Vector(0, 0, self.Fulton.DesiredAltitude), Vector(math.Rand(-1, 1), math.Rand(-1, 1), 0):GetNormalized()
		local Tries = 0
		local ClearPath = false
		local DirTr, OtherDirTr
		while not(ClearPath) and (Tries < 300) do
			DirTr = CheckForMapClip(util.TraceLine({start = PickupPos, endpos = PickupPos - (PickupVelocity * 9e9), filter = {self, self.Fulton}, mask = MASK_SOLID_BRUSHONLY}))
			OtherDirTr = CheckForMapClip(util.TraceLine({start = PickupPos, endpos = PickupPos + (PickupVelocity * 9e9), filter = {self, self.Fulton}, mask = MASK_SOLID_BRUSHONLY}))
			--print(Tries, DirTr.HitTexture, OtherDirTr.HitTexture)
			--debugoverlay.Line(PickupPos, PickupPos + (PickupVelocity * 9e9), 2, Color(217, 255, 0), true)

			if DirTr.HitSky and OtherDirTr.HitSky then
				ClearPath = true
				self.PlaneComing = true
				self:CallinFultonRecover(PickupPos, PickupVelocity)

				return
			else
				Tries = Tries + 1
				PickupVelocity = Vector(math.Rand(-1, 1), math.Rand(-1, 1), 0):GetNormalized()
			end
		end

		self.Fulton:Collapse()
	end--]]

	function ENT:CallinFultonRecover(pos, dir)
		local PickupPos, PickupVelocity = pos, dir
		local CratePos = self:GetPos()
		local CargoPlane = ents.Create("ent_aboot_jsmod_ezcargoplane")
		CargoPlane:SetPos(PickupPos)--PickupPos + Vector(0, 0, -50) + PickupVelocity * -800)
		CargoPlane:SetAngles(PickupVelocity:Angle())
		CargoPlane.FlightDir = PickupVelocity
		CargoPlane:Spawn()

		for _, ply in player.Iterator() do
			if IsValid(ply) then
				local Pos = ply:GetPos()
				local Dist = Pos:Distance(PickupPos)
				if Dist < 5000 then
					local Direction = (Pos - PickupPos):GetNormalized()
					sound.Play("@julton/cargo_plane_flyby_mono.wav", Pos + Vector(0, 0, 100), 160, 100, 1)
				end
			end
		end

		timer.Simple(10, function()
			if not IsValid(self) or not IsValid(self.Fulton) or not IsValid(self.Cable) then return end
			if PickupPos:Distance(self.Fulton:GetPos()) > 500 then return end
			self.Fulton:SetPos(PickupPos)
			self.Fulton:OnRecover(PickupVelocity * -2500)
			--
			self:GetPhysicsObject():EnableDrag(false)
			self:GetPhysicsObject():EnableGravity(false)
			self:GetPhysicsObject():SetVelocity(((self:GetPos() - CargoPlane:GetPos()):GetNormalized() * 5000))
			sound.Play("ambient/machines/catapult_throw.wav", CratePos + Vector(0, 0, 100), 75, 60, 1)
			timer.Simple(3, function()
				if not IsValid(self) then return end
				self:OnFultonRecover()
			end)
		end)
	end

	function ENT:OnFultonRecover()
		if self.Recovered then return end
		local AvaliableResources = self.JModInv.EZresources

		local JBuxToGain = GAMEMODE:CalcJBuxWorth(AvaliableResources)

		if self.JModInv.EZitems and next(self.JModInv.EZitems) then
			JBuxToGain = JBuxToGain + GAMEMODE:CalcJBuxWorth(self.JModInv.Items)
			for k, v in pairs(self.JModInv.EZitems) do
				SafeRemoveEntity(v.ent)
			end
		end
		self.JModInv = {} -- Make sure there's absolutely no double dipping

		local Owner = JMod.GetEZowner(self)
		if (JBuxToGain > 0) and IsValid(Owner) then
			GAMEMODE:SetJBux(Owner, GAMEMODE:GetJBux(Owner) + JBuxToGain)
		end
		self.Recovered = true
		SafeRemoveEntity(self)
		SafeRemoveEntity(self.Fulton)
	end

	function ENT:Use(activator)
		if (self:GetItemCount() <= 0) or self.PlaneComing then return end
		local Alt = JMod.IsAltUsing(activator)
		if Alt then
			if IsValid(self.Fulton) then
				self.Fulton:Collapse()
			else
				self:ReleaseFulton(activator)
			end
		else
			net.Start("JMod_ItemInventory")
			net.WriteEntity(self)
			net.WriteString("open_menu")
			net.WriteTable(self.JModInv)
			net.Send(activator)
		end
	end

	function ENT:Think()
		if IsValid(self.Fulton) then
			if not IsValid(self.Cable) then
				self.Fulton:Collapse()
				self.Fulton = nil
				self.PlaneComing = false
			end
		end
	end

	function ENT:OnRemove()
		if self.PlaneComing then
			--self:OnFultonRecover()
		end
	end

elseif CLIENT then
	local TxtCol = Color(10, 10, 10, 220)

	function ENT:Initialize()
		self.OxygenTank = JMod.MakeModel(self, "models/props_c17/canister01a.mdl", nil)
		self.FultonBox = JMod.MakeModel(self, "models/props_junk/cardboard_box002a.mdl", nil)
	end

	function ENT:Use(activator)
		if (self:GetItemCount() <= 0) then
			notification.AddLegacy("Load items or resources and then press alt+use to call in a cargo plane!", NOTIFY_HINT, 3)
		end
	end

	function ENT:Draw()
		local Ang, Pos = self:GetAngles(), self:GetPos()
		local Up, Right, Forward, Resource = Ang:Up(), Ang:Right(), Ang:Forward(), tostring(self:GetItemCount())
		local Closeness = LocalPlayer():GetFOV() * EyePos():Distance(Pos)
		local DetailDraw = Closeness < 45000 -- cutoff point is 500 units when the fov is 90 degrees
		self:DrawModel()

		local TankPos = Pos + Up * 27 - Right * 10 - Forward * 3
		local TankAng = Ang:GetCopy()
		TankAng:RotateAroundAxis(Right, 90)
		JMod.RenderModel(self.OxygenTank, TankPos, TankAng, Vector(1.5, 1.5, 0.8))
		local BoxPos = Pos + Up * 27 + Right * 8
		local BoxAng = Ang:GetCopy()
		BoxAng:RotateAroundAxis(Up, 90)
		JMod.RenderModel(self.FultonBox, BoxPos, BoxAng, Vector(.7, 1, .6))

		if DetailDraw then
			Ang:RotateAroundAxis(Ang:Right(), 90)
			Ang:RotateAroundAxis(Ang:Up(), -90)
			cam.Start3D2D(Pos + Up * 10 - Forward * 19.8 + Right, Ang, .15)
			draw.SimpleText("JACKARUNDA INDUSTRIES", "JMod-Stencil-S", 0, 0, TxtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText("STORAGE", "JMod-Stencil", 0, 15, TxtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText("Capacity: " .. Resource .. "/" .. self.MaxItems, "JMod-Stencil-S", 0, 70, TxtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			cam.End3D2D()
			---
			Ang:RotateAroundAxis(Ang:Right(), 180)
			cam.Start3D2D(Pos + Up * 10 + Forward * 20.1 - Right, Ang, .15)
			draw.SimpleText("JACKARUNDA INDUSTRIES", "JMod-Stencil-S", 0, 0, TxtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText("STORAGE", "JMod-Stencil", 0, 15, TxtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText("Capacity: " .. Resource .. "/" .. self.MaxItems, "JMod-Stencil-S", 0, 70, TxtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			cam.End3D2D()
		end
	end
	language.Add("ent_aboot_jsmod_ezcrate_fulton", "EZ Fulton Crate")
end
