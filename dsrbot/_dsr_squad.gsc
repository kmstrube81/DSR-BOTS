/* *************************************************************************************************
**** _dsr_squad.gsc
****
**** Squads, leader, shared enemy and slots come in Phase 5 (plan 5.1). Phase 3 adds the chatter: bots
**** speak only through the stock quick-chat lines (plan 2.5), sent as the same menuresponse a human's
**** quick-chat menu sends, so CODUO-X routes them to the stock _teams::quick* functions (head icon,
**** say text, the stock 2 s spam delay). Numbers (stock UO _teams.gsc):
****   statements 1 enemy spotted, 2 enemy down, 3 in position, 4 area secure
****   responses  3 on my way
************************************************************************************************* */

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
