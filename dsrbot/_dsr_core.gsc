/* *************************************************************************************************
**** _dsr_core.gsc
****
**** Think dispatcher, trace budget and bot_ai_level gating (plan 5.2).
**** Phase 1: bots patrol the waypoint graph; no targeting, no shooting.
************************************************************************************************* */

/* *************************************************************************************************
**** DSR_CoreVars()
****
**** declares the AI cvars (plan section 8); called from DSR_Vars before the default start gametype
************************************************************************************************* */
DSR_CoreVars()
{
    maps\mp\uox\_uox_vars::varDef("bot", "ai_level", "int", true, 1, 0, 5, "Bot AI Level");
    maps\mp\uox\_uox_vars::varDef("bot", "ai_thinkperiod", "float", true, 0.25, 0.05, 2.0, "Bot AI Think Period");
    maps\mp\uox\_uox_vars::varDef("bot", "ai_tracespersec", "int", true, 480, 20, 5000, "Bot AI Traces Per Second");
    maps\mp\uox\_uox_vars::varDef("bot", "ai_astarpersec", "int", true, 1280, 20, 20000, "Bot AI A* Expansions Per Second");
}

/* *************************************************************************************************
**** DSR_CoreStart()
****
**** threaded from DSR_StartGameType. DSR's start gametype callback runs before CODUO-X's default one,
**** which starts the server loop and sets level.frametime, so wait for those before using them.
************************************************************************************************* */
DSR_CoreStart()
{
    //level.frametime does not exist yet, so this one wait can't be expressed in frames
    while(!isDefined(level.frametime) || !isDefined(level.fastLoop))
        wait 0.1;

    level.dsr_frame = 0;
    level.dsr_slotNext = 0;
    level.dsr_traces = 0;
    level.dsr_thinks = 0;
    level.dsr_expansions = 0;
    dsrbot\_dsr_debug::DSR_TelemetryReset();
    DSR_UpdateBudgets();

    dsrbot\_dsr_nav::DSR_NavPrepare();
    if(!level.dsr_navReady)
        return;

    maps\mp\uox\_uox_loops::addToLoop(level, "fast", ::DSR_ThinkDispatcher, "DSR_ThinkDispatcher");
    maps\mp\uox\_uox_loops::addToLoop(level, "slow", ::DSR_UpdateBudgets, "DSR_UpdateBudgets");
    maps\mp\uox\_uox_loops::addToLoop(level, "slow", dsrbot\_dsr_debug::DSR_Telemetry, "DSR_Telemetry");
}

/* *************************************************************************************************
**** DSR_UpdateBudgets()
****
**** converts the per-second cvars to per-frame caps (plan 2.2: frames = int(seconds / frametime), min 1);
**** runs once a second so cvar changes apply at runtime
************************************************************************************************* */
DSR_UpdateBudgets()
{
    level.dsr_aiLevel = [[level.getVars]]("bot_ai_level");
    level.dsr_thinkFrames = DSR_Max(1, (int)([[level.getVars]]("bot_ai_thinkperiod") / level.frametime));
    level.dsr_traceCap = DSR_Max(1, (int)([[level.getVars]]("bot_ai_tracespersec") * level.frametime));
    level.dsr_astarCap = DSR_Max(1, (int)([[level.getVars]]("bot_ai_astarpersec") * level.frametime));
}

/* *************************************************************************************************
**** DSR_ThinkDispatcher()
****
**** level fast loop, every frame, never waits: closes the previous frame's counters, runs the shared
**** A* budget, steps turning and footsteps, and thinks each bot whose slot comes up this frame
************************************************************************************************* */
DSR_ThinkDispatcher()
{
    dsrbot\_dsr_debug::DSR_TelemetryFrame();
    level.dsr_frame++;
    level.dsr_traces = 0;
    level.dsr_thinks = 0;
    level.dsr_expansions = 0;

    if(level.dsr_aiLevel < 1)
        return;

    dsrbot\_dsr_nav::DSR_AStarRun();

    slot = level.dsr_frame % level.dsr_thinkFrames;
    players = getentarray("player", "classname");
    for(i = 0; i < players.size; i++)
    {
        bot = players[i];
        if(!isDefined(bot.dsr_active))
            continue;

        bot dsrbot\_dsr_motor::DSR_MotorFrame();

        if((bot.dsr_thinkSlot % level.dsr_thinkFrames) == slot)
        {
            level.dsr_thinks++;
            bot thread DSR_BotThink();
        }
    }
}

/* *************************************************************************************************
**** DSR_Trace(start, end, hitCharacters, ignoreEnt)
****
**** every AI trace goes through here. Over the per-frame cap it returns undefined, which callers treat as
**** "unknown, keep the previous value" (plan 5.2)
************************************************************************************************* */
DSR_Trace(start, end, hitCharacters, ignoreEnt)
{
    if(level.dsr_traces >= level.dsr_traceCap)
    {
        level.dsr_tracesRefused++;
        return undefined;
    }
    level.dsr_traces++;
    return bulletTrace(start, end, hitCharacters, ignoreEnt);
}

