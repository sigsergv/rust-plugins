PLUGIN.Title = "Teleport User To Coordinates"
PLUGIN.Description = "Teleport user to a specific set of coordinates"
PLUGIN.Author = "Monstrado"

function PLUGIN:Init()
    oxmin_mod = cs.findplugin("oxmin")
    if not oxmin_mod or not oxmin then
        print("Whitelist critical failure! Oxmin required to run use this plugin")
        return;
    end;
    oxmin_mod:AddExternalOxminChatCommand(self, "tpc", {oxmin.strtoflag["canteleport"]}, self.cmdTeleportCoords)
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
function PLUGIN:cmdGetCoords(netuser, args)
    local coords = netuser.playerClient.lastKnownPosition
    rust.SendChatToUser( netuser, "Current Position: {x: " .. coords.x .. ", y: " .. coords.y .. ", z: " .. coords.z .. "}")
end

-- Chat command to teleport user to a set of coordinates
function PLUGIN:cmdTeleportCoords(netuser, args) 
    local syntax = "Syntax: /teleport [name] [x coord] [y coord] [z coord]"
    if not args[4] then
        rust.Notice(netuser, syntax)
        return
    end
    local b, targetuser = rust.FindNetUsersByName("Monstrado")
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