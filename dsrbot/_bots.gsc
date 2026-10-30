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
    level.bot_unlimitedammo = maps\mp\uox\_uox_vars::varDef("bot", "unlimitedammo", "bool", true, true, "", "", "Give Bots Unlimited Ammo");
    maps\mp\uox\_uox_vars::varDef("bot", "debug", "bool", true, false, "", "", "Bot Developer Mode");
    maps\mp\uox\_uox_vars::varDef("bot", "ai_debug", "int", true, 0, 0, 3, "Bot AI Debug Level");
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

    // common 5
    precacheItem("bot_melee_mp");
    precacheItem("jumpdn_bot_mp");
    precacheItem("climbup_bot_mp");
	precacheItem("mantle_bot_mp");
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
    DSR_InitWeapons();

    level.playerAdmin = undefined;
    level.gamePaused = false;

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
    return;
}

// CODUO-X runs damage/killed callbacks in order, called (not threaded), and ignores return values
// (_uox_callbacks.gsc Callback_PlayerDamage / Callback_PlayerKilled). DSR's run before the defaults,
// so they can never veto damage or a kill, and must never wait: a wait here delays the default handler.
DSR_PlayerDamage(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc)
{
}

DSR_PlayerKilled(eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc)
{
    //runs before Default_PlayerKilled drops the current weapon
    self DSR_SwapToStockWeapon();
}

/* *************************************************************************************************
**** DSR_InitWeapons()
****
**** builds level.dsr_stockOf[variant] = stock weapon a dying player drops in place of a bot variant,
**** "none" for action variants that have no corresponding weapon
************************************************************************************************* */
DSR_InitWeapons()
{
    level.dsr_stockOf = [];

    weapons = [];
    weapons[weapons.size] = "bar";
    weapons[weapons.size] = "bren";
    weapons[weapons.size] = "enfield";
    weapons[weapons.size] = "gewehr43";
    weapons[weapons.size] = "kar98k";
    weapons[weapons.size] = "m1carbine";
    weapons[weapons.size] = "m1garand";
    weapons[weapons.size] = "mosin_nagant";
    weapons[weapons.size] = "mp40";
    weapons[weapons.size] = "mp44";
    weapons[weapons.size] = "ppsh";
    weapons[weapons.size] = "sten";
    weapons[weapons.size] = "svt40";
    weapons[weapons.size] = "thompson";

    for(i = 0; i < weapons.size; i++)
    {
        stock = weapons[i] + "_mp";
        level.dsr_stockOf["bot_" + weapons[i] + "_walk2_mp"] = stock;
        level.dsr_stockOf["bot_" + weapons[i] + "_close_mp"] = stock;
        level.dsr_stockOf["bot_" + weapons[i] + "_stand_mp"] = stock;
    }

    level.dsr_stockOf["ge_botgrenade_mp"] = "stielhandgranate_mp";
    level.dsr_stockOf["ge_botgrenade2_mp"] = "stielhandgranate_mp";
    level.dsr_stockOf["us_botgrenade_mp"] = "fraggrenade_mp";
    level.dsr_stockOf["us_botgrenade2_mp"] = "fraggrenade_mp";
    level.dsr_stockOf["uk_botgrenade_mp"] = "mk1britishfrag_mp";
    level.dsr_stockOf["uk_botgrenade2_mp"] = "mk1britishfrag_mp";
    level.dsr_stockOf["ru_botgrenade_mp"] = "rgd-33russianfrag_mp";
    level.dsr_stockOf["ru_botgrenade2_mp"] = "rgd-33russianfrag_mp";
    level.dsr_stockOf["bot_bazooka_mp"] = "bazooka_mp";
    level.dsr_stockOf["us_botpanzer_mp"] = "bazooka_mp";
    level.dsr_stockOf["bot_panzerfaust_mp"] = "panzerfaust_mp";

    level.dsr_stockOf["bot_binoculars_artillery_mp"] = "none";
    level.dsr_stockOf["bot_melee_mp"] = "none";
    level.dsr_stockOf["jumpdn_bot_mp"] = "none";
    level.dsr_stockOf["climbup_bot_mp"] = "none";
    level.dsr_stockOf["mantle_bot_mp"] = "none";
}

/* *************************************************************************************************
**** DSR_SwapToStockWeapon()
****
**** if self holds a bot variant, replace it with its stock weapon (or nothing) so the weapon dropped on
**** death never puts a bot variant (and its bot animations) in a human's hands
************************************************************************************************* */
DSR_SwapToStockWeapon()
{
    current = self getCurrentWeapon();
    if(!isDefined(current) || !isDefined(level.dsr_stockOf[current]))
        return; //stock weapon or none, leave the default drop alone

    stock = level.dsr_stockOf[current];
    slotA = self getWeaponSlotWeapon("primary");
    slotB = self getWeaponSlotWeapon("primaryb");
    before = slotA + "," + slotB;
    self takeAllWeapons();
    //takeAllWeapons left the other slot's weapon to be dropped (Phase 0 test: jumpdn_bot_mp death dropped
    //a thompson_mp held in the other slot), so empty both slots before giving the stock weapon
    //VERIFY: setWeaponSlotWeapon(slot, "none") clears the slot without a script error
    if(self getWeaponSlotWeapon("primary") != "none")
        self setWeaponSlotWeapon("primary", "none");
    if(self getWeaponSlotWeapon("primaryb") != "none")
        self setWeaponSlotWeapon("primaryb", "none");
    if(stock != "none")
    {
        self giveWeapon(stock);
        self setSpawnWeapon(stock);
    }

    after = self getCurrentWeapon();
    path = "default";
    //VERIFY: if setSpawnWeapon does not change the current weapon at once, drop the stock weapon here;
    //the default handler then drops whatever is current, which this player no longer owns
    if(stock != "none" && after != stock)
    {
        self dropItem(stock);
        path = "dsr";
    }

    if([[level.getVars]]("bot_ai_debug") >= 1)
    {
        slotA = self getWeaponSlotWeapon("primary");
        slotB = self getWeaponSlotWeapon("primaryb");
        logprint("DSR: deathswap " + self.name + " from=" + current + " to=" + stock + " current=" + after + " drop=" + path
            + " slots=" + before + "->" + slotA + "," + slotB + "\n");
    }
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
    rcon = getCvar("rconpassword");
    setCvar("rconpassword", level.bot_rcon);
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
                player waitHumanPlayer();
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

    rcon = getCvar("rconpassword");
    ip = getCvar("net_ip");
    setCvar("rconpassword", level.bot_rcon);
	level.rotating = true;
	logprint(self.name + " initiating rotation..." + "\n");
    self SetClientcvar( "cl_connectionAttempts", "20");
    self setClientCvar("rconAddress", ip);
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
    {
        ent.pers["isBot"] = true;
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

