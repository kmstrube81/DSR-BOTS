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

    //Phase 2 fire control per base weapon: how it fires (burst size) and MeatBot's getWeaponRange
    level.dsr_fireKind = [];
    level.dsr_range = [];
    DSR_AddWeapon("kar98k", "bolt", 3500);
    DSR_AddWeapon("enfield", "bolt", 3500);
    DSR_AddWeapon("mosin_nagant", "bolt", 3500);
    DSR_AddWeapon("m1garand", "semi", 3500);
    DSR_AddWeapon("gewehr43", "semi", 2500);
    DSR_AddWeapon("svt40", "semi", 3500);
    DSR_AddWeapon("m1carbine", "semi", 3000);
    DSR_AddWeapon("bar", "auto", 3000);
    DSR_AddWeapon("bren", "auto", 3500);
    DSR_AddWeapon("mp40", "auto", 1900);
    DSR_AddWeapon("mp44", "auto", 1900);
    DSR_AddWeapon("ppsh", "auto", 2000);
    DSR_AddWeapon("sten", "auto", 2000);
    DSR_AddWeapon("thompson", "auto", 2000);

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

DSR_AddWeapon(base, kind, range)
{
    level.dsr_fireKind[base] = kind;
    level.dsr_range[base] = range;
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

    weapon = self DSR_PickAllowedWeapon();
    if(!isDefined(weapon))
    {
        if([[level.getVars]]("bot_ai_debug") >= 1)
            logprint("DSR: pickweapon " + self.name + " team=" + team + " no unrestricted variant weapon; using CODUO-X giveBotWeapon\n");
        self maps\mp\uox\_uox::giveBotWeapon();
        return;
    }

    if(team == "axis")
        self notify("menuresponse", game["menu_weapon_axis"], weapon);
    else
        self notify("menuresponse", game["menu_weapon_allies"], weapon);
}

//self = bot. A random unrestricted weapon with bot variants for the bot's nationality, or undefined
DSR_PickAllowedWeapon()
{
    team = self.pers["team"];
    if(team != "allies" && team != "axis")
        return undefined;

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
        return undefined;
    return allowed[randomInt(allowed.size)];
}

/* *************************************************************************************************
**** DSR_FixWeapon(stock)
****
**** self = bot that spawned with a weapon that has no bot variants. CODUO-X moves bots to the other team
**** (halftime) with its own giveBotWeapon, whose lists include the snipers. Swaps in an unrestricted
**** variant weapon for this life and rewrites the pers weapon fields CODUO-X respawns from, so later lives
**** keep it. Sets self.dsr_weapon and returns the new stock name, or returns stock unchanged when nothing
**** is allowed. The sniper itself needs no removal: the variants replace the whole loadout
**** (DSR_SetFireMode) and the death swap drops the replacement's stock weapon.
************************************************************************************************* */
DSR_FixWeapon(stock)
{
    weapon = self DSR_PickAllowedWeapon();
    if(!isDefined(weapon))
        return stock;

    self.pers["weapon"] = weapon;
    self.pers["weapon1"] = weapon;
    self.pers[self.pers["team"] + "_weapon"] = weapon;
    if(isDefined(self.pers["spawnweapon"]))
        self.pers["spawnweapon"] = weapon;
    self.dsr_weapon = level.dsr_baseOf[weapon];

    if([[level.getVars]]("bot_ai_debug") >= 1)
        logprint("DSR: weaponfix " + self.name + " from=" + stock + " to=" + weapon + "\n");
    return weapon;
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
        stock = self DSR_FixWeapon(stock);
    if(!isDefined(self.dsr_weapon))
    {
        if([[level.getVars]]("bot_ai_debug") >= 1)
            logprint("DSR: botstart " + self.name + " weapon=" + stock + " has no bot variants; no AI this life\n");
        return;
    }

    self dsrbot\_dsr_core::DSR_ApplySkill();

    //simulated magazine (plan 4.3): the real clip only ever holds the current burst. With bot_unlimitedammo
    //off the reserve is the stock spawn ammo; -1 means unlimited
    self.dsr_magMax = getFullClipAmmo(stock);
    self.dsr_mag = self.dsr_magMax;
    if([[level.getVars]]("bot_unlimitedammo"))
        self.dsr_reserve = -1;
    else
        self.dsr_reserve = dsrbot\_dsr_core::DSR_Max(0, maps\mp\gametypes\_loadout_gmi::GetGunAmmo(stock) - self.dsr_magMax);
    self.dsr_firing = undefined;
    self.dsr_reloading = undefined;
    self.dsr_special = undefined;
    self.dsr_aiming = undefined;
    self.dsr_aimErrYaw = 0;
    self.dsr_aimErrPitch = 0;
    self.dsr_stance = undefined;
    self.dsr_sched = undefined;
    self.dsr_replan = undefined;
    self.dsr_avoid = undefined;
    self.dsr_moving = false;
    self.dsr_objGoalWp = undefined;
    self dsrbot\_dsr_obj::DSR_ObjSpawn();
    self dsrbot\_dsr_sense::DSR_SenseReset();

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

    if([[level.getVars]]("bot_ai_debug") >= 2)
        logprint("DSR: botstart " + self.name + " weapon=" + self.dsr_weapon + " slot=" + self.dsr_thinkSlot + " skill=" + self.dsr_skill + "\n");
}

