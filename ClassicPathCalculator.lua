print(123);

function getWorldMapPosition() 
    local zoneID = C_Map.GetBestMapForUnit("player")
    local mapPosition = C_Map.GetPlayerMapPosition(zoneID, "player")
    continentID, worldPosition = C_Map.GetWorldPosFromMapPos(zoneID, mapPosition)
        
    local worldMapID = -1
    if continentID == 1 then
        worldMapID = 1414
    else
        worldMapID = 1415
    end

    local worldMapPosition = C_Map.GetPlayerMapPosition(worldMapID, "player")
    return worldMapID, worldMapPosition
end

function getNameBeforeComma(fullString)
    local commaIndexStart, commaIndexEnd = string.find(fullString, ",")
    local name = ""
    if commaIndexStart ~= nil then
        name = string.sub(fullString, 1, commaIndexStart - 1)
    else
        name = fullString
    end
    return name
end

function getIndexedMapDataOnName(mapData)
    local newMapData = {}
    for k,v in pairs(mapData) do
        newMapData[getNameBeforeComma(v["desc"])] = v
    end
    return newMapData
end

function getChildPosFromParentPos(childMapID, parentMapID, parentMapPosition)
    if childMapID == parentMapID then 
        local x, y = parentMapPosition:GetXY()
        return x, y
    end
    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(childMapID, parentMapID)
    minX = minX * 100
    maxX = maxX * 100
    minY = minY * 100
    maxY = maxY * 100
    local xRatio = 100 / (maxX - minX)
    local yRatio = 100 / (maxY - minY)
    local posX, posY = parentMapPosition:GetXY()
    local newPosX = (posX - minX) * xRatio
    local newPosY = (posY - minY) * yRatio
    return newPosX, newPosY
end

function getParentPosFromChildPos(parentMapID, childMapID, childMapPosition)
    if parentMapID == childMapID then 
        local x, y = childMapPosition:GetXY()
        return x, y
    end
    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(childMapID, parentMapID)
    minX = minX * 100
    maxX = maxX * 100
    minY = minY * 100
    maxY = maxY * 100
    local posX, posY = childMapPosition:GetXY()
    local newPosX = minX + (maxX - minX) * posX / 100
    local newPosY = minY + (maxY - minY) * posY / 100
    return newPosX, newPosY
end

function getMapPosFromWorldPosForMap(mapID, worldMapID, worldMapPosition)
    local commonParentMapID = nil
    local mapParents = {}
    local worldMapParents = {}

    local current = mapID
    while current ~= 0 do
        local info = C_Map.GetMapInfo(current)
        if mapParents[current] == nil then mapParents[current] = {} end
        if mapParents[info.parentMapID] == nil then mapParents[info.parentMapID] = {} end
        mapParents[current].parent = info.parentMapID
        mapParents[info.parentMapID].child = current
        current = info.parentMapID
    end
    current = worldMapID
    local found = false
    while true do
        local info = C_Map.GetMapInfo(current)
        if worldMapParents[current] == nil then worldMapParents[current] = {} end
        if worldMapParents[info.parentMapID] == nil then worldMapParents[info.parentMapID] = {} end
        worldMapParents[current].parent = info.parentMapID
        worldMapParents[info.parentMapID].child = current
        for k,v in pairs(mapParents) do
            if k == current then
                found = true 
                break 
            end 
        end
        if found == true then break end
        current = info.parentMapID
    end
    commonParentMapID = current
    
    current = worldMapID
    local curX, curY = worldMapPosition:GetXY()
    while current ~= commonParentMapID do
        curX, curY = getParentPosFromChildPos(worldMapParents[current].parent, current, CreateVector2D(curX, curY))
        current = worldMapParents[current].parent
    end
    while current ~= mapID do
        curX, curY = getChildPosFromParentPos(mapParents[current].child, current, CreateVector2D(curX, curY))
        current = mapParents[current].child
    end
    return curX, curY
end

function getMapIDFromWorldPos(worldMapID, worldMapPosition)
    local subZonesInfo = C_Map.GetMapChildrenInfo(worldMapID)
    local posX, posY = worldMapPosition:GetXY()
    for k,v in pairs(subZonesInfo) do
        local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(v.mapID, worldMapID)
        if (posX >= minX and posX <= maxX) and (posY >= minY and posY <= maxY) then
            return v.mapID
        end
    end
    return nil
end

