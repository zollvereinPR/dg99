local Tower_Placement_System = {}

--// OOP //--

local MetaTower = {}
MetaTower.__index = MetaTower

--// Variables //--

local TOWERS_HOLDER = game.Workspace.TOWERS_HOLDER
local ITEM_DATA = require(game.ServerStorage.Data.Item_Data)
local TOWER_GROUP = "Tower"
local PROJECTILES_HOLDER = game.Workspace.PROJECTILES_HOLDER

--// Modules //--

local Networker = require(game.ReplicatedStorage.Network.Networker)
local Game_System = require(game.ServerStorage.Server.Modules.Game_System.Game_System_SERVER)
local Replicator = require(game.ReplicatedStorage.Shared.Packages.Replication_Package)
local misc = require(game.ReplicatedStorage.Shared.Packages.Misc_Package)
local Enemy_System = require(game.ServerStorage.Server.Modules.Enemy_System.Enemy_System_SERVER)
local ABILITIES = require(game.ServerStorage.Data.Ability_Data)
local COOLDOWN_HANDLER = require(game.ReplicatedStorage.Shared.Modules.Cooldown_System)
repeat
	task.wait()
until Game_System.CheckIfGameExists() == true

----------------
--// System //--
----------------

function Tower_Placement_System.GetHolder(plrID)
	--warn(Game_System)
	
	return Game_System.Game.Players[plrID]
end

function Tower_Placement_System.GetID(plrID, name)
	
	local plrHolder = Tower_Placement_System.GetHolder(plrID)
	if not plrHolder then warn("holder not initiated") return end
	
	--print(plrHolder)
	
	if not plrHolder.IDS[name] then
		
		plrHolder.IDS[name]= 0
	else
		plrHolder.IDS[name] += 1
	end
	
	return name..plrHolder.IDS[name]
end

function Tower_Placement_System.CheckIfTowerExists(plrID, towerID)
	
	local plrHolder = Tower_Placement_System.GetHolder(plrID)
	if not plrHolder then warn("holder not initiated") return end
	
	if not plrHolder.Towers[towerID] then	
		return false
	else
		return true
	end
end

function Tower_Placement_System.GetTower(plrID, towerID)

	local plrHolder = Tower_Placement_System.GetHolder(plrID)
	if not plrHolder then warn("holder not initiated") return end

	return plrHolder.Towers[towerID]
end

function Tower_Placement_System.CheckIfCanPlaceRAYCAST(pos, name)
	
	pos = Vector3.new(pos.X, pos.Y, pos.Z)
	
	local defData = ITEM_DATA[name]
	local direction = Vector3.new(0, -3, 0)
	local rayresult: RaycastResult = game.Workspace:Raycast(pos, direction)
	if rayresult then
		
		if rayresult.Instance then
			
			for _, acceptedType in pairs(defData.Types) do
				
				if rayresult.Instance.CollisionGroup == acceptedType then
					return true
				end
			end
		end
	end
	
	warn("couldnt place raycast")
	
	return false
end

function Tower_Placement_System.CheckIfInBounds(pos, model)
	
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {TOWERS_HOLDER}
	
	
	local getInBounds: {BasePart} = game.Workspace:GetPartsInPart(model, params)
	--print(getInBounds)
	if #getInBounds > 0 then
		--warn("not in bounds")
		return false
	else
		--print(getInBounds)
		return true
	end
end

function Tower_Placement_System.CheckIfCanPlace(pos, name, model)
	
	if Tower_Placement_System.CheckIfCanPlaceRAYCAST(pos, name) == false then return false end
	if Tower_Placement_System.CheckIfInBounds(pos, model) == false then return false end
	
	return true
end

function Tower_Placement_System.CheckIfEnoughMoney(plrID, name)
	
	local cost = ITEM_DATA[name].Cost
	local plrCurrency = Networker.Fire("Get_Currency", {
		Player = plrID,
		Currency = "Coins"
	}, {"BF"})
	
	if plrCurrency[1] >= cost then
		
		return true
	end
	
	return false
end

function Tower_Placement_System.GetModel(towerName, level)
	
	local data = ITEM_DATA[towerName]
	local model = data.Parent:FindFirstChild(level or 1)
	return model
end