/* *************************************************************************************************
**** DSR_BotRelease()
****
**** self = bot. Stops the AI and frees the script_origin; on death, respawn and disconnect.
************************************************************************************************* */
DSR_BotRelease()
{
    self dsrbot\_dsr_obj::DSR_ObjActionEnd(); //frees a bombzone / bomb it was planting or defusing
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
**** Every _close/_stand swap is emptied; FIRE_BURST loads each burst (DSR_StartBurst).
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

    self DSR_CeaseFire(); //the swap would throw away a burst or reload in progress

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
    self notify("dsr_motor_stop"); //at most one command runs at a time
    self.dsr_motorCmd = cmd;
    self.dsr_motorDone = false;
    self thread DSR_MotorRun(cmd);
}

/* *************************************************************************************************
**** DSR_MotorRun(cmd)
****
**** one thread per motor command; the only place a bot's blocking actions run (plan 5.2). Its own thread
**** so DSR_MotorStop can end it without ending anything else (an endon ends the whole thread).
************************************************************************************************* */
DSR_MotorRun(cmd)
{
    self endon("disconnect");
    self endon("spawned");
    self endon("dsr_death");
    self endon("dsr_motor_cancel");
    self endon("dsr_motor_stop");

    //left set if the previous command was cut off while blocked or giving way
    self.dsr_blockedBy = undefined;
    self.dsr_yielding = undefined;
    switch(cmd)
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
        case "point":
            //off the graph, onto an objective (DSR_ObjArrive traced the line clear)
            self DSR_WalkTo(self.dsr_pointPos);
            break;
        case "unstick":
            self DSR_UnstickRun();
            break;
    }
    self.dsr_moving = false;
    self.dsr_motorDone = true;
}

/* *************************************************************************************************
**** DSR_MotorStop()
****
**** ends the running command and halts dsr_org where it is (MeatBot stopMoving). Returns false, and does
**** nothing, during a jump, fall or ladder climb: those finish first.
************************************************************************************************* */
DSR_MotorStop()
{
    if(isDefined(self.dsr_special))
        return false;
    self notify("dsr_motor_stop");
    self.dsr_blockedBy = undefined;
    self.dsr_yielding = undefined;
    if(isDefined(self.dsr_org))
        self.dsr_org moveTo(self.dsr_org.origin, level.frametime, 0, 0);
    self.dsr_moving = false;
    self.dsr_motorDone = true;
    return true;
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
        else if(!self DSR_WalkTo(level.wp[to].origin))
        {
            //blocked: the next search routes around this node for a while, and patrol plans a new path from
            //wherever the bot ends up
            self DSR_Avoid(to);
            blocker = self.dsr_blocker;
            if(self.dsr_blockHow == "yield" && isPlayer(blocker))
            {
                //waypoint chains through doors are often one lane, so the bot gives way off the graph: a step
                //to the side where it stands, else on the node it came from (often in the room rather than
                //the door frame); failing both, a neighbouring node, else one node back along the path
                self.dsr_yielding = blocker;
                stepped = self DSR_SideStep(blocker);
                if(!stepped)
                {
                    self DSR_WalkTo(level.wp[from].origin);
                    stepped = self DSR_SideStep(blocker);
                }
                if(!stepped)
                {
                    if(!self DSR_StepAside(from, to, blocker) && k >= 2)
                    {
                        if(self DSR_WalkTo(level.wp[path[k - 2]].origin))
                            self.dsr_wp = path[k - 2];
                    }
                    self DSR_LetPass(blocker);
                }
                self.dsr_yielding = undefined;
            }
            else
                self DSR_WalkTo(level.wp[from].origin);
            return;
        }

        self.dsr_wp = to;
    }
}

