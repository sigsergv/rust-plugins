PLUGIN.Title = "Teleport User To Coordinates"
PLUGIN.Description = "Teleport user to a specific set of coordinates"
PLUGIN.Author = "Monstrado"

function PLUGIN:Init()
    oxmin_mod = cs.findplugin("oxmin")
    if not oxmin_mod or not oxmin then
        print("Whitelist critical failure! Oxmin required to run use this plugin")
        return;
    end;
    self.FLAG_TELEPORT = oxmin.strtoflag["canteleport"]
    oxmin_mod:AddExternalOxminChatCommand(self, "tpc", {FLAG_TELEPORT}, self.cmdTeleportCoords)
    oxmin_mod:AddExternalOxminChatCommand(self, "coords", {}, self.cmdGetCoords)
end

-- Teleport NetUser to Specific Coordinates
function PLUGIN:TeleportNetuser(netuser, x, y, z)
    local coords = netuser.playerClient.lastKnownPosition
    coords.x = x
    coords.y = y
    coords.z = z
    rust.ServerManagement():TeleportPlayer(netuser.playerClient.netPlayer, coords)
end

-- Chat command to return user's coordinates
-- /getcoords [optional:playername]
function PLUGIN:cmdGetCoords(netuser, args)
    local targetuser
    -- Check if a player name was specified
    if args[1] then
        if not oxmin_mod:HasFlag(netuser, self.FLAG_TELEPORT) then
            rust.Notice(netuser, "You do not have permission to obtain another player's coordinates")
            return
        else
            local b, targetuser = rust.FindNetUsersByName(args[1])
            if (not b) then
                if (targetuser == 0) then
                    rust.Notice(netuser, "No players found with that name!")
                else
                    rust.Notice(netuser, "Multiple players found with that name!")
                end
                return
            end
        end
    end
    -- If no player was specified, use netuser
    if not targetuser then
        targetuser = netuser
    end
    local coords = targetuser.playerClient.lastKnownPosition
    rust.SendChatToUser( netuser, targetuser.displayName .. "'s Position: {x: " .. coords.x .. ", y: " .. coords.y .. ", z: " .. coords.z .. "}")
end

-- Chat command to teleport user to a set of coordinates
-- /tpc <playername> <x coord> <y coord> <z coord>
function PLUGIN:cmdTeleportCoords(netuser, args) 
    local syntax = "Syntax: /tpc [name] [x coord] [y coord] [z coord]"
    if not args[4] then
        rust.Notice(netuser, syntax)
        return
    end
    local b, targetuser = rust.FindNetUsersByName(args[1])
    if (not b) then
        if (targetuser == 0) then
            rust.Notice( netuser, "No players found with that name!" )
        else
            rust.Notice( netuser, "Multiple players found with that name!" )
        end
        return
    end
    local x = tonumber(args[2])
    local y = tonumber(args[3])
    local z = tonumber(args[4])
    if not x or not y or not z then
        rust.Notice(netuser, syntax)
        return
    end
    self:TeleportNetuser(targetuser, x, y, z)
end