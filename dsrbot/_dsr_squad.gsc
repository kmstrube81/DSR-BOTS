/* *************************************************************************************************
**** _dsr_squad.gsc
****
**** Phase 3 chatter: bots speak only through the stock quick-chat lines (plan 2.5), sent as the same
**** menuresponse a human's quick-chat menu sends, so CODUO-X routes them to the stock _teams::quick*
**** functions (head icon, say text, the stock 2 s spam delay). Numbers (stock UO _teams.gsc):
****   commands   2 move in, 4 suppressing fire, 7 hold position
****   statements 1 enemy spotted, 2 enemy down, 3 in position, 4 area secure
****   responses  3 on my way, 5 great shot
****
**** Phase 5 squads (bot_ai_level 5, teamplay only; plan 5.5, HL's CSquadMonster). Maintainer choices:
****   - squads share information only (enemy, ENGAGE slots, callouts); each bot keeps its own patrol and
****     objective goal (no following the leader)
****   - formed by proximity once a second: a bot joins the nearest teammate bot within 1024 units whose
****     squad has room (bot_ai_squadsize), or the two start one; a bot over 1536 units from every squadmate
****     leaves. A squad of one is dissolved (a squadless bot acts as HL's squadless grunt)
****   - 2 ENGAGE slots per squad on top of the per-target cap (bot_ai_engagemax). A bot without a slot takes
****     cover or stands off and steps in when a slot frees
**** Squads are level arrays indexed by squad number; slots are level.dsr_sqSlot[squad * 2 + k].
**** Gunfire hearing: a 16-entry ring of shots (bot bursts, polled human fire buttons) for HEAR_COMBAT.
************************************************************************************************* */

/* *************************************************************************************************
**** DSR_SquadStart()
****
**** from DSR_CoreStart: empty squads and sound ring, and the loops
************************************************************************************************* */
DSR_SquadStart()
{
    level.dsr_sqMax = 16;
    level.dsr_sqUsed = [];
    level.dsr_sqTeam = [];
    level.dsr_sqLeader = [];
    level.dsr_sqEnemy = [];
    level.dsr_sqSeen = [];
    level.dsr_sqSlot = [];
    for(i = 0; i < level.dsr_sqMax; i++)
    {
        level.dsr_sqUsed[i] = false;
        level.dsr_sqSeen[i] = 0;
    }

    level.dsr_sndNext = 0;
    level.dsr_sndPos = [];
    level.dsr_sndBy = [];
    level.dsr_sndTime = [];
    for(i = 0; i < 16; i++)
        level.dsr_sndTime[i] = 0;

    maps\mp\uox\_uox_loops::addToLoop(level, "slow", ::DSR_FormSquads, "DSR_FormSquads");
    maps\mp\uox\_uox_loops::addToLoop(level, "medium", ::DSR_PollGunfire, "DSR_PollGunfire");
}

/* *************************************************************************************************
**** DSR_Speak(menu, n)
****
**** self = bot. Says quick-chat line n of menu ("commands", "statements" or "responses") at bot_ai_level 3
**** and above, if the rate limits let it (plan 2.5):
****   bot_battlechatter (maintainer, Phase 3): 0-10, each line is said with a chance of value / 10
****     (default 1 = 10%, 10 = every line, 0 = off)
****   per team: one line every bot_ai_chatcooldown seconds (default 4)
****   per bot: the stock spam delay (self.spamdelay, set by _teams::quick*)
**** Returns true when the line was sent. Never waits. VERIFY that the CODUO-X menu dispatcher handles a
**** bot's quick-chat menuresponse the way it handles the team and weapon menus.
************************************************************************************************* */
DSR_Speak(menu, n)
{
    if(level.dsr_aiLevel < 3 || isDefined(self.spamdelay))
        return false;
    scale = [[level.getVars]]("bot_battlechatter");
    if(scale <= 0)
        return false;
    team = self.pers["team"];
    if(!isDefined(team) || team == "spectator")
        return false;

    now = getTime();
    if(!isDefined(level.dsr_chatNext))
        level.dsr_chatNext = [];
    if(isDefined(level.dsr_chatNext[team]) && now < level.dsr_chatNext[team])
        return false;
    if(randomFloat(10) >= scale)
        return false;

    level.dsr_chatNext[team] = now + [[level.getVars]]("bot_ai_chatcooldown") * 1000;
    if([[level.getVars]]("bot_ai_debug") >= 2)
        logprint("DSR: chat " + self.name + " " + menu + " " + n + "\n");
    self notify("menuresponse", game["menu_quick" + menu], "" + n);
    return true;
}