function getContinentMapIDFromMapPos(mapID, mapPosition)
    local x, y = mapPosition:GetXY()
    x, y = getMapPosFromWorldPosForMap(1415, mapID, CreateVector2D(x, y))
    if x < 0 then
        return 1414
    else
        return 1415
    end
end

function getContinentMapIDFromMapID(mapID)
    if mapID == 947 then return mapID end
    local parent = mapID
    while parent ~= 1414 and parent ~= 1415 do
        parent = C_Map.GetMapInfo(parent).parentMapID
    end
    return parent
end

function getPreciseMapData(mapID, completeFactionMapData)
    local newMapData = {}
    for id,l in pairs(completeFactionMapData) do
        if id ~= 1414 and id ~= 1415 and id ~= 947 then
            for k,v in pairs(l) do
                local posX = tonumber(v["x"])
                local posY = tonumber(v["y"])
                local newPosX, newPosY = getMapPosFromWorldPosForMap(mapID, id, CreateVector2D(posX, posY))
                local name = getNameBeforeComma(v["desc"])
                newMapData[name] = {}
                newMapData[name]["x"] = tostring(newPosX)
                newMapData[name]["y"] = tostring(newPosY)
                newMapData[name]["desc"] = v["desc"]
                newMapData[name]["faction"] = v["faction"]
                newMapData[name]["type"] = v["type"]
                newMapData[name]["mapID"] = id
            end 
        end
    end
    return newMapData
end

function getData(faction, mapID)
    local lengths = {}
    local mapData = {}
    if faction == "Horde" then
        mapData = ClassicTravelPoints.MapDataHorde
        lengths = InFlight.defaults.global["Horde"]
    elseif faction == "Alliance" then
        mapData = ClassicTravelPoints.MapDataAlliance
        lengths = InFlight.defaults.global["Alliance"]
    else
        lengths = InFlight.defaults.global
    end
    if mapData == nil then mapData = {} end
    local newMapData = getPreciseMapData(mapID, mapData)
    return lengths, newMapData
end

function addZLPData(ZLPData, locData, mapData)
    for fromID,toList in pairs(ZLPData) do
        for toID,v in pairs(toList) do
            local locName = C_Map.GetMapInfo(fromID).name .. "-" .. C_Map.GetMapInfo(toID).name
            
            local pos = CreateVector2D(v["x"], v["y"])
            local fromPosX, fromPosY = pos:GetXY()
            local toPosX, toPosY = getMapPosFromWorldPosForMap(toID, fromID, pos)
            local gPosX, gPosY = getMapPosFromWorldPosForMap(947, fromID, pos)
            

            if mapData[fromID] == nil then mapData[fromID] = {} end
            if mapData[toID] == nil then mapData[toID] = {} end
            locData[locName] =            {["type"] = v["type"], ["faction"] = v["faction"], ["x"] = gPosX, ["y"]    = gPosY,  ["desc"]   = locName}
            table.insert(mapData[fromID], {["type"] = v["type"], ["faction"] = v["faction"], ["x"] = fromPosX, ["y"] = fromPosY, ["desc"] = locName})
            table.insert(mapData[toID],   {["type"] = v["type"], ["faction"] = v["faction"], ["x"] = toPosX, ["y"]   = toPosY, ["desc"]   = locName})
        end
    end
end

YARDS_PER_PIXEL_KALIMDOR = 333.33
YARDS_PER_PIXEL_EASTERN = 395.00
NORMAL_PLAYER_SPEED = 8
function getYardsPerPixelForMap(mapID)
    if mapID == 1414 then
        return YARDS_PER_PIXEL_KALIMDOR
    elseif mapID == 1415 then
        return YARDS_PER_PIXEL_EASTERN
    else
        return 300
    end
end


function initDistData(mapData, lengths)
    for mapID,locList in pairs(mapData) do
        if mapID ~= 1414 and mapID ~= 1415 and mapID ~= 947 then 
            local continentID = getContinentMapIDFromMapID(mapID)
            for _,loc1 in pairs(locList) do
                local x1, y1 = getMapPosFromWorldPosForMap(continentID, mapID, CreateVector2D(loc1["x"], loc1["y"]))
                local name1 = getNameBeforeComma(loc1["desc"])
                
                for _,loc2 in pairs(locList) do
                    if loc1 ~= loc2 then
                        local x2, y2 = getMapPosFromWorldPosForMap(continentID, mapID, CreateVector2D(loc2["x"], loc2["y"]))
                        local name2 = getNameBeforeComma(loc2["desc"])

                        local dxTime = math.abs(x2 - x1) * getYardsPerPixelForMap(continentID) / NORMAL_PLAYER_SPEED
                        local dyTime = math.abs(y2 - y1) * getYardsPerPixelForMap(continentID) / NORMAL_PLAYER_SPEED
                        local timeDistance = math.sqrt(math.pow(dxTime, 2) + math.pow(dyTime, 2))

                        if lengths[name1] == nil then lengths[name1] = {} end
                        lengths[name1][name2] = timeDistance
                    end
                end
            end
        end
    end