/* *************************************************************************************************
**** DSR_WalkTo(pos)
****
**** walks dsr_org to pos. A linked bot is never pushed by the engine, so it must not be walked into another
**** player: the two overlap, wiggle in place and stop taking bullet hits. The way ahead is checked before
**** each move and every frame of it; a blocked bot halts and waits (DSR_WaitBlocked). Returns false when
**** it gave up, with self.dsr_blockHow ("yield" or "timeout") and self.dsr_blocker set.
************************************************************************************************* */
DSR_WalkTo(pos)
{
    self DSR_SetFireMode("run");

    for(;;)
    {
        dist = distance(self.dsr_org.origin, pos);
        if(dist < 1)
            return true;
        self DSR_FaceTo(pos);
        self.dsr_lookPitch = 0;

        blocker = self DSR_BlockedAhead(pos);
        if(!isDefined(blocker))
        {
            speed = level.dsr_moveSpeed + randomInt(16);
            moveTime = dist / speed;
            if(moveTime < level.frametime)
                moveTime = level.frametime;

            self.dsr_moving = true;
            self.dsr_org moveTo(pos, moveTime, 0, 0);

            //moveTo ends exactly on pos; the time cap only guards against a move that never gets there
            endTime = getTime() + moveTime * 1000 + 500;
            while(distanceSquared(self.dsr_org.origin, pos) > 1 && getTime() < endTime)
            {
                wait level.frametime;
                blocker = self DSR_BlockedAhead(pos);
                if(isDefined(blocker))
                    break;
            }
            if(!isDefined(blocker))
                return true;

            self.dsr_org moveTo(self.dsr_org.origin, level.frametime, 0, 0);
        }
        self.dsr_moving = false;
        if(!self DSR_WaitBlocked(pos, blocker))
            return false;
    }
}

//self = walking bot. A live player in the way to pos, or undefined: within 40 units and in front, or one
//the next 24 units of the walk would bring within 34 (a player crossing from the side; two players' boxes
//overlap under 32)
DSR_BlockedAhead(pos)
{
    dir = vectorNormalize((pos[0] - self.origin[0], pos[1] - self.origin[1], 0));
    step = (dir[0] * 24, dir[1] * 24, 0);
    players = getentarray("player", "classname");
    for(i = 0; i < players.size; i++)
    {
        p = players[i];
        if(p == self || p.sessionstate != "playing")
            continue;
        d = (p.origin[0] - self.origin[0], p.origin[1] - self.origin[1], 0);
        dz = p.origin[2] - self.origin[2];
        if(distanceSquared(d, (0, 0, 0)) > 40 * 40 || dz > 64 || dz < -64)
            continue;
        if(vectorDot(vectorNormalize(d), dir) > 0.3)
            return p;
        if(distanceSquared(d, step) < 34 * 34 && vectorDot(d, dir) > 0)
            return p;
    }
    return undefined;
}

