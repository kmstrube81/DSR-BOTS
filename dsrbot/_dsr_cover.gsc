/* *************************************************************************************************
**** _dsr_cover.gsc
****
**** Cover (plan 5.1, Phase 4, bot_ai_level 4): lateral cover and graph cover (HL FindLateralCover /
**** FindCover), DSR_CheckLocalMove (plan 6.4) and the cover tasks of TakeCover, HideReload,
**** WaitInCover, PeekFire and ReturnToCover (_dsr_core schedules).
**** Per-bot fields:
****   dsr_coverPos    where the bot took cover; dsr_coverKind "lateral" (off the graph) or "node"
****   dsr_coverCrouch true for low cover: the threat sees the head but not the chest, so the bot crouches
****   dsr_inCover     set on arrival (REMEMBER_INCOVER); DSR_InCover also checks the bot is still there
****   dsr_peekPos     where it stood when the cover search started (it had a line to the enemy there)
****   dsr_coverRounds waits and peeks in this cover without seeing the enemy (3 peeks: leave and pursue)
**** VERIFY the cover heights below (crouched head and chest) against the bot's crouch animation.
************************************************************************************************* */

/* *************************************************************************************************
**** DSR_CheckLocalMove(from, to)
****
**** self = bot. Plan 6.4: before a move off the graph, knee (16) and waist (40) traces from -> to must hit
**** nothing, and a ground trace at to must find the floor within step height (18), which to is snapped
**** to (self.dsr_lmPos). 1 = clear, 0 = blocked, -1 = trace budget refused (try again next think).
************************************************************************************************* */
DSR_CheckLocalMove(from, to)
{
    for(h = 16; h <= 40; h += 24)
    {
        trace = dsrbot\_dsr_core::DSR_Trace(from + (0, 0, h), to + (0, 0, h), false, self);
        if(!isDefined(trace))
            return -1;
        if(trace["fraction"] < 1)
            return 0;
    }
    trace = dsrbot\_dsr_core::DSR_Trace(to + (0, 0, 18), to + (0, 0, -40), false, self);
    if(!isDefined(trace))
        return -1;
    if(trace["fraction"] == 1)
        return 0;
    floor = trace["position"];
    dz = floor[2] - from[2];
    if(dz > 18 || dz < -18)
        return 0;
    self.dsr_lmPos = floor;
    return 1;
}

//self = bot. Where the threat looks from: the enemy's helmet mark while it is seen, else head height at
//its last known position; undefined with no enemy to hide from
DSR_ThreatEye()
{
    e = self.dsr_enemy;
    if(isDefined(e) && self.dsr_cond["SEE_ENEMY"] && isDefined(e.dsr_marks))
        return e.dsr_marks[0].origin;
    if(isDefined(self.dsr_enemyLastPos))
        return self.dsr_enemyLastPos + (0, 0, 60);
    if(isDefined(e))
        return e.origin + (0, 0, 60);
    return undefined;
}

/* *************************************************************************************************
**** DSR_CoverTest(eye, spot)
****
**** world traces (no characters) from the threat's eye to head (56) and chest (32) height above spot:
**** 2 = full cover (both hidden), 1 = low cover (head seen, chest hidden: crouch there), 0 = none,
**** -1 = refused
************************************************************************************************* */
DSR_CoverTest(eye, spot)
{
    head = dsrbot\_dsr_core::DSR_Trace(eye, spot + (0, 0, 56), false, self);
    if(!isDefined(head))
        return -1;
    chest = dsrbot\_dsr_core::DSR_Trace(eye, spot + (0, 0, 32), false, self);
    if(!isDefined(chest))
        return -1;
    if(chest["fraction"] == 1)
        return 0;
    if(head["fraction"] < 1)
        return 2;
    return 1;
}

//true while the bot is at the cover it arrived at
DSR_InCover()
{
    return isDefined(self.dsr_inCover) && isDefined(self.dsr_coverPos)
        && distanceSquared(self.origin, self.dsr_coverPos) < 64 * 64;
}

//forgets the cover (it left it, or the fight is over)
DSR_LeaveCover()
{
    self.dsr_inCover = undefined;
    self.dsr_coverPos = undefined;
    self.dsr_peeking = undefined;
    self.dsr_peekStand = undefined;
    self.dsr_coverRounds = 0;
}

//a live teammate already uses cover within 128 units of pos (plan 7: HL FValidateCover spacing)
DSR_CoverTaken(pos)
{
    players = getentarray("player", "classname");
    for(i = 0; i < players.size; i++)
    {
        p = players[i];
        if(p == self || !isDefined(p.dsr_active) || !isDefined(p.dsr_coverPos) || p.sessionstate != "playing")
            continue;
        if(level.uox_teamplay && p.pers["team"] != self.pers["team"])
            continue;
        if(distanceSquared(p.dsr_coverPos, pos) < 128 * 128)
            return true;
    }
    return false;
}