end

function getData2(faction)
    local data = {}
    local locData = {}
    local mapData = {}
    local lengths = {}
    if faction == "Horde" then
        mapData = ClassicTravelPoints.MapDataHorde
        lengths = InFlight.defaults.global["Horde"]
    elseif faction == "Alliance" then
        mapData = ClassicTravelPoints.MapDataAlliance
        lengths = InFlight.defaults.global["Alliance"]
    else
        lengths = InFlight.defaults.global
    end
    if mapData == nil then mapData = {} end
    locData = getPreciseMapData(947, mapData)
    addZLPData(ZoneLinkPoints, locData, mapData)
    initDistData(mapData, lengths)
    
    
    data.locData = locData
    data.mapData = mapData
    data.ZLPData = ZoneLinkPoints
    data.lengths = lengths
    print("getData2")
    
    return data
end

function removeNodeFromData(posName, data)
    if data.lengths[posName] ~= nil then
        for k,v in pairs(data.lengths[posName]) do
            data.lengths[posNam][k] = nil
            data.lengths[k][posName] = nil
        end
    end

    if data.locData[posName] ~= nil then
        local mapID = data.locData[posName]["mapID"]
        for k,v in pairs(data.mapData[mapID]) do
            if getNameBeforeComma(v["desc"]) == posName then
                data.mapData[mapID][k] = nil
            end
        end
        data.locData[posName] = nil
    end
end

function setDistData(posName, mapID, mapPos, data)
    removeNodeFromData(posName, data)
    
    local continentID = getContinentMapIDFromMapPos(mapID, mapPos)
    local posX, posY = getMapPosFromWorldPosForMap(continentID, mapID, mapPos)
    
    local info = C_Map.GetMapInfoAtPosition(continentID, posX, posY)
    if info == nil then return end

    for _,loc in pairs(data.mapData[info.mapID]) do
        local x2, y2 = getMapPosFromWorldPosForMap(continentID, mapID, CreateVector2D(loc["x"], loc["y"]))
        local name = getNameBeforeComma(loc["desc"])

        local dxTime = math.abs(posX - x1) * getYardsPerPixelForMap(mapID) / NORMAL_PLAYER_SPEED
        local dyTime = math.abs(posY - y1) * getYardsPerPixelForMap(mapID) / NORMAL_PLAYER_SPEED
        local timeDistance = math.sqrt(math.pow(dxTime, 2) + math.pow(dyTime, 2))

        lengths[posName][name] = timeDistance
        lengths[name][posName] = timeDistance
    end

    
    posX, posY = getMapPosFromWorldPosForMap(947, mapID, mapPos)
    data.locData[posName] = {["type"] = "C", ["faction"] = "N", ["mapID"] = info.mapID, ["x"] = posX, ["y"] = posY, ["desc"] = posName}
    posX, posY = getMapPosFromWorldPosForMap(info.mapID, mapID, mapPos)
    table.insert(data.mapData[info.mapID], {["type"] = "C", ["faction"] = "N", ["mapID"] = info.mapID, ["x"] = posX, ["y"] = posY, ["desc"] = posName})
end



function setDistanceDataForPosition(posX, posY, positionName, lengths, mapData, mapID, updateExisting)
    if lengths[positionName] == nil then
        lengths[positionName] = {}
    end
    for k, v in pairs(mapData) do
        local name = getNameBeforeComma(v["desc"])
        local targetX = tonumber(v["x"])
        local targetY = tonumber(v["y"])
        if targetX > 0 and targetX < 100 and targetY > 0 and targetY < 100 then 
            local dxTime = math.abs(posX - targetX) * getYardsPerPixelForMap(mapID) / NORMAL_PLAYER_SPEED
            local dyTime = math.abs(posY - targetY) * getYardsPerPixelForMap(mapID) / NORMAL_PLAYER_SPEED
            local timeDistance = math.sqrt(math.pow(dxTime, 2) + math.pow(dyTime, 2))

            if lengths[name] ~= nil then
                if lengths[positionName][name] == nil or updateExisting == true then
                    lengths[positionName][name] = timeDistance
                    lengths[name][positionName] = timeDistance
                end
            end
        end
    end
