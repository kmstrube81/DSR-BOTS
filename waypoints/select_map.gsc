choose()
{
	level.wpsize = 0;
	level.vMapName=getCvar("mapname");
	
	switch(level.vMapName)
	{
		case "mp_carentan":
			waypoints\mp_carentan_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
	
		case "mp_stalingrad":
			waypoints\mp_stalingrad_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
	
		case "mp_neuville":
			waypoints\mp_neuville_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
		
		case "mp_neuville-winter":
			waypoints\mp_neuville_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
	
		case "mp_kharkov":
			waypoints\mp_kharkov_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
	
		case "mp_cassino":
			waypoints\mp_cassino_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
	
		case "mp_brecourt":
			waypoints\mp_brecourt_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
		
		case "brecourt_russian":
			waypoints\mp_brecourt_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
	
		case "mp_hurtgen":
			waypoints\mp_hurtgen_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
		
		case "mp_hurtgen-autumn":
			waypoints\mp_hurtgen_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
	
		case "mp_dawnville":
			waypoints\mp_dawnville_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
	
		case "mp_sicily":
			waypoints\mp_sicily_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
	
		case "mp_pavlov":
			waypoints\mp_pavlov_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
	
		case "mp_chateau":
			waypoints\mp_chateau_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
	
		case "mp_railyard":
			waypoints\mp_railyard_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
	
		case "mp_powcamp":
			waypoints\mp_powcamp_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
		
		case "mp_berlin":
			waypoints\mp_berlin_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
	
		case "mp_depot":
			waypoints\mp_depot_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
	
		case "mp_harbor":
			waypoints\mp_harbor_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
	
		case "mp_rocket":
			waypoints\mp_rocket_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
	
		case "mp_ship":
			waypoints\mp_ship_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
	
		case "mp_uo_stanjel":
			waypoints\mp_uo_stanjel_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
		
		case "mp_stanjel":
			waypoints\mp_stanjel_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
		
		case "mp_tigertown":
			waypoints\mp_tigertown_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;
		
		case "mp_arnhem":
			waypoints\mp_arnhem_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;

		case "mp_priory":
			waypoints\mp_priory_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;

		case "haugesund_docks":
			waypoints\haugesund_docks_tdm::load_waypoints();
			level.bot_wptype = false;
			println("Loaded.\n");
			return true;

		//PeZBOT Waypoints
		case "remagen_v1.1":
			waypoints\remagen_v1_1_waypoints::load_waypoints();
			level.bot_wptype = true;
			println("Loaded.\n");
			return true;
		
		case "mp_uo_borisovka2":
			waypoints\mp_uo_borisovka2_waypoints::load_waypoints();
			level.bot_wptype = true;
			println("Loaded.\n");
			return true;
		
		case "mp_uo_borisovka2_night":
			waypoints\mp_uo_borisovka2_waypoints::load_waypoints();
			level.bot_wptype = true;
			println("Loaded.\n");
			return true;
		
		case "midnight":
			waypoints\midnight_waypoints::load_waypoints();
			level.bot_wptype = true;
			println("Loaded.\n");
			return true;

		case "mp_saint-lo":
			waypoints\mp_saint_lo_waypoints::load_waypoints();
			level.bot_wptype = true;
			println("Loaded.\n");
			return true;

		case "mp_stcomedumont":
			waypoints\mp_stcomedumont_waypoints::load_waypoints();
			level.bot_wptype = true;
			println("Loaded.\n");
			return true;

		default:
		return false;
	}
}