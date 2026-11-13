main()
{
	setExpFog(0.00001, 0, 0, 0, 0);
	ambientPlay("ambient_mp_powcamp");

	maps\mp\_load::main();
        maps\mp\bugs_fx::main();
	level.the_bug = loadfx("fx/weather/fireflys.efx");

	game["allies"] = "american";
	game["axis"] = "german";

	game["american_soldiertype"] = "airborne";
	game["american_soldiervariation"] = "normal";
	game["german_soldiertype"] = "wehrmacht";
	game["german_soldiervariation"] = "normal";

	game["attackers"] = "allies";
	game["defenders"] = "axis";
	
	game["layoutimage"] = "mp_chateau";
         game["ctf_layoutimage"] = "mp_chateau";

        game["hud_allies_victory_image"]= "gfx/hud/hud@mp_victory_chabrit.dds";
	game["hud_axis_victory_image"] 	= "gfx/hud/hud@mp_victory_chager.dds";

	radioA = getent("sd_objective_a", "targetname");
	radioB = getent("sd_objective_b", "targetname");

	radioA playLoopSound("german_radio");
	radioB playLoopSound("german_radio");

	level.dsr_wpLoad = waypoints\mp_chateau_tdm::load_waypoints;

}
