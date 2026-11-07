/* *************************************************************************************************
**** _dsr_debug.gsc
****
**** Telemetry (plan section 10). The dispatcher closes each frame's counters into these accumulators;
**** DSR_Telemetry logs them once a second when bot_ai_debug >= 1.
************************************************************************************************* */

DSR_TelemetryReset()
{
    level.dsr_tmFrames = 0;
    level.dsr_tmTraces = 0;
    level.dsr_tmTracesMax = 0;
    level.dsr_tmThinks = 0;
    level.dsr_tmThinksMax = 0;
    level.dsr_tmExp = 0;
    level.dsr_tmExpMax = 0;
    level.dsr_tracesRefused = 0;
    level.dsr_tmAcquire = 0;
    level.dsr_tmBursts = 0;
    level.dsr_tmShots = 0;
    level.dsr_tmReloads = 0;
    level.dsr_tmFlanks = 0;
    level.dsr_tmGiveUps = 0;
}

/* *************************************************************************************************
**** DSR_TelemetryFrame()
****
**** from the dispatcher, before it resets the per-frame counters: adds the frame that just ended
************************************************************************************************* */
DSR_TelemetryFrame()
{
    level.dsr_tmFrames++;
    level.dsr_tmTraces += level.dsr_traces;
    if(level.dsr_traces > level.dsr_tmTracesMax)
        level.dsr_tmTracesMax = level.dsr_traces;
    level.dsr_tmThinks += level.dsr_thinks;
    if(level.dsr_thinks > level.dsr_tmThinksMax)
        level.dsr_tmThinksMax = level.dsr_thinks;
    level.dsr_tmExp += level.dsr_expansions;
    if(level.dsr_expansions > level.dsr_tmExpMax)
        level.dsr_tmExpMax = level.dsr_expansions;
}

/* *************************************************************************************************
**** DSR_Telemetry()
****
**** level slow loop (1 s). One line:
****   DSR: telemetry bots=<active> frames=<n> traces=<avg>/<max> cap=<cap> refused=<n>
****        thinks=<avg>/<max> astar=<avg>/<max> cap=<cap> queue=<n> paths=<ok>/<failed> drift=<units>
**** avg and max are per frame over the last second; paths are totals for the map; drift is the largest
**** distance between an active bot and its dsr_org, and should stay near 0. Phase 2 appends
****        acquire=<n> bursts=<n> shots=<n> reloads=<n> flanks=<n> giveups=<n>
**** totals for the last second: new enemies, bursts loaded, rounds fired, reloads started, flank requests,
**** targets given up after missed bursts
************************************************************************************************* */
DSR_Telemetry()
{
    if([[level.getVars]]("bot_ai_debug") >= 1 && level.dsr_tmFrames > 0)
    {
        //drift: the largest distance between an active bot and the script_origin it should be riding
        bots = 0;
        drift = 0;
        players = getentarray("player", "classname");
        for(i = 0; i < players.size; i++)
        {
            if(!isDefined(players[i].dsr_active))
                continue;
            bots++;
            if(isDefined(players[i].dsr_org))
            {
                d = distance(players[i].origin, players[i].dsr_org.origin);
                if(d > drift)
                    drift = d;
            }
        }
        drift = (int)(drift + 0.5);

        n = level.dsr_tmFrames;
        squads = 0;
        if(isDefined(level.dsr_sqUsed))
        {
            for(i = 0; i < level.dsr_sqMax; i++)
            {
                if(level.dsr_sqUsed[i])
                    squads++;
            }
        }
        logprint("DSR: telemetry level=" + level.dsr_aiLevel + " squads=" + squads + " bots=" + bots + " frames=" + n
            + " traces=" + DSR_Avg(level.dsr_tmTraces, n) + "/" + level.dsr_tmTracesMax + " cap=" + level.dsr_traceCap
            + " refused=" + level.dsr_tracesRefused
            + " thinks=" + DSR_Avg(level.dsr_tmThinks, n) + "/" + level.dsr_tmThinksMax
            + " astar=" + DSR_Avg(level.dsr_tmExp, n) + "/" + level.dsr_tmExpMax + " cap=" + level.dsr_astarCap
            + " queue=" + level.dsr_pathQueue.size + " paths=" + level.dsr_pathOk + "/" + level.dsr_pathFail
            + " drift=" + drift
            + " acquire=" + level.dsr_tmAcquire + " bursts=" + level.dsr_tmBursts + " shots=" + level.dsr_tmShots
            + " reloads=" + level.dsr_tmReloads + " flanks=" + level.dsr_tmFlanks + " giveups=" + level.dsr_tmGiveUps + "\n");
    }
    DSR_TelemetryReset();
}

//average to two decimals, as a string
DSR_Avg(total, frames)
{
    hundredths = (int)((total * 100.0) / frames + 0.5);
    whole = (int)(hundredths / 100);
    frac = hundredths - whole * 100;
    if(frac < 10)
        return "" + whole + ".0" + frac;
    return "" + whole + "." + frac;
}
