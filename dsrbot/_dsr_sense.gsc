/* *************************************************************************************************
**** _dsr_sense.gsc
****
**** Perception: the two tag-linked marks per player (plan 3.2, 7), the targeting rule (plan 2.4), enemy
**** acquisition, the Phase 2 conditions (plan 5.4) and damage memory.
**** There is no getTagOrigin in UO, so a script_origin linked to a tag stands in for the tag's position.
**** VERIFY which tags hit best; MeatBot linked six, DSR keeps two.
************************************************************************************************* */

/* *************************************************************************************************
**** DSR_MarksLink()
****
**** self = player who just spawned. Creates the two marks on first use (never more), then re-links them to
**** the player's tags on every spawn.
************************************************************************************************* */
DSR_MarksLink()
{
    if(!isDefined(self.dsr_marks))
    {
        self.dsr_marks = [];
        self.dsr_marks[0] = spawn("script_origin", self.origin);
        self.dsr_marks[1] = spawn("script_origin", self.origin);
    }

    self.dsr_marks[0] unlink();
    self.dsr_marks[0] linkTo(self, "tag_helmet", (0, 0, 0), (0, 0, 0));
    self.dsr_marks[1] unlink();
    self.dsr_marks[1] linkTo(self, "tag_breastpocket_left", (0, 0, 0), (0, 0, 0));
}

/* *************************************************************************************************
**** DSR_MarksDelete()
****
**** self = disconnecting player
************************************************************************************************* */
DSR_MarksDelete()
{
    if(!isDefined(self.dsr_marks))
        return;
    for(i = 0; i < self.dsr_marks.size; i++)
    {
        if(isDefined(self.dsr_marks[i]))
            self.dsr_marks[i] delete();
    }
    self.dsr_marks = undefined;
}

/* *************************************************************************************************
**** DSR_IsValidTarget(player)
****
**** self = bot. The one targeting rule (plan 2.4): any other living, playing player, and in teamplay only
**** players on the other team
************************************************************************************************* */
DSR_IsValidTarget(player)
{
    if(!isDefined(player) || !isPlayer(player) || player == self)
        return false;
    if(player.sessionstate != "playing" || !isAlive(player))
        return false;
    if(level.uox_teamplay)
    {
        if(!isDefined(player.pers["team"]) || player.pers["team"] == "spectator" || player.pers["team"] == self.pers["team"])
            return false;
    }
    return true;
}

/* *************************************************************************************************
**** DSR_SenseReset()
****
**** self = bot, at the start of every life
************************************************************************************************* */
DSR_SenseReset()
{
    self.dsr_standoff = undefined;
    self.dsr_standoffMeleed = undefined;
    self.dsr_standoffShot = undefined;
    self.dsr_enemy = undefined;
    self.dsr_lastEnemy = undefined;
    self.dsr_enemyLastPos = undefined;
    self.dsr_enemyLastSeen = 0;
    self.dsr_reactUntil = 0;
    self.dsr_friendBlock = false;
    self.dsr_clearShot = false;
    self.dsr_ignore = [];
    self.dsr_missBursts = 0;
    self.dsr_lastHitTime = 0;
    self.dsr_dmgPending = undefined;
    self.dsr_dmgHint = undefined;
    self.dsr_lastDmgTime = 0;
    self.dsr_lastDmgPos = undefined;
    self.dsr_dmgTaken = 0;
    self.dsr_flankTarget = undefined;
    self.dsr_flankTime = 0;
    self.dsr_flankPending = undefined;
    self.dsr_flankWanted = undefined;
    self DSR_ClearConditions();
}

DSR_ClearConditions()
{
    self.dsr_cond = [];
    self.dsr_cond["SEE_ENEMY"] = false;
    self.dsr_cond["NEW_ENEMY"] = false;
    self.dsr_cond["ENEMY_DEAD"] = false;
    self.dsr_cond["ENEMY_OCCLUDED"] = false;
    self.dsr_cond["ENEMY_LOST"] = false;
    self.dsr_cond["CAN_FIRE"] = false;
    self.dsr_cond["OBJ_ACT"] = false;
    self.dsr_cond["CAN_MELEE"] = false;
    self.dsr_cond["NO_AMMO"] = false;
    self.dsr_cond["LIGHT_DAMAGE"] = false;
    self.dsr_cond["HEAVY_DAMAGE"] = false;
}

