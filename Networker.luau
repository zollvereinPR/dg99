--[[
	Made by:
	
		Discord: zollverein.
		Roblox: Admin0408,
		Github: zollvereinPR
		
	Disclaimer:
		
		The game provided (16+ players only) in the link ALWAYS uses this networking module, and it amounts to over 50 events. 
		If needed, i can link other code in THIS repository/game that uses it. But for proof, literally the
		whole game is built around this.
		Other example linked here: 
			https://github.com/zollvereinPR/dg99/blob/main/Enemy_System_SERVER.luau,
			https://github.com/zollvereinPR/dg99/blob/main/Tower_Placement_SERVER.luau
		
	Short Description:
	
		This module is a dynamically-created networker, as you can create your remotes with 1 line, and if it doesn't exist;,
		it's created automatically and then fired. This supports multiple :Fires, 1 single event can use up to all of them at once (Remote Function, Remote Event, etc).
		If needed, you can also create remotes from the client, but it's not recommended. This works for both client and server as the "state" describes the current
		place of runtime.
		
--]]

local Networker = {}

--// Services //--

local RS = game:GetService("RunService")

--// Variables //--

local REMOTES_HOLDER = game.ReplicatedStorage.Network.Remotes
local REMOTE_CREATOR_CLIENT = script.Parent.CreateRemoteByClient
local CLIENT_CAN_CREATE_REMOTES = true

Networker.Events = {}
Networker.Types = {
	RF = "RemoteFunction",
	RE = "RemoteEvent",
	FA = "RemoteEvent",
	BE = "BindableEvent",
	RECEIVED = "RemoteEvent",
	BF = "BindableFunction"
} --// Acronyms, crucial

----------------
--// System //--
----------------

--// INITIALIZER //--

if RS:IsServer() then
	REMOTE_CREATOR_CLIENT.OnServerEvent:Connect(function(plr, eventID)
		
		if not CLIENT_CAN_CREATE_REMOTES then return end
		
		Networker.NewEvent(tostring(eventID))
	end)
end

function Networker.GetEvent(eventID)
	
	local state = Networker.GetState(eventID)
	if state == "server" then
		return Networker.Events[eventID]
	else
		return {
			Folder = REMOTES_HOLDER:FindFirstChild(eventID),
			ID = eventID
		}
	end
	
end

function Networker.CheckIfExists(eventID: string)
	local state = Networker.GetState(eventID)
	if state == "server" then
		if Networker.Events[eventID] then return true end
		
		return false
	else
		if REMOTES_HOLDER:FindFirstChild(eventID) then return true end
		
		return false
	end
end

function Networker.NewEvent(eventID: string)
	local state = Networker.GetState()
	if state == "server" then
		
		if Networker.CheckIfExists(eventID) == false then
			
			Networker.Events[eventID] = {
				ID = eventID,
				last_fired = os.clock(),
			}
			Networker.Replicate(eventID)
		end
	else
		REMOTE_CREATOR_CLIENT:FireServer(eventID)
	end
end

function Networker.Replicate(eventID) --// makes sure you can use each remote type witb 1 ID.
	if Networker.CheckIfExists(eventID) == true then
		
		local event = Networker.Events[eventID]

		local folder = Instance.new("Folder")
		folder.Name = eventID
		folder.Parent = REMOTES_HOLDER
		event.Folder = folder

		for name, typeofevent in pairs(Networker.Types) do
			
			local newInstance = Instance.new(typeofevent)
			newInstance.Name = name
			newInstance.Parent = folder
		end
	end
end

function Networker.GetState() --// used to determine whether the script is being run from the server or client.
	if RS:IsServer() then
		return "server"
	else
		return "client"
	end
end

-----------------
--// FIRE TO //--
----------------- 
function Networker.FireToClient(eventID, args, towho)
	if typeof(args.Player) == "string" then
		warn("DOESNT ACCEPT STRINGS")
		return
	end
	
	if not game.Players:GetPlayerByUserId(args.Player) then warn("Player not inserted", eventID) return end
	local state = Networker.GetState()
	if state == "client" then return end

	local event = Networker.GetEvent(eventID)
	if not event then warn("event not found ", eventID) return end

	local plr = game.Players:GetPlayerByUserId(args.Player)

	for _, eventInstance: RemoteFunction in pairs(event.Folder:GetChildren()) do
		
		if table.find(towho, eventInstance.Name) then
			
			if eventInstance.Name == "RF" then
				
				return eventInstance:InvokeClient(plr, args)
				
			elseif eventInstance.Name == "RE" or eventInstance.Name == "RECEIVED" then
				
				eventInstance:FireClient(plr, args)
			end
		end
	end
end

function Networker.FireToAllClients(eventID, args)
	
	local state = Networker.GetState()
	if state == "client" then return end

	local event = Networker.GetEvent(eventID)
	if event then
		
		local remote: RemoteEvent = event.Folder.FA
		remote:FireAllClients(args)
	end
end

function Networker.FireToServer(eventID, args, towho)
	
	local state = Networker.GetState()
	if state == "server" then return end

	local event = REMOTES_HOLDER:FindFirstChild(eventID)
	if not event then warn("event not found ", eventID) return eventID end

	for _, eventInstance: RemoteFunction in pairs(event:GetChildren()) do
		
		if table.find(towho, eventInstance.Name) then
			
			if eventInstance.Name == "RF" then
	
				return eventInstance:InvokeServer(args)
			elseif eventInstance.Name == "RE" or eventInstance.Name == "RECEIVED" then
				eventInstance:FireServer(args)
				return
			end
		end
	end
end

