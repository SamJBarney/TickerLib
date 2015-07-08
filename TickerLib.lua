E_BLOCK_ANY = -1
E_META_ANY = -1

local CHUNK_WIDTH = 16
local CHUNK_HEIGHT = 256

local TickRegistry = {}
local ChunkRegistry = {}

local issetup = false

function TickerSetup()
	if not issetup then
		cPluginManager.AddHook(cPluginManager.HOOK_WORLD_TICK, OnWorldTick)
		cPluginManager.AddHook(cPluginManager.HOOK_CHUNK_AVAILABLE, OnChunkAvailable)
		cPluginManager.AddHook(cPluginManager.HOOK_CHUNK_UNLOADING, OnChunkUnloading)
		issetup = true
	end
end

function RegisterTickerCallback(WorldName, BlockId, BlockMeta, a_Callback)
	if TickRegistry[WorldName] == nil then
		TickRegistry[WorldName] = {}
		TickRegistry[WorldName][BlockId] = {}
		TickRegistry[WorldName][BlockId][BlockMeta] = {}
	end
	if TickRegistry[WorldName][BlockId] == nil then
		TickRegistry[WorldName][BlockId] = {}
		TickRegistry[WorldName][BlockId][BlockMeta] = {}
	end

	if TickRegistry[WorldName][BlockId][BlockMeta] == nil then
		TickRegistry[WorldName][BlockId][BlockMeta] = {}
	end

	-- local already_exists = false
	-- for i,callback in ipairs(TickRegistry[WorldName][BlockId][BlockMeta]) do
	-- 	if callback.theCallback == a_Callback then
	-- 		already_exists = true
	-- 		break
	-- 	end
	-- end

	if a_Callback ~= nil then
		table.insert(TickRegistry[WorldName][BlockId][BlockMeta], {theCallback = a_Callback, remove = false})
		return true
	end
	return false
end

function UnregisterTickerCallback(WorldName, BlockId, BlockMeta, a_Callback)
	if TickRegistry[WorldName] == nil or TickRegistry[WorldName][BlockId] == nil or TickRegistry[WorldName][BlockId][BlockMeta] == nil then
		return false
	end

	for i,callback in ipairs(TickRegistry[WorldName][BlockId][BlockMeta]) do
		if callback.theCallback == a_Callback then
			callback.remove = true
			return true
		end
	end

	return false
end

function OnChunkAvailable(World, ChunkX, ChunkZ)
	local WorldName = World:GetName()
	if ChunkRegistry[WorldName] == nil then
		ChunkRegistry[WorldName] = {}
	end
	ChunkRegistry[WorldName][ChunkX .. "," .. ChunkZ] = {x=ChunkX, z=ChunkZ, TickX=0, TickY=0, TickZ=0}

end


function OnChunkUnloading(World, ChunkX, ChunkZ)
	local WorldName = World:GetName()

	if (ChunkRegistry[WorldName]) then
		ChunkRegistry[WorldName][ChunkX .. "," .. ChunkZ] = nil
	end
end


function OnWorldTick(World, TimeDelta)
	local WorldName = World:GetName()
	if TickRegistry[WorldName] ~= nil and ChunkRegistry[WorldName] ~= nil then
		for _, chunk in pairs(ChunkRegistry[WorldName]) do
			TickChunk(World, TimeDelta, chunk)
		end
	end
end


function TickChunk(World, TimeDelta, a_Chunk)
	-- Only tick the chunk if all of its neighbors are loaded (to avoid force-loading the neighbors):
	local ChunkReg = ChunkRegistry[World:GetName()] or {}
	if (
		not(ChunkReg[(a_Chunk.x - 1) .. "," .. (a_Chunk.z + 1)]) or
		not(ChunkReg[(a_Chunk.x - 1) .. "," .. a_Chunk.z]) or
		not(ChunkReg[(a_Chunk.x - 1) .. "," .. (a_Chunk.z - 1)]) or
		not(ChunkReg[a_Chunk.x       .. "," .. (a_Chunk.z + 1)]) or
		not(ChunkReg[a_Chunk.x       .. "," .. (a_Chunk.z - 1)]) or
		not(ChunkReg[(a_Chunk.x + 1) .. "," .. (a_Chunk.z + 1)]) or
		not(ChunkReg[(a_Chunk.x + 1) .. "," .. a_Chunk.z]) or
		not(ChunkReg[(a_Chunk.x + 1) .. "," .. (a_Chunk.z - 1)])
	) then
		return
	end
	
	local RandomX = math.random(0,16777215)
	local RandomY = math.random(0,16777215)
	local RandomZ = math.random(0,16777215)

	local TickX = a_Chunk.TickX
	local TickY = a_Chunk.TickY
	local TickZ = a_Chunk.TickZ

	for i=0,50 do
		TickX = (TickX + RandomX) % (CHUNK_WIDTH * 2)
		TickY = (TickY + RandomY) % (CHUNK_HEIGHT * 2)
		TickZ = (TickZ + RandomZ) % (CHUNK_WIDTH * 2)
		a_Chunk.TickX = math.floor(TickX / 2)
		a_Chunk.TickY = math.floor(TickY / 2)
		a_Chunk.TickZ = math.floor(TickZ / 2)
	end

	TickX = a_Chunk.TickX + a_Chunk.x * CHUNK_WIDTH
	TickZ = a_Chunk.TickZ + a_Chunk.z * CHUNK_WIDTH
	TickY = a_Chunk.TickY

	local Valid, BlockType, BlockMeta, SkyLight, BlockLight = World:GetBlockInfo(TickX, TickY, TickZ)

	local WorldName = World:GetName()

	if TickRegistry[WorldName][BlockType] ~= nil then
		if TickRegistry[WorldName][BlockType][BlockMeta] ~= nil then
			for i,callback in ipairs(TickRegistry[WorldName][BlockType][BlockMeta]) do
				if callback.remove ~= true then
					if callback.theCallback(World, TickX, TickY, TickZ, BlockType, BlockMeta, SkyLight, BlockLight) then
						break
					end
				else
					TickRegistry[WorldName][BlockType][BlockMeta][i] = nil
				end
			end
		end

		if TickRegistry[WorldName][BlockType][E_META_ANY] ~= nil then
			for i,callback in ipairs(TickRegistry[WorldName][BlockType][E_META_ANY]) do
				if callback.remove ~= true then
					if callback.theCallback(World, TickX, TickY, TickZ, BlockType, BlockMeta, SkyLight, BlockLight) then
						break
					end
				else
					TickRegistry[WorldName][BlockType][E_META_ANY][i] = nil
				end
			end
		end
	end

	Valid, BlockType, BlockMeta, SkyLight, BlockLight = World:GetBlockInfo(TickX, TickY, TickZ)

	if TickRegistry[WorldName][E_BLOCK_ANY] ~= nil and TickRegistry[WorldName][E_BLOCK_ANY][E_META_ANY] ~= nil then
		for i,callback in ipairs(TickRegistry[WorldName][E_BLOCK_ANY][E_META_ANY]) do
			if callback.remove ~= true then
				if callback.theCallback(World, TickX, TickY, TickZ, BlockType, BlockMeta, SkyLight, BlockLight) then
					break
				end
			else
				TickRegistry[WorldName][E_BLOCK_ANY][E_META_ANY][i] = nil
			end
		end
	end
end