/* *************************************************************************************************
**** DSR_GatherConditions()
****
**** self = bot, once per think (bot_ai_level >= 2). Conditions are separate bools in self.dsr_cond, since
**** bitwise ops on ints are still VERIFY (plan 2.1). A refused trace keeps the previous SEE_ENEMY.
************************************************************************************************* */
DSR_GatherConditions()
{
    see = false;
    newEnemy = false;
    dead = false;
    occluded = false;
    lost = false;
    canFire = false;
    light = false;
    heavy = false;
    noAmmo = (self.dsr_mag <= 0);

    if(isDefined(self.dsr_dmgPending))
    {
        if(self.dsr_dmgPending == "heavy")
            heavy = true;
        else
            light = true;
        self.dsr_dmgPending = undefined;
    }

    //out of every round (bot_unlimitedammo 0): nothing to fight with, so don't look for enemies
    if(noAmmo && self.dsr_reserve == 0)
    {
        self DSR_ForgetEnemy();
        self.dsr_lastEnemy = undefined;
    }
    else if(isDefined(self.dsr_enemy) && !self DSR_IsValidTarget(self.dsr_enemy))
        dead = true;
    else
    {
        vis = self DSR_FindEnemy();
        if(vis < 0)
        {
            //budget refused: unknown, keep the previous value
            vis = 0;
            if(self.dsr_cond["SEE_ENEMY"])
            {
                vis = 1;
                if(self.dsr_clearShot)
                    vis = 2;
            }
        }
        self.dsr_clearShot = (vis == 2);

        if(isDefined(self.dsr_enemy) && self DSR_ShouldYield(self.dsr_enemy))
        {
            //too many bots on this target already, and this one is the farthest: leave it and flank
            if([[level.getVars]]("bot_ai_debug") >= 2)
                logprint("DSR: enemy " + self.name + " yield " + self.dsr_enemy.name + " engaged=" + DSR_EngagedCount(self.dsr_enemy) + "\n");
            self DSR_NoteFlank(self.dsr_enemy);
            self DSR_ForgetEnemy();
            lost = true;
        }
        else if(isDefined(self.dsr_enemy))
        {
            if(vis)
            {
                see = true;
                self.dsr_enemyLastPos = self.dsr_enemy.origin;
                self.dsr_enemyLastSeen = getTime();
            }
            else if(getTime() - self.dsr_enemyLastSeen > self.dsr_skMemory)
            {
                if([[level.getVars]]("bot_ai_debug") >= 2)
                    logprint("DSR: enemy " + self.name + " lost " + self.dsr_enemy.name + "\n");
                self DSR_ForgetEnemy();
                lost = true;
            }
            else
                occluded = true;
        }
    }

    if(isDefined(self.dsr_enemy) && (!isDefined(self.dsr_lastEnemy) || self.dsr_enemy != self.dsr_lastEnemy))
    {
        newEnemy = true;
        self.dsr_reactUntil = getTime() + self.dsr_skReact;
        self.dsr_missBursts = 0;
        level.dsr_tmAcquire++;
        if([[level.getVars]]("bot_ai_debug") >= 2)
            logprint("DSR: enemy " + self.name + " new " + self.dsr_enemy.name + " see=" + see + " dist=" + (int)(distance(self.origin, self.dsr_enemy.origin)) + "\n");
    }
    self.dsr_lastEnemy = self.dsr_enemy;

    if(see && self.dsr_clearShot && !self.dsr_friendBlock && !noAmmo)
    {
        range = level.dsr_range[self.dsr_weapon];
        if(distanceSquared(self.origin, self.dsr_enemy.origin) <= range * range)
            canFire = true;
        //bel allies only fight when hurt or when the axis player is close (_dsr_obj)
        if(canFire && self dsrbot\_dsr_obj::DSR_ObjPassive(self.dsr_enemy))
            canFire = false;
    }

    self.dsr_cond["SEE_ENEMY"] = see;
    self.dsr_cond["NEW_ENEMY"] = newEnemy;
    self.dsr_cond["ENEMY_DEAD"] = dead;
    self.dsr_cond["ENEMY_OCCLUDED"] = occluded;
    self.dsr_cond["ENEMY_LOST"] = lost;
    self.dsr_cond["CAN_FIRE"] = canFire;
    self.dsr_cond["OBJ_ACT"] = self dsrbot\_dsr_obj::DSR_ObjCanAct();
    self.dsr_cond["CAN_MELEE"] = (see && self DSR_MeleeRoll());
    self.dsr_cond["NO_AMMO"] = noAmmo;
    self.dsr_cond["LIGHT_DAMAGE"] = light;
    self.dsr_cond["HEAVY_DAMAGE"] = heavy;
}

