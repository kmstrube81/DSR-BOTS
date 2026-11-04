/* *************************************************************************************************
**** _dsr_obj.gsc
****
**** Objective goals per level.objective (Phase 2.5, maintainer; bot_ai_level >= 2). Each bot picks a role
**** when it spawns; DSR_GetObjectiveGoal turns the role and the objective's current state into a position
**** and a mode:
****   "reach"  go to the position itself (touch a flag, stand at a radio or command post, plant, defuse)
****   "hold"   stay around it: short walks between nodes within 512 units, camping at some of them
**** Fighting still comes first (DSR_GetSchedule); between fights the patrol heads for the objective. The
**** objective state is read from CODUO-X's own level fields (_uox_bombs, _uox_flags, _uox_radios,
**** _uox_commandposts, _uox_retrievals); bomb plants and defuses are faked here (DSR_Task_OBJ_ACTION),
**** since CODUO-X gives bots no hold-use input.
****   bomb         attackers: plant at site A or B (50/50); after a plant, guard the bomb.
****                defenders: guard A or B (50/50); after a plant, go and defuse.
****   ctf          50/50 attack (take the enemy flag, carry it to the goal) or defend (stay by the flag,
****                chase its carrier, return it when dropped)
****   radio        the active HQ radio: guard it when the bot's team holds it, else take it
****   commandpost  50/50 attack the nearest post not held by the bot's team, or guard the nearest one it
****   (and base)   holds; with none of the wanted kind it does the other
****   retrieval    attackers take the nearest objective to its goal; defenders guard it
****   bel          allies keep away from axis players and only fight when hurt or when one is within 600
************************************************************************************************* */

DSR_ObjStart()
{
    level.dsr_objective = "none";
    if(isDefined(level.objective))
        level.dsr_objective = level.objective;
    if(level.dsr_objective == "base")
        level.dsr_objective = "commandpost";

    level.dsr_plantedAt = [];
    if(level.dsr_objective == "bomb")
        maps\mp\uox\_uox_loops::addToLoop(level, "medium", ::DSR_BombWatch, "DSR_BombWatch");
}

//level medium loop, bomb modes: when each site's bomb was planted (CODUO-X keeps no per-site time)
DSR_BombWatch()
{
    if(!isDefined(level.bombsites))
        return;
    sites = DSR_Sites();
    for(i = 0; i < sites.size; i++)
    {
        s = sites[i];
        if(level.bombsites[s]["planted"])
        {
            if(!isDefined(level.dsr_plantedAt[s]))
                level.dsr_plantedAt[s] = getTime();
        }
        else
            level.dsr_plantedAt[s] = undefined;
    }
}

DSR_Sites()
{
    sites = [];
    sites[0] = "A";
    sites[1] = "B";
    return sites;
}

DSR_ObjActive()
{
    return isDefined(level.dsr_aiLevel) && level.dsr_aiLevel >= 2 && isDefined(level.dsr_objective) && level.dsr_objective != "none";
}

/* *************************************************************************************************
**** DSR_ObjSpawn()
****
**** self = bot, from DSR_BotStart: picks this life's role
************************************************************************************************* */
DSR_ObjSpawn()
{
    self.dsr_objRole = undefined;
    self.dsr_objSite = undefined;
    self.dsr_objPos = undefined;
    self.dsr_objPickPos = undefined;
    self.dsr_objUrgent = false;
    self DSR_ObjActionEnd();
    if(!isDefined(level.dsr_objective))
        return;

    switch(level.dsr_objective)
    {
        case "ctf":
        case "commandpost":
            self.dsr_objRole = "attack";
            if(randomInt(2))
                self.dsr_objRole = "defend";
            break;
        case "bomb":
            self.dsr_objSite = "A";
            if(randomInt(2))
                self.dsr_objSite = "B";
            break;
    }
}

