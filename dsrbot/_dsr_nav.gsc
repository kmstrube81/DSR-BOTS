/* *************************************************************************************************
**** _dsr_nav.gsc
****
**** Waypoint prep, spatial grid, nearest node and time-sliced A* (plan section 6).
**** level.wp[i] comes from waypoints\select_map.gsc: .origin, .type, .next[] (directed), .angles.
**** No per-node fields are added; A* uses level-scope parallel arrays reset by a generation counter.
************************************************************************************************* */

/* *************************************************************************************************
**** DSR_NavPrepare()
****
**** loads the map's waypoints and builds the grid, waiting a frame every 200 nodes
************************************************************************************************* */
DSR_NavPrepare()
{
    level.dsr_navReady = false;
    level.dsr_cellSize = 512;
    level.dsr_gridOffset = 65536; //keeps cell coordinates positive so (int) truncation acts as floor

    if(!waypoints\select_map::choose() || !isDefined(level.wp) || level.wp.size < 2)
    {
        logprint("DSR: nav unavailable map=" + getCvar("mapname") + "; bots keep stock behaviour\n");
        return;
    }
    level.dsr_wpCount = level.wp.size;

    level.dsr_grid = [];
    level.dsr_campWps = [];
    for(i = 0; i < level.dsr_wpCount; i++)
    {
        if(level.wp[i].type == "c")
            level.dsr_campWps[level.dsr_campWps.size] = i;

        key = DSR_GridKey(level.wp[i].origin);
        if(!isDefined(level.dsr_grid[key]))
            level.dsr_grid[key] = [];
        level.dsr_grid[key][level.dsr_grid[key].size] = i;

        if(i % 200 == 199)
            wait level.frametime;
    }

    //A* state (6.3): mark[i] = gen*2 when open, gen*2+1 when closed; older gens mean unvisited
    level.dsr_asGen = 0;
    level.dsr_asMark = [];
    level.dsr_asG = [];
    level.dsr_asParent = [];
    level.dsr_heapNode = [];
    level.dsr_heapF = [];
    level.dsr_heapSize = 0;
    level.dsr_asMaxExpand = 3000; //per search, then fail
    level.dsr_search = undefined;
    level.dsr_pathQueue = [];
    level.dsr_pathOk = 0;
    level.dsr_pathFail = 0;

    level.dsr_navReady = true;
    logprint("DSR: nav ready map=" + getCvar("mapname") + " nodes=" + level.dsr_wpCount + " camp=" + level.dsr_campWps.size + "\n");
}

DSR_GridKey(pos)
{
    cx = (int)((pos[0] + level.dsr_gridOffset) / level.dsr_cellSize);
    cy = (int)((pos[1] + level.dsr_gridOffset) / level.dsr_cellSize);
    return cx * 1024 + cy;
}

/* *************************************************************************************************
**** DSR_NearbyCandidates(pos, maxCount)
****
**** up to maxCount node indices from pos's cell and its 8 neighbours, nearest first (plan 6.2).
**** Widens to the 5x5 block if the 3x3 block is empty.
************************************************************************************************* */
DSR_NearbyCandidates(pos, maxCount)
{
    best = [];
    bestDist = [];
    cx = (int)((pos[0] + level.dsr_gridOffset) / level.dsr_cellSize);
    cy = (int)((pos[1] + level.dsr_gridOffset) / level.dsr_cellSize);

    for(r = 1; r <= 2; r++)
    {
        for(dx = 0 - r; dx <= r; dx++)
        {
            for(dy = 0 - r; dy <= r; dy++)
            {
                //the second pass only adds the outer ring
                if(r == 2 && dx > -2 && dx < 2 && dy > -2 && dy < 2)
                    continue;
                key = (cx + dx) * 1024 + (cy + dy);
                if(!isDefined(level.dsr_grid[key]))
                    continue;
                cell = level.dsr_grid[key];
                for(i = 0; i < cell.size; i++)
                {
                    d = distanceSquared(pos, level.wp[cell[i]].origin);
                    //insertion into a short sorted list
                    j = best.size;
                    if(j >= maxCount && d >= bestDist[maxCount - 1])
                        continue;
                    if(j >= maxCount)
                        j = maxCount - 1;
                    while(j > 0 && bestDist[j - 1] > d)
                    {
                        best[j] = best[j - 1];
                        bestDist[j] = bestDist[j - 1];
                        j--;
                    }
                    best[j] = cell[i];
                    bestDist[j] = d;
                }
            }
        }
        if(best.size)
            break;
    }
    return best;
}

/* *************************************************************************************************
**** DSR_NearestWp(pos)
****
**** nearest node index from the grid, or -1 if there is none within two cells
************************************************************************************************* */
DSR_NearestWp(pos)
{
    best = DSR_NearbyCandidates(pos, 1);
    if(!best.size)
        return -1;
    return best[0];
}