/* *************************************************************************************************
**** DSR_MeleeRoll()
****
**** self = bot that sees its enemy. With the enemy within 56 units (2D; 64 up or down), once a second a
**** chance of 25% at skill 5 up to 45% at skill 9 (maintainer: point-blank standoffs, often two bots
**** stuck against each other, should end in a melee kill)
************************************************************************************************* */
DSR_MeleeRoll()
{
    e = self.dsr_enemy;
    d = (e.origin[0] - self.origin[0], e.origin[1] - self.origin[1], 0);
    dz = e.origin[2] - self.origin[2];
    if(distanceSquared(d, (0, 0, 0)) > 56 * 56 || dz > 64 || dz < -64)
        return false;
    now = getTime();
    if(isDefined(self.dsr_meleeNext) && now < self.dsr_meleeNext)
        return false;
    self.dsr_meleeNext = now + 1000;
    return randomInt(100) < 25 + 5 * (self.dsr_skill - 5);
}

/* *************************************************************************************************
**** DSR_StandoffTarget()
****
**** self = bot. The enemy it has been pressed up against for 1-2 s (random, so the two bots of a standoff
**** don't both act on the same think), then every 1.5 s while it lasts; undefined otherwise. Pressed up:
**** within 80 units (2D; 64 up or down), and either overlapping (under 32: no wall fits between) or the
**** enemy it currently sees (a wall between them otherwise)
************************************************************************************************* */
DSR_StandoffTarget()
{
    best = undefined;
    bestD = 0;
    players = getentarray("player", "classname");
    for(i = 0; i < players.size; i++)
    {
        p = players[i];
        if(!self DSR_IsValidTarget(p))
            continue;
        d = (p.origin[0] - self.origin[0], p.origin[1] - self.origin[1], 0);
        dz = p.origin[2] - self.origin[2];
        dd = distanceSquared(d, (0, 0, 0));
        if(dd > 80 * 80 || dz > 64 || dz < -64)
            continue;
        if(dd >= 32 * 32 && (!self.dsr_cond["SEE_ENEMY"] || self.dsr_enemy != p))
            continue;
        if(!isDefined(best) || dd < bestD)
        {
            best = p;
            bestD = dd;
        }
    }
    if(!isDefined(best))
    {
        self.dsr_standoff = undefined;
        self.dsr_standoffMeleed = undefined;
        return undefined;
    }
    if(!isDefined(self.dsr_standoff) || self.dsr_standoff != best)
    {
        self.dsr_standoff = best;
        self.dsr_standoffMeleed = undefined;
        self.dsr_standoffAt = getTime() + 1000 + randomInt(1000);
        return undefined;
    }
    if(getTime() < self.dsr_standoffAt)
        return undefined;
    self.dsr_standoffAt = getTime() + 1500;
    return best;
}

DSR_ForgetEnemy()
{
    self.dsr_enemy = undefined;
    self.dsr_aiming = undefined;
}

