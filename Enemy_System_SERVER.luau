local Enemy_System = {}

--// OOP //--

local MetaEnemy = {}
MetaEnemy.__index = MetaEnemy

Enemy_System.Enemies = {}
Enemy_System.IDS = {}
Enemy_System.Created = {}

--// Physics //--

local PS = game:GetService("PhysicsService")

PS:RegisterCollisionGroup("Enemy")
PS:RegisterCollisionGroup("Holder")
PS:RegisterCollisionGroup("Scenery")
PS:CollisionGroupSetCollidable("Enemy", "Enemy", false)
PS:CollisionGroupSetCollidable("Enemy", "Holder", true)
PS:CollisionGroupSetCollidable("Enemy", "Scenery", false)

--// Modules //--

local Networker = require(game.ReplicatedStorage.Network.Networker)
local Enemy_Data = require(game.ServerStorage.Data.Enemy_Data)
local Misc = require(game.ReplicatedStorage.Shared.Packages.Misc_Package)
local Replicator = require(game.ReplicatedStorage.Shared.Packages.Replication_Package)
local MAP_SYSTEM = require(game.ServerStorage.Server.Modules.Map_System.Map_Loader)

--// Variables //--

local ENEMIES_HOLDER = game.Workspace.ENEMIES_HOLDER
local MAP = MAP_SYSTEM.WaitForMap(3, "Casa_Conti")
local PATHWAYS: Folder = MAP:WaitForChild("Pathway_Points")
local ASSETS = game.ReplicatedStorage.Storage.Enemy_Assets
local TIME_BETWEEN_ENEMIES = 0.5

----------------
--// System //--
----------------

function Enemy_System.InsertCreated(name)
	
	Enemy_System.Created[name] = os.clock()
end

function Enemy_System.CheckIfExists(enemyName)
	
	if Enemy_System.Enemies[enemyName] then return true end
		 
	return false

end

function Enemy_System.GetAllEnemies()
	
	local tab = {}
	for id, data in pairs(Enemy_System.Enemies) do
		
		table.insert(tab, id)
	end
	
	return #tab
end

function Enemy_System.GetEnemyByID(enemyID)

	return Enemy_System.Enemies[enemyID]
end

function Enemy_System.GetEnemiesByName(enemyName)

	local tab = {}
	for ID, eData in pairs(Enemy_System.Enemies) do
		
		if eData.Name == enemyName then
			
			table.insert(tab, ID)
		end
	end
	
	return tab
end

function Enemy_System.GetID(enemyName)
	
	if not Enemy_System.IDS[enemyName] then
		
		Enemy_System.IDS[enemyName] = 1
	else
		Enemy_System.IDS[enemyName] += 1
	end
	
	return enemyName..Enemy_System.IDS[enemyName]
end

function Enemy_System.NewEnemy(enemyName, amount)
	
	task.wait(0.15)
	
	amount = amount or 1
	
	warn("spawning ", enemyName)
	
	for times = 1, amount do
		
		if Enemy_System.CheckIfExists(enemyName) == false then

			local defData = Enemy_Data[enemyName]
			if not defData then warn("Enemy doesn't have preset data ", enemyName) return end

			local ID = Enemy_System.GetID(enemyName)
			local self = Misc.Copy(defData)

			self.ID = ID
			self.Walk_Connections = {}
			self.Network_Connections = {}
			self.Can_Walk = true

			setmetatable(self, MetaEnemy)

			Networker.Fire("Enemy_New", self, {"BE"})
		
			Enemy_System.Enemies[ID] = self

			task.spawn(function()
				self:Setup()
			end)
		
		else
			warn("enemy exists already, ", enemyName)
		end
		
		task.wait(TIME_BETWEEN_ENEMIES)
	end
end

---------------------
--// ENEMY CLASS //--
---------------------

function MetaEnemy:Destroy()
	 
	if Enemy_System.Enemies[self.ID] then
		
		if Enemy_System.Enemies[self.ID].Folder then
			Enemy_System.Enemies[self.ID].Folder:Destroy()
		end
		Enemy_System.Enemies[self.ID] = nil
	end
end

function MetaEnemy:ReplicateFolder()
	
	if not self.Folder then
		
		self.Folder = Instance.new("Folder")
		self.Folder.Name = self.ID
		self.Folder.Parent = ENEMIES_HOLDER
	end
	
	if self.Folder then
		
		Replicator.ReplicateTable(self, self.Folder, true)
	else
		warn("can't find folder ", self)
	end
end

function MetaEnemy:UpdateFolder()
	
	if self.Folder then

		Replicator.Update(self, self.Folder, true)
	else
		warn("can't find folder ", self)
	end
end

function MetaEnemy:SetupModel()
	
	local assetClone = ASSETS:FindFirstChild(self.Name):Clone()
	if assetClone then
		
		
		assetClone.Parent = self.Folder
		
		self.Model = assetClone
		self.Model.Name = "Model"
		
		for _, part: BasePart in pairs(self.Model:GetDescendants()) do
			
			if part:IsA("BasePart") then
				
				part.CollisionGroup = "Enemy"
				part.CanCollide = false

			end
		end
		
		self:Summon()
	else
		warn("can't find asset ", self)
	end