/* *************************************************************************************************
**** DSR_Unstick()
****
**** self = bot whose motor is idle, from DSR_BotThink. The safety net for two players already inside each
**** other (the engine won't push a linked bot out, so they wiggle and stop taking bullet hits): with a
**** live player within 24 units, the bot with the lower entity number (or a bot overlapping a human or a
**** non-AI bot) walks 40 units straight away from it, or to either side, where traces show room
**** (DSR_SpotClear). Returns true when it started the move.
************************************************************************************************* */
DSR_Unstick()
{
    if(isDefined(self.dsr_special) || !self.dsr_motorDone)
        return false;
    players = getentarray("player", "classname");
    for(i = 0; i < players.size; i++)
    {
        p = players[i];
        if(p == self || p.sessionstate != "playing")
            continue;
        d = (self.origin[0] - p.origin[0], self.origin[1] - p.origin[1], 0);
        dz = p.origin[2] - self.origin[2];
        if(distanceSquared(d, (0, 0, 0)) > 24 * 24 || dz > 64 || dz < -64)
            continue;
        if(isDefined(p.dsr_active) && self getEntityNumber() > p getEntityNumber())
            continue; //the other one moves
        self.dsr_unstickFrom = p;
        self DSR_MotorCommand("unstick");
        return true;
    }
    return false;
}

DSR_UnstickRun()
{
    p = self.dsr_unstickFrom;
    if(!isPlayer(p))
        return;
    away = vectorNormalize((self.origin[0] - p.origin[0], self.origin[1] - p.origin[1], 0));
    if(away[0] == 0 && away[1] == 0)
        away = anglesToForward((0, randomInt(360), 0));
    dirs = [];
    dirs[0] = away;
    dirs[1] = (0 - away[1], away[0], 0);
    dirs[2] = (away[1], 0 - away[0], 0);
    for(i = 0; i < dirs.size; i++)
    {
        spot = self.origin + (dirs[i][0] * 40, dirs[i][1] * 40, 0);
        if(self DSR_SpotClear(spot, dirs[i]))
        {
            if([[level.getVars]]("bot_ai_debug") >= 2)
                logprint("DSR: unstick " + self.name + " from=" + p.name + "\n");
            //straight there: the player it leaves is in the way of an ordinary walk's checks
            self.dsr_moving = true;
            self.dsr_org moveTo(spot, 40.0 / level.dsr_moveSpeed, 0, 0); //40.0: int / int truncates to 0
            self.dsr_org waittill("movedone");
            return;
        }
    }
}

/* *************************************************************************************************
**** DSR_WaitBlocked(pos, blocker)
****
**** waits for the way ahead to clear; true when it does. Two bots blocking each other: the one with the
**** lower entity number gives way at once ("yield"). Otherwise the wait depends on the blocker: up to 3 s
**** for a bot giving way to this one, 2 s for a bot that is walking, 1 s for a human (or a bot without DSR
**** AI), and 0.5 s for a DSR bot standing still (fighting, camping or blocked itself), after which it gives up
**** ("timeout") and routes around.
************************************************************************************************* */
DSR_WaitBlocked(pos, blocker)
{
    start = getTime();
    for(;;)
    {
        self.dsr_blockedBy = blocker;
        if(isPlayer(blocker) && isDefined(blocker.dsr_blockedBy) && blocker.dsr_blockedBy == self
            && self getEntityNumber() < blocker getEntityNumber())
            return self DSR_BlockGiveUp(blocker, "yield");

        limit = 500;
        if(!isDefined(blocker.dsr_active))
            limit = 1000;
        else if(isDefined(blocker.dsr_yielding) && blocker.dsr_yielding == self)
            limit = 3000; //covers its walk back to the node it came from and the step aside
        else if(blocker.dsr_moving)
            limit = 2000;
        else if(blocker.dsr_motorCmd == "hold" && !blocker.dsr_motorDone)
        {
            //camping in the way: it cuts the camp short (DSR_Hold) and walks on
            blocker.dsr_holdYield = true;
            limit = 2000;
        }
        if(getTime() - start >= limit)
            return self DSR_BlockGiveUp(blocker, "timeout");

        wait level.frametime;
        blocker = self DSR_BlockedAhead(pos);
        if(!isDefined(blocker))
        {
            self.dsr_blockedBy = undefined;
            return true;
        }
    }
}