/* *************************************************************************************************
**** squad membership
************************************************************************************************* */

//self = bot. Its squad number, or -1 without one (always -1 below bot_ai_level 5)
DSR_Squad()
{
    if(level.dsr_aiLevel < 5 || !isDefined(self.dsr_squad))
        return -1;
    return self.dsr_squad;
}

//self = bot. The squad's leader, or squadless (HL: leader checks are skipped without a squad)
DSR_IsLeader()
{
    i = self DSR_Squad();
    return (i < 0 || (isDefined(level.dsr_sqLeader[i]) && level.dsr_sqLeader[i] == self));
}

//an active bot in this game: may be in a squad
DSR_SquadCandidate(p)
{
    return (isDefined(p.dsr_active) && p.sessionstate == "playing" && isAlive(p)
        && isDefined(p.pers["team"]) && (p.pers["team"] == "allies" || p.pers["team"] == "axis"));
}

DSR_SquadCount(i, players)
{
    n = 0;
    for(k = 0; k < players.size; k++)
    {
        if(isDefined(players[k].dsr_squad) && players[k].dsr_squad == i)
            n++;
    }
    return n;
}

/* *************************************************************************************************
**** DSR_FormSquads()
****
**** level slow loop. Off below bot_ai_level 5 and in FFA modes (any squads left over are dissolved).
****   1. a bot whose team changed, or that is over 1536 units from every squadmate, leaves
****   2. a squadless bot joins the nearest teammate bot within 1024 whose squad has room, or starts a
****      squad with a squadless one
****   3. squads of one are dissolved; a squad without a live leader elects the member alive longest
************************************************************************************************* */
DSR_FormSquads()
{
    players = getentarray("player", "classname");
    if(level.dsr_aiLevel < 5 || !level.uox_teamplay)
    {
        for(i = 0; i < players.size; i++)
        {
            if(isDefined(players[i].dsr_squad))
                players[i] DSR_SquadLeave("off");
        }
        return;
    }
    size = [[level.getVars]]("bot_ai_squadsize");

    //1. leave
    for(i = 0; i < players.size; i++)
    {
        b = players[i];
        if(!isDefined(b.dsr_squad))
            continue;
        s = b.dsr_squad;
        if(!DSR_SquadCandidate(b) || level.dsr_sqTeam[s] != b.pers["team"])
        {
            b DSR_SquadLeave("team");
            continue;
        }
        near = false;
        for(k = 0; k < players.size; k++)
        {
            p = players[k];
            if(p != b && isDefined(p.dsr_squad) && p.dsr_squad == s && distanceSquared(p.origin, b.origin) < 1536 * 1536)
            {
                near = true;
                break;
            }
        }
        if(!near)
            b DSR_SquadLeave("strayed");
    }

    //2. join
    for(i = 0; i < players.size; i++)
    {
        b = players[i];
        if(isDefined(b.dsr_squad) || !DSR_SquadCandidate(b))
            continue;
        best = undefined;
        bestSq = 1024 * 1024;
        for(k = 0; k < players.size; k++)
        {
            p = players[k];
            if(p == b || !DSR_SquadCandidate(p) || p.pers["team"] != b.pers["team"])
                continue;
            if(isDefined(p.dsr_squad) && DSR_SquadCount(p.dsr_squad, players) >= size)
                continue;
            d = distanceSquared(p.origin, b.origin);
            if(d < bestSq)
            {
                best = p;
                bestSq = d;
            }
        }
        if(!isDefined(best))
            continue;
        if(isDefined(best.dsr_squad))
        {
            b DSR_SquadJoin(best.dsr_squad);
            continue;
        }
        s = DSR_SquadNew(b.pers["team"]);
        if(s < 0)
            continue;
        best DSR_SquadJoin(s);
        b DSR_SquadJoin(s);
    }

    //3. dissolve and elect
    for(s = 0; s < level.dsr_sqMax; s++)
    {
        if(!level.dsr_sqUsed[s])
            continue;
        if(DSR_SquadCount(s, players) < 2)
        {
            for(i = 0; i < players.size; i++)
            {
                if(isDefined(players[i].dsr_squad) && players[i].dsr_squad == s)
                    players[i] DSR_SquadLeave("alone");
            }
            DSR_SquadFree(s);
            continue;
        }
        l = level.dsr_sqLeader[s];
        if(isDefined(l) && isDefined(l.dsr_squad) && l.dsr_squad == s)
            continue;
        best = undefined;
        for(i = 0; i < players.size; i++)
        {
            p = players[i];
            if(isDefined(p.dsr_squad) && p.dsr_squad == s && (!isDefined(best) || p.dsr_lifeStart < best.dsr_lifeStart))
                best = p;
        }
        level.dsr_sqLeader[s] = best;
        if([[level.getVars]]("bot_ai_debug") >= 2)
            logprint("DSR: squad " + s + " leader " + best.name + "\n");
    }
}

