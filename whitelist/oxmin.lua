PLUGIN.Title = "Oxmin"
PLUGIN.Description = "Administration mod"

PLUGIN.ReservedSlots = 5

if (not oxmin) then
	oxmin = {}
	oxmin.flagtostr = {}
	oxmin.strtoflag = {}
	oxmin.nextflagid = 1
end
function oxmin.AddFlag( name )
	if (oxmin.strtoflag[ name ]) then return oxmin.strtoflag[ name ] end
	local id = oxmin.nextflagid
	oxmin.flagtostr[ id ] = name
	oxmin.strtoflag[ name ] = id
	oxmin.nextflagid = oxmin.nextflagid + 1
	return id
end

local FLAG_ALL = oxmin.AddFlag( "all" )
local FLAG_BANNED = oxmin.AddFlag( "banned" )
local FLAG_CANKICK = oxmin.AddFlag( "cankick" )
local FLAG_CANBAN = oxmin.AddFlag( "canban" )
local FLAG_CANUNBAN = oxmin.AddFlag( "canunban" ) -- !
local FLAG_CANTELEPORT = oxmin.AddFlag( "canteleport" )
local FLAG_CANGIVE = oxmin.AddFlag( "cangive" ) -- !
local FLAG_CANGOD = oxmin.AddFlag( "cangod" )
local FLAG_GODMODE = oxmin.AddFlag( "godmode" ) -- !
local FLAG_CANLUA = oxmin.AddFlag( "canlua" )
local FLAG_CANCALLAIRDROP = oxmin.AddFlag( "cancallairdrop" )
local FLAG_CANGIVE = oxmin.AddFlag( "cangive" )
local FLAG_RESERVED = oxmin.AddFlag( "reserved" )

local newusertext = "Welcome %s, type /help for information about the server!"

function PLUGIN:Init()
	print( "Loading Oxmin..." )
	self.DataFile = datafile( "oxmin" )
	local txt = self.DataFile:GetText()
	if (txt ~= "") then
		self.Data = json.decode( txt )
	else
		self.Data = {}
		self.Data.Users = {}
	end
	local cnt = 0
	for _, _ in pairs( self.Data.Users ) do cnt = cnt + 1 end
	print( tostring( cnt ) .. " users are tracked by Oxmin!" )
	self.ChatCommands = {}
	self:AddOxminChatCommand( "kick", { FLAG_CANKICK }, self.cmdKick )
	self:AddOxminChatCommand( "ban", { FLAG_CANBAN }, self.cmdBan )
	self:AddOxminChatCommand( "lua", { FLAG_CANLUA }, self.cmdLua )
	self:AddOxminChatCommand( "god", { FLAG_CANGOD }, self.cmdGod )
	self:AddOxminChatCommand( "airdrop", { FLAG_CANCALLAIRDROP }, self.cmdAirdrop )
	self:AddOxminChatCommand( "give", { FLAG_CANGIVE }, self.cmdGive )
	self:AddOxminChatCommand( "help", { }, self.cmdHelp )
	self:AddOxminChatCommand( "who", { }, self.cmdWho )
	self:AddOxminChatCommand( "tp", { FLAG_CANTELEPORT }, self.cmdTeleport )
	self:AddOxminChatCommand( "bring", { FLAG_CANTELEPORT }, self.cmdBring )
	self:AddCommand( "oxmin", "giveflag", self.ccmdGiveFlag )
	self:AddCommand( "oxmin", "takeflag", self.ccmdTakeFlag )
end

function PLUGIN:AddOxminChatCommand( name, flagsrequired, callback )
	local function FixedCallback( self, netuser, cmd, args )
		for i=1, #flagsrequired do
			if (not self:HasFlag( netuser, flagsrequired[i] )) then
				rust.Notice( netuser, "You don't have permission to use this command!" )
				return true
			end
		end
		callback( self, netuser, args )
	end
	self:AddChatCommand( name, FixedCallback )
end

-- PATCHED SECTION
function PLUGIN:AddExternalOxminChatCommand( context, name, flagsrequired, callback )
	local function FixedCallback( context, netuser, cmd, args )
		for i=1, #flagsrequired do
			if (not self:HasFlag( netuser, flagsrequired[i] )) then
				rust.Notice( netuser, "You don't have permission to use this command!" )
				return true
			end
		end
		callback( context, netuser, args )
	end
	context:AddChatCommand( name, FixedCallback )