end


function initBoatZepplinDistanceData(faction, mapID)
    local lengths, mapData = getData(faction, mapID)
    for k, v in pairs(mapData) do
        local name = getNameBeforeComma(v["desc"])
        if string.find(name, "Boat") ~= nil or string.find(name, "Zepplin") ~= nil then
            setDistanceDataForPosition(tonumber(v["x"]), tonumber(v["y"]), name, lengths, mapData, mapID, false)
        end
    end 
end

-- TODO: implement priority Queue with O(lgn)
function extractMinNode(nodeTable)
    minValue = 3e9
    minNode = ""
    for k, v in pairs(nodeTable) do
        if v < minValue then
            minValue = v
            minNode = k
        end
    end
    nodeTable[minNode] = nil
    return minNode
end


function dijkstrasSSSP(lengths, start)
    dist = {}
    prev = {}
    nodeQueue = {}
    dist[start] = 0
    nodeQueue[start] = 0
    prev[start] = nil
    for k, v in pairs(lengths) do
        if k ~= start then
            dist[k] = 3e9
            prev[k] = nil
        end
        if lengths[start][k] ~= nil then
            nodeQueue[k] = lengths[start][k]
        end
    end

    while next(nodeQueue) ~= nil do
        u = extractMinNode(nodeQueue)
        for v, l in pairs(lengths[u]) do
            alt = dist[u] + lengths[u][v]
            if alt < dist[v] then
                dist[v] = alt
                prev[v] = u
                nodeQueue[v] = alt
            end
        end
    end
    return dist, prev
end


function createPathList(prev, endNode) 
    local pathList = {}
    local node = endNode
    local lastNode = nil
    while node ~= nil do
        pathList[node] = {}
        pathList[node].nextNode = lastNode
        pathList[node].prevNode = prev[node]
        lastNode = node
        node = prev[node]
    end
    return pathList
end

function createPathOrderedList(dist, prev, endNode) 
    local pathList = {}
    local node = endNode
    local lastNode = nil
    local count = 1
    while node ~= nil do
        pathList[count] = {}
        pathList[count].node = node
        pathList[count].nextNode = lastNode
        pathList[count].prevNode = prev[node]
        if lastNode ~= nil then
            pathList[count].nextEdgeCost = dist[lastNode] - dist[node]
        end
        lastNode = node
        node = prev[node]
        count = count + 1
    end
    return pathList
end

function printPath(prev, endNode)
    local pathList = createPathList(prev, endNode)
    local node = endNode
    while node ~= nil do
        print(node)
        node = pathList[node].prevNode
    end
end



function createPathCoordinateTable2(pathList, mapID, playerX, playerY, playerMapID, targetX, targetY, targetMapID, globalMapData, globalMapID)
    local coordTable = {}
    local npx, npy = getMapPosFromWorldPosForMap(mapID, playerMapID, CreateVector2D(playerX, playerY))
    coordTable["player"] = {}
    coordTable["player"].x = npx
    coordTable["player"].y = npy
    coordTable["player"].prevNode = pathList["player"].prevNode
    coordTable["player"].nextNode = pathList["player"].nextNode
    local ntx, nty = getMapPosFromWorldPosForMap(mapID, targetMapID, CreateVector2D(targetX, targetY))
    coordTable["target"] = {}
    coordTable["target"].x = ntx
    coordTable["target"].y = nty
    coordTable["target"].prevNode = pathList["target"].prevNode
    coordTable["target"].nextNode = pathList["target"].nextNode
    for k,v in pairs(pathList) do
        if k ~= "player" and k ~= "target" then
            coordTable[k] = {}
            local gPosX = tonumber(globalMapData[k]["x"])
            local gPosY = tonumber(globalMapData[k]["y"])
            local posX, posY = getMapPosFromWorldPosForMap(mapID, globalMapID, CreateVector2D(gPosX, gPosY))
            coordTable[k].x = posX
            coordTable[k].y = posY
            coordTable[k].prevNode = v.prevNode
            coordTable[k].nextNode = v.nextNode
        end
    end
    return coordTable
