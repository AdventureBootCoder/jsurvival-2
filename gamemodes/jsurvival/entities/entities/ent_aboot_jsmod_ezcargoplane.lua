-- AdventureBoots 2023
AddCSLuaFile()
ENT.Type = "anim"
ENT.PrintName = "EZ Cargo Plane"
ENT.Category = "JMod - EZ Misc."
ENT.Spawnable = true 
ENT.AdminSpawnable = false
ENT.StandardLifeTime = 20
ENT.StandardSpeed = 50000

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "ManualRender")
	self:NetworkVar("Vector", 0, "RenderPos")
end

if SERVER then
	function ENT:SpawnFunction(ply, tr)
		local SpawnPos = tr.HitPos + tr.HitNormal * 40
		local ent = ents.Create(self.ClassName)
		ent:SetAngles(Angle(0, 0, 0))
		ent:SetPos(SpawnPos)
		JMod.SetEZowner(ent, ply)
		ent:Spawn()
		ent:Activate()
		sound.Play("@julton/cargo_plane_flyby_mono.wav", ply:GetPos(), 160, 100, 1)

		return ent
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	function ENT:Initialize()
		self:SetModel("models/jsurvival/jargoplane.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_NONE)
		--self:DrawShadow(true)
		--self:AddEFlags(EFL_IN_SKYBOX)
	
		self.PickupPos = self.PickupPos or self:GetPos()
		self.FlightDir = self.FlightDir or Vector(math.random(-1, 1), math.random(-1, 1), 0):GetNormalized()
		self.TotalDistance = self.FlightDir * self.StandardSpeed
		self.LifeTime = self.LifeTime or self.StandardLifeTime
		self.DieTime = CurTime() + self.LifeTime

		self.FlightAng = self.FlightDir:Angle()
		self.FlightAng:RotateAroundAxis(self.FlightAng:Up(), 180)
		self:SetAngles(self.FlightAng)
		self:SetManualRender(true) -- We will most likely start outside the map
		self:SetRenderPos(self.PickupPos + self.TotalDistance * .5)
		self:EmitSound("@julton/cargo_plane_flyby_mono.wav", 160, 100, 1)

		local Phys = self:GetPhysicsObject()
		timer.Simple(0, function() 
			if IsValid(self) and IsValid(Phys) then
				Phys:SetMass(50000)
				--Phys:EnableMotion(false) 
			end 
		end)
	end

	function ENT:Think()
		local Time = CurTime()
		local TimeLeft = self.DieTime - Time
		if TimeLeft <= 0 then self:Remove() return false end
		PlayerFilter = RecipientFilter()
		PlayerFilter:AddAllPlayers()
		self:SetPreventTransmit(PlayerFilter, false)

		local Frac = ((self.DieTime - Time) / self.LifeTime) - .5
		local Pos = self.PickupPos + self.TotalDistance * Frac
		
		local Boundry = util.TraceLine({start = self.PickupPos, endpos = Pos, filter = self, mask = MASK_SOLID_BRUSHONLY})
		if Boundry.HitSky or not(util.IsInWorld(Pos)) then
			self:SetManualRender(true)
			self:SetRenderPos(Pos)
			self:SetPos(Boundry.HitPos + Boundry.Normal)
		else
			self:SetManualRender(false)
			self:SetPos(Boundry.HitPos + Boundry.Normal)
		end
		self:SetAngles(self.FlightAng)
		--debugoverlay.Line(self.PickupPos, Pos, 1, Color(0, 247, 255), true)
		debugoverlay.Cross(self:GetPos(), 10, 1, Color(0, 255, 221), true)

		self:NextThink(Time)
		return true
	end

elseif CLIENT then
	function ENT:Initialize()
		--self:AddEFlags(EFL_IN_SKYBOX)
	end

	function ENT:Think()
		--print(self:GetNoDraw(), self:GetManualRender(), self:GetRenderPos())

		if (self:GetNoDraw() == false) then self:Draw() end

		self:NextThink(CurTime())
		return true
	end

	local GlowSprite = Material("sprites/mat_jack_basicglow")
	local RedLight, GreenLight = Color(255, 21, 21), Color(29, 255, 21)
	function ENT:Draw()
		local Time = CurTime()
		local Pos = self:GetRenderPos()
		if self:GetManualRender() then
			self:SetRenderOrigin(Pos)
			--render.SetLightingOrigin(self:GetPos())
		else
			self:SetRenderOrigin(nil)
		end
		--print(self:GetManualRender(), self:GetRenderPos())
		--debugoverlay.Cross(self:GetPos(), 10, 2, Color(255, 251, 0), true)
		--
		self:DrawShadow(true)
		self:DrawModel()
		--
		local SelfAng = self:GetAngles() 
		local Up, Right, Forward = SelfAng:Up(), SelfAng:Right(), SelfAng:Forward()
		local SelfPos = self:GetPos()
		local Brightness = 255--(math.sin(Time * 1) / 2 + .5) * 255
		render.SetMaterial(GlowSprite)
		local SpritePos1 = SelfPos + Up * 255 + Right * 956 + Forward * 150
		local Light1 = (SpritePos1 - EyePos()):GetNormalized()
		render.DrawSprite(SpritePos1 - Light1 * 5, 50, 50, RedLight)
		local SpritePos2 = SelfPos + Up * 255 - Right * 955 + Forward * 150
		local Light2 = (SpritePos2 - EyePos()):GetNormalized()
		render.DrawSprite(SpritePos2 - Light2 * 5, 50, 50, GreenLight)
	end
end
