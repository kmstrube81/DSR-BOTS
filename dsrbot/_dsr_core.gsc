/* *************************************************************************************************
**** _dsr_core.gsc
****
**** Think dispatcher, trace budget, schedule and task engine, bot_ai_level gating (plan 5.2, 5.5).
****   bot_ai_level 1: bots patrol the waypoint graph; no targeting, no shooting
****   bot_ai_level 2: MeatBot parity: they see enemies, face them, fire stand / crouch bursts and reload
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
    maps\mp\uox\_uox_vars::varDef("bot", "ai_engagemax", "int", true, 2, 0, 16, "Bot AI Max Bots Engaging One Target");
    maps\mp\uox\_uox_vars::varDef("bot", "ai_replandist", "int", true, 256, 32, 4096, "Bot AI Goal Move That Triggers A Replan");
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
    DSR_DefineSchedules();
    dsrbot\_dsr_obj::DSR_ObjStart();

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
**** runs once a second so cvar changes apply at runtime. bot_skill is per bot (DSR_ApplySkill).
************************************************************************************************* */
DSR_UpdateBudgets()
{
    level.dsr_aiLevel = [[level.getVars]]("bot_ai_level");
    level.dsr_thinkFrames = DSR_Max(1, (int)([[level.getVars]]("bot_ai_thinkperiod") / level.frametime));
    level.dsr_traceCap = DSR_Max(1, (int)([[level.getVars]]("bot_ai_tracespersec") * level.frametime));
    level.dsr_astarCap = DSR_Max(1, (int)([[level.getVars]]("bot_ai_astarpersec") * level.frametime));
    level.dsr_engageMax = [[level.getVars]]("bot_ai_engagemax");
}