end
--[[
function createPathCoordinateTable(prevList, playerX, playerY, targetX, targetY, targetMapID, mapID, mapData, worldMapID, worldMapData)
    local coordTable = {}
    local pathList = createPathList(prevList, "target")

    local targetZoneID = getMapIDFromWorldPos(targetMapID, CreateVector2D(targetX / 100, targetY / 100))
    if playerX ~= nil and playerY ~= nil then
        coordTable["player"] = {}
        coordTable["player"].x = playerX
        coordTable["player"].y = playerY
        coordTable["player"].prevNode = pathList["player"].prevNode
        coordTable["player"].nextNode = pathList["player"].nextNode
    end
    if targetZoneID == mapID or targetMapID == mapID or mapID == 947 then
        coordTable["target"] = {}
        local newTargetX, newTargetY = getMapPosFromWorldPosForMap(mapID, worldMapID, CreateVector2D(targetX, targetY))
        coordTable["target"].x = newTargetX
        coordTable["target"].y = newTargetY
        coordTable["target"].prevNode = pathList["target"].prevNode
        coordTable["target"].nextNode = pathList["target"].nextNode
    end
    
    for k, v in pairs(mapData) do
        local name = getNameBeforeComma(v["desc"])
        if pathList[name] ~= nil then
            coordTable[name] = {}
            coordTable[name].x = tonumber(v["x"])
            coordTable[name].y = tonumber(v["y"])
            coordTable[name].prevNode = pathList[name].prevNode
            coordTable[name].nextNode = pathList[name].nextNode
            print(coordTable[name].x, coordTable[name].y, coordTable[name].prevNode, name, coordTable[name].nextNode)
        end
    end

    for k, v in pairs(coordTable) do
        if v.nextNode ~= nil and coordTable[v.nextNode] == nil then
            local name = v.nextNode
            local newX = -1
            local newY = -1
            if name == "player" then
                newX, newY = getMapPosFromWorldPosForMap(mapID, worldMapID, CreateVector2D(playerX, playerY)) 
            elseif name == "target" then
                newX, newY = getMapPosFromWorldPosForMap(mapID, worldMapID, CreateVector2D(targetX, targetY))
            else
                local node = worldMapData[name]
                newX, newY = getMapPosFromWorldPosForMap(mapID, worldMapID, CreateVector2D(tonumber(node["x"]), tonumber(node["y"])))
            end
            coordTable[name] = {}
            coordTable[name].x = newX
            coordTable[name].y = newY
            coordTable[name].prevNode = k
            coordTable[name].nextNode = nil
            break
        end
    end
    for k,v in pairs(coordTable) do
        if v.prevNode ~= nil and coordTable[v.prevNode] == nil then
            local name = v.prevNode
            local newX = -1
            local newY = -1
            if name == "player" then
                newX, newY = getMapPosFromWorldPosForMap(mapID, worldMapID, CreateVector2D(playerX, playerY)) 
            elseif name == "target" then
                newX, newY = getMapPosFromWorldPosForMap(mapID, worldMapID, CreateVector2D(targetX, targetY))
            else
                local node = worldMapData[name]
                newX, newY = getMapPosFromWorldPosForMap(mapID, worldMapID, CreateVector2D(tonumber(node["x"]), tonumber(node["y"])))
            end
            coordTable[name] = {}
            coordTable[name].x = newX
            coordTable[name].y = newY
            coordTable[name].prevNode = nil
            coordTable[name].nextNode = k
            break
        end
    end
    return coordTable
end
--]]

local englishFaction, localizedFaction = UnitFactionGroup("player")
print(englishFaction)
local mapID, position = getWorldMapPosition()
local zoneID = C_Map.GetBestMapForUnit("player")
local playerX, playerY = position:GetXY()
playerX = playerX * 100
playerY = playerY * 100

targetX = 47
targetY = 78
targetMapID = 1415

lengths, mapData = getData(englishFaction, 1414)
lengths2, mapData2 = getData(englishFaction, 1415)
local data = getData2(englishFaction)
setDistData("player", mapID, position, data)
setDistData("target", targetMapID, CreateVector2D(targetX, targetY), data)
--setDistanceDataForPosition(playerX, playerY, "player", lengths, mapData2, mapID, true)
--setDistanceDataForPosition(targetX, targetY, "target", lengths2, mapData2, targetMapID, true)
--initBoatZepplinDistanceData(englishFaction, 1414)
--initBoatZepplinDistanceData(englishFaction, 1415)