end

function PLUGIN:ccmdGiveFlag( arg )
	local user = arg.argUser
	if (user and not user:CanAdmin()) then return end
	local b, targetuser = rust.FindNetUsersByName( arg:GetString( 0 ) )
	if (not b) then
		if (targetuser == 0) then
			arg:ReplyWith( "No players found with that name!" )
		else
			arg:ReplyWith( "Multiple players found with that name!" )
		end
		return
	end
	local targetname = rust.QuoteSafe( targetuser.displayName )
	local flagid = oxmin.strtoflag[ arg:GetString( 1 ) ]
	if (not flagid) then
		arg:ReplyWith( "Unknown flag!" )
		return
	end
	self:GiveFlag( targetuser, flagid )
	arg:ReplyWith( "Flag given to " .. targetname .. "." )
end
function PLUGIN:ccmdTakeFlag( arg )
	local user = arg.argUser
	if (user and not user:CanAdmin()) then return end
	local b, targetuser = rust.FindNetUsersByName( arg:GetString( 0 ) )
	if (not b) then
		if (targetuser == 0) then
			arg:ReplyWith( "No players found with that name!" )
		else
			arg:ReplyWith( "Multiple players found with that name!" )
		end
		return
	end
	local targetname = rust.QuoteSafe( targetuser.displayName )
	local flagid = oxmin.strtoflag[ arg:GetString( 1 ) ]
	if (not flagid) then
		arg:ReplyWith( "Unknown flag!" )
		return
	end
	self:TakeFlag( targetuser, flagid )
	arg:ReplyWith( "Flag taken from " .. targetname .. "." )
end
function PLUGIN:Save()
	self.DataFile:SetText( json.encode( self.Data ) )
	self.DataFile:Save()
end
local SteamIDField = field_get( RustFirstPass.SteamLogin, "SteamID", true )
local PlayerClientAll = static_property_get( RustFirstPass.PlayerClient, "All" )
local serverMaxPlayers = static_field_get( RustFirstPass.server, "maxplayers" )
function PLUGIN:CanClientLogin( login )
	local steamlogin = login.SteamLogin
	local userID = tostring( SteamIDField( steamlogin ) )
	local data = self:GetUserDataFromID( userID, steamlogin.UserName )
	for i=1, #data.Flags do
		local f = data.Flags[i]
		if (f == FLAG_BANNED) then return NetError.Facepunch_Kick_Ban end
	end
	local maxplayers = serverMaxPlayers()
	local curplayers = self:GetUserCount()
	if (curplayers + self.ReservedSlots >= maxplayers) then
		for i=1, #data.Flags do
			local f = data.Flags[i]
			if (f == FLAG_RESERVED or f == FLAG_ALL) then return end
		end
		return NetError.Facepunch_Approval_TooManyConnectedPlayersNow
	end
end
function PLUGIN:GetUserCount()
	return PlayerClientAll().Count
end
function PLUGIN:OnUserConnect( netuser )
	local sid = rust.CommunityIDToSteamID( tonumber( rust.GetUserID( netuser ) ) )
	print( "User \"" .. rust.QuoteSafe( netuser.displayName ) .. "\" connected with SteamID '" .. sid .. "'" )
	local data = self:GetUserData( netuser )
	data.Connects = data.Connects + 1
	self:Save()
	if (data.Connects == 1) then
		rust.Notice( netuser, newusertext:format( netuser.displayName ), 20.0 )
	end
	rust.BroadcastChat( netuser.displayName .. " has joined the game." )
end
function PLUGIN:GetUserData( netuser )
	local userID = rust.GetUserID( netuser )
	return self:GetUserDataFromID( userID, netuser.displayName )
end
function PLUGIN:GetUserDataFromID( userID, name )
	local userentry = self.Data.Users[ userID ]
	if (not userentry) then
		userentry = {}
		userentry.Flags = {}
		userentry.ID = userID
		userentry.Name = name
		userentry.Connects = 0
		self.Data.Users[ userID ] = userentry
		self:Save()
	end
	return userentry