/* *************************************************************************************************
**** DSR_NearestVisibleWp(pos)
****
**** self = bot. Nearest of the 4 closest nodes with a clear waist-height trace. Returns -2 when the trace
**** budget refused a trace (retry next think), -1 when there are no nodes near, and the nearest node
**** when none is visible (logged), so the bot is never stranded off the graph.
************************************************************************************************* */
DSR_NearestVisibleWp(pos)
{
    cand = DSR_NearbyCandidates(pos, 4);
    if(!cand.size)
        return -1;

    for(i = 0; i < cand.size; i++)
    {
        trace = dsrbot\_dsr_core::DSR_Trace(pos + (0, 0, 40), level.wp[cand[i]].origin + (0, 0, 40), false, self);
        if(!isDefined(trace))
            return -2;
        if(trace["fraction"] == 1)
            return cand[i];
    }

    if([[level.getVars]]("bot_ai_debug") >= 1)
        logprint("DSR: startnode " + self.name + " none visible, using nearest wp=" + cand[0] + " pos=" + pos + "\n");
    return cand[0];
}

/* *************************************************************************************************
**** DSR_PickPatrolGoal(from)
****
**** a random node at least 1024 units away (best of 6 tries), so patrols cover the map
************************************************************************************************* */
DSR_PickPatrolGoal(from)
{
    org = level.wp[from].origin;
    goal = randomInt(level.dsr_wpCount);
    for(i = 0; i < 6; i++)
    {
        if(goal != from && distanceSquared(org, level.wp[goal].origin) > 1024 * 1024)
            break;
        goal = randomInt(level.dsr_wpCount);
    }
    return goal;
}

/* *************************************************************************************************
**** DSR_RequestPath(start, goal)
****
**** self = bot. Queues a search; the result lands in self.dsr_path / self.dsr_pathState
**** ("queued", "ready", "failed"). A newer request makes an older result stale.
************************************************************************************************* */
DSR_RequestPath(start, goal)
{
    if(!isDefined(self.dsr_pathReq))
        self.dsr_pathReq = 0;
    self.dsr_pathReq++;
    self.dsr_pathState = "queued";
    self.dsr_pathStart = start;
    self.dsr_pathGoal = goal;
    level.dsr_pathQueue[level.dsr_pathQueue.size] = self;
}

/* *************************************************************************************************
**** DSR_GreedyHop(from)
****
**** plan 6.3 fallback: a one-edge path to a random successor of from. Leaves dsr_pathState "failed" if
**** the node has no successors.
************************************************************************************************* */
DSR_GreedyHop(from)
{
    next = level.wp[from].next;
    if(!next.size)
    {
        self.dsr_pathState = "failed";
        return;
    }
    self.dsr_path = [];
    self.dsr_path[0] = from;
    self.dsr_path[1] = next[randomInt(next.size)];
    self.dsr_pathState = "ready";
}

/* *************************************************************************************************
**** DSR_AStarRun()
****
**** called every frame by the dispatcher. Spends at most level.dsr_astarCap node expansions, shared by
**** all bots, working through the path queue one search at a time.
************************************************************************************************* */
DSR_AStarRun()
{
    budget = level.dsr_astarCap;
    while(budget > 0)
    {
        if(!isDefined(level.dsr_search))
        {
            if(!DSR_AStarNext())
                return;
        }
        budget -= DSR_AStarStep(budget);
    }
}

//pops the next live request off the queue and starts it; false when the queue is empty
DSR_AStarNext()
{
    while(level.dsr_pathQueue.size)
    {
        bot = level.dsr_pathQueue[0];
        queue = [];
        for(i = 1; i < level.dsr_pathQueue.size; i++)
            queue[queue.size] = level.dsr_pathQueue[i];
        level.dsr_pathQueue = queue;

        if(!isDefined(bot) || !isPlayer(bot) || !isDefined(bot.dsr_active) || bot.dsr_pathState != "queued")
            continue;

        level.dsr_search = bot;
        level.dsr_searchReq = bot.dsr_pathReq;
        level.dsr_searchGoal = bot.dsr_pathGoal;
        level.dsr_searchStart = bot.dsr_pathStart;
        level.dsr_searchExpanded = 0;

        level.dsr_asGen++;
        level.dsr_heapSize = 0;
        start = level.dsr_searchStart;
        level.dsr_asG[start] = 0;
        level.dsr_asParent[start] = -1;
        level.dsr_asMark[start] = level.dsr_asGen * 2;
        DSR_HeapPush(start, distance(level.wp[start].origin, level.wp[level.dsr_searchGoal].origin));
        return true;
    }
    return false;
}