//a free squad number for team, or -1
DSR_SquadNew(team)
{
    for(s = 0; s < level.dsr_sqMax; s++)
    {
        if(level.dsr_sqUsed[s])
            continue;
        level.dsr_sqUsed[s] = true;
        level.dsr_sqTeam[s] = team;
        level.dsr_sqLeader[s] = undefined;
        level.dsr_sqEnemy[s] = undefined;
        level.dsr_sqSeen[s] = 0;
        level.dsr_sqSlot[s * 2] = undefined;
        level.dsr_sqSlot[s * 2 + 1] = undefined;
        return s;
    }
    return -1;
}

DSR_SquadFree(s)
{
    level.dsr_sqUsed[s] = false;
    level.dsr_sqLeader[s] = undefined;
    level.dsr_sqEnemy[s] = undefined;
    level.dsr_sqSlot[s * 2] = undefined;
    level.dsr_sqSlot[s * 2 + 1] = undefined;
}

DSR_SquadJoin(s)
{
    self.dsr_squad = s;
    if([[level.getVars]]("bot_ai_debug") >= 2)
        logprint("DSR: squad " + s + " join " + self.name + "\n");
}

//self = bot leaving its squad (also from DSR_BotRelease on death, respawn and disconnect)
DSR_SquadLeave(why)
{
    if(!isDefined(self.dsr_squad))
        return;
    s = self.dsr_squad;
    self DSR_ReleaseSlot();
    if(isDefined(level.dsr_sqLeader[s]) && level.dsr_sqLeader[s] == self)
        level.dsr_sqLeader[s] = undefined;
    self.dsr_squad = undefined;
    if([[level.getVars]]("bot_ai_debug") >= 2)
        logprint("DSR: squad " + s + " leave " + self.name + " " + why + "\n");
}

/* *************************************************************************************************
**** ENGAGE slots (HL OccupySlot, 2 per squad). Held while the bot is in an engage schedule; DSR_SetSchedule
**** releases it on any other. Squadless bots (and every bot below level 5) always have a slot.
************************************************************************************************* */
DSR_IsEngageSched(name)
{
    return (name == "RangeAttack" || name == "PeekFire" || name == "EstablishLineOfFire" || name == "FoundEnemy"
        || name == "CombatFace" || name == "Melee" || name == "PointBlank");
}

