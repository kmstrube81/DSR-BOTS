main()
{
	setCullFog(0, 20000, 0.35, 0.345, 0.33, 0 );
	ambientPlay("ambient_mp_carentan");
	// set the nighttime flag to be off
	setcvar("sv_night", "0" );

	maps\mp\_load::main();
	game["allies"] = "american";
	game["axis"] = "german";

	game["hud_allies_victory_image"]= "gfx/hud/hud@mp_victory_killhouse_r.dds";
	game["hud_axis_victory_image"] 	= "gfx/hud/hud@mp_victory_killhouse_g.dds";

	game["attackers"] = "allies";
	game["defenders"] = "axis";

	game["compass_range"] = 6124;

        level thread maps\mp\_tankdrive_gmi::main();//for tanks
        level thread maps\mp\_jeepdrive_gmi::main();//for jeeps
        level thread maps\mp\_flak_gmi::main();//for flak88s 

	level.dsr_wpLoad = waypoints\custom\mp_uo_killhouse_waypoints_ctf::main;

}