/* *************************************************************************************************
**** DSR_AStarStep(budget)
****
**** expands up to budget nodes of the current search; returns the number of expansions used
************************************************************************************************* */
DSR_AStarStep(budget)
{
    open = level.dsr_asGen * 2;
    closed = open + 1;
    goal = level.dsr_searchGoal;
    goalOrg = level.wp[goal].origin;

    used = 0;
    while(used < budget)
    {
        if(!level.dsr_heapSize || level.dsr_searchExpanded >= level.dsr_asMaxExpand)
        {
            DSR_AStarFinish(false);
            return used + 1;
        }

        node = DSR_HeapPop();
        if(level.dsr_asMark[node] == closed)
            continue; //stale duplicate left by a cheaper re-push
        level.dsr_asMark[node] = closed;
        used++;
        level.dsr_searchExpanded++;
        level.dsr_expansions++;

        if(node == goal)
        {
            DSR_AStarFinish(true);
            return used;
        }

        wp = level.wp[node];
        //special edges cost extra so walking routes win when they are close
        penalty = 0;
        if(wp.type == "j" || wp.type == "f")
            penalty = 64;
        else if(wp.type == "l")
            penalty = 128;

        for(i = 0; i < wp.next.size; i++)
        {
            s = wp.next[i];
            g = level.dsr_asG[node] + distance(wp.origin, level.wp[s].origin) + penalty;
            if(isDefined(level.dsr_asMark[s]) && level.dsr_asMark[s] >= open)
            {
                if(level.dsr_asMark[s] == closed || g >= level.dsr_asG[s])
                    continue;
            }
            level.dsr_asG[s] = g;
            level.dsr_asParent[s] = node;
            level.dsr_asMark[s] = open;
            DSR_HeapPush(s, g + distance(level.wp[s].origin, goalOrg));
        }
    }
    return used;
}

DSR_AStarFinish(found)
{
    bot = level.dsr_search;
    level.dsr_search = undefined;

    if(found)
        level.dsr_pathOk++;
    else
        level.dsr_pathFail++;

    //the bot died, left or asked for a newer path while this one was running
    if(!isDefined(bot) || !isPlayer(bot) || !isDefined(bot.dsr_active) || bot.dsr_pathReq != level.dsr_searchReq)
        return;

    if(!found)
    {
        bot.dsr_pathState = "failed";
        if([[level.getVars]]("bot_ai_debug") >= 2)
            logprint("DSR: path " + bot.name + " from=" + level.dsr_searchStart + " to=" + level.dsr_searchGoal + " failed exp=" + level.dsr_searchExpanded + "\n");
        return;
    }

    //walk the parents back from the goal, then reverse
    rev = [];
    n = level.dsr_searchGoal;
    while(n != -1)
    {
        rev[rev.size] = n;
        n = level.dsr_asParent[n];
    }
    path = [];
    for(i = rev.size - 1; i >= 0; i--)
        path[path.size] = rev[i];

    bot.dsr_path = path;
    bot.dsr_pathState = "ready";
    if([[level.getVars]]("bot_ai_debug") >= 2)
        logprint("DSR: path " + bot.name + " from=" + level.dsr_searchStart + " to=" + level.dsr_searchGoal + " nodes=" + path.size + " exp=" + level.dsr_searchExpanded + "\n");
}

/* *************************************************************************************************
**** binary min-heap on f, in level.dsr_heapNode / level.dsr_heapF. No decrease-key: a cheaper route
**** pushes the node again and the stale copy is skipped when popped (it is already closed).
************************************************************************************************* */
DSR_HeapPush(node, f)
{
    i = level.dsr_heapSize;
    level.dsr_heapSize++;
    while(i > 0)
    {
        p = (int)((i - 1) / 2);
        if(level.dsr_heapF[p] <= f)
            break;
        level.dsr_heapNode[i] = level.dsr_heapNode[p];
        level.dsr_heapF[i] = level.dsr_heapF[p];
        i = p;
    }
    level.dsr_heapNode[i] = node;
    level.dsr_heapF[i] = f;
}

DSR_HeapPop()
{
    top = level.dsr_heapNode[0];
    level.dsr_heapSize--;
    count = level.dsr_heapSize;
    if(!count)
        return top;

    node = level.dsr_heapNode[count];
    f = level.dsr_heapF[count];
    i = 0;
    for(;;)
    {
        c = i * 2 + 1;
        if(c >= count)
            break;
        if(c + 1 < count && level.dsr_heapF[c + 1] < level.dsr_heapF[c])
            c++;
        if(level.dsr_heapF[c] >= f)
            break;
        level.dsr_heapNode[i] = level.dsr_heapNode[c];
        level.dsr_heapF[i] = level.dsr_heapF[c];
        i = c;
    }
    level.dsr_heapNode[i] = node;
    level.dsr_heapF[i] = f;
    return top;
}