/* *************************************************************************************************
**** DSR_GetObjectiveGoal()
****
**** self = bot. The objective position for this bot now, with self.dsr_objMode "reach" or "hold", or
**** undefined (no objective: patrol as usual). Also sets self.dsr_objPos.
************************************************************************************************* */
DSR_GetObjectiveGoal()
{
    pos = undefined;
    self.dsr_objDirect = undefined; //set when the goal is a planted bomb: shortest path, no variety (nav)
    if(DSR_ObjActive())
    {
        switch(level.dsr_objective)
        {
            case "bomb":        pos = self DSR_GoalBomb(); break;
            case "ctf":         pos = self DSR_GoalCtf(); break;
            case "radio":       pos = self DSR_GoalRadio(); break;
            case "commandpost": pos = self DSR_GoalPost(); break;
            case "retrieval":   pos = self DSR_GoalRetrieval(); break;
        }
    }
    self.dsr_objPos = pos;
    return pos;
}

DSR_SetMode(mode, pos)
{
    self.dsr_objMode = mode;
    return pos;
}

//bomb: attackers plant at their site, then guard a planted bomb; defenders guard their site, then defuse
DSR_GoalBomb()
{
    if(!isDefined(level.bombsites) || !isDefined(game["attackers"]))
        return undefined;

    planted = self DSR_NearestBomb();
    if(isDefined(planted))
        self.dsr_objDirect = true; //the bomb is ticking: get there the quickest way (maintainer)
    if(self.pers["team"] == game["attackers"])
    {
        if(isDefined(planted))
            return self DSR_SetMode("hold", planted.origin);
        site = self.dsr_objSite;
        zone = getent("bombzone_" + site, "targetname");
        if(!isDefined(zone) || level.bombsites[site]["exploded"] || level.bombsites[site]["planted"])
        {
            //that site is done: the other one
            if(site == "A")
                site = "B";
            else
                site = "A";
            zone = getent("bombzone_" + site, "targetname");
            if(!isDefined(zone) || level.bombsites[site]["exploded"] || level.bombsites[site]["planted"])
                return undefined;
        }
        return self DSR_SetMode("reach", zone.origin);
    }

    if(isDefined(planted))
        return self DSR_SetMode("reach", planted.origin);
    zone = getent("bombzone_" + self.dsr_objSite, "targetname");
    if(!isDefined(zone))
        return undefined;
    return self DSR_SetMode("hold", zone.origin);
}

//the defuse trigger of the planted bomb nearest the bot, or undefined
DSR_NearestBomb()
{
    best = undefined;
    bestD = 0;
    triggers = getentarray("bombtrigger", "targetname");
    for(i = 0; i < triggers.size; i++)
    {
        t = triggers[i];
        if(!isDefined(t.bomb) || !isDefined(t.bomb.objectiveName) || !level.bombsites[t.bomb.objectiveName]["planted"])
            continue;
        d = distanceSquared(self.origin, t.origin);
        if(!isDefined(best) || d < bestD)
        {
            best = t;
            bestD = d;
        }
    }
    return best;
}

//milliseconds left on the bomb behind defuse trigger t (0 if unknown)
DSR_BombLeft(t)
{
    site = t.bomb.objectiveName;
    if(!isDefined(level.dsr_plantedAt[site]))
        return level.countdowntime * 1000;
    return level.countdowntime * 1000 - (getTime() - level.dsr_plantedAt[site]);
}

DSR_GoalCtf()
{
    if(!isDefined(level.allies_flag) || !isDefined(level.axis_flag))
        return undefined;
    own = level.axis_flag;
    enemy = level.allies_flag;
    if(self.pers["team"] == "allies")
    {
        own = level.allies_flag;
        enemy = level.axis_flag;
    }

    if(isDefined(enemy.carried_by) && enemy.carried_by == self)
        return self DSR_SetMode("reach", enemy.goal.origin);

    if(self.dsr_objRole == "attack")
    {
        pos = enemy maps\mp\uox\_uox_flags::get_flag_position();
        if(isDefined(enemy.carried_by))
            return self DSR_SetMode("hold", pos); //a teammate has it: go with them
        return self DSR_SetMode("reach", pos);
    }

    pos = own maps\mp\uox\_uox_flags::get_flag_position();
    if(isDefined(own.carried_by) || own.moved)
        return self DSR_SetMode("reach", pos); //chase the carrier, or return the dropped flag
    return self DSR_SetMode("hold", pos);
}