/* *************************************************************************************************
**** FIND_COVER_FROM_ENEMY
****
**** HL order: lateral cover first, then graph cover. Spread over thinks: at most 3 candidates per think,
**** and a refused trace retries the same candidate next think.
****   lateral: 5 spots x 48 units on each side, across the line to the threat, nearest first; a side
****            whose nearer spot was blocked is skipped (the farther ones are behind the same wall)
****   graph:   the bot_ai_covercand nodes nearest the bot (none when 0), from a rotating start index so
****            bots near each other try different nodes; within 784 units of the bot, at least 192 from
****            the threat, not taken by a teammate (DSR_CoverTaken). The path there is asked for here.
**** Done with dsr_coverPos / dsr_coverKind / dsr_coverCrouch set; fails when nothing is found.
************************************************************************************************* */
DSR_Task_FIND_COVER_FROM_ENEMY(starting)
{
    if(starting)
    {
        eye = self DSR_ThreatEye();
        if(!isDefined(eye))
            return "fail";
        self DSR_LeaveCover();
        self.dsr_cvEye = eye;
        self.dsr_cvFrom = self.origin;
        self.dsr_peekPos = self.origin;
        away = vectorNormalize((self.origin[0] - eye[0], self.origin[1] - eye[1], 0));
        self.dsr_cvSide = (0 - away[1], away[0], 0);
        self.dsr_cvSgn = 1;
        if(randomInt(2))
            self.dsr_cvSgn = -1;
        self.dsr_cvBlocked = [];
        self.dsr_cvIdx = 0;
        self.dsr_cvNodes = undefined;
        self.dsr_cvStage = "lateral";
        self.dsr_cvDirect = true;
    }

    if(self.dsr_cvStage == "path")
    {
        if(self.dsr_pathState == "ready")
            return self DSR_CoverFound("node");
        if(self.dsr_pathState == "failed")
            return "fail";
        return "running";
    }

    for(checks = 0; checks < 3; checks++)
    {
        if(self.dsr_cvStage == "lateral")
        {
            k = self.dsr_cvIdx;
            if(k >= 10)
            {
                self.dsr_cvStage = "nodes";
                self.dsr_cvIdx = 0;
                continue;
            }
            side = k % 2;
            if(isDefined(self.dsr_cvBlocked[side]))
            {
                self.dsr_cvIdx++;
                continue;
            }
            sgn = self.dsr_cvSgn;
            if(side)
                sgn = 0 - sgn;
            dist = 48 * (1 + (int)(k / 2));
            spot = self.dsr_cvFrom + (self.dsr_cvSide[0] * sgn * dist, self.dsr_cvSide[1] * sgn * dist, 0);
            r = self DSR_CheckLocalMove(self.dsr_cvFrom, spot);
            if(r < 0)
                return "running";
            if(r == 0)
            {
                self.dsr_cvBlocked[side] = true;
                self.dsr_cvIdx++;
                continue;
            }
            spot = self.dsr_lmPos;
            if(self DSR_CoverTaken(spot))
            {
                self.dsr_cvIdx++;
                continue;
            }
            c = self DSR_CoverTest(self.dsr_cvEye, spot);
            if(c < 0)
                return "running";
            self.dsr_cvIdx++;
            if(c > 0)
            {
                self.dsr_coverPos = spot;
                self.dsr_coverCrouch = (c == 1);
                return self DSR_CoverFound("lateral");
            }
            continue;
        }

        //graph cover
        if(level.dsr_coverCand <= 0)
            return "fail";
        if(!isDefined(self.dsr_cvNodes))
        {
            self.dsr_cvNodes = dsrbot\_dsr_nav::DSR_NearbyCandidates(self.origin, level.dsr_coverCand);
            if(!isDefined(level.dsr_coverRot))
                level.dsr_coverRot = 0;
            level.dsr_coverRot++;
            self.dsr_cvStart = 0;
            if(self.dsr_cvNodes.size)
                self.dsr_cvStart = level.dsr_coverRot % self.dsr_cvNodes.size;
        }
        if(self.dsr_cvIdx >= self.dsr_cvNodes.size)
            return "fail";
        n = self.dsr_cvNodes[(self.dsr_cvStart + self.dsr_cvIdx) % self.dsr_cvNodes.size];
        pos = level.wp[n].origin;
        flat = (self.dsr_cvEye[0], self.dsr_cvEye[1], pos[2]);
        if(!isDefined(level.dsr_wpGoal[n]) || distanceSquared(pos, self.origin) > 784 * 784
            || distanceSquared(pos, flat) < 192 * 192 || self DSR_CoverTaken(pos))
        {
            self.dsr_cvIdx++;
            continue;
        }
        c = self DSR_CoverTest(self.dsr_cvEye, pos);
        if(c < 0)
            return "running";
        self.dsr_cvIdx++;
        if(c <= 0)
            continue;
        start = self dsrbot\_dsr_nav::DSR_NearestVisibleWp(self.origin);
        if(start == -2)
        {
            self.dsr_cvIdx--; //trace budget refused: this node again next think
            return "running";
        }
        if(start < 0)
            return "fail";
        self.dsr_coverPos = pos;
        self.dsr_coverCrouch = (c == 1);
        self.dsr_cvDirect = (start == n); //the node it is next to: walk straight there, no path
        if(self.dsr_cvDirect)
            return self DSR_CoverFound("node");
        self dsrbot\_dsr_nav::DSR_RequestPath(start, n);
        self.dsr_cvStage = "path";
        return "running";
    }
    return "running";
}