DSR_SlotValid(k, s)
{
    h = level.dsr_sqSlot[k];
    return (isDefined(h) && isPlayer(h) && isDefined(h.dsr_active) && isDefined(h.dsr_squad) && h.dsr_squad == s
        && isDefined(h.dsr_sched) && DSR_IsEngageSched(h.dsr_sched));
}

DSR_HasSlot()
{
    s = self DSR_Squad();
    if(s < 0)
        return true;
    for(k = s * 2; k < s * 2 + 2; k++)
    {
        if(isDefined(level.dsr_sqSlot[k]) && level.dsr_sqSlot[k] == self)
            return true;
    }
    return false;
}

//self = bot. Has a slot, or could take one now
DSR_SlotAvailable()
{
    if(self DSR_HasSlot())
        return true;
    s = self.dsr_squad;
    for(k = s * 2; k < s * 2 + 2; k++)
    {
        if(!DSR_SlotValid(k, s))
            return true;
    }
    return false;
}

//self = bot about to engage. Takes a free slot; false when both are held by squadmates
DSR_OccupySlot()
{
    if(self DSR_HasSlot())
        return true;
    s = self.dsr_squad;
    for(k = s * 2; k < s * 2 + 2; k++)
    {
        if(DSR_SlotValid(k, s))
            continue;
        level.dsr_sqSlot[k] = self;
        if([[level.getVars]]("bot_ai_debug") >= 3)
            logprint("DSR: squad " + s + " slot " + self.name + "\n");
        return true;
    }
    return false;
}

DSR_ReleaseSlot()
{
    if(!isDefined(self.dsr_squad))
        return;
    s = self.dsr_squad;
    for(k = s * 2; k < s * 2 + 2; k++)
    {
        if(isDefined(level.dsr_sqSlot[k]) && level.dsr_sqSlot[k] == self)
            level.dsr_sqSlot[k] = undefined;
    }
}

/* *************************************************************************************************
**** shared enemy (HL SquadMakeEnemy, SquadEnemySplit, "eluded")
****
**** DSR_SquadSaw: self = bot that sees its enemy this think (from DSR_GatherConditions).
****   - a new enemy is passed to every squadmate without one (a squadmate busy with its own enemy keeps it:
****     the split). One already engaged by enough bots makes the squadmate flank instead (DSR_MayEngage)
****   - the squad's enemy unseen by anyone for 5 s ("eluded") and seen again: dsr_foundEnemy (FoundEnemy)
************************************************************************************************* */
DSR_SquadSaw(newEnemy)
{
    s = self DSR_Squad();
    if(s < 0)
        return;
    e = self.dsr_enemy;
    now = getTime();
    if(isDefined(level.dsr_sqEnemy[s]) && level.dsr_sqEnemy[s] == e && now - level.dsr_sqSeen[s] > 5000)
        self.dsr_foundEnemy = true;
    level.dsr_sqEnemy[s] = e;
    level.dsr_sqSeen[s] = now;
    if(newEnemy)
        self DSR_SquadMakeEnemy(e);
}

DSR_SquadMakeEnemy(e)
{
    s = self.dsr_squad;
    players = getentarray("player", "classname");
    for(i = 0; i < players.size; i++)
    {
        m = players[i];
        if(m == self || !isDefined(m.dsr_squad) || m.dsr_squad != s || !isDefined(m.dsr_active))
            continue;
        if(isDefined(m.dsr_enemy) || (isDefined(m.dsr_objUrgent) && m.dsr_objUrgent) || m dsrbot\_dsr_sense::DSR_IsIgnoring(e))
            continue;
        if(!m dsrbot\_dsr_sense::DSR_MayEngage(e))
        {
            m dsrbot\_dsr_sense::DSR_NoteFlank(e);
            continue;
        }
        m.dsr_enemy = e;
        m.dsr_enemyLastPos = e.origin;
        m.dsr_enemyLastSeen = getTime();
        m.dsr_squadGiven = true;
        if([[level.getVars]]("bot_ai_debug") >= 2)
            logprint("DSR: squad " + s + " enemy " + m.name + " from=" + self.name + " enemy=" + e.name + "\n");
    }
}