DSR_GoalRadio()
{
    if(!isDefined(level.radio))
        return undefined;
    for(i = 0; i < level.radio.size; i++)
    {
        r = level.radio[i];
        if(!isDefined(r) || r.hidden)
            continue;
        if(r.team == self.pers["team"])
            return self DSR_SetMode("hold", r.origin);
        return self DSR_SetMode("reach", r.origin);
    }
    return undefined;
}

//commandpost: the nearest post not held (attack) or held (defend) by the bot's team; the other kind when
//there is none of the wanted kind
DSR_GoalPost()
{
    if(!isDefined(level.flags))
        return undefined;
    team = self.pers["team"];
    want = (self.dsr_objRole == "defend");
    for(pass = 0; pass < 2; pass++)
    {
        best = undefined;
        bestD = 0;
        for(i = 0; i < level.flags.size; i++)
        {
            f = level.flags[i];
            if(!isDefined(f) || !isDefined(f.team) || (f.team == team) != want)
                continue;
            pos = DSR_PostPos(f);
            d = distanceSquared(self.origin, pos);
            if(!isDefined(best) || d < bestD)
            {
                best = pos;
                bestD = d;
            }
        }
        if(isDefined(best))
        {
            if(want)
                return self DSR_SetMode("hold", best);
            return self DSR_SetMode("reach", best);
        }
        want = !want;
    }
    return undefined;
}

//a command post's position: its neutral flag model (as CODUO-X's compass uses), else the trigger origin
DSR_PostPos(f)
{
    if(!isDefined(f.dsr_pos))
    {
        model = getent("flag" + f.id + "_neutral", "targetname");
        if(isDefined(model))
            f.dsr_pos = model.origin;
        else
            f.dsr_pos = f.origin;
    }
    return f.dsr_pos;
}

//retrieval: attackers take the nearest objective nobody holds and carry it to its goal; defenders guard it
DSR_GoalRetrieval()
{
    if(!isDefined(level.retrieval_objective) || !isDefined(game["re_attackers"]))
        return undefined;
    attacker = (self.pers["team"] == game["re_attackers"]);

    best = undefined;
    bestD = 0;
    for(i = 0; i < level.retrieval_objective.size; i++)
    {
        o = level.retrieval_objective[i];
        if(!isDefined(o))
            continue;
        if(attacker && isDefined(self.hasobj) && isDefined(self.hasobj[o.objnum]) && self.hasobj[o.objnum] == o
            && isDefined(o.goal))
            return self DSR_SetMode("reach", o.goal.origin);
        d = distanceSquared(self.origin, o.origin);
        if(!isDefined(best) || d < bestD)
        {
            best = o;
            bestD = d;
        }
    }
    if(!isDefined(best))
        return undefined;
    if(attacker)
        return self DSR_SetMode("reach", best.origin);
    return self DSR_SetMode("hold", best.origin);
}

/* *************************************************************************************************
**** DSR_ObjPickGoal(from)
****
**** self = bot, from DSR_PickPatrolGoal. The patrol goal node for the objective, or -1 for a random goal.
**** reach: the node nearest the position. hold: a random node within 512 units of it (the nearest node if
**** none). bel allies: of 8 random nodes, the one farthest from the nearest living axis player.
************************************************************************************************* */
DSR_ObjPickGoal(from)
{
    if(!DSR_ObjActive())
        return -1;
    if(level.dsr_objective == "bel")
        return self DSR_FleeGoal(from);

    pos = self DSR_GetObjectiveGoal();
    if(!isDefined(pos))
        return -1;

    cand = dsrbot\_dsr_nav::DSR_NearbyCandidates(pos, 16);
    nearest = -1;
    near = [];
    for(i = 0; i < cand.size; i++)
    {
        n = cand[i];
        if(!isDefined(level.dsr_wpGoal[n]))
            continue;
        if(nearest < 0)
            nearest = n; //candidates come nearest first
        if(distanceSquared(level.wp[n].origin, pos) < 512 * 512)
            near[near.size] = n;
    }
    if(nearest < 0)
        return -1;
    self.dsr_objPickPos = pos;
    self.dsr_objPickMode = self.dsr_objMode;
    self.dsr_objCheckAt = getTime() + 1000;
    if(self.dsr_objMode == "hold" && near.size)
        return near[randomInt(near.size)];
    return nearest;
}

