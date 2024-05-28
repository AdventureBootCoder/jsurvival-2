function EFFECT:Init(data)
	self.Pos = data:GetOrigin()
	self.TotalDistance = data:GetStart() * 200
	self.LifeTime = 20
	self.DieTime = CurTime() + self.LifeTime

	self.Plane = ClientsideModel("models/cargop/cargo.mdl")
	self.Plane:SetNoDraw(true)
	--self.Plane:SetPos(self.Pos)
	-- according to my math, this plane is doing about mach 1.25 when it passes
	-- if this effect is called with data:SetStart() velocity length of 400
end

function EFFECT:Think()
	local TimeLeft = self.DieTime - CurTime()
	if TimeLeft > 0 then return true end

	self.Plane:Remove()
	return false
end

function EFFECT:Render()
	local Frac = ((self.DieTime - CurTime()) / self.LifeTime) - .5
	local Pos = self.Pos + self.TotalDistance * Frac
	self.Plane:SetRenderOrigin(Pos)
	--self:SetOrigin(Pos)
	local Ang = self.TotalDistance:Angle()
	Ang:RotateAroundAxis(Ang:Up(), 180)
	--Ang:RotateAroundAxis(Ang:Right(), -45)
	self.Plane:SetRenderAngles(Ang)
	self.Plane:DrawModel()
end