function Networker.FireBindableFunction(eventID, args)

	local event = Networker.GetEvent(eventID)
	if not event then warn("event not found ", eventID) return eventID end

	local eventInstance: BindableFunction = event.Folder:FindFirstChild("BF")

	if eventInstance then
		
		return eventInstance:Invoke(args)
	end
end

function Networker.FireBindable(eventID, args)
	
	local event = Networker.GetEvent(eventID)
	if not event then warn("event not found ", eventID) return eventID end

	local eventInstance = event.Folder:FindFirstChild("BE")
	if eventInstance then

		eventInstance:Fire(args)
	end
end

function Networker.Fire(eventID, args, towho) --// the default method to fire, automatically checks each previous function
	local state = Networker.GetState()
	if Networker.CheckIfExists(eventID) == false then
		Networker.NewEvent(eventID)
		
		
		repeat task.wait() until Networker.CheckIfExists(eventID) == true
	end

	local allowedCalls = Networker.Allowed[state]
	local returnedData = {}
	if towho == nil then
		warn(eventID, " NOT INSERTED TOWHO ARGUMENT")
	end

	for _, eventAlias in pairs(towho) do
		if allowedCalls[eventAlias] then

			if eventAlias == "RF" or eventAlias == "BF" then
				local data = allowedCalls[eventAlias](eventID, args, towho)
				table.insert(returnedData, data)
			else

				allowedCalls[eventAlias](eventID, args, towho)
			end
		end
	end

	return returnedData
end

-------------------
--// ON EVENTS //--
-------------------

function Networker.OnClientEvent(eventID, callback, bywho)
	local state = Networker.GetState()
	if state == "server" then return end

	local event = REMOTES_HOLDER:FindFirstChild(eventID) or REMOTES_HOLDER:FindFirstChild(tostring(eventID))

	if event then
		for _, eventInstance: RemoteFunction in pairs(event:GetChildren()) do
			
			if table.find(bywho, eventInstance.Name) then
				
				if eventInstance.Name == "RE" or eventInstance.Name == "RECEIVED" or eventInstance.Name == "FA" then
					--print("binding to client", eventID)
					
					eventInstance.OnClientEvent:Connect(function(args)
						
						--warn(args)

						callback(args)
					end)
				elseif eventInstance.Name == "RF" then
					
					eventInstance.OnClientInvoke = function(args)
					
						return callback(args)
					end
				end
			end
		end
	else
		warn("event not found")
	end
end

function Networker.OnServerEvent(eventID, callback, bywho)
	local state = Networker.GetState()
	if state == "client" then return end

	local event = Networker.GetEvent(eventID)
	if event then
		for _, eventInstance: RemoteEvent in pairs(event.Folder:GetChildren()) do
			
			if table.find(bywho, eventInstance.Name) then
				
				if eventInstance.Name == "RE" or eventInstance.Name == "RECEIVED" then
					
					eventInstance.OnServerEvent:Connect(function(plr, args)
						callback(plr, args)
					end)
				elseif eventInstance.Name == "RF" then
					
					eventInstance.OnServerInvoke = function(plr, args)

						return callback(plr, args) 
					end
				end
			end
		end
	end


end

function Networker.OnBindableEvent(eventID, callback)

	local event = Networker.GetEvent(eventID)
	if event then
		
		local BE: BindableEvent = event.Folder.BE
		BE.Event:Connect(function(args)
			local d = callback(args)
			--print(d)
			return d
		end)
	end
end

function Networker.OnBindableFunction(eventID, callback)
	
	local data = {}
	local event = Networker.GetEvent(eventID)
	if event then
		
		local BF: BindableFunction = event.Folder.BF
		BF.OnInvoke = function(args)
	
			--print("invoked")
			local d = callback(args)
			--warn(d)
			return d
		end
	end
	
end

function Networker.OnResponse(eventID, callback)
	
	local state = Networker.GetState()
	local allowedResponses = Networker.AllowedResponses[state]

	if allowedResponses["RECEIVED"] then
		
		return allowedResponses["RECEIVED"](eventID, callback, {"RECEIVED"})
	end
end

function Networker.OnEvent(eventID, bywho, callback) --// DEFAULT method to bind to events, automatically checks previous functions and types.
	
	local state = Networker.GetState()
	if Networker.CheckIfExists(eventID) == false then
		Networker.NewEvent(eventID)

		repeat
			task.wait()
		until Networker.CheckIfExists(eventID) == true
	end

	local allowedCalls = Networker.AllowedResponses[state]
	for _, eventAlias in pairs(bywho) do
		
		if allowedCalls[eventAlias] then
			
			allowedCalls[eventAlias](eventID, callback, bywho)
		end
	end
end

Networker.Allowed = {
	client = {
		RE = Networker.FireToServer,
		RF = Networker.FireToServer,
		RECEIVED = Networker.FireToServer,
		BE = Networker.FireBindable,
		BF = Networker.FireBindableFunction,
	},
	server = {
		RE = Networker.FireToClient,
		BE = Networker.FireBindable,
		FA = Networker.FireToAllClients,
		RF = Networker.FireToClient,
		RECEIVED = Networker.FireToClient,
		BF = Networker.FireBindableFunction,
	}
}

Networker.AllowedResponses = {
	client = {
		BE = Networker.OnBindableEvent,
		RE = Networker.OnClientEvent,
		RF = Networker.OnClientEvent,
		RECEIVED = Networker.OnClientEvent,
		BF = Networker.OnBindableFunction,
		FA = Networker.OnClientEvent
	},
	server = {
		RE = Networker.OnServerEvent,
		RF = Networker.OnServerEvent,
		RECEIVED = Networker.OnServerEvent,
		BE = Networker.OnBindableEvent,
		BF = Networker.OnBindableFunction
	}
}

return Networker
