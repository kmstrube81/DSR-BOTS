main()
{
	game["allies"] = "american";
	game["axis"] = "german";

	game["american_soldiertype"] = "airborne";
	game["american_soldiervariation"] = "normal";
	game["german_soldiertype"] = "fallschirmjagergrey";
	game["german_soldiervariation"] = "normal";
	game["attackers"] = "allies";
	game["defenders"] = "axis";

	level.dsr_wpLoad = waypoints\custom\wawa_3dAim_waypoints::load_waypoints;
	level.dsr_wpType = false;
}