DSR_FleeGoal(from)
{
    if(self.pers["team"] != "allies")
        return -1;
    axis = [];
    players = getentarray("player", "classname");
    for(i = 0; i < players.size; i++)
    {
        if(players[i].sessionstate == "playing" && players[i].pers["team"] == "axis")
            axis[axis.size] = players[i];
    }
    if(!axis.size)
        return -1;

    goals = level.dsr_goalWps;
    best = -1;
    bestD = -1;
    for(k = 0; k < 8; k++)
    {
        n = goals[randomInt(goals.size)];
        o = level.wp[n].origin;
        nearD = -1;
        for(i = 0; i < axis.size; i++)
        {
            d = distanceSquared(o, axis[i].origin);
            if(nearD < 0 || d < nearD)
                nearD = d;
        }
        if(nearD > bestD)
        {
            best = n;
            bestD = nearD;
        }
    }
    return best;
}

/* *************************************************************************************************
**** DSR_ObjApproach()
****
**** self = bot near its reach-mode objective. 1 when it may walk straight toward dsr_objPos, with the spot
**** in self.dsr_pointPos; 0 when it may not or is already within 24 units; -1 when the trace budget
**** refused. Objective origins are poor walk targets (a bombzone's is the middle of its trigger brush, in
**** the air or inside the crate the site is built round), so the bot aims at that point level with its own
**** feet and walks as far as the way is clear: knee (16) and waist (40) traces, stopping 24 units short of
**** whatever they hit, with floor within step height (18) under the spot (plan 6.4). Touching the trigger
**** anywhere is enough to plant. Up to 3 traces; the reason it can't is logged at bot_ai_debug 2.
************************************************************************************************* */
DSR_ObjApproach()
{
    if(!isDefined(self.dsr_objPos) || self.dsr_objMode != "reach")
        return 0;
    pos = self.dsr_objPos;
    flat = (pos[0], pos[1], self.origin[2]);
    dist = distance(self.origin, flat);
    if(dist < 24)
        return 0;
    dir = vectorNormalize(flat - self.origin);

    frac = 1;
    for(h = 16; h <= 40; h += 24)
    {
        trace = dsrbot\_dsr_core::DSR_Trace(self.origin + (0, 0, h), flat + (0, 0, h), false, self);
        if(!isDefined(trace))
            return -1;
        if(trace["fraction"] < frac)
            frac = trace["fraction"];
    }
    reach = dist * frac;
    if(frac < 1)
        reach -= 24;
    if(reach < 16)
        return self DSR_ApproachFail("blocked", dist);

    spot = self.origin + (dir[0] * reach, dir[1] * reach, 0);
    trace = dsrbot\_dsr_core::DSR_Trace(spot + (0, 0, 18), spot + (0, 0, -40), false, self);
    if(!isDefined(trace))
        return -1;
    if(trace["fraction"] == 1)
        return self DSR_ApproachFail("nofloor", dist);
    floor = trace["position"];
    dz = floor[2] - self.origin[2];
    if(dz > 18 || dz < -18)
        return self DSR_ApproachFail("step", dist);
    self.dsr_pointPos = floor;
    return 1;
}

DSR_ApproachFail(why, dist)
{
    if([[level.getVars]]("bot_ai_debug") >= 2)
        logprint("DSR: obj " + self.name + " noapproach " + why + " dist=" + (int)dist + "\n");
    return 0;
}

/* *************************************************************************************************
**** DSR_ObjReplan()
****
**** self = bot walking to an objective goal. Plan 6.3: replan when the goal moved more than
**** bot_ai_replandist since it was picked, or switched between reach and hold (a bomb planted, a flag taken).
**** Checked once a second.
************************************************************************************************* */
DSR_ObjReplan()
{
    if(!isDefined(self.dsr_objPickPos) || getTime() < self.dsr_objCheckAt)
        return false;
    self.dsr_objCheckAt = getTime() + 1000;
    mode = self.dsr_objPickMode;
    picked = self.dsr_objPickPos;
    pos = self DSR_GetObjectiveGoal();
    if(!isDefined(pos))
        return true;
    dist = [[level.getVars]]("bot_ai_replandist");
    return self.dsr_objMode != mode || distanceSquared(pos, picked) > dist * dist;
}

