/////////////////////////////////////////
///////////|OCG|=gLiTcH=/////////////////
////////http://ocgamers.net//////////////
/////////////////////////////////////////

main()
{
	setExpFog(0.00010, .32, .36, .40, 0);
	ambientPlay("ambient_mp_dawnville");

	maps\mp\_load::main();
	maps\mp\uo_tigertown_ctf_fx::main();
      maps\mp\uo_tigertown_ctf::layout_images(); 

	game["allies"] = "american";
	game["axis"] = "german";

      game["hud_allies_victory_image"]= "gfx/hud/hud@mp_victory_uo_tigertown_ctf_us.dds";
	game["hud_axis_victory_image"] = "gfx/hud/hud@mp_victory_uo_tigertown_ctf_g.dds";

	game["american_soldiertype"] = "airborne";
	game["american_soldiervariation"] = "normal";
	game["german_soldiertype"] = "waffen";
	game["german_soldiervariation"] = "normal";

	game["attackers"] = "allies";
	game["defenders"] = "axis";

      game["ctf_spectator_obj_text"] = "^3Quit spectating, you Bum!! You've got a job to do!!";

	level.dsr_wpLoad = waypoints\mp_tigertown_tdm::load_waypoints;

}

layout_images()
{
	
	game["layoutimage"] = "uo_tigertown_ctf";
      game["ctf_layoutimage"] = "uo_tigertown_ctf";
}



	