end
function PLUGIN:HasFlag( netuser, flag )
	local userID = rust.GetUserID( netuser )
	local data = self:GetUserData( netuser )
	for i=1, #data.Flags do
		local f = data.Flags[i]
		if ((f == FLAG_ALL and flag ~= FLAG_BANNED) or f == flag) then return true end
	end
	return false
end
function PLUGIN:GiveFlag( netuser, flag )
	local userID = rust.GetUserID( netuser )
	local data = self:GetUserData( netuser )
	for i=1, #data.Flags do
		if (data.Flags[i] == flag) then return false end
	end
	table.insert( data.Flags, flag )
	rust.Notice( netuser, "You now have the flag '" .. oxmin.flagtostr[ flag ] .. "'!" )
	self:Save()
	return true
end
function PLUGIN:TakeFlag( netuser, flag )
	local userID = rust.GetUserID( netuser )
	local data = self:GetUserData( netuser )
	for i=1, #data.Flags do
		if (data.Flags[i] == flag) then
			table.remove( data.Flags, i )
			rust.Notice( netuser, "You no longer have the flag '" .. oxmin.flagtostr[ flag ] .. "'!" )
			self:Save()
			return true
		end
	end
	return false
end
function PLUGIN:OnTakeDamage( dmg )
	--[[print( "OnTakeDamage!" )
	print( dmg )
	print( dmg.attacker )
	print( dmg.victim )]]
	local client = dmg.victim.client
	if (client) then
		print( "Client valid!" )
		local user = client.netUser
		if (self:HasFlag( user, FLAG_GODMODE )) then
			dmg.amount = 0
			local attacker = dmg.attacker.client
			if (attacker) then
				rust.Notice( attacker.netUser, "That player is in godmode!" )
			end
			print( "Returning something!" )
			return dmg
		end
	end
end

-- CHAT COMMANDS --
function PLUGIN:cmdHelp( netuser, args )
	rust.SendChatToUser( netuser, "Welcome to the server!" )
	rust.SendChatToUser( netuser, "This server is powered by the Oxide Modding API for Rust." )
	rust.SendChatToUser( netuser, "Use /who to see how many players are online." )
	callplugins( "SendHelpText", netuser )