/* *************************************************************************************************
**** bel (maintainer): an allied bot leaves an axis player alone unless it was hurt in the last 5 s or the
**** axis player is within 600 units
************************************************************************************************* */
DSR_ObjPassive(enemy)
{
    if(!DSR_ObjActive() || level.dsr_objective != "bel" || self.pers["team"] != "allies" || !isDefined(enemy))
        return false;
    if(isDefined(self.dsr_lastDmgTime) && getTime() - self.dsr_lastDmgTime < 5000)
        return false;
    return distanceSquared(self.origin, enemy.origin) > 600 * 600;
}

/* *************************************************************************************************
**** faked bomb plant / defuse (maintainer, Phase 2.5)
****
**** A bot touching a bombzone it may plant at, or within 64 units of a planted bomb it may defuse
**** (CODUO-X's own tests: canPlant / canDefuse, less the use key and the look direction), runs the
**** ObjAction schedule: it crouches with its weapon disabled for scr_bombplanttime / scr_bombdefusetime
**** seconds, marking the trigger .doing as a human's hold does, then calls CODUO-X's plantBomb / defuseBomb.
**** Damage aborts it and the bot fights, unless aborting would lose: a plant the round timer would not
**** leave time to start again, a defuse the bomb timer would not. A defender with less than
**** 2 x scr_bombdefusetime left on a bomb is urgent: it heads for the bomb and defuses, ignoring fights.
************************************************************************************************* */

//self = bot. Sets dsr_objAct / dsr_objTrigger when it can start a plant or defuse here
DSR_ObjCanAct()
{
    self.dsr_objAct = undefined;
    self.dsr_objTrigger = undefined;
    if(!DSR_ObjActive() || level.dsr_objective != "bomb" || !isDefined(level.bombsites) || !game["matchstarted"])
        return false;
    if(level.roundended || level.mapended || level.halftime)
        return false;

    if(self.pers["team"] == game["attackers"])
    {
        sites = DSR_Sites();
        for(i = 0; i < sites.size; i++)
        {
            s = sites[i];
            zone = getent("bombzone_" + s, "targetname");
            if(!isDefined(zone) || isDefined(zone.doing) || level.bombsites[s]["planted"] || level.bombsites[s]["exploded"])
                continue;
            if(level.bombmode < 1 && isDefined(zone.bombzone_other) && isDefined(zone.bombzone_other.doing))
                continue;
            if(!(self isTouching(zone)))
                continue;
            self.dsr_objAct = "plant";
            self.dsr_objTrigger = zone;
            return true;
        }
        return false;
    }

    t = self DSR_NearestBomb();
    if(!isDefined(t) || isDefined(t.doing) || distance(self.origin, t.origin) >= 64)
        return false;
    self.dsr_objAct = "defuse";
    self.dsr_objTrigger = t;
    return true;
}

//self = bot. A defender with a bomb about to go off: defusing comes before everything
DSR_ObjUrgent()
{
    if(!DSR_ObjActive() || level.dsr_objective != "bomb" || !isDefined(level.bombsites)
        || self.pers["team"] != game["defenders"])
        return false;
    t = self DSR_NearestBomb();
    if(!isDefined(t))
        return false;
    return self DSR_BombLeft(t) < 2 * [[level.getVars]]("scr_bombdefusetime") * 1000;
}

//seconds left on the round timer, or -1 when it isn't running (no limit, or paused by a planted bomb)
DSR_RoundLeft()
{
    if(!isDefined(level.roundTimeLeft) || !isDefined(level.roundresumetime) || level.roundTimeLeft <= 0)
        return -1;
    if(level.bombsites["A"]["planted"] || level.bombsites["B"]["planted"])
        return -1;
    return level.roundTimeLeft - (getTime() - level.roundresumetime) / 1000;
}