/* *************************************************************************************************
**** DSR_FindEnemy()
****
**** self = bot. Returns DSR_CanSee's answer for self.dsr_enemy (possibly a new one): 2 clear, 1 partly
**** visible, 0 hidden, -1 refused. The current enemy is rechecked first (at most 2 traces); only when it
**** is hidden are other players tried: the nearest 2 inside sight range and the view cone (the last
**** attacker skips the cone), at most 2 traces each. Skipped without a trace: targets this bot gave up on
**** (DSR_IsIgnoring) and targets with a full set of engaged bots (DSR_MayEngage).
************************************************************************************************* */
DSR_FindEnemy()
{
    self.dsr_friendBlock = false;
    eye = self DSR_EyePos();
    enemy = self.dsr_enemy;
    if(isDefined(enemy))
    {
        r = self DSR_CanSee(enemy, eye);
        if(r != 0)
            return r;
    }

    range = level.dsr_range[self.dsr_weapon];
    if(range < 1900)
        range = 1900; //MeatBot's minimum sight range
    rangeSq = range * range;
    fwd = anglesToForward((0, self.dsr_curYaw, 0));
    hint = undefined;
    if(isDefined(self.dsr_dmgHint) && getTime() - self.dsr_lastDmgTime < 3000)
        hint = self.dsr_dmgHint;

    players = getentarray("player", "classname");
    tried = undefined;
    for(pick = 0; pick < 2; pick++)
    {
        best = undefined;
        bestSq = rangeSq;
        for(i = 0; i < players.size; i++)
        {
            p = players[i];
            if(isDefined(enemy) && p == enemy)
                continue;
            if(isDefined(tried) && p == tried)
                continue;
            if(!self DSR_IsValidTarget(p))
                continue;
            d = distanceSquared(eye, p.origin);
            if(d >= bestSq)
                continue;
            if(!isDefined(hint) || p != hint)
            {
                dir = vectorNormalize((p.origin[0] - eye[0], p.origin[1] - eye[1], 0));
                if(vectorDot(fwd, dir) < self.dsr_skConeCos)
                    continue;
            }
            if(self DSR_IsIgnoring(p))
                continue;
            if(!self DSR_MayEngage(p))
            {
                self DSR_NoteFlank(p); //already engaged by enough bots: no trace, flank instead
                continue;
            }
            best = p;
            bestSq = d;
        }
        if(!isDefined(best))
            return 0;

        r = self DSR_CanSee(best, eye);
        if(r > 0)
        {
            self.dsr_enemy = best;
            return r;
        }
        if(r < 0)
            return -1;
        tried = best;
    }
    return 0;
}

/* *************************************************************************************************
**** DSR_CanSee(target, eye)
****
**** 2 = clear shot (chest mark visible), 1 = partly visible (only the helmet mark: peeking over or round
**** cover), 0 = hidden, -1 = refused. Traces from the bot's helmet mark to the target's chest, then
**** helmet, hitting players. A hit on the target counts as visible; a hit on a player who isn't a valid
**** target (a teammate) also counts, but sets dsr_friendBlock so the bot won't fire through them.
**** Only a clear shot allows CAN_FIRE, so bots don't stop and plink at a corner a target barely shows at.
************************************************************************************************* */
DSR_CanSee(target, eye)
{
    for(m = 1; m >= 0; m--)
    {
        if(isDefined(target.dsr_marks))
            pos = target.dsr_marks[m].origin;
        else if(m == 0)
            pos = target.origin + (0, 0, 60);
        else
            pos = target.origin + (0, 0, 40);

        trace = dsrbot\_dsr_core::DSR_Trace(eye, pos, true, self);
        if(!isDefined(trace))
            return -1;
        visible = false;
        if(trace["fraction"] == 1)
            visible = true;
        else if(isDefined(trace["entity"]))
        {
            if(trace["entity"] == target)
                visible = true;
            else if(isPlayer(trace["entity"]) && !self DSR_IsValidTarget(trace["entity"]))
            {
                self.dsr_friendBlock = true;
                visible = true;
            }
        }
        if(visible)
            return m + 1;
    }
    return 0;
}

