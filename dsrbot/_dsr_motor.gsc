/* *************************************************************************************************
**** _dsr_motor.gsc
****
**** Bot body: the script_origin a bot rides (dsr_org), the motor thread, fire modes, weapon pick,
**** the death weapon swap, and the moves ported from MeatBot (walk, fall, jump down, ladder).
**** Plan 3.2, 5.1, 5.2 and 6.3.
************************************************************************************************* */

/* *************************************************************************************************
**** DSR_MotorInit()
****
**** level tables, built once per map from DSR_StartGameType
************************************************************************************************* */
DSR_MotorInit()
{
    level.dsr_moveSpeed = 190; //MeatBot level.movespeed; each walk adds 0-15
    level.dsr_turnRate = 360; //turning: top speed, degrees per second
    level.dsr_turnMinRate = 45; //slowest speed near the end of a turn, degrees per second
    level.dsr_turnEase = 8; //part of the remaining turn covered per second (8 = 40% a frame at 20 fps)
    level.dsr_turnLeeway = 0.25; //degrees; closer than this counts as on target and stops the updates
    level.dsr_stepInterval = 430; //ms between footsteps, MeatBot's step loop interval

    //weapons with bot variants (plan 4.4); stock name -> base name used to build variant names
    level.dsr_baseOf = [];
    level.dsr_stockOf = [];
    bases = [];
    bases[bases.size] = "bar";
    bases[bases.size] = "bren";
    bases[bases.size] = "enfield";
    bases[bases.size] = "gewehr43";
    bases[bases.size] = "kar98k";
    bases[bases.size] = "m1carbine";
    bases[bases.size] = "m1garand";
    bases[bases.size] = "mosin_nagant";
    bases[bases.size] = "mp40";
    bases[bases.size] = "mp44";
    bases[bases.size] = "ppsh";
    bases[bases.size] = "sten";
    bases[bases.size] = "svt40";
    bases[bases.size] = "thompson";

    for(i = 0; i < bases.size; i++)
    {
        stock = bases[i] + "_mp";
        level.dsr_baseOf[stock] = bases[i];
        //level.dsr_stockOf[variant] = the weapon a dying player drops in place of a bot variant
        level.dsr_stockOf["bot_" + bases[i] + "_walk2_mp"] = stock;
        level.dsr_stockOf["bot_" + bases[i] + "_close_mp"] = stock;
        level.dsr_stockOf["bot_" + bases[i] + "_stand_mp"] = stock;
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

    //action variants have no stock weapon: drop nothing
    level.dsr_stockOf["bot_binoculars_artillery_mp"] = "none";
    level.dsr_stockOf["bot_melee_mp"] = "none";
    level.dsr_stockOf["jumpdn_bot_mp"] = "none";
    level.dsr_stockOf["climbup_bot_mp"] = "none";
    level.dsr_stockOf["mantle_bot_mp"] = "none";

    //weapons DSR_PickWeapon may choose, per nationality: CODUO-X giveBotWeapon's lists minus the snipers
    level.dsr_botWeapons = [];
    level.dsr_botWeapons["american"] = DSR_List4("m1carbine_mp", "m1garand_mp", "thompson_mp", "bar_mp");
    level.dsr_botWeapons["british"] = DSR_List4("enfield_mp", "sten_mp", "bren_mp", undefined);
    level.dsr_botWeapons["russian"] = DSR_List4("mosin_nagant_mp", "ppsh_mp", "svt40_mp", undefined);
    level.dsr_botWeapons["german"] = DSR_List4("kar98k_mp", "mp40_mp", "mp44_mp", "gewehr43_mp");

    //MeatBot's velsqr table: fall height -> seconds in the air
    level.dsr_velH = [];
    level.dsr_velT = [];
    DSR_AddVelSqr(12, 0.17);
    DSR_AddVelSqr(25, 0.25);
    DSR_AddVelSqr(37, 0.31);
    DSR_AddVelSqr(50, 0.36);
    DSR_AddVelSqr(75, 0.44);
    DSR_AddVelSqr(100, 0.51);
    DSR_AddVelSqr(125, 0.56);
    DSR_AddVelSqr(150, 0.62);
    DSR_AddVelSqr(175, 0.67);
    DSR_AddVelSqr(200, 0.71);
    DSR_AddVelSqr(250, 0.8);
    DSR_AddVelSqr(300, 0.88);
    DSR_AddVelSqr(350, 0.94);
    DSR_AddVelSqr(400, 1.01);
    DSR_AddVelSqr(450, 1.07);
    DSR_AddVelSqr(500, 1.13);
    DSR_AddVelSqr(600, 1.21);
    DSR_AddVelSqr(650, 1.29);
    DSR_AddVelSqr(700, 1.34);
    DSR_AddVelSqr(750, 1.38);
    DSR_AddVelSqr(800, 1.43);
    DSR_AddVelSqr(850, 1.5);
    DSR_AddVelSqr(900, 1.51);
    DSR_AddVelSqr(1000, 1.6);
}

DSR_List4(a, b, c, d)
{
    list = [];
    if(isDefined(a)) list[list.size] = a;
    if(isDefined(b)) list[list.size] = b;
    if(isDefined(c)) list[list.size] = c;
    if(isDefined(d)) list[list.size] = d;
    return list;
}

DSR_AddVelSqr(h, t)
{
    level.dsr_velH[level.dsr_velH.size] = h;
    level.dsr_velT[level.dsr_velT.size] = t;
}

//port of MeatBot getvelsqr: the table entry nearest to height h
DSR_GetVelSqr(h)
{
    hprev = level.dsr_velH[0];
    for(i = 1; i < level.dsr_velH.size; i++)
    {
        hcur = level.dsr_velH[i];
        if(h > hcur)
        {
            hprev = hcur;
            continue;
        }
        if(h < hprev + (hcur - hprev) / 2)
            return level.dsr_velT[i - 1];
        return level.dsr_velT[i];
    }
    return level.dsr_velT[level.dsr_velT.size - 1];
}

/* *************************************************************************************************
**** DSR_PickWeapon()
****
**** self = bot that just joined a team. Replaces CODUO-X giveBotWeapon (plan 4.4): only weapons with bot
**** variants, for the bot's nationality, filtered by the same _teams::restrict check CODUO-X uses.
**** Falls back to giveBotWeapon if every candidate is restricted; such a bot gets no DSR AI.
************************************************************************************************* */
DSR_PickWeapon()
{
    team = self.pers["team"];
    if(team != "allies" && team != "axis")
        return;

    list = level.dsr_botWeapons[game[team]];
    allowed = [];
    if(isDefined(list))
    {
        for(i = 0; i < list.size; i++)
        {
            if(self maps\mp\gametypes\_teams::restrict(list[i]) != "restricted")
                allowed[allowed.size] = list[i];
        }
    }

    if(!allowed.size)
    {
        if([[level.getVars]]("bot_ai_debug") >= 1)
            logprint("DSR: pickweapon " + self.name + " team=" + team + " no unrestricted variant weapon; using CODUO-X giveBotWeapon\n");
        self maps\mp\uox\_uox::giveBotWeapon();
        return;
    }

    weapon = allowed[randomInt(allowed.size)];
    if(team == "axis")
        self notify("menuresponse", game["menu_weapon_axis"], weapon);
    else
        self notify("menuresponse", game["menu_weapon_allies"], weapon);
}

/* *************************************************************************************************
**** DSR_BotStart()
****
**** self = bot, spawned with its stock loadout. Links it to a new script_origin, switches to the run
**** variant and starts the motor thread. A bot without a variant weapon keeps stock behaviour.
************************************************************************************************* */
DSR_BotStart()
{
    stock = self getWeaponSlotWeapon("primary");
    self.dsr_weapon = level.dsr_baseOf[stock];
    if(!isDefined(self.dsr_weapon))
    {
        if([[level.getVars]]("bot_ai_debug") >= 1)
            logprint("DSR: botstart " + self.name + " weapon=" + stock + " has no bot variants; no AI this life\n");
        return;
    }

    //swap to the run variant before linking, as MeatBot does
    self.dsr_fireMode = undefined;
    self.dsr_fireWeapon = undefined;
    self.dsr_org = undefined;
    self DSR_SetFireMode("run");

    //MeatBot's exact order (spawnPlayer): spawn at the player, link, wait a frame, snap the origin to the
    //ground (the player should follow), wait a frame. Phase 1 test 2: linking first and moving later left
    //the player behind, so the timing is copied as is. Waits here, so self endon dsr_death.
    self endon("dsr_death");
    org = spawn("script_origin", self.origin);
    self.dsr_org = org;
    self linkTo(org);
    wait level.frametime;
    trace = dsrbot\_dsr_core::DSR_Trace(self.origin + (0, 0, 50), self.origin + (0, 0, -50), false, self);
    if(isDefined(trace) && trace["fraction"] < 1 && !isDefined(trace["entity"]))
        org.origin = trace["position"];
    wait level.frametime;

    self.dsr_wp = undefined;
    self.dsr_path = undefined;
    self.dsr_pathState = "none";
    self.dsr_pathFails = 0;
    self.dsr_state = "start";
    self.dsr_motorDone = true;
    self.dsr_moving = false;
    self.dsr_nextStep = 0;
    self.dsr_lastSurface = "default";
    self.dsr_lookYaw = self.angles[1];
    self.dsr_lookPitch = 0;
    self.dsr_curYaw = self.angles[1];
    self.dsr_curPitch = 0;

    self.dsr_active = true;
    self thread DSR_MotorThread();

    if([[level.getVars]]("bot_ai_debug") >= 2)
        logprint("DSR: botstart " + self.name + " weapon=" + self.dsr_weapon + " slot=" + self.dsr_thinkSlot + "\n");
}

/* *************************************************************************************************
**** DSR_BotRelease()
****
**** self = bot. Stops the AI and frees the script_origin; on death, respawn and disconnect.
************************************************************************************************* */
DSR_BotRelease()
{
    self.dsr_active = undefined;
    self.dsr_moving = false;
    self notify("dsr_motor_cancel");
    if(isDefined(self.dsr_org))
    {
        self unlink();
        self.dsr_org delete();
        self.dsr_org = undefined;
    }
}

/* *************************************************************************************************
**** DSR_OnKilled()
****
**** from DSR_PlayerKilled, before CODUO-X's default handler drops the current weapon
************************************************************************************************* */
DSR_OnKilled()
{
    self notify("dsr_death");
    if(isDefined(self.dsr_org) || isDefined(self.dsr_active))
        self DSR_BotRelease();
    self DSR_SwapToStockWeapon();
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
    if(isDefined(current) && current == "bot_binoculars_mp" && isDefined(self.dsr_weapon))
        stock = level.dsr_stockOf["bot_" + self.dsr_weapon + "_walk2_mp"]; //killed in the hold pose
    else if(!isDefined(current) || !isDefined(level.dsr_stockOf[current]))
        return; //stock weapon or none, leave the default drop alone
    else
        stock = level.dsr_stockOf[current];
    slotA = self getWeaponSlotWeapon("primary");
    slotB = self getWeaponSlotWeapon("primaryb");
    before = slotA + "," + slotB;
    self takeAllWeapons();
    //takeAllWeapons left the other slot's weapon to be dropped (Phase 0 test: jumpdn_bot_mp death dropped
    //a thompson_mp held in the other slot), so empty both slots before giving the stock weapon
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
    //if setSpawnWeapon did not change the current weapon at once, drop the stock weapon here;
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

/* *************************************************************************************************
**** DSR_SetFireMode(mode, special)
****
**** swaps the held variant (plan 5.3 dsr_fireMode). Skips the swap when nothing changes (plan 7).
****   run         -> bot_<w>_walk2_mp (run pose, binocular ammo: never clicks)
****   fire_stand  -> bot_<w>_close_mp (standing aim)
****   fire_crouch -> bot_<w>_stand_mp (crouching aim)
****   hold        -> bot_binoculars_mp (an emptied _close dry-fired while camping): stock binoculars
****                  whose idle plays the look-through pose (playeranim binocularsbot), since bots never
****                  ADS. takeAllWeapons removes it at once, so leaving hold costs only the next
****                  weapon's raise.
****   special     -> the named weapon (jumpdn_bot_mp, climbup_bot_mp, ...)
**** Phase 1 never shoots, so every _close/_stand swap is emptied.
****
**** A test client presses fire at random (about 2/s), so an empty weapon dry-fires. The pose-only variants
**** are spotters with the stock binocular clip (10, clip only, no ADS fire), like binoculars_mp: the clip is
**** never empty and a spotter doesn't fire from the hip, so they're silent (Phase 1 test).
****
**** The unlink / re-link around the swap follows MeatBot's setweaponslot. The swap itself didn't break the
**** link; that was CODUO-X's hold-use watcher unlinking every player (fixed in CODUO-X c111fcf).
************************************************************************************************* */
DSR_SetFireMode(mode, special)
{
    if(mode == "special")
        weapon = special;
    else if(mode == "run")
        weapon = "bot_" + self.dsr_weapon + "_walk2_mp";
    else if(mode == "hold")
        weapon = "bot_binoculars_mp";
    else if(mode == "fire_crouch")
        weapon = "bot_" + self.dsr_weapon + "_stand_mp";
    else
        weapon = "bot_" + self.dsr_weapon + "_close_mp";

    if(isDefined(self.dsr_fireWeapon) && self.dsr_fireWeapon == weapon)
    {
        self.dsr_fireMode = mode;
        return;
    }

    if(isDefined(self.dsr_org))
        self unlink();

    self takeAllWeapons();
    self giveWeapon(weapon);
    if(mode == "fire_stand" || mode == "fire_crouch")
    {
        self setWeaponSlotAmmo("primary", 0);
        self setWeaponSlotClipAmmo("primary", 0);
    }
    self setSpawnWeapon(weapon);
    self switchToWeapon(weapon);

    if(isDefined(self.dsr_org))
    {
        self.dsr_org.origin = self.origin;
        self linkTo(self.dsr_org);
    }
    self.dsr_fireMode = mode;
    self.dsr_fireWeapon = weapon;

    if([[level.getVars]]("bot_ai_debug") >= 3)
    {
        primary = self getWeaponSlotWeapon("primary");
        clip = self getWeaponSlotClipAmmo("primary");
        logprint("DSR: firemode " + self.name + " " + mode + " " + weapon + " primary=" + primary + " clip=" + clip + "\n");
    }
}

/* *************************************************************************************************
**** DSR_MotorCommand(cmd)
****
**** issued by DSR_BotThink when dsr_motorDone is true; the motor thread is then waiting for it
************************************************************************************************* */
DSR_MotorCommand(cmd)
{
    self.dsr_motorCmd = cmd;
    self.dsr_motorDone = false;
    self notify("dsr_motor_cmd");
}

/* *************************************************************************************************
**** DSR_MotorThread()
****
**** one per bot life; the only place a bot's blocking actions run (plan 5.2)
************************************************************************************************* */
DSR_MotorThread()
{
    self endon("disconnect");
    self endon("spawned");
    self endon("dsr_death");
    self endon("dsr_motor_cancel");

    for(;;)
    {
        self waittill("dsr_motor_cmd");
        switch(self.dsr_motorCmd)
        {
            case "start":
                self DSR_WalkTo(level.wp[self.dsr_startWp].origin);
                self.dsr_wp = self.dsr_startWp;
                break;
            case "path":
                self DSR_FollowPath();
                break;
            case "hold":
                self DSR_Hold(self.dsr_motorTime);
                break;
        }
        self.dsr_moving = false;
        self.dsr_motorDone = true;
    }
}

/* *************************************************************************************************
**** DSR_FollowPath()
****
**** walks self.dsr_path (node indices, [0] = the node the bot is on). The edge type is the type of the
**** node the bot is leaving, as in MeatBot: f fall, j jump down, l ladder; m (mantle) is walked, since
**** CODUO-X has no mantling.
************************************************************************************************* */
DSR_FollowPath()
{
    path = self.dsr_path;
    for(k = 1; k < path.size; k++)
    {
        from = path[k - 1];
        to = path[k];
        type = level.wp[from].type;

        if(type == "j")
            self DSR_JumpDown(from, to);
        else if(type == "f")
            self DSR_Fall(from, to);
        else if(type == "l" && level.wp[to].origin[2] - level.wp[from].origin[2] > 20)
            self DSR_ClimbUp(from, to);
        else
            self DSR_WalkTo(level.wp[to].origin);

        self.dsr_wp = to;
    }
}

DSR_WalkTo(pos)
{
    self DSR_SetFireMode("run");
    self DSR_WaitClear(pos);

    dist = distance(self.dsr_org.origin, pos);
    if(dist < 1)
        return;
    self DSR_FaceTo(pos);
    self.dsr_lookPitch = 0;

    speed = level.dsr_moveSpeed + randomInt(16);
    moveTime = dist / speed;
    if(moveTime < level.frametime)
        moveTime = level.frametime;

    self.dsr_moving = true;
    self.dsr_org moveTo(pos, moveTime, 0, 0);
    self.dsr_org waittill("movedone");
}

//port of MeatBot checkOccupancy: wait up to 1 s while another live player stands on the next node
DSR_WaitClear(pos)
{
    frames = dsrbot\_dsr_core::DSR_Max(1, (int)(1 / level.frametime));
    for(f = 0; f < frames; f++)
    {
        blocked = false;
        players = getentarray("player", "classname");
        for(i = 0; i < players.size; i++)
        {
            p = players[i];
            if(p != self && p.sessionstate == "playing" && distanceSquared(p.origin, pos) < 32 * 32)
            {
                blocked = true;
                break;
            }
        }
        if(!blocked)
            return;
        self.dsr_moving = false;
        wait level.frametime;
    }
}

//port of MeatBot fallGravity: drop off a ledge onto a lower node
DSR_Fall(from, to)
{
    src = level.wp[from].origin;
    dest = level.wp[to].origin;
    height = src[2] - dest[2];
    if(height <= 0)
    {
        self DSR_WalkTo(dest);
        return;
    }

    self DSR_FaceTo(dest);
    angles = vectorToAngles(dest - src);
    dir = anglesToForward((0, angles[1], 0));
    t = DSR_GetVelSqr(height);
    speed = distance((src[0], src[1], 0), (dest[0], dest[1], 0)) / t;
    if(speed > 240)
        speed = 240;

    if(height > 64)
        self DSR_SetFireMode("special", "jumpdn_bot_mp");

    self.dsr_moving = false;
    self.dsr_org moveGravity((dir[0] * speed, dir[1] * speed, 0), t);
    wait t;
    self.dsr_org moveTo(dest, level.frametime, 0, 0);
    self.dsr_org waittill("movedone");
    self DSR_PlaySurface();
}

//port of MeatBot jumpGravity: jump from a j node to the next node
DSR_JumpDown(from, to)
{
    src = level.wp[from].origin;
    dest = level.wp[to].origin;
    vmax = 240;

    self DSR_FaceTo(dest);
    angles = vectorToAngles(dest - src);
    dir = anglesToForward((0, angles[1], 0));
    dst = distance(dest, src);
    if(dest[2] >= src[2])
        dst = dst * 1.6;
    else
    {
        h = src[2] - dest[2];
        dst = dst * 1.6 - h * (1.25 + h / (vmax * 10));
    }
    if(dst > vmax)
        dst = vmax;
    if(dst < 0)
        dst = 0;

    self DSR_SetFireMode("special", "jumpdn_bot_mp");
    self.dsr_moving = false;
    self.dsr_org moveGravity((dir[0] * dst, dir[1] * dst, vmax), 10);

    //up: until the bot reaches the target height or the apex (vmax / 800 s); down: until 64 above it
    frames = dsrbot\_dsr_core::DSR_Max(1, (int)(3 / level.frametime));
    apex = dsrbot\_dsr_core::DSR_Max(1, (int)((vmax / 800.0) / level.frametime));
    for(f = 0; f < frames; f++)
    {
        wait level.frametime;
        z = self.dsr_org.origin[2];
        if(dest[2] >= src[2])
        {
            if(z >= dest[2] || f >= apex)
                break;
        }
        else if(f > apex && z <= dest[2] + 64)
            break;
    }

    self.dsr_org moveTo(dest, 0.1, 0, 0);
    self.dsr_org waittill("movedone");
    self DSR_PlaySurface();
}

//port of MeatBot climbUp: straight up the ladder, then step onto the top node
DSR_ClimbUp(from, to)
{
    src = level.wp[from].origin;
    dest = level.wp[to].origin;
    height = dest[2] - src[2] - 10;
    top = src + (0, 0, height);

    self DSR_FaceTo(dest);
    self.dsr_lookPitch = -50;
    self DSR_SetFireMode("special", "climbup_bot_mp");

    self.dsr_moving = false;
    self.dsr_org moveTo(top, height / 100, 0, 0);
    self.dsr_org waittill("movedone");

    self.dsr_lookPitch = 0;
    self DSR_WalkTo(dest);
}

DSR_Hold(holdTime)
{
    node = level.wp[self.dsr_wp];
    if(isDefined(node.angles))
        self.dsr_lookYaw = node.angles[1];
    self DSR_SetFireMode("hold");
    wait holdTime;
}

DSR_FaceTo(pos)
{
    angles = vectorToAngles(pos - self.origin);
    self.dsr_lookYaw = angles[1];
}

/* *************************************************************************************************
**** DSR_MotorFrame()
****
**** called for every active bot by the dispatcher each frame (no per-bot loop thread): turns toward
**** dsr_lookYaw at level.dsr_turnRate and plays footsteps while walking
************************************************************************************************* */
DSR_MotorFrame()
{
    //turn every frame while off target. The motor keeps its own yaw/pitch instead of reading self.angles
    //back, which can lag a frame behind setPlayerAngles and make the steps uneven
    yawDiff = DSR_AngleSubtract(self.dsr_lookYaw, self.dsr_curYaw);
    pitchDiff = self.dsr_lookPitch - self.dsr_curPitch;
    if(yawDiff > level.dsr_turnLeeway || yawDiff < 0 - level.dsr_turnLeeway
        || pitchDiff > level.dsr_turnLeeway || pitchDiff < 0 - level.dsr_turnLeeway)
    {
        self.dsr_curYaw = DSR_AngleNormalize(self.dsr_curYaw + DSR_TurnStep(yawDiff));
        self.dsr_curPitch += DSR_TurnStep(pitchDiff);
        self setPlayerAngles((self.dsr_curPitch, self.dsr_curYaw, 0));
    }

    if(self.dsr_moving && getTime() >= self.dsr_nextStep)
    {
        self.dsr_nextStep = getTime() + level.dsr_stepInterval;
        self DSR_PlaySurface();
    }
}

/* *************************************************************************************************
**** DSR_PlaySurface()
****
**** footstep / landing sound on MeatBot's existing surface aliases (step_walk_<surfacetype>); landings
**** reuse the footstep alias. When the trace budget refuses, the last surface is reused.
**** VERIFY: step_walk_<surfacetype> aliases are stock UO (no new aliases).
************************************************************************************************* */
DSR_PlaySurface()
{
    trace = dsrbot\_dsr_core::DSR_Trace(self.origin + (0, 0, 8), self.origin + (0, 0, -64), false, self);
    if(isDefined(trace))
    {
        if(trace["fraction"] == 1 || trace["surfacetype"] == "none")
            self.dsr_lastSurface = "default";
        else
            self.dsr_lastSurface = trace["surfacetype"];
    }
    self playSound("step_walk_" + self.dsr_lastSurface);
}

/* *************************************************************************************************
**** DSR_TurnStep(diff)
****
**** this frame's share of a turn: eases out (a fixed part of what's left, per second), capped at
**** dsr_turnRate and never below dsr_turnMinRate so the last few degrees don't crawl; within the
**** leeway it finishes the turn
************************************************************************************************* */
DSR_TurnStep(diff)
{
    size = diff;
    if(size < 0)
        size = 0 - size;
    if(size <= level.dsr_turnLeeway)
        return diff;

    step = size * level.dsr_turnEase * level.frametime;
    if(step > level.dsr_turnRate * level.frametime)
        step = level.dsr_turnRate * level.frametime;
    if(step < level.dsr_turnMinRate * level.frametime)
        step = level.dsr_turnMinRate * level.frametime;
    if(step > size)
        step = size;

    if(diff < 0)
        return 0 - step;
    return step;
}

DSR_AngleNormalize(a)
{
    while(a > 180)
        a -= 360;
    while(a < -180)
        a += 360;
    return a;
}

DSR_AngleSubtract(a1, a2)
{
    a = a1 - a2;
    while(a > 180)
        a -= 360;
    while(a < -180)
        a += 360;
    return a;
}