//self = bot. Its enemy is looking at it (HL ENEMY_FACING_ME: within ~25 degrees). VERIFY that a player's
//angles carry its view yaw
DSR_EnemyFacingMe()
{
    e = self.dsr_enemy;
    fwd = anglesToForward((0, e.angles[1], 0));
    dir = vectorNormalize((self.origin[0] - e.origin[0], self.origin[1] - e.origin[1], 0));
    return (vectorDot(fwd, dir) > 0.9);
}

/* *************************************************************************************************
**** DSR_FriendInLine(target)
****
**** self = bot (teamplay, bot_ai_level 5). HL NoFriendlyFire: a teammate inside a box 48 units wide (1.5x a
**** player) and 128 high along the line from the bot to target. No traces.
************************************************************************************************* */
DSR_FriendInLine(target)
{
    from = self.origin;
    flat = (target.origin[0] - from[0], target.origin[1] - from[1], 0);
    len = distance(flat, (0, 0, 0));
    if(len < 1)
        return false;
    dir = (flat[0] / len, flat[1] / len, 0);
    players = getentarray("player", "classname");
    for(i = 0; i < players.size; i++)
    {
        p = players[i];
        if(p == self || p == target || p.sessionstate != "playing" || p.pers["team"] != self.pers["team"])
            continue;
        d = (p.origin[0] - from[0], p.origin[1] - from[1], 0);
        along = vectorDot(d, dir);
        if(along <= 0 || along >= len)
            continue;
        side = d - (dir[0] * along, dir[1] * along, 0);
        if(distanceSquared(side, (0, 0, 0)) >= 24 * 24)
            continue;
        z = from[2] + (target.origin[2] - from[2]) * along / len;
        if(p.origin[2] - z < 64 && z - p.origin[2] < 64)
            return true;
    }
    return false;
}

/* *************************************************************************************************
**** gunfire hearing (HEAR_COMBAT). A ring of the last 16 shots: bot bursts (DSR_NoteGunfire from
**** DSR_StartBurst) and humans (and non-AI bots), polled on the medium loop, at most one entry per 0.5 s
**** each. attackButtonPressed() reads true whenever +attack is held, alive or not, with ammo or not
**** (maintainer), so a human's shot is a drop in the clip of a gun slot (primary, primaryb, pistol)
**** since the last poll, with the same weapons in those slots, while alive and playing (VERIFY the slot name
**** "pistol" in UO).
**** Grenades (their own slot), melee and binoculars use no gun clip and don't count. A shot and a reload
**** inside one poll (0.25 s) is missed.
************************************************************************************************* */
DSR_NoteGunfire()
{
    if(!isDefined(level.dsr_sndNext))
        return;
    i = level.dsr_sndNext;
    level.dsr_sndPos[i] = self.origin;
    level.dsr_sndBy[i] = self;
    level.dsr_sndTime[i] = getTime();
    level.dsr_sndNext = (i + 1) % 16;
}

