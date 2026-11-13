/////////////////////////////////////////
///////////|OCG|=gLiTcH=/////////////////
////////http://ocgamers.net//////////////
/////////////////////////////////////////

main()
{
      setCullFog (200, 3700, .32, .36, .40, 0);
	ambientPlay("cold_weather");

	maps\mp\_load::main();
	maps\mp\uo_rocket_ctf_fx::main();
      maps\mp\uo_rocket_ctf::layout_images(); 

      level thread maps\mp\uo_rocket_snow_fx::main();

	game["allies"] = "british";
	game["axis"] = "german";

      game["hud_allies_victory_image"]= "gfx/hud/hud@mp_victory_uo_rocket_ctf_br.dds";
	game["hud_axis_victory_image"] = "gfx/hud/hud@mp_victory_uo_rocket_ctf_g.dds";

	game["british_soldiertype"] = "commando";
	game["british_soldiervariation"] = "winter";
	game["german_soldiertype"] = "waffen";
	game["german_soldiervariation"] = "winter";

	game["attackers"] = "allies";
	game["defenders"] = "axis";

      game["ctf_spectator_obj_text"] = "^3Quit spectating, you Bum!! You've got a job to do!!";

	level.dsr_wpLoad = waypoints\mp_rocket_tdm::load_waypoints;
	
}

layout_images()
{
	
	game["layoutimage"] = "uo_rocket_ctf";
      game["ctf_layoutimage"] = "uo_rocket_ctf";
}





