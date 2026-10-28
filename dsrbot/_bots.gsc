DSR_Init()
{

    //run bot before regular start game callback
    level.StartGametype_Callbacks = maps\mp\uox\_uox_arrays::arrayUnshift(level.StartGametype_Callbacks, ::DSR_StartGameType);
    //define menus after regular start game callback
    level.StartGametype_Callbacks = maps\mp\uox\_uox_arrays::arrayPush(level.StartGametype_Callbacks, ::DSR_DefineMenus);
    //run bot routines before regular player damage callback
    level.PlayerDamage_Callbacks = maps\mp\uox\_uox_arrays::arrayUnshift(level.PlayerDamage_Callbacks, ::DSR_PlayerDamage);
    //run bot routines before regular player killed callback
    level.PlayerKilled_Callbacks = maps\mp\uox\_uox_arrays::arrayUnshift(level.PlayerKilled_Callbacks, ::DSR_PlayerKilled);
    //run pam routines after regular player connect callback
    level.PlayerConnect_Callbacks = maps\mp\uox\_uox_arrays::arrayPush(level.PlayerConnect_Callbacks, ::DSR_PlayerConnect);

}

DSR_Vars()
{
    level.bot_skill = maps\mp\uox\_uox_vars::varDef("bot", "skill", "int", true, 7, 1, 10, "Bot Skill Level");
    maps\mp\uox\_uox_vars::varDef("bot", "team1_num", "int", true, 0, 0, 63, "Number of Bots on Team 1");
    maps\mp\uox\_uox_vars::varDef("bot", "team2_num", "int", true, 0, 0, 63, "Number of Bots on Team 2");
    maps\mp\uox\_uox_vars::varDef("bot", "forceteam", "int", true, 0, 0, 3, "Force Human Team");
    level.bot_camptime = maps\mp\uox\_uox_vars::varDef("bot", "camptime", "int", true, 10, 0, 120, "Bot Camping Time");
    level.bot_battlechatter = maps\mp\uox\_uox_vars::varDef("bot", "battlechatter", "int", true, 1, 0, 3, "Bot Battle Chatter");
    level.bot_unlimitedammo = maps\mp\uox\_uox_vars::varDef("bot", "unlimitedammo", "bool", true, true, "", "", "Force Human Team");
    maps\mp\uox\_uox_vars::varDef("bot", "rconpassword", "string", true, "dsr");
}

DSR_Precache()
{
    switch(game["allies"])
	{
		case "american":
			//game["headicon_allies"] = "gfx/hud/headicon@american.tga";
			precacheItem("us_botgrenade_mp");
			precacheItem("us_botgrenade2_mp");
			precacheItem("bot_bazooka_mp");
			precacheItem("bot_m1carbine_walk2_mp");
			precacheItem("bot_m1carbine_close_mp");
			precacheItem("bot_thompson_walk2_mp");
			precacheItem("bot_thompson_close_mp");
			precacheItem("bot_bar_walk2_mp");
			precacheItem("bot_bar_close_mp");
			precacheItem("bot_m1garand_walk2_mp");
			precacheItem("bot_m1garand_close_mp");	
			precacheItem("bot_m1carbine_stand_mp");
			precacheItem("bot_thompson_stand_mp");
			precacheItem("bot_bar_stand_mp");
			precacheItem("bot_m1garand_stand_mp");
			break;
	
		case "british":
			//game["headicon_allies"] = "gfx/hud/headicon@british.tga";
			precacheItem("uk_botgrenade_mp");
			precacheItem("uk_botgrenade2_mp");
			precacheItem("bot_bazooka_mp");
			precacheItem("bot_sten_walk2_mp");
			precacheItem("bot_sten_close_mp");
			precacheItem("bot_thompson_walk2_mp");
			precacheItem("bot_thompson_close_mp");
			precacheItem("bot_enfield_walk2_mp");
			precacheItem("bot_enfield_close_mp");
			precacheItem("bot_bren_walk2_mp");
			precacheItem("bot_bren_close_mp");
			precacheItem("bot_sten_stand_mp");
			precacheItem("bot_thompson_stand_mp");
			precacheItem("bot_enfield_stand_mp");
			precacheItem("bot_bren_stand_mp");
			break;
	
		case "russian":
			//game["headicon_allies"] = "gfx/hud/headicon@russian.tga";
			precacheItem("ru_botgrenade_mp");
			precacheItem("ru_botgrenade2_mp");
			precacheItem("bot_bazooka_mp");
			precacheItem("bot_svt40_walk2_mp");
			precacheItem("bot_svt40_close_mp");
			precacheItem("bot_ppsh_walk2_mp");
			precacheItem("bot_ppsh_close_mp");
			precacheItem("bot_mosin_nagant_walk2_mp");
			precacheItem("bot_mosin_nagant_close_mp");
			precacheItem("bot_svt40_stand_mp");
			precacheItem("bot_ppsh_stand_mp");
			precacheItem("bot_mosin_nagant_stand_mp");
			break;
	}

	switch(game["axis"])
	{
		case "german":
			//game["headicon_axis"] = "gfx/hud/headicon@german.tga";
			precacheItem("ge_botgrenade_mp");
			precacheItem("ge_botgrenade2_mp");
			precacheItem("bot_panzerfaust_mp");
			precacheItem("bot_mp40_walk2_mp");
			precacheItem("bot_mp40_close_mp");
			precacheItem("bot_mp44_walk2_mp");
			precacheItem("bot_mp44_close_mp");
			precacheItem("bot_kar98k_walk2_mp");
			precacheItem("bot_kar98k_close_mp");
			precacheItem("bot_gewehr43_walk2_mp");
			precacheItem("bot_gewehr43_close_mp");
			precacheItem("bot_mp40_stand_mp");
			precacheItem("bot_mp44_stand_mp");
			precacheItem("bot_kar98k_stand_mp");
			precacheItem("bot_gewehr43_stand_mp");
			break;
    }
	
    precacheItem("bot_melee_mp");
    precacheItem("jumpdn_bot_mp");
    precacheItem("climbup_bot_mp");
	precacheItem("mantle_bot_mp");
	precacheItem("smokegrenade_mp");
	precacheItem("flashgrenade_mp");
	precacheItem("bot_binoculars_artillery_mp");

	precacheString(&"MBOT_MAPNOTSUPPORT");
	precacheString(&"MBOT_NOMORE");
	precacheString(&"MBOT_SKILLSWITCH");
	precacheString(&"MBOT_REMOVED");
}