DSR_PollGunfire()
{
    if(level.dsr_aiLevel < 5)
        return;
    now = getTime();
    players = getentarray("player", "classname");
    for(i = 0; i < players.size; i++)
    {
        p = players[i];
        if(isDefined(p.dsr_active))
            continue;
        if(p.sessionstate != "playing" || !isAlive(p) || !isDefined(p.pers["team"]) || p.pers["team"] == "spectator")
        {
            p.dsr_sndGuns = undefined; //start over at the next life
            continue;
        }
        guns = p getWeaponSlotWeapon("primary") + " " + p getWeaponSlotWeapon("primaryb") + " " + p getWeaponSlotWeapon("pistol");
        clip = 0;
        if(p getWeaponSlotWeapon("primary") != "none")
            clip += p getWeaponSlotClipAmmo("primary");
        if(p getWeaponSlotWeapon("primaryb") != "none")
            clip += p getWeaponSlotClipAmmo("primaryb");
        if(p getWeaponSlotWeapon("pistol") != "none")
            clip += p getWeaponSlotClipAmmo("pistol");
        fired = (isDefined(p.dsr_sndGuns) && p.dsr_sndGuns == guns && clip < p.dsr_sndClip);
        p.dsr_sndGuns = guns;
        p.dsr_sndClip = clip;
        if(!fired || (isDefined(p.dsr_sndLast) && now - p.dsr_sndLast < 500))
            continue;
        p.dsr_sndLast = now;
        p DSR_NoteGunfire();
    }
}

//self = bot with no enemy. The nearest shot of the last second by a valid target within 1500 units
//(VERIFY the radius in play): sets dsr_heardBy / dsr_heardPos
DSR_HearCombat()
{
    now = getTime();
    best = -1;
    bestSq = 1500 * 1500;
    for(i = 0; i < 16; i++)
    {
        if(now - level.dsr_sndTime[i] > 1000)
            continue;
        p = level.dsr_sndBy[i];
        if(!self dsrbot\_dsr_sense::DSR_IsValidTarget(p) || self dsrbot\_dsr_sense::DSR_IsIgnoring(p))
            continue;
        d = distanceSquared(self.origin, level.dsr_sndPos[i]);
        if(d < bestSq)
        {
            best = i;
            bestSq = d;
        }
    }
    if(best < 0)
        return false;
    self.dsr_heardBy = level.dsr_sndBy[best];
    self.dsr_heardPos = level.dsr_sndPos[best];
    return true;
}

//self = bot with HEAR_COMBAT and no enemy (DSR_GetSchedule): the shooter becomes its enemy, last seen
//where the shot was heard, so EstablishLineOfFire walks there, sweeps and gives up
DSR_Investigate()
{
    p = self.dsr_heardBy;
    if(!self dsrbot\_dsr_sense::DSR_IsValidTarget(p) || !self DSR_OccupySlot())
        return false;
    self.dsr_enemy = p;
    self.dsr_lastEnemy = p; //no NEW_ENEMY for a shooter it hasn't seen
    self.dsr_enemyLastPos = self.dsr_heardPos;
    self.dsr_enemyLastSeen = getTime();
    self.dsr_elofReached = undefined;
    self.dsr_elofTries = 0;
    if([[level.getVars]]("bot_ai_debug") >= 2)
        logprint("DSR: hear " + self.name + " shooter=" + p.name + " dist=" + (int)(distance(self.origin, self.dsr_heardPos)) + "\n");
    return true;
}

/* *************************************************************************************************
**** DSR_SquadOnKill(attacker)
****
**** self = player just killed (from DSR_PlayerKilled; never waits). Squadmates of a bot that made the kill
**** and had the victim as their enemy say "great shot" at their next think.
************************************************************************************************* */
DSR_SquadOnKill(attacker)
{
    if(!isDefined(level.dsr_aiLevel) || level.dsr_aiLevel < 5 || !isPlayer(attacker) || attacker == self || !isDefined(attacker.dsr_squad))
        return;
    s = attacker.dsr_squad;
    players = getentarray("player", "classname");
    for(i = 0; i < players.size; i++)
    {
        m = players[i];
        if(m != attacker && isDefined(m.dsr_squad) && m.dsr_squad == s && isDefined(m.dsr_enemy) && m.dsr_enemy == self)
            m.dsr_greatShot = true;
    }
}
