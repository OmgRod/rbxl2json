local json = require("lib.dkjson") -- Using dkjson library

-- Function to read bytes from the file
local function readBytes(file, numBytes)
    local bytes = file:read(numBytes)
    return bytes or ""
end

-- Function to output a hex dump of data
local function hexDump(data)
    local hex = ""
    for i = 1, #data do
        hex = hex .. string.format("%02X ", string.byte(data, i))
        if i % 16 == 0 then
            print(hex)
            hex = ""
        end
    end
    if #hex > 0 then
        print(hex) -- Output any remaining bytes
    end
end

-- Function to read the next chunk from the .rbxl file
local function readNextChunk(file)
    local sizeBytes = readBytes(file, 4)
    if #sizeBytes < 4 then return nil, "End of file or error reading size" end

    local size = 0
    for i = 1, 4 do
        size = size + (string.byte(sizeBytes, i) * (2 ^ ((i - 1) * 8)))
    end

    local chunkType = readBytes(file, 4)
    if #chunkType < 4 then return nil, "End of file or error reading chunk type" end

    local chunkData = readBytes(file, size)

    -- Debugging output for chunkType
    print("Chunk type raw bytes: " .. chunkType:sub(1, 4))
    print("Chunk type (bytes):")
    for i = 1, #chunkType do
        io.write(string.format("%02X ", string.byte(chunkType, i)))
    end
    print("\nChunk size: " .. size)

    -- Convert chunkType to a readable string
    local readableChunkType = ""
    for i = 1, #chunkType do
        local byte = string.byte(chunkType, i)
        if byte >= 32 and byte <= 126 then  -- Check for printable characters
            readableChunkType = readableChunkType .. string.char(byte)
        else
            readableChunkType = readableChunkType .. "."
        end
    end

    -- Print hex representation of chunk type
    print("Chunk type in hex: ")
    hexDump(chunkType)

    return readableChunkType, chunkData, size
end

-- Function to recursively convert Roblox instances to a table format
local function convertInstance(instance)
    local result = {}

    for property, value in pairs(instance:GetProperties()) do
        result[property] = value
    end

    local children = {}
    for _, child in ipairs(instance:GetChildren()) do
        table.insert(children, convertInstance(child))
    end
    result["Children"] = children

    return result
end

-- Function to decompile the .rbxl file
local function decompileRbxl(filePath)
    local file = assert(io.open(filePath, "rb"))

    local header = file:read(8)  -- Read the header
    if header ~= "<roblox!" then
        error("Invalid RBXL header: " .. header)
    end
    print("Header read: " .. header)

    local data = {}

    while true do
        local chunkType, chunkData, chunkSize = readNextChunk(file)

        if not chunkType then
            break -- End of file
        end

        print("Read chunk type: " .. chunkType)

        -- Check if the chunk type is valid
        if chunkType == "[PROP]" then
            local properties = readPropertiesChunk(chunkData) -- Implement this function based on your needs
            table.insert(data, properties)
        elseif chunkType == "[INST]" then
            local instances = readInstancesChunk(chunkData) -- Implement this function based on your needs
            table.insert(data, instances)
        elseif chunkType == "[PARN]" then
            local parents = readParentsChunk(chunkData) -- Implement this function based on your needs
            table.insert(data, parents)
        elseif chunkType == "[END]" then
            break -- End chunk
        else
            print("Unknown chunk type encountered: " .. chunkType)
            print("Chunk size: " .. chunkSize)

            -- Investigate chunkData
            print("Chunk data size: " .. #chunkData)
            print("Chunk data preview: " .. chunkData:sub(1, 128)) -- Increased preview size

            -- Hex dump of the chunk data
            print("Chunk data hex dump:")
            hexDump(chunkData)

            print("Continuing despite unknown chunk type...")
        end
    end

    file:close()

    if #data > 0 then
        local rootInstance = data[1]
        local gameTable = convertInstance(rootInstance)

        local jsonOutput, pos, err = json.encode(gameTable, {indent = true})

        if err then
            error("Failed to encode JSON: " .. err)
        end

        local jsonFilePath = filePath:gsub(".rbxl$", ".json")
        local jsonFile = io.open(jsonFilePath, "w")
        if jsonFile then
            jsonFile:write(jsonOutput)
            jsonFile:close()
            print("Decompiled to " .. jsonFilePath)
        else
            error("Failed to write JSON file")
        end
    else
        print("No data found in .rbxl file.")
    end
end

-- Main CLI logic
local args = {...}
if #args ~= 1 then
    print("Usage: lua main.lua <game.rbxl>")
else
    local filePath = args[1]
    decompileRbxl(filePath)
end
