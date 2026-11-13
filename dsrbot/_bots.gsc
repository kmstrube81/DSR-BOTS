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
    //free bot and mark entities after the regular player disconnect callback
    level.PlayerDisconnect_Callbacks = maps\mp\uox\_uox_arrays::arrayPush(level.PlayerDisconnect_Callbacks, ::DSR_PlayerDisconnect);

}

DSR_Vars()
{
    //0 = mixed: each bot draws its own skill from 5-9 (average 7) when it joins (dsr_motor DSR_ApplySkill)
    level.bot_skill = maps\mp\uox\_uox_vars::varDef("bot", "skill", "int", true, 0, 0, 10, "Bot Skill Level (0 = mixed)");
    maps\mp\uox\_uox_vars::varDef("bot", "team1_num", "int", true, 0, 0, 63, "Number of Bots on Team 1");
    maps\mp\uox\_uox_vars::varDef("bot", "team2_num", "int", true, 0, 0, 63, "Number of Bots on Team 2");
    maps\mp\uox\_uox_vars::varDef("bot", "forceteam", "int", true, 0, 0, 3, "Force Human Team");
    level.bot_camptime = maps\mp\uox\_uox_vars::varDef("bot", "camptime", "int", true, 10, 0, 120, "Bot Camping Time");
    level.bot_battlechatter = maps\mp\uox\_uox_vars::varDef("bot", "battlechatter", "float", true, 1.0, 0.0, 10.0, "Bot Battle Chatter (chance per line = value / 10)");
    level.bot_unlimitedammo = maps\mp\uox\_uox_vars::varDef("bot", "unlimitedammo", "bool", true, true, "", "", "Give Bots Unlimited Ammo");
    maps\mp\uox\_uox_vars::varDef("bot", "debug", "bool", true, false, "", "", "Bot Developer Mode");
    maps\mp\uox\_uox_vars::varDef("bot", "ai_debug", "int", true, 0, 0, 3, "Bot AI Debug Level");
    dsrbot\_dsr_core::DSR_CoreVars();
    level.bot_rcon = maps\mp\uox\_uox_vars::varDef("bot", "rconpassword", "string", true, "dsr");
}

