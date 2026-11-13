main()
{
	setExpFog(0.00001, 0, 0, 0, 0);
	ambientPlay("ambient_mp_powcamp");

	maps\mp\_load::main();
        maps\mp\bugs_fx::main();
	level.the_bug = loadfx("fx/weather/fireflys.efx");

	game["allies"] = "british";
	game["axis"] = "german";

	game["british_soldiertype"] = "airborne";
	game["british_soldiervariation"] = "normal";
	game["german_soldiertype"] = "wehrmacht";
	game["german_soldiervariation"] = "normal";

	game["attackers"] = "allies";
	game["defenders"] = "axis";
	
	game["layoutimage"] = "ctf_chateau";
         game["ctf_layoutimage"] = "ctf_chateau";

        game["hud_allies_victory_image"]= "gfx/hud/hud@mp_victory_chabrit.dds";
	game["hud_axis_victory_image"] 	= "gfx/hud/hud@mp_victory_chager.dds";
	
	level.dsr_wpLoad = waypoints\mp_chateau_tdm::load_waypoints;
}