//the bot's eye: its helmet mark, which follows the stand / crouch animation
DSR_EyePos()
{
    if(isDefined(self.dsr_marks))
        return self.dsr_marks[0].origin;
    return self.origin + (0, 0, 60);
}

/* *************************************************************************************************
**** engage slots (maintainer, Phase 2; HL's ENGAGE slots per target instead of per squad, plan 5.5 / 7)
****
**** At most bot_ai_engagemax bots (default 2, 0 = no limit) fight one target. A bot that would be one too
**** many keeps patrolling and flanks instead. Exception: a bot within 400 units that is also the closest
**** bot to the target always fights, and then the farthest engaged bot yields. "Engaged" = has the
**** target as dsr_enemy and is in a combat schedule (not Patrol). No traces.
************************************************************************************************* */

//level fast loop, once per frame before the thinks: level.dsr_engCount[target entity number]
DSR_CountEngaged(players)
{
    level.dsr_engCount = [];
    for(i = 0; i < players.size; i++)
    {
        p = players[i];
        if(!isDefined(p.dsr_active) || !isDefined(p.dsr_enemy) || !isPlayer(p.dsr_enemy))
            continue;
        if(!isDefined(p.dsr_sched) || p.dsr_sched == "Patrol")
            continue;
        k = p.dsr_enemy getEntityNumber();
        if(!isDefined(level.dsr_engCount[k]))
            level.dsr_engCount[k] = 0;
        level.dsr_engCount[k]++;
    }
}

DSR_EngagedCount(target)
{
    k = target getEntityNumber();
    if(!isDefined(level.dsr_engCount) || !isDefined(level.dsr_engCount[k]))
        return 0;
    return level.dsr_engCount[k];
}

DSR_IsEngagedWith(target)
{
    return (isDefined(self.dsr_active) && isDefined(self.dsr_enemy) && self.dsr_enemy == target
        && isDefined(self.dsr_sched) && self.dsr_sched != "Patrol");
}

//self = bot not engaged with target yet: is there a free slot, or does the close-and-closest rule apply?
DSR_MayEngage(target)
{
    if(level.dsr_engageMax <= 0 || DSR_EngagedCount(target) < level.dsr_engageMax)
        return true;
    return self DSR_IsClosestWithin400(target);
}

//self = bot with target as its enemy: true when the target has a full set of other bots on it, this bot
//isn't within 400 and closest, and no other engaged bot is farther away than this one
DSR_ShouldYield(target)
{
    if(level.dsr_engageMax <= 0)
        return false;
    others = DSR_EngagedCount(target);
    if(self DSR_IsEngagedWith(target))
        others--;
    if(others < level.dsr_engageMax || self DSR_IsClosestWithin400(target))
        return false;

    myDist = distanceSquared(self.origin, target.origin);
    players = getentarray("player", "classname");
    for(i = 0; i < players.size; i++)
    {
        p = players[i];
        if(p != self && p DSR_IsEngagedWith(target) && distanceSquared(p.origin, target.origin) > myDist)
            return false;
    }
    return true;
}

//within 400 units of target and no other bot hostile to it is closer
DSR_IsClosestWithin400(target)
{
    myDist = distanceSquared(self.origin, target.origin);
    if(myDist >= 400 * 400)
        return false;
    players = getentarray("player", "classname");
    for(i = 0; i < players.size; i++)
    {
        p = players[i];
        if(p == self || !isDefined(p.dsr_active) || !(p DSR_IsValidTarget(target)))
            continue;
        if(distanceSquared(p.origin, target.origin) < myDist)
            return false;
    }
    return true;
}