end
function PLUGIN:cmdWho( netuser, args )
	rust.SendChatToUser( netuser, "There are " .. tostring( #rust.GetAllNetUsers() ) .. " survivors online." )
end
function PLUGIN:cmdKick( netuser, args )
	if (not args[1]) then
		rust.Notice( netuser, "Syntax: /kick name" )
		return
	end
	local b, targetuser = rust.FindNetUsersByName( args[1] )
	if (not b) then
		if (targetuser == 0) then
			rust.Notice( netuser, "No players found with that name!" )
		else
			rust.Notice( netuser, "Multiple players found with that name!" )
		end
		return
	end
	local targetname = rust.QuoteSafe( targetuser.displayName )
	rust.BroadcastChat( "'" .. targetname .. "' was kicked by '" .. rust.QuoteSafe( netuser.displayName ) .. "'!" )
	rust.Notice( netuser, "\"" .. targetname .. "\" kicked." )
	targetuser:Kick( NetError.Facepunch_Kick_RCON, true )
end
function PLUGIN:cmdBan( netuser, args )
	if (not args[1]) then
		rust.Notice( netuser, "Syntax: /ban name" )
		return
	end
	local b, targetuser = rust.FindNetUsersByName( args[1] )
	if (not b) then
		if (targetuser == 0) then
			rust.Notice( netuser, "No players found with that name!" )
		else
			rust.Notice( netuser, "Multiple players found with that name!" )
		end
		return
	end
	local targetname = rust.QuoteSafe( targetuser.displayName )
	rust.BroadcastChat( "'" .. targetname .. "' was banned by '" .. rust.QuoteSafe( netuser.displayName ) .. "'!" )
	rust.Notice( netuser, "\"" .. targetname .. "\" banned." )
	self:GiveFlag( targetuser, FLAG_BANNED )
	targetuser:Kick( NetError.Facepunch_Kick_Ban, true )
end
function PLUGIN:cmdUnban( netuser, args )
	-- TODO: This
end
function PLUGIN:cmdTeleport( netuser, args )
	if (not args[1]) then
		rust.Notice( netuser, "Syntax: /tp target OR /tp player target" )
		return
	end
	local b, targetuser = rust.FindNetUsersByName( args[1] )
	if (not b) then
		if (targetuser == 0) then
			rust.Notice( netuser, "No players found with that name!" )
		else
			rust.Notice( netuser, "Multiple players found with that name!" )
		end
		return
	end
	if (not args[2]) then
		-- Teleport netuser to targetuser
		rust.ServerManagement():TeleportPlayerToPlayer( netuser.networkPlayer, targetuser.networkPlayer )
		rust.Notice( netuser, "You teleported to '" .. rust.QuoteSafe( targetuser.displayName ) .. "'!" )
		rust.Notice( targetuser, "'" .. rust.QuoteSafe( netuser.displayName ) .. "' teleported to you!" )
	else
		local b, targetuser2 = rust.FindNetUsersByName( args[2] )
		if (not b) then
			if (targetuser2 == 0) then
				rust.Notice( netuser, "No players found with that name!" )
			else
				rust.Notice( netuser, "Multiple players found with that name!" )
			end
			return
		end
		
		-- Teleport targetuser to targetuser2
		rust.ServerManagement():TeleportPlayerToPlayer( targetuser.networkPlayer, targetuser2.networkPlayer )
		rust.Notice( targetuser, "You were teleported to '" .. rust.QuoteSafe( targetuser2.displayName ) .. "'!" )
		rust.Notice( targetuser2, "'" .. rust.QuoteSafe( targetuser.displayName ) .. "' teleported to you!" )
	end
end
function PLUGIN:cmdGod( netuser, args )
	if (not args[1]) then
		if (not self:GiveFlag( netuser, FLAG_GODMODE )) then
			self:TakeFlag( netuser, FLAG_GODMODE )
		end
		return
	end
	local b, targetuser = rust.FindNetUsersByName( args[1] )
	if (not b) then
		if (targetuser == 0) then
			rust.Notice( netuser, "No players found with that name!" )
		else
			rust.Notice( netuser, "Multiple players found with that name!" )
		end
		return
	end
	local targetname = rust.QuoteSafe( targetuser.displayName )
	if (self:GiveFlag( targetuser, FLAG_GODMODE )) then
		rust.Notice( netuser, "\"" .. targetname .. "\" now has godmode." )
	elseif (self:TakeFlag( targetuser, FLAG_GODMODE )) then
		rust.Notice( netuser, "\"" .. targetname .. "\" no longer has godmode." )
	end
end
function PLUGIN:cmdLua( netuser, args )
	local code = table.concat( args, " " )
	local func, err = load( code )
	if (err) then
		rust.Notice( netuser, err )
		return
	end
	local b, res = pcall( func )
	if (not b) then
		rust.Notice( netuser, err )
		return
	end
	if (res) then
		rust.Notice( netuser, tostring( res ) )
	else
		rust.Notice( netuser, "No output from Lua call." )
	end
end
function PLUGIN:cmdAirdrop( netuser, args )
	rust.CallAirdrop()
end

function PLUGIN:cmdGive( netuser, args )
	if (not args[1]) then
		rust.Notice( netuser, "Syntax: /give itemname {quantity}" )
		return
	end
	local datablock = rust.GetDatablockByName( args[1] )
	if (not datablock) then
		rust.Notice( netuser, "No such item!" )
		return
	end
	local amount = tonumber( args[2] ) or 1
	-- IInventoryItem objA = current.AddItem(byName, Inventory.Slot.Preference.Define(Inventory.Slot.Kind.Default, false, Inventory.Slot.KindFlags.Belt), quantity);
	local pref = rust.InventorySlotPreference( InventorySlotKind.Default, false, InventorySlotKindFlags.Belt )
	local inv = netuser.playerClient.rootControllable.idMain:GetComponent( "Inventory" )
	print( datablock )
	print( pref )
	print( amount )
	--local invitem = inv:AddItem( datablock, pref, amount )
	local invitem = inv:AddItemAmount( datablock, amount, pref )
	
end