dist, prev = dijkstrasSSSP(data.lengths, "player")
printPath(prev, "target")


local lines = {}
local nodeFrames = {}

local mouseUpFunc = WorldMapFrame.ScrollContainer.OnMouseUp
--[[
WorldMapFrame.ScrollContainer:OnMouseUp()
    print("is this working")
    return mouseUpFunc
end
--]]
--[[
WorldMapFrame.ScrollContainer:SetScript("OnMouseUp", function (self, button)
    if button=='LeftButton' then 
        print ('OMG left button?!')
    end
    
end)
--]]


function clearDrawingData()
    --self:GetMap():RemoveAllPinsByTemplate("PinMixinTemplate");
    local drawContainer = WorldMapFrame.ScrollContainer
    drawContainer:GetMap():RemoveAllPinsByTemplate("PinMixinTemplate")
    for line, v in pairs(lines) do
        line:SetColorTexture(0, 0, 0, 0)
        line:Hide()
        --table.remove(lines, line)
        line = nil
    end
    lines = {}
    nodeFrames = {}
end

function refreshDrawingData()
    clearDrawingData()

    local drawContainer = WorldMapFrame.ScrollContainer
    print("abcde") 
    local zoneID = drawContainer:GetMap():GetMapID()
    --local parentMapID = C_Map.GetMapInfo(uiMapID).parentMapID
    local mapPosition = C_Map.GetPlayerMapPosition(zoneID, "player")
    local worldMapID, worldMapPosition = getWorldMapPosition()
    local playerX = nil
    local playerY = nil
    if worldMapPosition ~= nil then  
        playerX, playerY = worldMapPosition:GetXY()
        playerX = playerX * 100
        playerY = playerY * 100
    end
    local x, y = drawContainer:GetNormalizedCursorPosition()
    --[[
    for k,v in pairs(WorldMapFrame.ScrollContainer) do
        print(k,v)
    end
    --]]
    --print("LayerIndex", drawContainer:GetCurrentLayerIndex())
    --print("CursorOnMapPosition", x, y)
    local lengths, mapData = getData(englishFaction, zoneID)
    local worldMapLenghts, globalMapData = getData(englishFaction, worldMapID)

    local pathList = createPathList(prev, "target")
    local coordTable = createPathCoordinateTable2(pathList, zoneID, playerX, playerY, worldMapID, targetX, targetY, targetMapID, globalMapData, worldMapID)

    for k, v in pairs(coordTable) do
        local poiInfo = {}
        poiInfo.position = CreateVector2D(v.x / 100, v.y / 100);
        poiInfo.name = k;
        poiInfo.drawLines = false
        poiInfo.drawPoints = true
        
        drawContainer:GetMap():AcquirePin("PinMixinTemplate", poiInfo)
    end

    for k, v in pairs(coordTable) do
        local poiInfo = {}
        poiInfo.position = CreateVector2D(v.x / 100, v.y / 100);
        poiInfo.name = k;
        poiInfo.drawLines = true
        poiInfo.drawPoints = false
        --print(self:GetMap():GetScale())
        --print(self:GetMap():GetEffectiveScale())
        if v.nextNode ~= nil and coordTable[v.nextNode] then
            poiInfo.nextX = (coordTable[v.nextNode].x - v.x) / 100 * drawContainer:GetMap():GetWidth() * 0.95
            poiInfo.nextY = -(coordTable[v.nextNode].y - v.y) / 100 * drawContainer:GetMap():GetHeight() * 0.85
            poiInfo.nextNode = v.nextNode
        else
            poiInfo.nextNode = nil
            poiInfo.nextX = 0
            poiInfo.nextY = 0
        end
        
        drawContainer:GetMap():AcquirePin("PinMixinTemplate", poiInfo)
    end
    print(123)
end

DataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)
function DataProviderMixin:RefreshAllData(fromOnShow)
    refreshDrawingData()
end

