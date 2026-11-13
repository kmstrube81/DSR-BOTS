main()
{
//	setCullFog (0, 5500, .32, .36, .40, 0); //stormyfogged sky fog color
	setCullFog (0, 6500, .8, .8, .8, 0); //pavlovtest sky color
	ambientPlay("ambient_mp_harbor");

	maps\mp\_load::main();
	//maps\mp\mp_railyard_fx::main();
	
	game["allies"] = "russian";
	game["axis"] = "german";

	game["russian_soldiertype"] = "conscript";
	game["russian_soldiervariation"] = "winter";
	game["german_soldiertype"] = "waffen";
	game["german_soldiervariation"] = "winter";

	game["attackers"] = "allies";
	game["defenders"] = "axis";

	maps\mp\ctf_brecourt::layout_images();
	       game["hud_allies_victory_image"]= "gfx/hud/hud@mp_victory_harusa.dds";
       game["hud_axis_victory_image"] = "gfx/hud/hud@mp_victory_harger.dds";

	//retrival settings
	level.obj["Artillery Map"] = (&"RE_OBJ_ARTILLERY_MAP");
	game["re_attackers"] = "allies";
	game["re_defenders"] = "axis";
	game["re_attackers_obj_text"] = (&"RE_OBJ_HARBOR_OBJ_ATTACKER");
	game["re_defenders_obj_text"] = (&"RE_OBJ_HARBOR_OBJ_DEFENDER");
	game["re_spectator_obj_text"] = (&"RE_OBJ_HARBOR_OBJ_SPECTATOR");
	game["re_attackers_intro_text"] = (&"RE_OBJ_HARBOR_SPAWN_ATTACKER");
	game["re_defenders_intro_text"] = (&"RE_OBJ_HARBOR_SPAWN_DEFENDER");
	
	game["ctf_spectator_obj_text"] = "wtf"; //put whatever spec text you want

	level.dsr_wpLoad = waypoints\mp_harbor_tdm::load_waypoints;
	
}

layout_images()
{      

      game["layoutimage"] = "ctf_brecourt";  //this is the load screen
      game["ctf_layoutimage"] = "ctf_brecourt";   //this is brecourts overhead, make a new one for ctf
}