// Bot weapons precached per map, current nationalities only (weapon limit 128, stock included):
//   american 15, british 15, russian 12, german 15, common 5
//   max per map = 15 allies + 15 axis + 5 common = 35 bot weapons on top of the gametype's stock weapons
DSR_Precache()
{
    switch(game["allies"])
	{
		case "american": // 15
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

		case "british": // 15
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

		case "russian": // 12
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
		case "german": // 15
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

    // common 5 (mantle_bot_mp is not precached: CODUO-X has no mantling)
    precacheItem("bot_melee_mp");
    precacheItem("jumpdn_bot_mp");
    precacheItem("climbup_bot_mp");
	precacheItem("bot_binoculars_artillery_mp");
    precacheItem("bot_binoculars_mp"); //the hold pose

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
    dsrbot\_dsr_motor::DSR_MotorInit();

    level.playerAdmin = undefined;
    level.gamePaused = false;

    thread DSR_AddBots();
    thread DSR_PostGame();
    thread dsrbot\_dsr_core::DSR_CoreStart();
}

DSR_PlayerConnect()
{
    //every player: bots get the AI on spawn, everyone gets marks
    self thread dsrbot\_dsr_core::DSR_SpawnWatch();

    if(isDefined(self.pers["isBot"]))
    {
        self thread DSR_BotConnect();
        return;
    }
    self thread DSR_Intermission();
}

DSR_BotConnect()
{
    return;
}

// CODUO-X runs damage/killed callbacks in order, called (not threaded), and ignores return values
// (_uox_callbacks.gsc Callback_PlayerDamage / Callback_PlayerKilled). DSR's run before the defaults,
// so they can never veto damage or a kill, and must never wait: a wait here delays the default handler.
DSR_PlayerDamage(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc)
{
    self dsrbot\_dsr_sense::DSR_OnDamaged(eAttacker, iDamage, sWeapon);
}

DSR_PlayerKilled(eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc)
{
    //runs before Default_PlayerKilled drops the current weapon
    self dsrbot\_dsr_motor::DSR_OnKilled();
    self dsrbot\_dsr_squad::DSR_SquadOnKill(attacker); //"great shot" from the killer's squadmates
}

DSR_PlayerDisconnect()
{
    if(isDefined(self.pers["isBot"]))
        self dsrbot\_dsr_motor::DSR_BotRelease();
    self dsrbot\_dsr_sense::DSR_MarksDelete();
}

DSR_PostGame()
{
    level waittill("intermission");

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

    if(!level.didFinalKillcam)
	{
		level notify("postround");
		level waittill("end_finalkillcam");
	}

    level waittill("map_ended");
    wait 10 - level.frametime; // kill end map 1 frame before regular rotation

    level notify("kill_endmap");
    game["state"] = "rotating";
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
		
		if((int)getCvar("dedicated") != 0)
		{
			if(!isdefined(level.playerAdmin) && !isdefined(player.pers["isBot"]) && player.sessionstate == "intermission")
			{ 
				level.playerAdmin = player;
	
				if(isdefined(player))
				{
					logprint(player.name + " initiating rotation..." + "\n");
					player SetClientcvar( "cl_connectionAttempts", "40");
					wait level.frametime;
					level thread DSR_RconRotate(player, "mp/kill.cfg", "wait 300;reconnect"); //MeatBot's wait
				}
			}
			else if(!isdefined(player.pers["isBot"]))
			{
				if(isdefined(player))
				{
					logprint(player.name + " reconnecting..." + "\n");
					player SetClientcvar("cl_connectionAttempts", "40"); //keep retrying while the next map loads
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
            //listen server: only the host (client 0, never a bot) can rotate it (waitHumanPlayer)
            if(isdefined(player) && player getEntityNumber() == 0 && !isdefined(player.pers["isBot"]))
            {
                player closeMenu();
                player waitHumanPlayer();
                break;
            }
		}
	}
}

//label: what to log instead of cmd, for a command that carries a password
ExecClientCommand(cmd, label)
{
	if(!isDefined(label))
		label = cmd;
	logprint(self.name + " Executing Command " + label + "\n");
	self setClientcvar("ui_ex_clientcmd", cmd);
	self openMenu("clientcmd");
	self closeMenu("clientcmd");
}

DSR_Intermission()
{
    if(game["state"] == "playing")
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
    while(game["state"] != "rotating")
        wait level.frametime;

    //a dedicated server's loadMap already picked a rotating player (level.playerAdmin): this standby is
    //only for a server where nobody could be picked when the map ended
    if(isDefined(level.playerAdmin) || !isDefined(self) || !isPlayer(self))
        return;

    if((int)getCvar("dedicated") == 0)
    {
        //listen server: the host runs the server in its own process, so it rotates it from its own console,
        //with no rcon and no reconnect ("Can't reconnect to localhost"), as MeatBot's restart menu did. Only
        //the host (client 0): any other client running map_rotate would start a server of its own
        if(self getEntityNumber() != 0 || isDefined(self.pers["isBot"]))
            return;
        level.playerAdmin = self;
        level.rotating = true;
        logprint(self.name + " initiating rotation (listen server)..." + "\n");
        self ExecClientCommand("disconnect;wait 1;map_rotate");
        return;
    }

    //dedicated server with nobody to pick when the map ended: the first human to join rotates it, as loadMap
    //would have
    level.playerAdmin = self;
	level.rotating = true;
	logprint(self.name + " initiating rotation..." + "\n");
    self SetClientcvar("cl_connectionAttempts", "40");
	level thread DSR_RconRotate(self, "mp/kill.cfg", "wait 300;reconnect");
}

/* *************************************************************************************************
**** DSR_RconRotate(player, cfg, after)
****
**** A script can't run killserver / map_rotate, so a human client runs them for the server: it is handed
**** an rcon password and sent "rcon exec <cfg>" (ExecClientCommand). To keep the server's real password
**** off that client (it would be readable in its cvars and memory):
****   - the password it gets is a one-time one, made here (bot_rconpassword + random digits), valid only
****     until the cfg starts
****   - the cfg's first line sets dsr_rotating 1; the frame the script sees it, the rest of the cfg is
****     already queued and the real password goes straight back. Without it after 5 s (the client never
****     sent the command) the real password goes back anyway
****   - the client clears its own rconpassword after the command; the log never shows a password
**** The client then runs after (reconnect). If the engine refuses setCvar("rconpassword") from script, the
**** rotation is skipped and logged ("DSR: rcon refused"): the read back is the test.
************************************************************************************************* */
DSR_RconRotate(player, cfg, after)
{
	if(!isDefined(player) || !isPlayer(player))
	{
		logprint("DSR: rcon rotating player left, no rotation\n");
		return;
	}
	//one rotation at a time: a second one would read the first one-time password as the real one
	if(isDefined(level.dsr_rconBusy))
	{
		logprint("DSR: rcon rotation already running, " + cfg + " skipped\n");
		return;
	}
	level.dsr_rconBusy = true;
	real = getCvar("rconpassword");
	prefix = "dsr";
	if(isDefined(level.bot_rcon) && level.bot_rcon != "")
		prefix = level.bot_rcon;
	otp = prefix + randomInt(10000) + (getTime() % 10000) + randomInt(10000);
	setCvar("dsr_rotating", "0");
	setCvar("rconpassword", otp);
	if(getCvar("rconpassword") != otp)
	{
		logprint("DSR: rcon refused: the script can't set rconpassword, no rotation\n");
		setCvar("rconpassword", real);
		level.dsr_rconBusy = undefined;
		return;
	}
	logprint("DSR: rcon one-time password set for " + player.name + "\n");
	player ExecClientCommand("rconpassword " + otp + ";rcon exec " + cfg + ";rconpassword -;" + after,
		"rcon exec " + cfg + ";" + after);

	frames = (int)(5 / level.frametime);
	started = false;
	for(f = 0; f < frames; f++)
	{
		wait level.frametime;
		if(getCvar("dsr_rotating") == "1")
		{
			started = true;
			break;
		}
	}
	setCvar("rconpassword", real);
	if(getCvar("rconpassword") != real)
		logprint("DSR: rcon WARNING: the real password could not be put back\n");
	else if(started)
		logprint("DSR: rcon " + cfg + " started, real password restored after " + (f + 1) + " frames\n");
	else
		logprint("DSR: rcon " + cfg + " never started (5 s), real password restored\n");
	level.dsr_rconBusy = undefined; //the cfg kills the server soon after; a failed rotation may be tried again
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
    //flag the bot before the frame wait: the connect callbacks are parked on "begin", and anything they
    //register after it (PAM's drop weapon hold) skips players with isBot set
    if(isDefined(ent))
        ent.pers["isBot"] = true;
    wait level.frametime; // wait a single frame to make sure bot was successfully added to game
    if(isDefined(ent))
    {
        ent.isDsr = true;
        ent.pers["botTeam"] = teamNo;
        thread DSR_JoinBot(ent, team);
    }
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
        bot dsrbot\_dsr_motor::DSR_PickWeapon();
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

