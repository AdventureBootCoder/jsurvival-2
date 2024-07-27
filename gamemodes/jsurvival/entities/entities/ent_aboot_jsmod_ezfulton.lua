-- AdventureBoots 2023
AddCSLuaFile()
ENT.Type = "anim"
ENT.PrintName = "EZ Fulton"
ENT.Spawnable = false 
ENT.AdminSpawnable = false

local STATE_COLLAPSING, STATE_FINE = -1, 0

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "State")
	self:NetworkVar("Float", 1, "Inflation")
end


if SERVER then
	function ENT:Initialize()
		self:SetModel("models/mgsv/items/fulton.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:DrawShadow(true)
		self:SetSubMaterial(0, "models/mgsv/items/fulton_blue")
		local Phys = self:GetPhysicsObject()

		if IsValid(Phys) then
			Phys:Wake()
			Phys:SetMass(5)
			Phys:EnableDrag(false)
			Phys:SetMaterial("cloth")
		end
		self.Durability = 100
		self.DesiredAltitude = self.DesiredAltitude or 1000
		self.CurrentAltitude = 0
		self.AttachedCargo = self.AttachedCargo or nil
		self:SetInflation(0)

		self:SetState(STATE_FINE)
	end

	function ENT:Think()
		local Time, State = CurTime(), self:GetState()
		local Up = self:GetUp()

		local Phys = self:GetPhysicsObject()
		local Inflated = self:GetInflation()

		if State == STATE_FINE then
			if not IsValid(self.AttachedCargo) then self:SetState(STATE_COLLAPSING) return end
			if (self.Grabbed) then
				if self.PickupVel then
					Phys:SetVelocity(self.PickupVel)
				end
			else
				self.CurrentAltitude = (self:GetPos().z - self.AttachedCargo:GetPos().z)
				if not self.ReadyForPickup and (self.CurrentAltitude >= self.DesiredAltitude) then
					self.ReadyForPickup = true
					self.AttachedCargo:OnFultonReady(self)
				end
				JMod.AeroDrag(self, Up, 10, 10)
				Phys:ApplyForceOffset(Vector(0, 0, 100 * Inflated), self:GetPos() + Up * 100)
			end
			self:SetInflation(math.min(Inflated + 0.01, 1))
		elseif State == STATE_COLLAPSING then
			self:SetInflation(math.min(Inflated - 0.01, 1))
			if Inflated <= 0 then
				self:Remove()
			end
		end

		self:NextThink(Time + 0.01)
		return true
	end

	function ENT:Collapse()
		if self:GetState() == STATE_COLLAPSING then return end
		self:SetState(STATE_COLLAPSING)
	end

	function ENT:OnRecover(PickupVel)
		if not PickupVel then self:Remove() return end
		self.Grabbed = true
		self:SetNoDraw(true)
		local Phys = self:GetPhysicsObject()
		Phys:EnableMotion(true)
		Phys:EnableDrag(false)
		Phys:EnableGravity(false)
		Phys:SetMass(50000)
		self.PickupVel = PickupVel
	end

	function ENT:PhysicsCollide(data, physobj)
		if self.Grabbed then
			local SkyTr = util.TraceLine({start = self:GetPos(), endpos = self:GetPos() - (data.OurOldVelocity), filter = {self, self.Fulton}, mask = MASK_SOLID_BRUSHONLY})
			if SkyTr.HitSky then
				SafeRemoveEntityDelayed(self, 0)
				if IsValid(self.AttachedCargo) then
					self.AttachedCargo:SetVelocity(data.OurOldVelocity)
				end
			end
		end
	end

	function ENT:OnTakeDamage(dmg)
		if dmg:IsDamageType(DMG_RADIATION) then return end
		self.Durability = math.Clamp(self.Durability - (dmg:GetDamage() - (200/dmg:GetDamage())^2), 0, 100)
		if self.Durability <= 0 then
			self:Collapse()
		end
	end

	function ENT:GravGunPickupAllowed(ply)
		return false
	end

elseif CLIENT then
	function ENT:Initialize()
		--
	end

	local GlowSprite = Material("sprites/mat_jack_basicglow")
	local LightColor = Color(255, 21, 21)
	function ENT:Think()
		local State, SelfPos, Ang = self:GetState(), self:GetPos(), self:GetAngles()
		local Inflated = self:GetInflation()

		if (Inflated >= 1) and (State == STATE_FINE) then
			local Up, Right, Forward = Ang:Up(), Ang:Right(), Ang:Forward()
			local R, G, B = LightColor.r, LightColor.g, LightColor.b
			local DLight = DynamicLight(self:EntIndex())
			local Brightness = (math.sin(CurTime() * 1) / 2 + .5) * 3

			if DLight then
				DLight.Pos = SelfPos + Up * 15
				DLight.r = R
				DLight.g = G
				DLight.b = B
				DLight.Brightness = Brightness
				DLight.Size = 300
				DLight.Decay = 1000
				DLight.DieTime = CurTime() + .3
				DLight.Style = 0
			end
		end
	end

	function ENT:Draw()
		local Mat = Matrix()
		local Inflation = self:GetInflation()
		local Siz = Vector(1, 1, 1 * Inflation)
		Mat:Scale(Siz)
		self:EnableMatrix("RenderMultiply", Mat)
		self:DrawModel()
		self:DisableMatrix("RenderMultiply")

		if (Inflation >= 1) and (self:GetState() == STATE_FINE) then
			local Up = self:GetAngles():Up()
			local SelfPos = self:GetPos()
			local Brightness = (math.sin(CurTime() * 1) / 2 + .5) * 255
			render.SetMaterial(GlowSprite)
			local SpritePos = SelfPos + Up * 15
			local Vec = (SpritePos - EyePos()):GetNormalized()
			render.DrawSprite(SpritePos - Vec * 5, 20, 20, Color(255, 21, 21, Brightness))
			render.DrawSprite(SpritePos - Vec * 5, 10, 10, Color(255, 255, 255, Brightness))
		end
	end
	language.Add("ent_aboot_jsmod_ezfulton", "EZ fulton")
end
