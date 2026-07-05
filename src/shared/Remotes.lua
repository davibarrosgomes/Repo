--[[
	Remotes.lua
	Creates (on the server) and fetches (on either side) the RemoteEvents
	used by the combat system.

	UseSkill     client -> server : (slot: number 1-4)
	M1           client -> server : ()
	ActivateUlt  client -> server : ()
	Dash             client -> server : ()
	Block            client -> server : (enabled: boolean)
	SelectCharacter  client -> server : (characterId: string)
	VFX          server -> client : (effectName: string, data: table)
	HUDUpdate    server -> client : (kind: string, ...)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "UseSkill", "M1", "ActivateUlt", "Dash", "Block", "SelectCharacter", "VFX", "HUDUpdate" }

local Remotes = {}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		for _, name in NAMES do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

function Remotes.get(name)
	-- Time out instead of yielding forever, so a stale/mismatched Remotes
	-- module surfaces as a clear error instead of a silent hang (which would
	-- stall the map build on the server and the UI on the client).
	local remote = folder:WaitForChild(name, 10)
	if not remote then
		error(
			("Remotes.get: RemoteEvent %q was not found. Make sure the Remotes "
				.. "module is updated to the latest version on BOTH server and client."):format(name),
			2
		)
	end
	return remote
end

return Remotes