function Tower_Placement_System.NewTower(plrID, towerName, position)
	
	local plrHolder = Tower_Placement_System.GetHolder(plrID)
	if not plrHolder then warn("holder not initiated") return false end
	
	local towerData = ITEM_DATA[towerName]
	if not towerData then warn("towerData not found") return false end
	
	local model = Tower_Placement_System.GetModel(towerName)
	if not model then warn("model not found") return false end
	
	local ID = Tower_Placement_System.GetID(plrID, towerName)
	
	if Tower_Placement_System.CheckIfTowerExists(plrID, ID) == false then
		
		
		if Tower_Placement_System.CheckIfCanPlace(position, towerName, model.Hitbox) == false then warn("not able to place") return end
		if Tower_Placement_System.CheckIfEnoughMoney(plrID, towerName) == false then warn("not enough money") return end
		
		Networker.Fire("Remove_Currency", {
			Player = plrID,
			Currency = "Coins",
			Amount = towerData.Cost
		}, {"BE"})
		
		local self = {
			ID = ID,
			Player = plrID,
			Name = towerName,
			Position = position,
			Data = towerData,
			Level = 1
		}
		
		warn(position, "POSITION 1")
		
		setmetatable(self, MetaTower)
		
		plrHolder.Towers[ID] = self
		
		self:SetupFolder()
		self:Setup()
		self:CreateProjectile()
		self:SetupLoop()
	
		
		--self:Upgrade()
		
		return true
	end
	
	return false
end

---------------------
--// TOWER CLASS //--
---------------------

function MetaTower:SetupFolder()
	
	if not TOWERS_HOLDER:FindFirstChild(self.Player) then
		
		local folder = Instance.new("Folder")
		folder.Name = self.Player
		folder.Parent = TOWERS_HOLDER
	end
	
	local s = os.clock()
	
	if not self.Folder then
		
		local folder = Instance.new("Folder")
		folder.Name = self.ID
		folder.Parent = TOWERS_HOLDER:FindFirstChild(self.Player)
		
		self.Folder = folder
	end
	
	Replicator.ReplicateTable(self, self.Folder, true)
end

function MetaTower:Setup()
	
	local model: Model = Tower_Placement_System.GetModel(self.Name, self.Level)
	if not model then warn("model not found") return false end
	if not model.PrimaryPart then warn("primaery part not set") return false end
	
	local clone = model:Clone()
	self.Model = clone
	
	clone.Parent = self.Folder
	clone.Name = "Model"
	clone:PivotTo(self.Position)
	
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.Parent = self.Model.Bottom
	highlight.FillTransparency = 0.3
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	
	self.Model.Bottom.Transparency = 0
	
	for _, obj: BasePart in pairs(clone:GetDescendants()) do
		
		if obj:IsA("BasePart") then
			
			obj.CollisionGroup = TOWER_GROUP
		end
	end
	
	--print(clone.Hitbox.Position, self.Position)
end

function MetaTower:Destroy()
	
	self:DestroyModel()
	local holder = Tower_Placement_System.GetHolder(self.Player)
	if holder then
		
		if holder[self.ID] then
			
			holder[self.ID] = nil
		end
	end
end

function MetaTower:DestroyModel()
	
	self.Model:Destroy()
end

function MetaTower:UpdateReplication()
	if not self.Folder then error("folder not found") end
	
	Replicator.Update(self, self.Folder, true)
end

function MetaTower:CheckIfCanUpgrade(levelData)
	
	local price = levelData.Price
	local currencyPlr = Networker.Fire("Get_Currency", {
		Currency = "Coins",
		Player = self.Player
	}, {"BF"})
	warn(currencyPlr)
	
	if not currencyPlr[1] then warn("not found") return false end
	
	if currencyPlr[1] >= price then
		
		return true
	end
	
	return false
end

function MetaTower:GetStats()
	
	local level = self.Level
	local data = self.Data
	if data.Statistics[level] then
		
		return data.Statistics[level]
	end
	
	warn("stats not found")
end

function MetaTower:Upgrade(level)
	
	level = level or self.Level + 1
	
	local data = self.Data
	if data.Statistics[level] then
		
		if self:CheckIfCanUpgrade(data.Statistics[level]) == false then
			
			Networker.Fire("New_Notification", {
				ID = "error_money",
				Content = "Not enough money to upgrade tower!",
				Extradata = {
					Fade = 4,
					New = true,
					Sound = game.SoundService.wrong,
					Icon = "rbxassetid://135759921485971"
				},
				Player = self.Player
			}, {"RE"})
			
			error("not enough money") return
		end
		
		self.Level = level
		
		Networker.Fire("Remove_Currency", {
			Currency = "Coins",
			Player = self.Player,
			Amount = data.Statistics[level].Price
		}, {"BE"})
		
		Networker.Fire("New_Notification", {
			ID = self.ID,
			Content = "Successfully upgraded tower "..self.Name,
			Extradata = {
				Fade = 4,
				New = false,
				Icon = "rbxassetid://70717560560459",
				Sound = game.SoundService.wrong
			},
			Player = self.Player
		}, {"RE"})
		
		print("TOWER SYSTEM | UPGRADED TOWER ", self.ID,  " TO ", self.Level)
		
		self:DestroyModel()
		self:Setup()
		
		self:UpdateReplication()
		
	else
		warn("level not found")
		return 
	end
end

function MetaTower:GetSellValue()
	
	local data = self.Data
	local level = self.Level
	local sum = 0
	for i = level, 1, -1 do
		
		if data.Statistics[i] then
			
			print(data.Statistics[i].Price)
			
			sum += data.Statistics[i].Price / 2
		end
		
	end
	return sum
