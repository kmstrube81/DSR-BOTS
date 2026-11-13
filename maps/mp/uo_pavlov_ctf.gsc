/////////////////////////////////////////
///////////|OCG|=gLiTcH=/////////////////
////////http://ocgamers.net//////////////
/////////////////////////////////////////

main()
{
	setCullFog (0, 6000, 0.8, 0.8, 0.8, 0);
	ambientPlay("ambient_mp_pavlov");
	
	maps\mp\_load::main();
	maps\mp\uo_pavlov_ctf_fx::main();
      maps\mp\uo_pavlov_ctf::layout_images(); 
	
	game["allies"] = "russian";
	game["axis"] = "german";

      game["hud_allies_victory_image"]= "gfx/hud/hud@mp_victory_uo_pavlov_ctf_r.dds";
	game["hud_axis_victory_image"] = "gfx/hud/hud@mp_victory_uo_pavlov_ctf_g.dds";

	game["russian_soldiertype"] = "conscript";
	game["russian_soldiervariation"] = "winter";
	game["german_soldiertype"] = "waffen";
	game["german_soldiervariation"] = "winter";

	game["attackers"] = "axis";
	game["defenders"] = "allies";

      game["ctf_spectator_obj_text"] = "^3Quit spectating, you Bum!! You've got a job to do!!";

	level.dsr_wpLoad = waypoints\mp_pavlov_tdm::load_waypoints;
	}

layout_images()
{
	
	game["layoutimage"] = "uo_pavlov_ctf";
      game["ctf_layoutimage"] = "uo_pavlov_ctf";
}

