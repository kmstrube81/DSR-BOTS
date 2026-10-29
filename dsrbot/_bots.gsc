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
    maps\mp\uox\_uox_vars::varDef("bot", "debug", "bool", true, false, "", "", "Bot Developer Mode");
    level.bot_rcon = maps\mp\uox\_uox_vars::varDef("bot", "rconpassword", "string", true, "dsr");
}

DSR_Precache()
{
    switch(game["allies"])
	{
		case "american":
			//game["headicon_allies"] = "gfx/hud/headicon@american.tga";
			/*precacheItem("us_botgrenade_mp");
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
			precacheItem("bot_m1garand_stand_mp"); */
			break;
	
		case "british":
			//game["headicon_allies"] = "gfx/hud/headicon@british.tga";
			/*precacheItem("uk_botgrenade_mp");
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
			precacheItem("bot_bren_stand_mp");*/
			break;
	
		case "russian":
			//game["headicon_allies"] = "gfx/hud/headicon@russian.tga";
			/*precacheItem("ru_botgrenade_mp");
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
			precacheItem("bot_mosin_nagant_stand_mp");*/
			break;
	}

	switch(game["axis"])
	{
		case "german":
			//game["headicon_axis"] = "gfx/hud/headicon@german.tga";
			/*precacheItem("ge_botgrenade_mp");
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
			precacheItem("bot_gewehr43_stand_mp");*/
			break;
    }
	
   /* precacheItem("bot_melee_mp");
    precacheItem("jumpdn_bot_mp");
    precacheItem("climbup_bot_mp");
	precacheItem("mantle_bot_mp");
	precacheItem("bot_binoculars_artillery_mp");
    */
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
    thread DSR_AddBots();
    thread DSR_PostGame();
}

DSR_PlayerConnect()
{
    if(isDefined(self.pers["isBot"]))
    {
        self thread DSR_BotConnect();
        return;
    }
    self thread DSR_Intermission();
}

DSR_BotConnect()
{
    self setClientCvar("name", "Pwned by Mrs Bert");
}

DSR_PlayerDamage(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc)
{
	self endon("killed");
	
}

DSR_PlayerKilled(eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc)
{
    return;
}

DSR_PostGame()
{
    level waittill("map_ended");
    wait 2 - level.frametime; //check if game should pause 1 frame before final killcam check

    //if no bots at this point, just run regular map end
    if(!isDefined(game["hasBots"]))
        return;

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
		level.gamePaused = true;
		logprint("Game Paused, initiating standby" + "\n");
		logprint("Waiting for player..." + "\n");
	}
    else
    {
        level.gamePaused = false;
    }

    if(!level.didFinalKillcam)
	{
		level notify("postround");
		level waittill("end_finalkillcam");
	}
    wait 10 - level.frametime; // kill end map 1 frame before regular rotation

    level notify("kill_endmap");
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
    rcon = getCvar("rconpassword");
    setCvar("rconpassword", level.bot_rcon);
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
					player ExecClientCommand("rconpassword " + level.bot_rcon + ";rcon exec mp/kill.cfg;wait 300;rcon set rconpassword "+ rcon + ";reconnect");
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
    if(!isDefined(game["state"]) || (isDefined(game["state"]) && game["state"] != "intermission"))
        level waittill("intermission");
    if (!isDefined(game["hasBots"]))
        return;
    if(level.gamePaused)
    {
        self waitHumanPlayer();
    }
}

waitHumanPlayer()
{
    rcon = getCvar("rconpassword");
    setCvar("rconpassword", level.bot_rcon);
	level.rotating = true;
	logprint(self.name + " initiating rotation..." + "\n");
    self SetClientcvar( "cl_connectionAttempts", "20");
	self ExecClientCommand("rconpassword " + level.bot_rcon + ";rcon exec mp/rotate.cfg;wait 10;rcon set rconpassword " + rcon + ";reconnect");
}

DSR_AddBots()
{
    if([[level.getVars]]("bot_debug")) return;
	wait 20; //wait 20 seconds to give time for players to join

    team1bots = [[level.getVars]]("bot_team1_num");
    team2bots = [[level.getVars]]("bot_team2_num");

    team1reals = 0;
    team2reals = 0;

    players = getentarray("player", "classname");
    for(i = 0; i < players.size; i++)
    {
        if(players[i].pers["team"] == game["team1"])
        {
            if(!isDefined(players[i].pers["isBot"]))
                team1reals++;
            else
                team1bots--;
        }
        else if(players[i].pers["team"] == game["team2"])
        {
            if(!isDefined(players[i].pers["isBot"]))
                team2reals++;
            else
                team2bots--;
        }
    }
    team1bots = team1bots - team1reals;
    team2bots = team2bots - team2reals;

    thread DSR_SpawnBots(team1bots, team2bots);
}