//the bot's current node for log lines; none before its first walk from the spawn point reaches one
DSR_WpText()
{
    if(isDefined(self.dsr_wp))
        return "" + self.dsr_wp;
    return "none";
}

DSR_BlockGiveUp(blocker, how)
{
    if([[level.getVars]]("bot_ai_debug") >= 2)
        logprint("DSR: blocked " + self.name + " by=" + blocker.name + " " + how + " wp=" + self DSR_WpText() + "\n");
    self.dsr_blockedBy = undefined;
    self.dsr_blockHow = how;
    self.dsr_blocker = blocker;
    return false;
}

//self = bot giving way at node from. Walks on to a neighbour of from that is not toward the blocked node
//and is farther from the blocker, so it is off the other bot's way. Walked edges only
DSR_StepAside(from, to, blocker)
{
    type = level.wp[from].type;
    if(type == "j" || type == "f" || type == "l" || !isPlayer(blocker))
        return false;
    next = level.wp[from].next;
    here = distanceSquared(level.wp[from].origin, blocker.origin);
    best = -1;
    bestD = here;
    for(i = 0; i < next.size; i++)
    {
        s = next[i];
        if(s == to)
            continue;
        d = distanceSquared(level.wp[s].origin, blocker.origin);
        if(d > bestD)
        {
            best = s;
            bestD = d;
        }
    }
    if(best >= 0 && self DSR_WalkTo(level.wp[best].origin))
    {
        self.dsr_wp = best;
        return true;
    }
    return false;
}

/* *************************************************************************************************
**** DSR_SideStep(blocker)
****
**** self = bot giving way to blocker. Steps 48 units to one side of the line between them (a random side
**** first), if traces show room for a player there and floor under it, then waits for the blocker to pass
**** (DSR_LetPass). False when neither side has room. Up to 6 budgeted traces.
************************************************************************************************* */
DSR_SideStep(blocker)
{
    d = vectorNormalize((blocker.origin[0] - self.origin[0], blocker.origin[1] - self.origin[1], 0));
    sgn = 1;
    if(randomInt(2))
        sgn = -1;
    for(n = 0; n < 2; n++)
    {
        side = (0 - d[1] * sgn, d[0] * sgn, 0);
        spot = self.origin + (side[0] * 48, side[1] * 48, 0);
        if(self DSR_SpotClear(spot, side))
        {
            if([[level.getVars]]("bot_ai_debug") >= 2)
                logprint("DSR: sidestep " + self.name + " for=" + blocker.name + " wp=" + self DSR_WpText() + "\n");
            if(!self DSR_WalkTo(spot))
                return false;
            self DSR_LetPass(blocker);
            return true;
        }
        sgn = 0 - sgn;
    }
    return false;
}

//self = bot. True when the way from the bot toward spot is clear at knee and chest height out to 64 units
//(the 48 unit step plus half a player's width) and spot has floor under it
DSR_SpotClear(spot, side)
{
    far = (side[0] * 64, side[1] * 64, 0);
    for(h = 20; h <= 56; h += 36)
    {
        trace = self DSR_TraceWait(self.origin + (0, 0, h), self.origin + far + (0, 0, h));
        if(!isDefined(trace) || trace["fraction"] < 1)
            return false;
    }
    trace = self DSR_TraceWait(spot + (0, 0, 20), spot + (0, 0, -40));
    return isDefined(trace) && trace["fraction"] < 1;
}

//a budgeted world trace (no characters) that waits up to 10 frames for budget; undefined if refused
DSR_TraceWait(start, end)
{
    for(f = 0; f < 10; f++)
    {
        trace = dsrbot\_dsr_core::DSR_Trace(start, end, false, self);
        if(isDefined(trace))
            return trace;
        wait level.frametime;
    }
    return undefined;
}

//self = bot that gave way. Holds still, facing the blocker, until it has gone by (over 96 units away),
//stopped being a live player, or 3 s passed
DSR_LetPass(blocker)
{
    self.dsr_moving = false;
    frames = dsrbot\_dsr_core::DSR_Max(1, (int)(3 / level.frametime));
    for(f = 0; f < frames; f++)
    {
        if(!isPlayer(blocker) || blocker.sessionstate != "playing"
            || distanceSquared(blocker.origin, self.origin) > 96 * 96)
            return;
        self DSR_FaceTo(blocker.origin);
        wait level.frametime;
    }
}

