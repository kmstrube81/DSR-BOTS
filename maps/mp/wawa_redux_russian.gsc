main()
{
	game["allies"] = "russian";
	game["axis"] = "german";

	game["russian_soldiertype"] = "conscript";
	game["russian_soldiervariation"] = "normal";
	game["german_soldiertype"] = "fallschirmjagergrey";
	game["german_soldiervariation"] = "normal";
	game["attackers"] = "allies";
	game["defenders"] = "axis";

	level.dsr_wpLoad = waypoints\custom\wawa_3dAim_waypoints::load_waypoints;
}