end

function MetaEnemy:Summon(position)
	position = position or PATHWAYS:FindFirstChild("0").Position

	if not self.Model then error("model not found") return end

	for _, part in ipairs(self.Model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end

	self.Model:PivotTo(CFrame.new(position) * CFrame.new(0, 5, 0))

end

function MetaEnemy:SetupHumanoid()
	
	if self.Model then
		
		local humanoid: Humanoid = self.Model:WaitForChild("Humanoid")
		if humanoid then
			
			humanoid.WalkSpeed = self.Statistics.Speed
			humanoid.Health = self.Statistics.MaxHealth
			humanoid.MaxHealth = self.Statistics.MaxHealth
			
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			
			self.Humanoid = humanoid
		end
	else
		warn("Setup model first!")
	end
end

function MetaEnemy:LoopAnimation()
	
	if not self.Model then error("model not found", 10) return end
	
	local hum: Humanoid = self.Model.Humanoid
	if hum then
		
		local controller: Animator = hum.Animator
		
		local animationID = self.Animations.Walk
		local anim: Animation  = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. animationID
		
		local loadedAnimation: AnimationTrack = controller:LoadAnimation(anim)
		loadedAnimation.Looped = true
		loadedAnimation:Play()
	end
end

function MetaEnemy:Setup()
	
	self:ReplicateFolder()
	self:SetupModel()
	self:SetupHumanoid()
	
	if table.find(self.Types, "Boss") then
		
		if not Enemy_System.Created[self.Name] then
			
			Networker.Fire("Bossfight_Create", {
				ID = self.ID,
			}, {"FA"})

		end
	end
	
	Enemy_System.InsertCreated(self.Name)
	
	if self.Animations["Walk"] then
		self:LoopAnimation()
	end
	self:StartWalking()
end

--------------------
--// AI WALKING //--
--------------------

function MetaEnemy:StartWalking()
	
	if PATHWAYS and self.Model then
		
		local hum: Humanoid = self.Model.Humanoid
		for index = 1, #PATHWAYS:GetChildren() - 1 do
			
			if not self.Can_Walk then break end
			
			local point = PATHWAYS:FindFirstChild(index)
			if not point then error("point not found", 10) return end
			
			self.Walk_Connections["Walking"] = hum:MoveTo(point.Position)
			hum.MoveToFinished:Wait()
			self.Walk_Connections["Walking"] = nil
			
			if index == #PATHWAYS:GetChildren() - 1 then
				--print("enemy reached ed")
				
				Networker.Fire("Bossfight_Destroy", {ID = self.ID}, {"FA"})
				
				Networker.Fire("Enemy_Damage_Game", self, {"BE"})
				self:Destroy()
			end
		end
	else
		error("pathways not found", 10)
	end
end

function MetaEnemy:StopWalking()
	
	if self.Walk_Connections["Walking"] then
		
		self.Can_Walk = false
		local hum = self.Model.Humanoid
		if not hum then error("humanoid not found", 10) return end
		
		hum.WalkSpeed = 0
		
		self.Walk_Connections["Walking"]:Disconnect()
		self.Can_Walk = true
		

		hum.WalkSpeed = self.Statistics.Speed
	end
end

-----------------------
--// DAMAGE SYSTEM //--
-----------------------

function MetaEnemy:Damage(plrID, damage: number)
	
	local stats = self.Statistics
	if stats.Health - damage <= 0 then
		damage = stats.Health
		
		self.Humanoid.Health = 0
		
		Networker.Fire("Bossfight_Destroy", {ID = self.ID}, {"FA"})
		
		self:Destroy()
	else
		stats.Health -= damage
		self.Humanoid.Health = stats.Health
	end
	
	Networker.Fire("Add_Currency", {
		Player = plrID,
		Currency = "Coins",
		Amount = damage / 2
	}, {"BE"})
	
	print("ENEMY SYSTEM | DAMAGED ENEMY ID ",self.ID)
	
	self:UpdateFolder()
end

---------------------
--// CONNECTIONS //--
---------------------

Networker.OnEvent("Damage_Enemy", {"BE"}, function(args)
	
	local plr = args.Player
	local enemyID = args.ID
	local dmg = math.round(args.Damage * 10) / 10
	if not plr or not enemyID then error("err") return end
	
	if Enemy_System.CheckIfExists(enemyID) == true then
		
		local enemyTable = Enemy_System.GetEnemyByID(enemyID)
		
		print("DAMAGING ENEMY: ", enemyID, dmg)
		enemyTable:Damage(plr, dmg)
	else
		warn("ENEMY DOESNT EXIST")
	end
end)

--// Testing //--

--local newEnemy = Enemy_System.NewEnemy("Normal", 15)

return Enemy_System	