/* *************************************************************************************************
**** DSR_Avoid(wp)
****
**** self = bot. A* makes node wp expensive for this bot's searches for the next 5 s (dsr_nav AStarStep), so
**** a blocked bot routes around the player in the way. Keeps the 3 newest nodes.
************************************************************************************************* */
DSR_Avoid(wp)
{
    now = getTime();
    nodes = [];
    times = [];
    nodes[0] = wp;
    times[0] = now + 5000;
    if(isDefined(self.dsr_avoid))
    {
        for(i = 0; i < self.dsr_avoid.size && nodes.size < 3; i++)
        {
            if(self.dsr_avoidT[i] > now && self.dsr_avoid[i] != wp)
            {
                nodes[nodes.size] = self.dsr_avoid[i];
                times[times.size] = self.dsr_avoidT[i];
            }
        }
    }
    self.dsr_avoid = nodes;
    self.dsr_avoidT = times;
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

    self.dsr_special = true; //can't be stopped in the air (DSR_MotorStop)
    self.dsr_moving = false;
    self.dsr_org moveGravity((dir[0] * speed, dir[1] * speed, 0), t);
    wait t;
    self.dsr_org moveTo(dest, level.frametime, 0, 0);
    self.dsr_org waittill("movedone");
    self.dsr_special = undefined;
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
    self.dsr_special = true;
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
    self.dsr_special = undefined;
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

    self.dsr_special = true;
    self.dsr_moving = false;
    self.dsr_org moveTo(top, height / 100, 0, 0);
    self.dsr_org waittill("movedone");
    self.dsr_special = undefined;

    self.dsr_lookPitch = 0;
    self DSR_WalkTo(dest);
}

DSR_Hold(holdTime)
{
    node = level.wp[self.dsr_wp];
    if(isDefined(node.angles))
        self.dsr_lookYaw = node.angles[1];
    self DSR_SetFireMode("hold");

    //a bot blocked by this one sets dsr_holdYield (DSR_WaitBlocked): end the camp and let the patrol move on
    self.dsr_holdYield = undefined;
    frames = dsrbot\_dsr_core::DSR_Max(1, (int)(holdTime / level.frametime));
    for(f = 0; f < frames; f++)
    {
        wait level.frametime;
        if(isDefined(self.dsr_holdYield))
        {
            self.dsr_holdYield = undefined;
            if([[level.getVars]]("bot_ai_debug") >= 2)
                logprint("DSR: holdyield " + self.name + " wp=" + self DSR_WpText() + "\n");
            return;
        }
    }
}

DSR_FaceTo(pos)
{
    angles = vectorToAngles(pos - self.origin);
    self.dsr_lookYaw = angles[1];
}

/* *************************************************************************************************
**** DSR_MotorFrame()
****
**** called for every active bot by the dispatcher each frame (no per-bot loop thread): aims at the enemy
**** while dsr_aiming, turns toward dsr_lookYaw / dsr_lookPitch, plays footsteps while walking and watches
**** the clip during a burst or reload. No traces.
************************************************************************************************* */
DSR_MotorFrame()
{
    rate = level.dsr_turnRate;
    if(isDefined(self.dsr_aiming))
    {
        self DSR_AimFrame();
        rate = self.dsr_skAimRate;
    }

    //turn every frame while off target. The motor keeps its own yaw/pitch instead of reading self.angles
    //back, which can lag a frame behind setPlayerAngles and make the steps uneven
    yawDiff = DSR_AngleSubtract(self.dsr_lookYaw, self.dsr_curYaw);
    pitchDiff = self.dsr_lookPitch - self.dsr_curPitch;
    if(yawDiff > level.dsr_turnLeeway || yawDiff < 0 - level.dsr_turnLeeway
        || pitchDiff > level.dsr_turnLeeway || pitchDiff < 0 - level.dsr_turnLeeway)
    {
        self.dsr_curYaw = DSR_AngleNormalize(self.dsr_curYaw + DSR_TurnStep(yawDiff, rate));
        self.dsr_curPitch += DSR_TurnStep(pitchDiff, rate);
        self setPlayerAngles((self.dsr_curPitch, self.dsr_curYaw, 0));
    }

    if(self.dsr_moving && getTime() >= self.dsr_nextStep)
    {
        self.dsr_nextStep = getTime() + level.dsr_stepInterval;
        self DSR_PlaySurface();
    }

    if(isDefined(self.dsr_firing) || isDefined(self.dsr_reloading))
        self DSR_FireFrame();
}

