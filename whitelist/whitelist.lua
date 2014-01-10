PLUGIN.Title = "User Whitelist"
PLUGIN.Description = "Allows admin to grant access to specific users"
PLUGIN.Author = "Monstrado"

function PLUGIN:Init()
  self.ServerWhitelistDataFile = datafile("server_whitelist")
  self:RefreshWhitelist()
  
  oxmin_mod = cs.findplugin("oxmin")
  if not oxmin_mod or not oxmin then
    print("Whitelist critical failure! Oxmin required to run use this plugin")
    return;
  end;

  -- Security Flags
  -- canwhitelist = allowed to whitelist players
  -- canblacklist = allowed to remove players from whitelist
  FLAG_CANWHITELIST = oxmin.AddFlag("canwhitelist")
  FLAG_CANBLACKLIST = oxmin.AddFlag("canblacklist")
  oxmin_mod:AddExternalOxminChatCommand(self, "whitelist", {FLAG_CANWHITELIST}, self.cmdWhitelist)
  oxmin_mod:AddExternalOxminChatCommand(self, "blacklist", {FLAG_CANBLACKLIST}, self.cmdBlacklist)
end


-- Check for user in whitelist
--- Returns position in array
function PLUGIN:inWhitelist(whitelistUserId)
  -- Refresh whitelist, to make sure admin hasn't added users manually
  -- to the whitelist file.
  self:RefreshWhitelist()
  for pos, userId in pairs(self.ServerWhitelistData) do
    if userId == whitelistUserId then return pos end
  end
  return false
end

-- Check the size of the whitelist
function PLUGIN:getWhitelistSize()
  return table.getn(self.ServerWhitelistData)
end

-- Add user to whitelist
function PLUGIN:addToWhitelist(whitelistUserId)
  if self:inWhitelist(whitelistUserId) then
    return false
  end
  table.insert(self.ServerWhitelistData, tostring(whitelistUserId))
  return true
end

-- Remove user from whitelist
function PLUGIN:removeFromWhitelist(whitelistUserId)
  local userIdPos = self:inWhitelist(whitelistUserId)
  if not userIdPos then
    return false
  end
  table.remove(self.ServerWhitelistData, userIdPos)
  return true
end

--
-- Save whitelist state
function PLUGIN:Save()
  self.ServerWhitelistDataFile:SetText(json.encode(self.ServerWhitelistData))
  self.ServerWhitelistDataFile:Save()
end

--
-- Reread whitelist state
function PLUGIN:RefreshWhitelist()
  self.ServerWhitelistDataFile = datafile("server_whitelist")
  local json_txt = json.decode(self.ServerWhitelistDataFile:GetText())
  if not json_txt then
    json_txt = {}
  end
  self.ServerWhitelistData = json_txt
end

-- Performs Whitelist/Blacklist Operations
-- Takes an action argument
function PLUGIN:performAction(netuser, args, action)
  local targetUserId = args[1]
  -- Whitelist
  if action == "whitelist" then
    if self:addToWhitelist(targetUserId) then
      rust. Notice(netuser, "User added to the server whitelist")
    else
      rust.Notice(netuser, "User already in whitelist")
      return
    end
    -- Blacklist
  elseif action == "blacklist" then
    if self:removeFromWhitelist(targetUserId) then
      rust.Notice(netuser, "User removed from the server whitelist")
    else
      rust.Notice(netuser, "User not found in whitelist")
      return
    end
    -- Discard all other actions
  else
    rust.Notice(netuser, "Internal server error, no action supplied")
    return
  end
  self:Save()
end

-- Whitelist command plugin
-- 	usage: /whitelist <steam_id>
function PLUGIN:cmdWhitelist(netuser, args)
  if (not args[1]) then
    rust.Notice(netuser, "Syntax: /whitelist [steamid]")
    return
  end
  self:performAction(netuser, args, "whitelist")
end

-- Blacklist command plugin
-- 	usage: /blacklist <steam_id>
function PLUGIN:cmdBlacklist(netuser, args)
  if (not args[1]) then
    rust.Notice(netuser, "Syntax: /blacklist [steam_id]")
    return
  end
  return self:performAction(netuser, args, "blacklist")
end

-- Enforce whitelist_refresht
local SteamIDField = field_get(RustFirstPass.SteamLogin, "SteamID", true)
function PLUGIN:OnUserConnect(netuser)
  local steamId_tmp = tonumber(rust.GetUserID(netuser))
  local steamId = self:CommunityIDToSteamID_fix(steamId_tmp)
  local steamId64 = self:ToSteamID64(steamId)

  -- Check  if the steamId is in the whitelist
  -- supports either SteamID, or SteamID64
  if self:inWhitelist(steamId64) or self:inWhitelist(steamId) then
    -- Access Granted
    return
  else
    -- Access Denied
    local deniedString = "You are not added to the whitelist [" .. steamId .. "]"
    rust.Notice(netuser, deniedString)
    rust.RunClientCommand(netuser, "chat.add \"" .. "Server" .. "\" \"" .. deniedString .. "\"")
    netuser:Kick(NetError.Facepunch_Kick_RCON, true)
    print("Kicked user \"" .. rust.QuoteSafe( netuser.displayName ) .. "\" ['" .. steamId64 .. "'] for not being in whitelist")
  end
end

-- Generic split function found on the internet
-- http://coronalabs.com/blog/2013/04/16/lua-string-magic/
function string:split(inSplitPattern, outResults)
   if not outResults then
      outResults = {}
   end
   local theStart = 1
   local theSplitStart, theSplitEnd = string.find(self, inSplitPattern, theStart)
   while theSplitStart do
      table.insert(outResults, string.sub(self, theStart, theSplitStart-1))
      theStart = theSplitEnd + 1
      theSplitStart, theSplitEnd = string.find(self, inSplitPattern, theStart)
   end
   table.insert(outResults, string.sub(self, theStart))
   return outResults
end

function PLUGIN:CommunityIDToSteamID_fix(id)
  return "STEAM_0:" .. math.ceil((id/2) % 1)  .. ":" .. math.floor(id / 2)
end

-- Convert SteamID to Community ID (aka: steamid64)
function PLUGIN:ToSteamID64(steamID)
    local A,B
    local id = steamID:split(":")
   
    if tonumber(id[2]) > tonumber(id[3])
    then
        A = id[3]
        B = id[2]
    else
        A = id[2]
        B = id[3]
    end;
   
   
    id = (((B * 2) + A) + 1197960265728)
    id = "7656" .. id
    return id
end;