//asks the patrol to flank target (DSR_Task_PATROL, DSR_PickFlankGoal); at most once per target per 10 s
DSR_NoteFlank(target)
{
    if(self DSR_IsIgnoring(target))
        return;
    if(isDefined(self.dsr_flankTarget) && self.dsr_flankTarget == target && getTime() - self.dsr_flankTime < 10000)
        return;
    self.dsr_flankTarget = target;
    self.dsr_flankTime = getTime();
    self.dsr_flankPending = true;
    level.dsr_tmFlanks++;
    if([[level.getVars]]("bot_ai_debug") >= 2)
        logprint("DSR: flankreq " + self.name + " target=" + target.name + " engaged=" + DSR_EngagedCount(target) + "\n");
}

/* *************************************************************************************************
**** DSR_OnDamaged(attacker, damage)
****
**** self = player, from DSR_PlayerDamage before the default handler; never waits.
**** - attacker is a bot shooting its enemy (self): stamps the hit, for the give-up rule (DSR_BurstMissed)
**** - self is a bot: records damage memory for the next think and, if it has no visible enemy, makes the
****   attacker its enemy so it turns toward them (replaces MeatBot's PlayerDamage turn). A target it gave up
****   on only counts again if this bot is within 400 units and closest to it.
**** VERIFY: 50 as the heavy damage threshold.
************************************************************************************************* */
DSR_OnDamaged(attacker, damage)
{
    if(isPlayer(attacker) && attacker != self && isDefined(attacker.dsr_active)
        && isDefined(attacker.dsr_enemy) && attacker.dsr_enemy == self)
        attacker.dsr_lastHitTime = getTime();

    if(!isDefined(self.dsr_active) || level.dsr_aiLevel < 2)
        return;

    self.dsr_lastDmgTime = getTime();
    self.dsr_dmgTaken += damage;
    if(damage >= 50)
        self.dsr_dmgPending = "heavy";
    else if(!isDefined(self.dsr_dmgPending))
        self.dsr_dmgPending = "light";

    if(!self DSR_IsValidTarget(attacker))
        return;
    if(self DSR_IsIgnoring(attacker) && !self DSR_IsClosestWithin400(attacker))
        return;
    self.dsr_lastDmgPos = attacker.origin;
    self.dsr_dmgHint = attacker;
    if(!isDefined(self.dsr_enemy) || !self.dsr_cond["SEE_ENEMY"])
    {
        self.dsr_enemy = attacker;
        self.dsr_enemyLastPos = attacker.origin;
        self.dsr_enemyLastSeen = getTime();
    }
}

/* *************************************************************************************************
**** give up after missing (maintainer, Phase 2)
****
**** After each burst: a hit on the enemy since the burst started resets the count of missed bursts. From
**** the 3rd missed burst in a row the bot gives up with a chance of 20% x (missed - 2): 20%, 40%, 60% ...
**** It then ignores that target for 10 s (no targeting, no flanking it, damage from it ignored unless
**** this bot is within 400 units and closest) and moves on. Typical cause: a target behind cover that
**** only the helmet trace reaches, or a long shot the bot keeps missing.
************************************************************************************************* */

//self = bot; burstStart = getTime() when the burst was loaded. Returns true when the bot gives up
DSR_BurstMissed(burstStart)
{
    if(self.dsr_lastHitTime >= burstStart)
    {
        self.dsr_missBursts = 0;
        return false;
    }
    self.dsr_missBursts++;
    if(self.dsr_missBursts < 3 || randomInt(100) >= 20 * (self.dsr_missBursts - 2))
        return false;

    target = self.dsr_enemy;
    if(isDefined(target))
    {
        self.dsr_ignore[target getEntityNumber()] = getTime() + 10000;
        level.dsr_tmGiveUps++;
        if([[level.getVars]]("bot_ai_debug") >= 2)
            logprint("DSR: enemy " + self.name + " giveup " + target.name + " missed=" + self.dsr_missBursts + "\n");
    }
    self.dsr_missBursts = 0;
    self DSR_ForgetEnemy();
    return true;
}

DSR_IsIgnoring(target)
{
    k = target getEntityNumber();
    return (isDefined(self.dsr_ignore[k]) && getTime() < self.dsr_ignore[k]);
}