/* *************************************************************************************************
**** DSR_AimFrame()
****
**** points dsr_lookYaw / dsr_lookPitch at the enemy: its chest mark while it is visible (the mark moves
**** with it, so this tracks between thinks for free), else its last known position. The burst's aim
**** error (skill) is added on top.
************************************************************************************************* */
DSR_AimFrame()
{
    enemy = self.dsr_enemy;
    if(!isDefined(enemy))
        return;
    if(self.dsr_cond["SEE_ENEMY"] && isDefined(enemy.dsr_marks))
        target = enemy.dsr_marks[1].origin;
    else if(isDefined(self.dsr_enemyLastPos))
        target = self.dsr_enemyLastPos + (0, 0, 48);
    else
        return;

    angles = vectorToAngles(target - self dsrbot\_dsr_sense::DSR_EyePos());
    self.dsr_lookYaw = DSR_AngleNormalize(angles[1] + self.dsr_aimErrYaw);
    pitch = DSR_AngleNormalize(angles[0]) + self.dsr_aimErrPitch;
    if(pitch > 70)
        pitch = 70;
    else if(pitch < -70)
        pitch = -70;
    self.dsr_lookPitch = pitch;
}

//true when the view is within a few degrees of where the bot wants to look
DSR_AimSettled()
{
    yawDiff = DSR_AngleSubtract(self.dsr_lookYaw, self.dsr_curYaw);
    pitchDiff = self.dsr_lookPitch - self.dsr_curPitch;
    return (yawDiff < 4 && yawDiff > -4 && pitchDiff < 6 && pitchDiff > -6);
}

/* *************************************************************************************************
**** fire control (plan 4.3, 5.5). A test client presses fire on its own, so the held fire variant shoots
**** whatever is in its clip: a burst is "put n rounds in the clip, reserve 0". dsr_mag counts what is left
**** of the simulated magazine; the real clip never holds more than the burst.
************************************************************************************************* */

//self = bot holding a fire variant. Loads a burst of n rounds (at most what is left in dsr_mag)
DSR_StartBurst(n)
{
    if(n > self.dsr_mag)
        n = self.dsr_mag;
    if(n <= 0)
        return;
    self setWeaponSlotAmmo("primary", 0);
    self setWeaponSlotClipAmmo("primary", n);
    self.dsr_burstClip = n;
    self.dsr_firing = true;
    level.dsr_tmBursts++;
    if([[level.getVars]]("bot_ai_debug") >= 3)
        logprint("DSR: burst " + self.name + " n=" + n + " mag=" + self.dsr_mag + " mode=" + self.dsr_fireMode + "\n");
}

//burst size by how the weapon fires, scaled by bot_skill: bolt 1, semi 1-3, auto 3-8
DSR_BurstSize()
{
    kind = level.dsr_fireKind[self.dsr_weapon];
    skill = self.dsr_skill;
    if(kind == "bolt")
        return 1;
    if(kind == "semi")
        return 1 + randomInt(1 + (int)(skill / 4));
    return 3 + randomInt(2 + (int)(skill / 2));
}

/* *************************************************************************************************
**** DSR_StartReload(amount)
****
**** engine reload: an empty clip with reserve ammo makes the next fire press start the stock reload
**** (animation and sound). DSR_FireFrame sees the clip fill and moves it into dsr_mag. VERIFY that test
**** clients reload this way; the RELOAD task falls back to MeatBot's timed refill after 6 s.
************************************************************************************************* */
DSR_StartReload(amount)
{
    self setWeaponSlotClipAmmo("primary", 0);
    self setWeaponSlotAmmo("primary", amount);
    self.dsr_reloading = true;
    level.dsr_tmReloads++;
}