/* *************************************************************************************************
**** DSR_ApplySkill()
****
**** self = bot, from DSR_BotStart. bot_skill 1-10 gives every bot that skill; 0 (the default, "mixed")
**** gives each bot its own skill from 5-9, drawn once per connection and kept in pers so it survives
**** respawns; changing bot_skill re-draws or re-assigns at the next spawn. The combat values (plan 8):
****   reaction  1000 - 80 x skill ms    (920 .. 200)   first sighting to first burst
****   aim error (11 - skill) x 0.25 deg (2.5 .. 0.25)  re-rolled per burst; half as much in pitch. On top
****                                                    of the fire variants' ADS-level hip spread
****   aim rate  360 + 72 x skill deg/s  (432 .. 1080)  turn speed while aiming
****   view cone 45 + 5 x skill deg      (50 .. 95)     each side of straight ahead
****   memory    2000 + 300 x skill ms   (2300 .. 5000) a hidden enemy is forgotten after this
****   pause     900 - 60 x skill ms     (840 .. 300)   between bursts, plus 0-300 ms
**** Burst size also scales with skill (DSR_BurstSize).
************************************************************************************************* */
DSR_ApplySkill()
{
    setting = [[level.getVars]]("bot_skill");
    if(!isDefined(self.pers["dsr_skill"]) || !isDefined(self.pers["dsr_skillSetting"]) || self.pers["dsr_skillSetting"] != setting)
    {
        if(setting <= 0)
            self.pers["dsr_skill"] = 5 + randomInt(5);
        else
            self.pers["dsr_skill"] = setting;
        self.pers["dsr_skillSetting"] = setting;
    }
    skill = self.pers["dsr_skill"];
    self.dsr_skill = skill;
    self.dsr_skReact = 1000 - 80 * skill;
    self.dsr_skAimErr = (11 - skill) * 0.25;
    self.dsr_skAimRate = 360 + 72 * skill;
    self.dsr_skConeCos = cos(45 + 5 * skill);
    self.dsr_skMemory = 2000 + 300 * skill;
    self.dsr_skPause = 900 - 60 * skill;
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

    players = getentarray("player", "classname");
    dsrbot\_dsr_sense::DSR_CountEngaged(players);

    slot = level.dsr_frame % level.dsr_thinkFrames;
    for(i = 0; i < players.size; i++)
    {
        bot = players[i];
        if(!isDefined(bot.dsr_active))
            continue;

        bot dsrbot\_dsr_motor::DSR_MotorFrame(); //every frame: aim, turn, footsteps, clip watch

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
**** one think for one bot (plan 5.2). Never waits: it issues motor commands and polls dsr_motorDone.
****   1. gather conditions (bot_ai_level >= 2)
****   2. drop the schedule if one of its interrupt conditions is set
****   3. select a schedule if there is none
****   4. advance the task; a finished task starts the next one in the same think
**** Phase 2 has no fail schedules (Phase 3): a failed task just selects again.
************************************************************************************************* */
DSR_BotThink()
{
    if(!isDefined(self.dsr_active))
        return;

    if(level.dsr_aiLevel >= 2)
        self dsrbot\_dsr_sense::DSR_GatherConditions();
    else
        self dsrbot\_dsr_sense::DSR_ClearConditions();

    //a defender with a bomb about to go off ignores fights until it has defused (DSR_Interrupted)
    self.dsr_objUrgent = (level.dsr_aiLevel >= 2 && self dsrbot\_dsr_obj::DSR_ObjUrgent());

    if(isDefined(self.dsr_sched))
    {
        reason = self DSR_Interrupted();
        if(isDefined(reason))
        {
            self.dsr_schedReason = reason;
            self.dsr_sched = undefined;
        }
    }
    if(!isDefined(self.dsr_sched))
        self DSR_SetSchedule(self DSR_GetSchedule());

    //standing inside another player: move out before anything else this think
    if(self dsrbot\_dsr_motor::DSR_Unstick())
    {
        self.dsr_replan = true; //the patrol restarts from the nearest node afterwards
        return;
    }

    tasks = level.dsr_sched[self.dsr_sched]["task"];
    for(guard = 0; guard < tasks.size; guard++)
    {
        result = self DSR_RunTask();
        if(result == "running")
            return;
        if(result == "fail")
        {
            if(!isDefined(self.dsr_schedReason))
                self.dsr_schedReason = "fail " + tasks[self.dsr_taskIdx];
            self DSR_SetSchedule(self DSR_GetSchedule());
            return;
        }
        self.dsr_taskIdx++;
        self.dsr_taskStarting = true;
        if(self.dsr_taskIdx >= tasks.size)
        {
            self.dsr_schedReason = "done";
            self DSR_SetSchedule(self DSR_GetSchedule());
            return;
        }
    }
}

/* *************************************************************************************************
**** schedules (plan 5.5). level.dsr_sched[name] = task / param lists plus the interrupt conditions.
**** Built once per map from DSR_CoreStart.
************************************************************************************************* */
DSR_DefineSchedules()
{
    level.dsr_sched = [];

    //a target that is only partly visible doesn't stop the patrol: only a clear shot (CAN_FIRE) or damage
    s = DSR_NewSched();
    s = DSR_AddTask(s, "PATROL", 0);
    s = DSR_AddInterrupt(s, "CAN_FIRE");
    s = DSR_AddInterrupt(s, "LIGHT_DAMAGE");
    s = DSR_AddInterrupt(s, "HEAVY_DAMAGE");
    s = DSR_AddInterrupt(s, "OBJ_ACT");
    s = DSR_AddInterrupt(s, "CAN_MELEE");
    level.dsr_sched["Patrol"] = s;

    //seen but can't shoot (out of range, a teammate in the way), or just lost: face it for a moment
    s = DSR_NewSched();
    s = DSR_AddTask(s, "STOP_MOVING", "now");
    s = DSR_AddTask(s, "FACE_ENEMY", "look");
    s = DSR_AddTask(s, "WAIT_FACE_ENEMY", 1.5);
    s = DSR_AddInterrupt(s, "NEW_ENEMY");
    s = DSR_AddInterrupt(s, "ENEMY_DEAD");
    s = DSR_AddInterrupt(s, "ENEMY_LOST");
    s = DSR_AddInterrupt(s, "CAN_FIRE");
    s = DSR_AddInterrupt(s, "CAN_MELEE");
    level.dsr_sched["CombatFace"] = s;

    //HEAVY_DAMAGE joins the interrupts in Phase 4, when there is cover to run to
    s = DSR_NewSched();
    s = DSR_AddTask(s, "STOP_MOVING", "peek");
    s = DSR_AddTask(s, "FACE_ENEMY", "fire");
    s = DSR_AddTask(s, "CHECK_FIRE", 0);
    s = DSR_AddTask(s, "FIRE_BURST", 0);
    s = DSR_AddTask(s, "CHECK_FIRE", 0);
    s = DSR_AddTask(s, "FIRE_BURST", 0);
    s = DSR_AddTask(s, "CHECK_FIRE", 0);
    s = DSR_AddTask(s, "FIRE_BURST", 0);
    s = DSR_AddInterrupt(s, "NEW_ENEMY");
    s = DSR_AddInterrupt(s, "ENEMY_DEAD");
    s = DSR_AddInterrupt(s, "ENEMY_OCCLUDED");
    s = DSR_AddInterrupt(s, "ENEMY_LOST");
    s = DSR_AddInterrupt(s, "NO_AMMO");
    s = DSR_AddInterrupt(s, "CAN_MELEE");
    level.dsr_sched["RangeAttack"] = s;

    s = DSR_NewSched();
    s = DSR_AddTask(s, "STOP_MOVING", "now");
    s = DSR_AddTask(s, "RELOAD", 0);
    level.dsr_sched["Reload"] = s;

    //faked bomb plant / defuse (_dsr_obj). No interrupts: the task itself decides whether damage aborts it
    s = DSR_NewSched();
    s = DSR_AddTask(s, "STOP_MOVING", "now");
    s = DSR_AddTask(s, "OBJ_ACTION", 0);
    level.dsr_sched["ObjAction"] = s;

    //an enemy close enough to touch (maintainer, moved forward from Phase 6): a melee swing
    s = DSR_NewSched();
    s = DSR_AddTask(s, "STOP_MOVING", "now");
    s = DSR_AddTask(s, "MELEE", 0);
    level.dsr_sched["Melee"] = s;
}

DSR_NewSched()
{
    s = [];
    s["task"] = [];
    s["param"] = [];
    s["int"] = [];
    return s;
}

DSR_AddTask(s, task, param)
{
    n = s["task"].size;
    s["task"][n] = task;
    s["param"][n] = param;
    return s;
}

DSR_AddInterrupt(s, cond)
{
    s["int"][s["int"].size] = cond;
    return s;
}

//the first interrupt condition of the current schedule that is set, or undefined. An urgent defuse
//(dsr_objUrgent) only gives way to the defuse itself
DSR_Interrupted()
{
    if(self.dsr_objUrgent)
    {
        if(self.dsr_sched == "Patrol" && self.dsr_cond["OBJ_ACT"])
            return "OBJ_ACT";
        return undefined;
    }
    list = level.dsr_sched[self.dsr_sched]["int"];
    for(i = 0; i < list.size; i++)
    {
        if(self.dsr_cond[list[i]])
            return list[i];
    }
    return undefined;
}

DSR_SetSchedule(name)
{
    if([[level.getVars]]("bot_ai_debug") >= 2)
    {
        from = "none";
        if(isDefined(self.dsr_schedLast))
            from = self.dsr_schedLast;
        reason = "";
        if(isDefined(self.dsr_schedReason))
            reason = self.dsr_schedReason;
        enemy = "none";
        if(isDefined(self.dsr_enemy))
            enemy = self.dsr_enemy.name;
        if(from != name || reason != "done")
            logprint("DSR: sched " + self.name + " " + from + "->" + name + " reason=" + reason + " enemy=" + enemy + " mag=" + self.dsr_mag + "\n");
    }
    self dsrbot\_dsr_motor::DSR_CeaseFire();
    self dsrbot\_dsr_obj::DSR_ObjActionEnd(); //leaving a plant / defuse unfinished
    self.dsr_sched = name;
    self.dsr_schedLast = name;
    self.dsr_schedReason = undefined;
    self.dsr_taskIdx = 0;
    self.dsr_taskStarting = true;
}

/* *************************************************************************************************
**** DSR_GetSchedule()
****
**** port of CHGrunt::GetSchedule (plan 5.5), Phase 2 lines only; each line is gated by bot_ai_level
************************************************************************************************* */
DSR_GetSchedule()
{
    if(level.dsr_aiLevel < 2)
        return "Patrol";

    //objectives (_dsr_obj): an urgent defuse comes before everything; otherwise a plant or defuse is
    //started whenever the bot has no enemy
    if(self.dsr_objUrgent)
    {
        if(self.dsr_cond["OBJ_ACT"])
            return "ObjAction";
        return "Patrol";
    }

    if(self.dsr_cond["ENEMY_DEAD"])
    {
        if([[level.getVars]]("bot_ai_debug") >= 2 && isDefined(self.dsr_enemy))
            logprint("DSR: enemy " + self.name + " dead " + self.dsr_enemy.name + "\n");
        self dsrbot\_dsr_sense::DSR_ForgetEnemy();
        return "Patrol";
    }
    if(!isDefined(self.dsr_enemy))
    {
        if(self.dsr_cond["OBJ_ACT"])
            return "ObjAction";
        return "Patrol";
    }
    if(self.dsr_cond["CAN_MELEE"])
        return "Melee";
    if(self.dsr_cond["NO_AMMO"] && self dsrbot\_dsr_motor::DSR_ReloadAmount() > 0)
        return "Reload";
    if(self.dsr_cond["CAN_FIRE"])
        return "RangeAttack";
    if(self.dsr_cond["SEE_ENEMY"] && !self.dsr_friendBlock)
    {
        //only partly visible (round or over cover) or out of range: no shot from here, so don't stand and
        //stare: keep moving and work round to it (maintainer, Phase 2)
        //(bel allies running from axis players don't flank them)
        if(!self dsrbot\_dsr_obj::DSR_ObjPassive(self.dsr_enemy))
            self dsrbot\_dsr_sense::DSR_NoteFlank(self.dsr_enemy);
        return "Patrol";
    }
    return "CombatFace"; //a teammate in the way, or hidden and not yet forgotten (DSR_GatherConditions)
}

//runs the current task: "running", "done" or "fail"
DSR_RunTask()
{
    s = level.dsr_sched[self.dsr_sched];
    if(self.dsr_taskIdx >= s["task"].size)
        return "fail"; //never expected; a think that waited would get here (thinks must not wait)
    task = s["task"][self.dsr_taskIdx];
    param = s["param"][self.dsr_taskIdx];
    starting = self.dsr_taskStarting;
    self.dsr_taskStarting = false;
    if(starting)
        self.dsr_taskStart = getTime();

    switch(task)
    {
        case "PATROL":          return self DSR_Task_PATROL(starting);
        case "STOP_MOVING":     return self DSR_Task_STOP_MOVING(param, starting);
        case "FACE_ENEMY":      return self DSR_Task_FACE_ENEMY(param, starting);
        case "WAIT_FACE_ENEMY": return self DSR_Task_WAIT_FACE_ENEMY(param, starting);
        case "CHECK_FIRE":      return self DSR_Task_CHECK_FIRE();
        case "FIRE_BURST":      return self DSR_Task_FIRE_BURST(starting);
        case "RELOAD":          return self DSR_Task_RELOAD(starting);
        case "OBJ_ACTION":      return self dsrbot\_dsr_obj::DSR_Task_OBJ_ACTION(starting);
        case "MELEE":           return self DSR_Task_MELEE(starting);
    }
    return "fail";
}

/* *************************************************************************************************
**** tasks (plan 5.5): DSR_Task_<NAME>, each returns "running", "done" or "fail"
************************************************************************************************* */

//the Phase 1 patrol; after a fight (dsr_replan) it starts again from the nearest visible node. A new flank
//request (dsr_flankPending, from DSR_NoteFlank) drops the current walk or camp so the next goal is the flank
DSR_Task_PATROL(starting)
{
    if(starting)
    {
        self.dsr_aiming = undefined;
        if(isDefined(self.dsr_replan))
        {
            self.dsr_replan = undefined;
            if(self.dsr_state != "lost")
                DSR_SetState("start");
        }
    }
    if(isDefined(self.dsr_flankPending) && self.dsr_state != "lost" && self dsrbot\_dsr_motor::DSR_MotorStop())
    {
        self.dsr_flankPending = undefined;
        self.dsr_flankWanted = true;
        DSR_SetState("start");
    }
    //the objective moved or changed (a bomb planted, a flag taken): drop the walk and plan again
    else if(self.dsr_state == "moving" && isDefined(self.dsr_objGoalWp) && self dsrbot\_dsr_obj::DSR_ObjReplan()
        && self dsrbot\_dsr_motor::DSR_MotorStop())
    {
        if([[level.getVars]]("bot_ai_debug") >= 2)
            logprint("DSR: obj " + self.name + " replan\n");
        self.dsr_objGoalWp = undefined;
        DSR_SetState("start");
    }
    self DSR_PatrolThink();
    return "running";
}

/* *************************************************************************************************
**** MELEE (maintainer; MeatBot StabKnife)
****
**** swaps to bot_melee_mp (its idle is the melee swing, playeranim.script) with the stock swing sound and,
**** 0.4 s in, kills the enemy if it is still alive and within 72 units: MOD_MELEE damage through the
**** gametype's damage callback, as MeatBot does, with the stock hit sound. No voice line (maintainer).
**** Done after 1 s; the next schedule restores the weapon.
************************************************************************************************* */
DSR_Task_MELEE(starting)
{
    now = getTime();
    if(starting)
    {
        if(!isDefined(self.dsr_enemy))
            return "fail";
        self.dsr_meleeTarget = self.dsr_enemy;
        self.dsr_meleeHitAt = now + 400;
        self.dsr_aiming = true;
        self dsrbot\_dsr_motor::DSR_SetFireMode("special", "bot_melee_mp");
        self playSound("melee_swing_large"); //stock MP alias (generic_mp_sound.csv), as a human's swing
    }

    target = self.dsr_meleeTarget;
    if(isDefined(self.dsr_meleeHitAt) && now >= self.dsr_meleeHitAt)
    {
        self.dsr_meleeHitAt = undefined;
        if(isPlayer(target) && isAlive(target) && target.sessionstate == "playing"
            && distanceSquared(self.origin, target.origin) < 72 * 72)
        {
            if([[level.getVars]]("bot_ai_debug") >= 1)
                logprint("DSR: melee " + self.name + " killed " + target.name + "\n");
            target playSound("melee_hit");
            dir = vectorNormalize(target.origin - self.origin);
            target thread [[level.callbackPlayerDamage]](self, self, 200, 0, "MOD_MELEE", "bot_melee_mp",
                target.origin + (0, 0, 40), dir, "torso_upper");
        }
    }
    if(now - self.dsr_taskStart >= 1000)
        return "done";
    return "running";
}

/* *************************************************************************************************
**** STOP_MOVING("now" | "peek")
****
**** halts the bot where it is; waits for a jump, fall or ladder to finish first. "peek" (maintainer,
**** Phase 2): a bot that spots its target while walking keeps going for 150-300 ms more (in practice the
**** next think, about one stride) while turning to it, so it steps out past the corner it just looked
**** round instead of stopping half hidden.
************************************************************************************************* */
DSR_Task_STOP_MOVING(param, starting)
{
    if(starting)
    {
        self.dsr_stopAt = 0;
        if(param == "peek" && self.dsr_moving && !isDefined(self.dsr_special))
        {
            self.dsr_stopAt = getTime() + 150 + randomInt(150);
            self.dsr_aiming = true;
        }
    }
    if(getTime() < self.dsr_stopAt && self.dsr_moving)
        return "running";
    if(!self dsrbot\_dsr_motor::DSR_MotorStop())
        return "running";
    self.dsr_replan = true;
    return "done";
}

/* *************************************************************************************************
**** FACE_ENEMY("fire" | "look")
****
**** turns to the enemy. "fire" swaps to this attack's stand or crouch fire variant now, so the raise
**** overlaps the turn; "look" keeps a fire variant if one is held, else raises the binoculars (hold).
**** Done when aimed, or after 1.5 s.
************************************************************************************************* */
DSR_Task_FACE_ENEMY(param, starting)
{
    if(starting)
    {
        self.dsr_aiming = true;
        if(param == "fire")
            self dsrbot\_dsr_motor::DSR_SetFireMode(self dsrbot\_dsr_motor::DSR_PickStance());
        else if(!isDefined(self.dsr_fireMode) || (self.dsr_fireMode != "fire_stand" && self.dsr_fireMode != "fire_crouch"))
            self dsrbot\_dsr_motor::DSR_SetFireMode("hold");
    }
    if(self dsrbot\_dsr_motor::DSR_AimSettled() || getTime() - self.dsr_taskStart > 1500)
        return "done";
    return "running";
}

DSR_Task_WAIT_FACE_ENEMY(seconds, starting)
{
    self.dsr_aiming = true;
    if(getTime() - self.dsr_taskStart >= seconds * 1000)
        return "done";
    return "running";
}

DSR_Task_CHECK_FIRE()
{
    if(self.dsr_cond["CAN_FIRE"])
        return "done";
    return "fail";
}

/* *************************************************************************************************
**** FIRE_BURST
****
**** aim (wait out the reaction delay and for the aim to settle, with a fresh skill-scaled aim error),
**** fire (load the burst; DSR_FireFrame sees the clip empty), pause (short, skill-scaled). Gives up after
**** 5 s. The empty clip during the pause can dry-fire: VERIFY how audible that is (Phase 2 decision).
**** After a burst that hit nothing the bot may give up on the target (DSR_BurstMissed): the task fails and
**** the bot moves on.
************************************************************************************************* */
DSR_Task_FIRE_BURST(starting)
{
    if(starting)
    {
        self.dsr_aiming = true;
        self.dsr_burstStep = "aim";
        self.dsr_taskData = getTime() + 5000;
        err = self.dsr_skAimErr;
        self.dsr_aimErrYaw = (randomFloat(2) - 1) * err;
        self.dsr_aimErrPitch = (randomFloat(2) - 1) * err * 0.5;
    }
    if(getTime() > self.dsr_taskData)
    {
        self dsrbot\_dsr_motor::DSR_CeaseFire();
        return "done";
    }

    if(self.dsr_burstStep == "aim")
    {
        if(getTime() < self.dsr_reactUntil || !self dsrbot\_dsr_motor::DSR_AimSettled())
            return "running";
        self dsrbot\_dsr_motor::DSR_StartBurst(self dsrbot\_dsr_motor::DSR_BurstSize());
        self.dsr_burstStart = getTime();
        self.dsr_burstStep = "fire";
        return "running";
    }
    if(self.dsr_burstStep == "fire")
    {
        if(isDefined(self.dsr_firing))
            return "running";
        if(self dsrbot\_dsr_sense::DSR_BurstMissed(self.dsr_burstStart))
        {
            self.dsr_schedReason = "giveup";
            return "fail";
        }
        self.dsr_pauseUntil = getTime() + self.dsr_skPause + randomInt(300);
        self.dsr_burstStep = "pause";
    }
    if(getTime() < self.dsr_pauseUntil)
        return "running";
    return "done";
}

/* *************************************************************************************************
**** RELOAD
****
**** holds a fire variant and starts the engine reload (DSR_StartReload); done when DSR_FireFrame has
**** moved the new clip into dsr_mag. After 6 s without a reload it falls back to MeatBot's refill.
************************************************************************************************* */
DSR_Task_RELOAD(starting)
{
    if(starting)
    {
        amount = self dsrbot\_dsr_motor::DSR_ReloadAmount();
        if(amount <= 0)
            return "fail";
        if(!isDefined(self.dsr_fireMode) || (self.dsr_fireMode != "fire_stand" && self.dsr_fireMode != "fire_crouch"))
            self dsrbot\_dsr_motor::DSR_SetFireMode(self dsrbot\_dsr_motor::DSR_PickStance());
        self.dsr_taskData = amount;
        self dsrbot\_dsr_motor::DSR_StartReload(amount);
        return "running";
    }
    if(!isDefined(self.dsr_reloading))
        return "done";
    if(getTime() - self.dsr_taskStart > 6000)
    {
        self dsrbot\_dsr_motor::DSR_ReloadFallback(self.dsr_taskData);
        return "done";
    }
    return "running";
}

/* *************************************************************************************************
**** DSR_PatrolThink()
****
**** the Phase 1 patrol state machine, run by the PATROL task; acts only when the motor is idle
****   start    -> walk to the nearest visible node
****   idle     -> pick a goal and queue a path
****   waitpath -> path ready: follow it; failed: pick again (greedy hop after 3 failures)
****   moving   -> arrived: maybe hold at a camp node, then idle
****   camp     -> hold finished: idle
************************************************************************************************* */
DSR_PatrolThink()
{
    if(!self.dsr_motorDone)
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
            goal = self dsrbot\_dsr_nav::DSR_PickPatrolGoal(self.dsr_wp);
            if(isDefined(self.dsr_objGoalWp))
            {
                if(goal == self.dsr_wp)
                {
                    //already at the objective's node
                    DSR_ObjArrive();
                    return;
                }
                //close to the objective: walk straight there rather than round the graph (waypoint chains
                //are often one-way, so the nearest node can be a long path away)
                if(self.dsr_objMode == "reach" && distanceSquared(self.origin, self.dsr_objPos) < 256 * 256)
                {
                    go = self dsrbot\_dsr_obj::DSR_ObjApproach();
                    if(go < 0)
                        return; //trace budget refused: try again next think
                    if(go)
                    {
                        DSR_ObjStartApproach();
                        return;
                    }
                }
            }
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
            if(isDefined(self.dsr_objGoalWp) && self.dsr_wp == self.dsr_objGoalWp)
            {
                DSR_ObjArrive();
                return;
            }
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

        case "approach":
            //walked off the graph onto the objective itself: stay on it for a while
            self.dsr_motorTime = 3 + randomFloat(3);
            DSR_SetState("camp");
            self dsrbot\_dsr_motor::DSR_MotorCommand("hold");
            break;

        case "lost":
            //no node anywhere near: nothing to do until the next spawn
            break;
    }
}

/* *************************************************************************************************
**** DSR_ObjArrive()
****
**** self = bot that reached the node of its objective goal (_dsr_obj). reach mode: walks straight on to
**** the objective position when the line to it is clear, then stays there 3-6 s; hold mode, or no clear
**** line: camps on the node (2-6 s, half the time when holding) and picks the next goal.
************************************************************************************************* */
DSR_ObjArrive()
{
    self.dsr_objGoalWp = undefined;
    go = self dsrbot\_dsr_obj::DSR_ObjApproach();
    if(go < 0)
        return; //trace budget refused: try again next think
    if(go)
    {
        DSR_ObjStartApproach();
        return;
    }
    if(self.dsr_objMode == "reach" || randomInt(2))
    {
        self.dsr_motorTime = 2 + randomFloat(4);
        DSR_SetState("camp");
        self dsrbot\_dsr_motor::DSR_MotorCommand("hold");
        return;
    }
    DSR_SetState("idle");
}

//walks off the graph onto the objective (DSR_ObjApproach checked the way and set dsr_pointPos)
DSR_ObjStartApproach()
{
    self.dsr_objGoalWp = undefined;
    if([[level.getVars]]("bot_ai_debug") >= 2)
        logprint("DSR: obj " + self.name + " approach dist=" + (int)(distance(self.origin, self.dsr_pointPos)) + "\n");
    DSR_SetState("approach");
    self dsrbot\_dsr_motor::DSR_MotorCommand("point");
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

    //round-based gametypes restart the map every round, and the bots spawn while nav is still being built
    //(a few frames: grid, reverse edges, goal set): wait for it rather than giving this life stock behaviour
    while(!isDefined(level.dsr_navDone) || !level.dsr_navDone)
        wait level.frametime;
    if(self.sessionstate != "playing")
        return;

    if(!isDefined(level.dsr_aiLevel) || level.dsr_aiLevel < 1 || !level.dsr_navReady)
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
