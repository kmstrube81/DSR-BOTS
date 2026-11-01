/* *************************************************************************************************
**** _dsr_sense.gsc
****
**** Perception. Phase 1: the two tag-linked marks per player that later phases trace to (plan 3.2, 7).
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