DSR_DefineMenus()
{

    if(!isDefined(game["bot_gamestarted"]))
    {
        game["menu_clientcmd"] = "clientcmd";
        precacheMenu(game["menu_clientcmd"]);
        game["bot_gamestarted"] = true;
        DSR_Precache();
    }

}

DSR_StartGameType()
{
    DSR_Vars();

    level.playerAdmin = undefined;
    thread DSR_PostGame();
}

DSR_PlayerConnect()
{
    self thread DSR_Intermission();
}

DSR_PlayerDamage(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc)
{
	self endon("killed");
	
}

DSR_PlayerKilled(eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc)
{
    	
}

DSR_PostGame()
{
    level waittill("map_ended");
    wait 10 - level.frametime; //kill normal map end one frame before it would restart

    //count real players
    realplayer = [];
	players = getentarray("player", "classname");
	for ( index = 0; index < players.size; index++ )
	{
		if(isdefined(players[index].pers["isBot"]) || players[index].sessionstate == "intermission")
		{	}
		else
			realplayer[realplayer.size] = players[index];
	}

	if(realplayer.size == 0)
	{
        level notify("kill_endmap");
		level.gamePaused = true;
		logprint("Game Paused, initiating standby" + "\n");
		logprint("Waiting for player..." + "\n");
	}
    endMap();
}

endMap()
{
	map = getCvar("mapname");
	type = getCvar("g_gametype");

	if(mapIsSupportBots(map, type))
		loadMap(map, type);
	else
		map_restart(false);
}

mapIsSupportBots(map, type)
{
    return true;
}

loadMap(map, type)
{
	players = getentarray("player", "classname");
	for ( index = 0; index < players.size; index++ )
	{
		player = players[index];
		
		if(getCvar("dedicated") != "0")
		{
			if(!isdefined(level.playerAdmin) && !isdefined(player.pers["isBot"]) && player.sessionstate == "intermission")
			{ 
				level.playerAdmin = player;
	
				if(isdefined(player))
				{
					logprint(player.name + " initiating rotation..." + "\n");
					player SetClientcvar( "cl_connectionAttempts", "40");
					wait 0.05;
					player ExecClientCommand("rconpassword " + level.bot_rcon + ";rcon exec mp/kill.cfg;wait 300;reconnect");
				}
			}
			else if(!isdefined(player.pers["isBot"]))
			{
				if(isdefined(player))
				{
					logprint(player.name + " reconnecting..." + "\n");
					player ExecClientCommand("wait 200;reconnect");
				}
			}
			else
			{
				if(isdefined(player))
					player closeMenu();
			}
		}
		else
		{
            if(isdefined(player))
            {
                player closeMenu();
                exitLevel(false);
                break;
            }
		}
	}
}

ExecClientCommand(cmd)
{
	logprint(self.name + " Executing Command " + cmd + "\n");
	self setClientcvar("ui_ex_clientcmd", cmd);
	self openMenu("clientcmd");
	self closeMenu("clientcmd");
}

DSR_Intermission()
{
    level waittill("intermission");
    if(level.gamePaused)
    {
        self waitHumanPlayer();
    }
}

waitHumanPlayer()
{
	level.rotating = true;
	logprint(self.name + " initiating rotation..." + "\n");
    self SetClientcvar( "cl_connectionAttempts", "20");
	self maps\mp\mbot\_mbot::ExecClientCommand("rconpassword " + level.bot_rcon + ";rcon exec mp/rotate.cfg;wait 10;reconnect");
}