//MeatBot style: no animation, the magazine is simply full again
DSR_ReloadFallback(amount)
{
    self setWeaponSlotAmmo("primary", 0);
    self setWeaponSlotClipAmmo("primary", 0);
    self.dsr_reloading = undefined;
    self.dsr_mag = amount;
    if(self.dsr_reserve > 0)
        self.dsr_reserve = DSR_ClampMin0(self.dsr_reserve - amount);
    if([[level.getVars]]("bot_ai_debug") >= 1)
        logprint("DSR: reload " + self.name + " fallback (no engine reload in 6 s) weapon=" + self getCurrentWeapon() + "\n");
}

//how many rounds a reload can load now; 0 if the reserve is empty
DSR_ReloadAmount()
{
    if(self.dsr_reserve < 0)
        return self.dsr_magMax;
    if(self.dsr_reserve < self.dsr_magMax)
        return self.dsr_reserve;
    return self.dsr_magMax;
}

//every frame during a burst or reload (from DSR_MotorFrame)
DSR_FireFrame()
{
    clip = self getWeaponSlotClipAmmo("primary");
    if(isDefined(self.dsr_reloading))
    {
        if(clip > 0)
        {
            //reload finished: keep the rounds in dsr_mag, empty the real clip until the next burst
            self setWeaponSlotClipAmmo("primary", 0);
            self setWeaponSlotAmmo("primary", 0);
            self.dsr_mag = clip;
            if(self.dsr_reserve > 0)
                self.dsr_reserve = DSR_ClampMin0(self.dsr_reserve - clip);
            self.dsr_reloading = undefined;
        }
        return;
    }

    if(clip < self.dsr_burstClip)
    {
        shots = self.dsr_burstClip - clip;
        self.dsr_mag -= shots;
        level.dsr_tmShots += shots;
        self.dsr_burstClip = clip;
    }
    if(clip <= 0)
        self.dsr_firing = undefined;
}

/* *************************************************************************************************
**** DSR_CeaseFire()
****
**** stops a burst or reload at once: empties the real clip and reserve. Rounds not fired stay in dsr_mag.
**** Called on every schedule change and before every weapon swap.
************************************************************************************************* */
DSR_CeaseFire()
{
    if(isDefined(self.dsr_firing))
    {
        self DSR_FireFrame(); //count what was fired so far
        self setWeaponSlotClipAmmo("primary", 0);
        self.dsr_firing = undefined;
    }
    if(isDefined(self.dsr_reloading))
    {
        self setWeaponSlotAmmo("primary", 0);
        self setWeaponSlotClipAmmo("primary", 0);
        self.dsr_reloading = undefined;
    }
}

//stand or crouch for this attack: HL re-rolls 10% of the time per attack schedule
DSR_PickStance()
{
    if(!isDefined(self.dsr_stance) || randomInt(10) == 0)
    {
        if(randomInt(2))
            self.dsr_stance = "fire_crouch";
        else
            self.dsr_stance = "fire_stand";
    }
    return self.dsr_stance;
}

DSR_ClampMin0(n)
{
    if(n < 0)
        return 0;
    return n;
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
**** DSR_TurnStep(diff, rate)
****
**** this frame's share of a turn: eases out (a fixed part of what's left, per second), capped at rate
**** (degrees per second: dsr_turnRate patrolling, the skill aim rate in combat) and never below
**** dsr_turnMinRate so the last few degrees don't crawl; within the leeway it finishes the turn
************************************************************************************************* */
DSR_TurnStep(diff, rate)
{
    size = diff;
    if(size < 0)
        size = 0 - size;
    if(size <= level.dsr_turnLeeway)
        return diff;

    step = size * level.dsr_turnEase * level.frametime;
    if(step > rate * level.frametime)
        step = rate * level.frametime;
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