/* *************************************************************************************************
**** DSR_BotThink()
****
**** one think for one bot. Never waits: it issues motor commands and polls dsr_motorDone (plan 5.2).
**** Phase 1 runs the patrol state machine only; the schedule engine arrives in Phase 3.
****   start    -> walk to the nearest visible node
****   idle     -> pick a goal and queue a path
****   waitpath -> path ready: follow it; failed: pick again (greedy hop after 3 failures)
****   moving   -> arrived: maybe hold at a camp node, then idle
****   camp     -> hold finished: idle
************************************************************************************************* */
DSR_BotThink()
{
    if(!isDefined(self.dsr_active) || !self.dsr_motorDone)
        return;

    switch(self.dsr_state)
    {
        case "start":
            wp = self dsrbot\_dsr_nav::DSR_NearestVisibleWp(self.origin);
            if(wp == -2)
                return; //trace budget refused, try again next think
            if(wp < 0)
            {
                DSR_SetState("lost");
                return;
            }
            self.dsr_startWp = wp;
            DSR_SetState("idle");
            self dsrbot\_dsr_motor::DSR_MotorCommand("start");
            break;

        case "idle":
            goal = dsrbot\_dsr_nav::DSR_PickPatrolGoal(self.dsr_wp);
            self dsrbot\_dsr_nav::DSR_RequestPath(self.dsr_wp, goal);
            DSR_SetState("waitpath");
            break;

        case "waitpath":
            if(self.dsr_pathState == "ready")
            {
                self.dsr_pathFails = 0;
                DSR_SetState("moving");
                self dsrbot\_dsr_motor::DSR_MotorCommand("path");
            }
            else if(self.dsr_pathState == "failed")
            {
                self.dsr_pathFails++;
                if(self.dsr_pathFails >= 3)
                {
                    //plan 6.3 fallback: one greedy hop, then plan again from the new node
                    self dsrbot\_dsr_nav::DSR_GreedyHop(self.dsr_wp);
                    if(self.dsr_pathState == "ready")
                    {
                        self.dsr_pathFails = 0;
                        DSR_SetState("moving");
                        self dsrbot\_dsr_motor::DSR_MotorCommand("path");
                        return;
                    }
                    //dead end with no way out: start again from the nearest visible node
                    self.dsr_pathFails = 0;
                    DSR_SetState("start");
                    return;
                }
                DSR_SetState("idle");
            }
            break;

        case "moving":
            node = level.wp[self.dsr_wp];
            if(node.type == "c" && randomInt(4) == 0)
            {
                camptime = [[level.getVars]]("bot_camptime");
                if(camptime >= 2)
                {
                    self.dsr_motorTime = 2 + randomFloat(camptime - 2);
                    DSR_AnnounceCamp();
                    DSR_SetState("camp");
                    self dsrbot\_dsr_motor::DSR_MotorCommand("hold");
                    return;
                }
            }
            DSR_SetState("idle");
            break;

        case "camp":
            DSR_SetState("idle");
            break;

        case "lost":
            //no node anywhere near: nothing to do until the next spawn
            break;
    }
}

/* *************************************************************************************************
**** DSR_AnnounceCamp()
****
**** debug log only (bot_ai_debug >= 1). The real "hold this position" quick command comes with chatter
**** (plan 2.5, Phase 3).
************************************************************************************************* */
DSR_AnnounceCamp()
{
    if([[level.getVars]]("bot_ai_debug") < 1)
        return;
    secs = (int)(self.dsr_motorTime + 0.5);
    logprint("DSR: camp " + self.name + " wp=" + self.dsr_wp + " secs=" + secs + " pos=" + self.origin + "\n");
}

DSR_SetState(state)
{
    if([[level.getVars]]("bot_ai_debug") >= 2)
    {
        wp = "none";
        if(isDefined(self.dsr_wp))
            wp = self.dsr_wp;
        logprint("DSR: state " + self.name + " " + self.dsr_state + "->" + state + " wp=" + wp + "\n");
    }
    self.dsr_state = state;
}

/* *************************************************************************************************
**** DSR_SpawnWatch()
****
**** threaded for every player from DSR_PlayerConnect. CODUO-X notifies "spawned" at the top of
**** spawnPlayer and spawnSpectator (_uox_respawns.gsc), before the loadout is given
************************************************************************************************* */
DSR_SpawnWatch()
{
    self endon("disconnect");

    //Default_PlayerConnect may already have spawned this player before DSR's connect callback ran
    if(self.sessionstate == "playing")
        self thread DSR_OnSpawned();

    for(;;)
    {
        self waittill("spawned");
        self thread DSR_OnSpawned();
    }
}

DSR_OnSpawned()
{
    self endon("disconnect");
    self endon("spawned");

    if(isDefined(self.pers["isBot"]))
        self dsrbot\_dsr_motor::DSR_BotRelease();

    //wait for spawnPlayer to finish (it waits a frame, spawns, then gives the loadout); up to 2 s
    frames = DSR_Max(1, (int)(2 / level.frametime));
    for(i = 0; i < frames; i++)
    {
        wait level.frametime;
        if(self.sessionstate == "playing" && self getWeaponSlotWeapon("primary") != "none")
            break;
    }
    if(self.sessionstate != "playing")
        return;

    if(!isDefined(level.dsr_aiLevel) || level.dsr_aiLevel < 1 || !isDefined(level.dsr_navReady) || !level.dsr_navReady)
        return;

    //MeatBot's markTarget waits a frame before and after linking the marks; copied as is
    wait level.frametime;
    self dsrbot\_dsr_sense::DSR_MarksLink();
    wait level.frametime;
    if(self.sessionstate != "playing")
        return;

    if(isDefined(self.pers["isBot"]))
    {
        self.dsr_thinkSlot = level.dsr_slotNext;
        level.dsr_slotNext++;
        self dsrbot\_dsr_motor::DSR_BotStart();
    }
}

DSR_Max(a, b)
{
    if(a > b)
        return a;
    return b;
}