end

function MetaTower:Sell()
	
	local val = self:GetSellValue()
	if val > 0 then
		
		Networker.Fire("Add_Currency", {
			Player = self.Player,
			Amount = val,
			Currency = "Coins"
		}, {"BE"})
		
		self:Destroy()
	else
		warn("invalid val")
	end
end

-------------------------
--// ENEMY DETECTION //--
-------------------------

function MetaTower:DetectNearestEnemy()
	local primaryPos = self.Model.PrimaryPart.Position
	local stats = self:GetStats()
	
	local list = {}
	local data = {}
	--print(Enemy_System.Enemies)
	for id, enemyData in pairs(Enemy_System.Enemies) do
		--
		--warn(enemyData)
		if enemyData.Model then
			
			--print("md")
			
			local distance = (enemyData.Model.PrimaryPart.Position - primaryPos).Magnitude
			--warn(distance)
			if distance <= stats.Range then
				--warn("inm range")
				table.insert(list, id)
				
				data[id] = distance
			end
		end
	end
	
	--warn(list)
	
	if #list > 0 then
		
		table.sort(list, function(a, b)
			return data[a] < data[b]
		end)
		
		return list[1], list, data[list[1]]
	else
		return nil
	end
end

function MetaTower:CheckIfCorrectType(enemyData)
	
	local towerTypes = self.Data.Types
	for _, typecheck in pairs(towerTypes) do
		
		if table.find(enemyData.Types, typecheck) then
			
			return true
		end
	end
	
	return false
end

function MetaTower:Shoot()
	
	local stats = self:GetStats()
	local enemy = self:DetectNearestEnemy()
	--warn(enemy)
	if enemy then
		
		local enemyData, completeList, distance = Enemy_System.GetEnemyByID(enemy)
		if self:CheckIfCorrectType(enemyData) then
			
			local defense = enemyData.Statistics.Defense
			local newdmg = stats.Damage * (1 - defense / 100)
			
			Networker.Fire("Damage_Enemy", {
				Player = self.Player,
				ID = enemy,
				Damage = newdmg,
				Position = enemyData.Model.PrimaryPart.Position,
			}, {"BE", "RE"})
			
			self:FireProjectile(enemyData.Model.PrimaryPart.Position, distance)
		else
			warn("cannot attack due to types being mismatched")
		end
	else
		--warn("enemy not detected")
	end
end

function MetaTower:SetupLoop()
	
	local s = os.clock()
	local elapsed = 0
	repeat
		elapsed = os.clock() - s
		task.wait()
	until elapsed >= self:GetStats().Cooldown
	
	self:Shoot()
	
	self:SetupLoop()
end

--------------------
--// PROJECTILE //--
--------------------

function MetaTower:CreateProjectile()
	
	if not PROJECTILES_HOLDER:FindFirstChild(self.ID) then
		
		local inst = Instance.new("Part")
		inst.Color = Color3.fromRGB(243, 255, 20)
		inst.Parent = PROJECTILES_HOLDER
		inst.Anchored = true
		inst.Massless = true
		inst.CanCollide = false
		
		self.Projectile = inst
	end
end

function MetaTower:FireProjectile(arrival)
	
	
	if not self.Model then return end

	local start = self.Model.Projectile_Start.Position
	local distance = (arrival - start).Magnitude

	local projectile = self.Projectile
	projectile.Transparency = 0.5

	projectile.Size = Vector3.new(0.2,0.2, distance)

	local position = start + (arrival - start) / 2

	projectile.CFrame = CFrame.lookAt(position, arrival)
	projectile.Parent = PROJECTILES_HOLDER
	
	task.delay(self:GetStats().Cooldown / 2,  function()
		projectile.Transparency = 1
	end)
end

function MetaTower:CallAbility()
	
	warn("callin ability")
	
	if not self.Data.Ability then warn("ab not found") return end
	
	local ability = ABILITIES[self.Name]
	if COOLDOWN_HANDLER.CheckCooldown(self.Player..self.ID.."Ability", ability.Countdown) == true then
		
		ability.Function(self)
	end
end

---------------------
--// CONNECTIONS //--
---------------------

Networker.OnEvent("Place_Hologram", {"RF"}, function(plr, args)

	return Tower_Placement_System.NewTower(plr.UserId, args.Data.Name, args.Position)
end)

Networker.OnEvent("Tower_Manager", {"RE"}, function(plr, args)
	
	local towerID = args.ID
	local towerData = Tower_Placement_System.GetTower(plr.UserId, towerID)
	
	if not towerData then error() end

	if args.Type == "Upgrade" then
		towerData:Upgrade()
	elseif args.Type == "Sell" then
		
		towerData:Sell()
	elseif args.Type == "Ability" then
		
		towerData:CallAbility()
	end
end)


return Tower_Placement_System