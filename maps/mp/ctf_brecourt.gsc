main()
{
	setCullFog (0, 13500, .32, .36, .40, 0);
	ambientPlay("ambient_mp_brecourt");
	
	maps\mp\_load::main();
	maps\mp\mp_dawnville_fx::main();
      maps\mp\ctf_brecourt::layout_images();
	
	game["allies"] = "american";
	game["axis"] = "german";

       game["hud_allies_victory_image"]= "gfx/hud/hud@mp_victory_breusa.dds";
       game["hud_axis_victory_image"] = "gfx/hud/hud@mp_victory_breger.dds";

	game["american_soldiertype"] = "airborne";
	game["american_soldiervariation"] = "normal";
	game["german_soldiertype"] = "fallschirmjagergrey";
	game["german_soldiervariation"] = "normal";

	game["attackers"] = "allies";
	game["defenders"] = "axis";
 

      game["ctf_spectator_obj_text"] = "^3Quit spectating, you Bum!! You've got a job to do!!"; //put whatever spec text you want

	level.dsr_wpLoad = waypoints\mp_brecourt_tdm::load_waypoints;
	}
	
layout_images()
{      

      game["layoutimage"] = "ctf_brecourt";  //this is the load screen
      game["ctf_layoutimage"] = "ctf_brecourt";   //this is brecourts overhead, make a new one for ctf
	
}