DSR_CoverFound(kind)
{
    self.dsr_coverKind = kind;
    if([[level.getVars]]("bot_ai_debug") >= 2)
    {
        low = "full";
        if(self.dsr_coverCrouch)
            low = "low";
        logprint("DSR: cover " + self.name + " " + kind + " " + low + " dist=" + (int)(distance(self.origin, self.dsr_coverPos))
            + " checked=" + self.dsr_cvIdx + "\n");
    }
    return "done";
}

//walks to the cover: straight there (lateral, DSR_CheckLocalMove passed) or along the path (node)
DSR_Task_RUN_TO_COVER(starting)
{
    if(starting)
    {
        if(!isDefined(self.dsr_coverPos))
            return "fail";
        if(self.dsr_cvDirect)
        {
            self.dsr_pointPos = self.dsr_coverPos;
            self dsrbot\_dsr_motor::DSR_MotorCommand("point");
        }
        else
            self dsrbot\_dsr_motor::DSR_MotorCommand("elof");
    }
    if(!self.dsr_motorDone)
        return "running";
    self.dsr_replan = true; //the patrol starts again from the nearest node afterwards
    return "done";
}

//arrived: the bot is in cover now (or the walk was cut short and the cover is lost)
DSR_Task_REMEMBER_INCOVER()
{
    if(!isDefined(self.dsr_coverPos) || distanceSquared(self.origin, self.dsr_coverPos) > 64 * 64)
    {
        self DSR_LeaveCover();
        return "fail";
    }
    self.dsr_inCover = true;
    self.dsr_peeking = undefined;
    self.dsr_peekStand = undefined;
    self dsrbot\_dsr_squad::DSR_Speak("statements", 3); //in position
    return "done";
}

/* *************************************************************************************************
**** PEEK
****
**** one look out of cover for PeekFire (CAN_FIRE interrupts it into RangeAttack):
****   low cover:  stand up where it is (the fire variant's stand pose lifts the head over the cover)
****   full cover: lateral cover only, back to dsr_peekPos (where it last had a line to the enemy)
**** Waits up to 1.5 s for a shot, then done (the bot goes back to WaitInCover / ReturnToCover).
************************************************************************************************* */
DSR_Task_PEEK(starting)
{
    if(starting)
    {
        self.dsr_coverRounds++;
        self.dsr_peeking = true;
        self.dsr_taskData = undefined;
        if(self.dsr_coverCrouch)
        {
            self.dsr_peekStand = true;
            self.dsr_aiming = true;
            self dsrbot\_dsr_motor::DSR_SetFireMode("fire_stand");
            self.dsr_taskData = getTime() + 1500;
        }
        else if(self.dsr_coverKind == "lateral" && isDefined(self.dsr_peekPos))
        {
            self.dsr_pointPos = self.dsr_peekPos;
            self dsrbot\_dsr_motor::DSR_MotorCommand("point");
        }
        else
            return "fail";
        if([[level.getVars]]("bot_ai_debug") >= 2)
            logprint("DSR: peek " + self.name + " round=" + self.dsr_coverRounds + " crouch=" + self.dsr_coverCrouch + "\n");
    }
    if(!isDefined(self.dsr_taskData))
    {
        if(!self.dsr_motorDone)
            return "running";
        self.dsr_aiming = true;
        self dsrbot\_dsr_motor::DSR_SetFireMode(self dsrbot\_dsr_motor::DSR_PickStance());
        self.dsr_taskData = getTime() + 1500;
    }
    if(getTime() < self.dsr_taskData)
        return "running";
    return "done";
}
