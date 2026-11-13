

main() 
{
maps\mp\_load::main();
level thread maps\mp\casa_fx::main();
    setCullFog (5000, 10000, .32, .36, .40, 0);

      setcvar("sv_night", "0" );
ambientPlay("ambient_casa");

              game["allies"] = "american";

	game["axis"] = "german";
	game["american_soldiertype"] = "airborne";
	game["american_soldiervariation"] = "normal";
	game["german_soldiertype"] = "fallschirmjagergrey";
	game["german_soldiervariation"] = "normal";

	game["attackers"] = "allies";
	game["defenders"] = "axis";

//retrieval settings
        level.obj["cod"] = (&"RE_OBJ_CODE_BOOK");
level.obj["rad"] = (&"RE_OBJ_FIELD_RADIO");
	game["re_attackers"] = "allies";
	game["re_defenders"] = "axis";
	game["re_attackers_obj_text"] = "Find the codebooks & return with them.";
	game["re_defenders_obj_text"] = "Protect the codebooks!";
	game["re_spectator_obj_text"] = "Allies have to return to base with the codebooks.";
	game["re_attackers_intro_text"] = "Locate & return with the Axis codebooks.";
	game["re_defenders_intro_text"] = "Don't let the codebooks slip into Allied hands!!!";


	level.dsr_wpLoad = waypoints\custom\casa_de_austin_ctf_waypoints::main;
}