PinMixin = BaseMapPoiPinMixin:CreateSubPin("PIN_FRAME_LEVEL_FLIGHT_POINT");
function PinMixin:SetTexture(poiInfo)
    if poiInfo.drawPoints == true then
        nodeFrames[poiInfo.name] = self
        self:CreateTexture()
    end

    if poiInfo.drawLines == true then
        self.Texture:SetTexture(nil)
        local line = self:CreateLine()
        line:SetBlendMode("BLEND")
        line:SetColorTexture(0,0,1,0.5)
        line:SetThickness(2)
        line:SetStartPoint("CENTER",0,0)
        if poiInfo.nextNode ~= nil and nodeFrames[poiInfo.nextNode] ~= nil then
            line:SetEndPoint("CENTER", nodeFrames[poiInfo.nextNode])
        else
            line:SetEndPoint("CENTER", poiInfo.nextX, poiInfo.nextY)
        end
        lines[line] = true
        --print("line")
    end

    --local posX, posY = poiInfo.position:GetXY()
    --posX1, posY 1= self:GetPosition()
    --print(self, posX1, posY1, posX, posY
    --print(self:GetSize())
    --local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint(1)
    --print(self:GetPoint(1))
    --self.endScale = 1
end
WorldMapFrame:AddDataProvider(CreateFromMixins(DataProviderMixin))

-- BasicFrameTemplate, BasicFrameTemplateWithInset, UIPanelDialogTemplate, UIDropDownMenuTemplate, MessageFrame, BasicFrameTemplateWithInset
local frame = CreateFrame("Frame", "MenuFrame", WorldMapFrame, "BasicFrameTemplate") 
frame:SetSize(300, 360)
frame:SetFrameStrata("TOOLTIP")
--frame:SetMovable(true)
--frame:SetUserPlaced(false)
--frame:StartMoving()
frame:SetAlpha(0.9)
--print("hello")
frame:SetPoint("TOPRIGHT", WorldMapFrame.ScrollContainer, "TOPRIGHT")

frame.title = frame:CreateFontString(nil, "OVERLAY")
frame.title:SetFontObject("GameFontHighlight")
frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 5, 0)
frame.title:SetText("ClassicPathCalculator")


frame.clearBtn = CreateFrame("Button", "ClearBtn", frame, "UIPanelButtonTemplate")
frame.clearBtn:SetSize(80 ,22) -- width, height
frame.clearBtn:SetText("Clear Path")
frame.clearBtn:SetPoint("TOPLEFT", 10, -30)
frame.clearBtn:SetScript("OnClick", function()
    clearDrawingData()
end)



frame.text = frame:CreateFontString(nil, "OVERLAY")
frame.text:SetFontObject("GameFontHighlight")
frame.text:SetText("This is new text \n This is a new line \n Hope it works like intended")
frame.text:SetPoint("TOPLEFT", frame.clearBtn, "TOPLEFT", 30, -30)
frame.text:SetJustifyH("LEFT")
frame.text:SetSpacing(32)

--[[
frame.tex = frame:CreateTexture()
frame.tex:SetPoint("CENTER")
frame.tex:SetSize(32, 32)
frame.tex:SetTexture("Interface\\AddOns\\ClassicPathCalculator\\Textures\\NeutralBoat.blp")
--]]

--[[
local text = frame:CreateFontString()
text:SetTextColor(1, 1, 1, 1)
text:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE, MONOCHROME")
text:SetText("123")
--]]

function secondsToMins(seconds)
    local seconds = tonumber(seconds)
    local text = ""

    if seconds <= 0 then
        return "0"
    else
        hours = string.format("%02.f", math.floor(seconds/3600))
        mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)))
        secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60))
        if math.floor(seconds/60 - (hours*60)) > 0 then
            return mins .. " mins, " .. secs .. " secs"
        else
            return secs .. " seconds"
        end
    end
end

function getEdgeType(startNode, endNode, mapData)
    if startNode == "player" or endNode == "target" then
        return "Run"
    elseif mapData[startNode]["type"] == "FM" and mapData[endNode]["type"] == "FM" then
        return "Flight"
    elseif mapData[startNode]["type"] == "BN" and mapData[endNode]["type"] == "BN" then
        if mapData[startNode]["faction"] == "H" then
            return "HordeBoat"
        elseif mapData[startNode]["faction"] == "A" then
            return "AllianceBoat"
        else
            return "NeutralBoat"
        end
    else
        return "Run"
    end
end

function getTotalPathTime(orderedPath)
    local totalTime = 0
    for k,v in pairs(orderedPath) do
        if v.nextEdgeCost ~= nil then
            totalTime = totalTime + v.nextEdgeCost
        end
    end
    return totalTime
end