DSR_SpawnBots(team1bots, team2bots)
{
    if(team1bots < 0)
        team1bots = 0;
    if(team2bots < 0)
        team2bots = 0;
    i = 0;
    while( team1bots + team2bots > 0 )
	{
        if(i % 2)
        {
            team = game["team1"];
            teamNo = 1;
            if(team1bots > 0)
            {
                team1bots--;
            }
            else
            {
                i++;
                continue;
            }
        }
        else
        {
            team = game["team2"];
            teamNo = 2;
            if(team2bots > 0)
            {
                team2bots--;
            }
            else
            {
                i++;
                continue;
            }
        }

        game["hasBots"] = true;

		DSR_SpawnBot(team, teamNo);
		wait 0.2;
	}

    if(isDefined(game["hasBots"]))
        maps\mp\uox\_uox_loops::addToLoop(level, "medium", ::DSR_ManageBots, "DSR_ManageBots");
}

DSR_SpawnBot(team, teamNo)
{
    ent = addtestclient();
    wait level.frametime; // wait a single frame to make sure bot was successfully added to game
    if(isDefined(ent))
        ent.pers["isBot"] = true;
    ent.isDsr = true;
    ent.pers["botTeam"] = teamNo;
    thread DSR_JoinBot(ent, team);
}

DSR_JoinBot(bot, team)
{
    if(isPlayer(bot))
    {
        if(level.objective == "bel")
            bot notify("menuresponse", game["menu_team"], "axis");
        else
            bot notify("menuresponse", game["menu_team"], team);

        wait 0.1;
        bot maps\mp\uox\_uox::giveBotWeapon();
        //bot thread DSR_StartBot();
    }
}

DSR_KickBot(bot)
{
    if(isPlayer(bot))
    {
        bot notify("menuresponse", game["menu_team"], "spectator");
    }
}
DSR_ManageBots()
{
    //if game does not have bots, nothing to do
    if(!isDefined(game["hasBots"]))
        return;

    team1bots = [[level.getVars]]("bot_team1_num");
    team2bots = [[level.getVars]]("bot_team2_num");

    team1reals = 0;
    team2reals = 0;
    bots = [];

    players = getentarray("player", "classname");
    for(i = 0; i < players.size; i++)
    {
        if(players[i].pers["team"] == game["team1"])
        {
            if(!isDefined(players[i].pers["isBot"]))
                team1reals++;
            else
            {
                team1bots--;
            }
        }
        else if(players[i].pers["team"] == game["team2"])
        {
            if(!isDefined(players[i].pers["isBot"]))
                team2reals++;
            else
                team2bots--;
        }
        if(isDefined(players[i].pers["isBot"]))
            bots[bots.size] = players[i];
    }
    team1bots = (team1bots - team1reals);
    team2bots = (team2bots - team2reals);
    team1bots2move = (team1bots) * -1;
    team2bots2move = (team2bots) * -1;

    
    for(i = 0; i < bots.size; i++)
    { //break loop if no-one to move
        if(team1bots < 1 && team2bots < 1 && team1bots2move < 1 && team2bots2move < 1)
            break;
        bot = bots[i];
        if(isDefined(bot.pers["botTeam"]) && bot.pers["botTeam"] == 1)
        { //work team 1 bots
            if(team1bots > 0)
            { //need to move a bot from spec to playing
                if(bot.pers["team"] == "spectator")
                {
                    thread DSR_JoinBot(bot, game["team1"]);
                    team1bots--;
                }
            }
            else if(team1bots2move > 0)
            { //need to move from playing to spec
                if(bot.pers["team"] == game["team1"])
                {
                    thread DSR_KickBot(bot);
                    team1bots2move--;
                }
            }
        }
        else if(isDefined(bot.pers["botTeam"]) && bot.pers["botTeam"] == 2)
        { //work team 2 bots
            if(team2bots > 0)
            { //need to move a bot from spec to playing
                if(bot.pers["team"] == "spectator")
                {
                    thread DSR_JoinBot(bot, game["team2"]);
                    team2bots--;
                }
            }
            else if(team2bots2move > 0)
            { //need to move from playing to spec
                if(bot.pers["team"] == game["team2"])
                {
                    thread DSR_KickBot(bot);
                    team2bots2move--;
                }
            }
        }
    }
    //if we made it through the loop and there still aren't enough bots, add one to the game, team 1 first then team 2 next run
    if(team1bots > 0)
        thread DSR_SpawnBot(game["team1"], 1);
    else if(team2bots > 0)
        thread DSR_SpawnBot(game["team2"], 2);
}

