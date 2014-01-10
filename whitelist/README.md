Whitelist Plugin
================

First working version of the whitelist plugin. Had to modify oxmin.lua to support the passing of a plugin's context. You will **need both the plugins in this gist**. 

    Commands:
    
    /whitelist [steamid]
    /blacklist [steamid]

You **must have** *canwhitelist* and *canblacklist* flags (using the oxmin giveflag command) to run these commands. The steamid supplied can be either regular (i.e. STEAM_0:1:16556317) or steamid64  (i.e. 76561197993378363). 


Whitelisted ids are stored in JSON format inside the server_whitelist.txt file...you can manually modify this and add the steamids, too...just make sure to keep the format correctly.

    ["first_steamid", "second_steamid", "third_steamid"]