local modeIcons = {}
function writePathText(orderedPath, mapData)
    for k,v in pairs(modeIcons) do
        v:SetTexture(nil)
    end

    local size = 1
    for k,v in pairs(orderedPath) do
        size = size + 1
    end

    local textString = "Total time: " .. secondsToMins(getTotalPathTime(orderedPath)) .. "\n\n"
    local i = 1
    while orderedPath[size - i] ~= nil and orderedPath[size - i].nextNode ~= nil do
        textString = textString .. tostring(i) .. ". |cFFE6CC80" .. orderedPath[size - i].node .. "|r  -->  |cFFE6CC80" .. orderedPath[size - i].nextNode .. "|r\n"
        textString = textString .. "     " .. secondsToMins(orderedPath[size - i].nextEdgeCost) .. "\n\n"
        
        if modeIcons[i] == nil then modeIcons[i] = frame:CreateTexture() end
        modeIcons[i]:SetPoint("TOPLEFT", frame.clearBtn, "TOPLEFT", 0, -((i - 1) * 64 + 64) )
        modeIcons[i]:SetSize(32, 32)
        modeIcons[i]:SetTexture(ModeIconsFilepath[getEdgeType(orderedPath[size - i].node, orderedPath[size - i].nextNode, mapData)])
        i = i + 1
    end
    frame.text:SetText(textString)
    frame.text:SetJustifyH("LEFT")
    frame.text:SetSpacing(8)
    frame:SetHeight(frame.text:GetHeight() + 32)
end


WorldMapFrame.ScrollContainer:HookScript("OnMouseUp", function(self)
    if IsLeftAltKeyDown() or IsRightAltKeyDown() then
        targetX, targetY = self:GetNormalizedCursorPosition()
        targetX = targetX * 100
        targetY = targetY * 100
        local currentMapID = self:GetMap():GetMapID()
        local continentID = getContinentMapIDFromMapPos(currentMapID, CreateVector2D(targetX, targetY))
        targetMapID = continentID
        targetX, targetY = getMapPosFromWorldPosForMap(targetMapID, currentMapID, CreateVector2D(targetX, targetY))
        if continentID == 1414 then
            setDistanceDataForPosition(targetX, targetY, "target", lengths, mapData, targetMapID, true)
        else
            setDistanceDataForPosition(targetX, targetY, "target", lengths, mapData2, targetMapID, true)
        end
        dist, prev = dijkstrasSSSP(lengths, "player")
        local path = createPathOrderedList(dist, prev, "target")
        writePathText(path, mapData)
        refreshDrawingData()
        frame:Show()
    end
end)



print("ending")
--[[
print("yoyo")
local info = C_Map.GetMapInfoAtPosition(1414, 0.44, 0.66)
print(info)
for k,v in pairs(info) do
    print(k,v)
end
print("done")
--]]

--[[
testTable = {
    ["hello"] = 12,
    ["123"] = 14,
    ["abc"] = 15,
}
print("print:")
for k,v in pairs(testTable) do
    print(k,v)
end
print("print:")
testTable["hello"] = nil 
for k,v in pairs(testTable) do
    print(k,v)
end
print("print:")
testTable["abc"] = nil
for k,v in pairs(testTable) do
    print(k,v)
end
print("print:")
testTable["123"] = nil 
for k,v in pairs(testTable) do
    print(k,v)
end
--]]

--[[
testArray = {
    {["type"] = "FM", ["faction"] = "A", ["x"] = 17.4, ["y"] = 19.6, ["desc"] = "Rut'theran Village, Teldrassil"},
    {["type"] = "BN", ["faction"] = "A", ["x"] = 18.3, ["y"] = 21.2, ["desc"] = "Darnassus Boat"},
}
for k,v in pairs(testArray) do
    print(k, v["type"], v["faction"], v["x"], v["y"], v["desc"])
end
print(testArray[1])
print(testArray[2])
testArray[1] = nil
for k,v in pairs(testArray) do
    print(k, v["type"], v["faction"], v["x"], v["y"], v["desc"])
end
testArray[2] = nil
table.insert(testArray, {["type"] = "BN", ["faction"] = "A", ["x"] = 18.3, ["y"] = 21.2, ["desc"] = "Darnassus Boat"})
for k,v in pairs(testArray) do
    print(k, v["type"], v["faction"], v["x"], v["y"], v["desc"])
end
--]]

emptyList = {}
table.insert(emptyList, 123)
for k,v in pairs(emptyList) do
    print(k,v)
end