DSR_Task_OBJ_ACTION(starting)
{
    now = getTime();
    if(starting)
    {
        if(!self DSR_ObjCanAct())
            return "fail";
        //DSR_ObjCanAct runs every think and resets dsr_objAct; the action in progress is dsr_objDoing
        self.dsr_objDoing = self.dsr_objAct;
        if(self.dsr_objDoing == "plant")
            self.dsr_objTime = [[level.getVars]]("scr_bombplanttime") * 1000;
        else
            self.dsr_objTime = [[level.getVars]]("scr_bombdefusetime") * 1000;
        self.dsr_objEnd = now + self.dsr_objTime;
        self.dsr_objTrigger.doing = true;
        self.dsr_objActing = self.dsr_objTrigger;
        self.dsr_objBusy = true;
        self dsrbot\_dsr_motor::DSR_SetFireMode("fire_crouch");
        self disableWeapon();
        //the sound a human's plant / defuse makes (CODUO-X passes these to addHoldUse)
        if(self.dsr_objDoing == "plant")
            self playSound("MP_bomb_plant");
        else
            self playSound("MP_bomb_defuse");
        self DSR_ObjLog("start");
    }

    t = self.dsr_objActing;
    if(!isDefined(t) || level.roundended || level.mapended || level.halftime
        || (self.dsr_objDoing == "plant" && (level.bombsites[t.objectiveName]["planted"] || level.bombsites[t.objectiveName]["exploded"]))
        || (self.dsr_objDoing == "defuse" && (!isDefined(t.bomb) || !level.bombsites[t.bomb.objectiveName]["planted"])))
    {
        self DSR_ObjActionEnd();
        return "fail";
    }

    if((self.dsr_cond["LIGHT_DAMAGE"] || self.dsr_cond["HEAVY_DAMAGE"]) && !self DSR_ObjCommitted(now))
    {
        self DSR_ObjLog("hurt");
        self DSR_ObjActionEnd();
        self.dsr_schedReason = "obj hurt";
        return "fail";
    }

    if(now < self.dsr_objEnd)
        return "running";

    act = self.dsr_objDoing;
    self DSR_ObjLog("done");
    self DSR_ObjActionEnd();
    //threaded: plantBomb waits (8 s before clearing the planted text), and a think must never wait
    if(act == "plant")
        self thread maps\mp\uox\_uox_bombs::plantBomb(t);
    else
        self thread maps\mp\uox\_uox_bombs::defuseBomb(t);
    return "done";
}

//true when stopping now would lose: not enough time left to start the plant / defuse again
DSR_ObjCommitted(now)
{
    remaining = self.dsr_objEnd - now;
    if(self.dsr_objDoing == "plant")
    {
        left = DSR_RoundLeft();
        return left >= 0 && left * 1000 < remaining + self.dsr_objTime;
    }
    return self DSR_BombLeft(self.dsr_objActing) < remaining + self.dsr_objTime;
}

//self = bot. Ends a plant / defuse in progress (done, aborted, schedule change, death or disconnect)
DSR_ObjActionEnd()
{
    //dsr_objBusy, not dsr_objActing: the trigger may already be gone (CODUO-X deletes the bombzones and
    //the defuse trigger), and the weapon must come back regardless
    if(!isDefined(self.dsr_objBusy))
        return;
    if(isDefined(self.dsr_objActing))
        self.dsr_objActing.doing = undefined;
    self.dsr_objActing = undefined;
    self.dsr_objBusy = undefined;
    if(isPlayer(self))
        self enableWeapon();
}

DSR_ObjLog(what)
{
    if([[level.getVars]]("bot_ai_debug") < 1)
        return;
    site = "?";
    t = self.dsr_objActing;
    if(isDefined(t) && isDefined(t.objectiveName))
        site = t.objectiveName;
    else if(isDefined(t) && isDefined(t.bomb) && isDefined(t.bomb.objectiveName))
        site = t.bomb.objectiveName;
    logprint("DSR: obj " + self.name + " " + self.dsr_objDoing + " " + what + " site=" + site
        + " left=" + (int)((self.dsr_objEnd - getTime()) / 100) / 10.0 + "\n");
}
