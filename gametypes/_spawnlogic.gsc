getSpawnpoint_Random(spawnpoints)
{

	// There are no valid spawnpoints in the map
	if(!isdefined(spawnpoints))
		return undefined;

	for(i = 0; i < spawnpoints.size; i++)
	{
		j = randomInt(spawnpoints.size);
		spawnpoint = spawnpoints[i];
		spawnpoints[i] = spawnpoints[j];
		spawnpoints[j] = spawnpoint;
	}
	 
	for(i = 0; i < spawnpoints.size; i++)
	{
		spawnpoint = spawnpoints[i];
		if(!positionWouldTelefrag(spawnpoint.origin))
			break;
	}

	return spawnpoint;
}

// Picks a non-telefragging spawn point farthest from other players
getSpawnpoint_Farthest(spawnpoints)
{
	
	// There are no valid spawnpoints in the map
	if(!isdefined(spawnpoints))
		return undefined;

// TEMP DISABLED SPAWNING AWAY FROM PLAYERS
/*
	// Make a list of fully connected, non-spectating, alive players
	players = getentarray("player", "classname");
	for(i = 0; i < players.size; i++)
	{
		player = players[i];
		
		if(player.sessionstate == "spectator" || player.sessionstate == "dead" || player == self)
		{
//			println("### ", player.name, " not considered:");
//			
//			println("    player.sessionstate == ", player.sessionstate);
//			
//			if(player == self)
//				println("    player == self");
				
			continue;
		}

		positions = addorigin_to_array(positions, player);
//		println("*** ", player.name, " added to consider list");
	}
*/
	if(isdefined(level.deatharray))
	{
		if(!isdefined(positions))
		{
			positions[0] = level.deatharray[0];

			for(i = 1; i < level.deatharray.size; i++)
				positions[positions.size] = level.deatharray[i];
		}
		else
		{
			for(i = 0; i < level.deatharray.size; i++)
				positions[positions.size] = level.deatharray[i];
		}
	}	

	// Spawn away from players if they exist, otherwise spawn at a random spawnpoint
	if(isdefined(positions))
	{
//		println("*** SPAWNING FARTHEST: ", self.name);
		
		distsmallest = 33554432;
	
		for(i = 0; i < spawnpoints.size; i++)
		{
			if(positionWouldTelefrag(spawnpoints[i].origin))
				continue;

			dist = 0;
		
			for(j = 0; j < positions.size; j++)
			{
				dist += 1.0 / (distance(spawnpoints[i].origin, positions[j]) + 1.0);
			}
		
			if(dist < distsmallest)
			{
				distsmallest = dist;
				bestposition = spawnpoints[i];
			}
		}
		
		spawnpoint = bestposition;
	}
	else
	{
//		println("*** SPAWNING RANDOM: ", self.name);
		spawnpoint = getSpawnpoint_Random(spawnpoints);
	}

	return spawnpoint;
}

getSpawnpoint_NearTeam(original_spawnpoints)
{
	// There are no valid spawnpoints in the map
	if(!isdefined(original_spawnpoints))
		return undefined;

	player_on_my_team = false;
	
	// clean out any spawn points that have recent deaths associated with them
	spawnpoints = clear_spawn_camped(original_spawnpoints);
	
	// if everything is spawn camped pick a random spot
	if ( spawnpoints.size == 0 )
	{
		return getSpawnpoint_Random(original_spawnpoints);
	}
	
	// Make a list of fully connected, non-spectating, alive players
	players = getentarray("player", "classname");
	for(i = 0; i < players.size; i++)
	{
		player = players[i];
		
		if(!isValidPlayer(player) || player.sessionstate == "spectator" || player.sessionstate == "dead" || player == self)
		{
			continue;
		}

		aliveplayers = maps\mp\_util_mp_gmi::add_to_array(aliveplayers, player);
//		println("*** ", player.name, " on team ", player.pers["team"], " added to consider list");
		if(player.pers["team"] == self.pers["team"])
		{
			player_on_my_team = true;
		}
	}

	// if there are no players on spawners team then go to a different spawn scheme
	if ( !player_on_my_team )
	{
		return getSpawnpoint_SemiRandom(spawnpoints);
	}
	
	// get all of the vehicles on a team
	vehicles = getentarray("script_vehicle","classname");
	for(i = 0; i < vehicles.size; i++)
	{
		vehicle = vehicles[i];
		
		if ( !isalive( vehicle ) )
			continue;
		
		validvehicles = maps\mp\_util_mp_gmi::add_to_array(validvehicles, vehicle);
	}
	
	// Spawn away from players if they exist, otherwise spawn at a random spawnpoint
	if(isdefined(aliveplayers) || isdefined(validvehicles))
	{
		distlargest = -33554432;

		for(i = 0; i < spawnpoints.size; i++)
		{
			if(positionWouldTelefrag(spawnpoints[i].origin))
				continue;
				
			dist = 0;

			if(isdefined(aliveplayers))
			{
				for(j = 0; j < aliveplayers.size; j++)
				{
					weight = 1.0;
								
					if(aliveplayers[j].pers["team"] == self.pers["team"])
					{
						player_on_my_team = true;
						weight *= -2.0;
					}
					else
						weight *= 1.0;
						
					// a small amount of randomness is introduced to keep everything from happening the same
					weight *= 0.8 + randomfloat( 0.4 );
	
					dist = dist + (distance(spawnpoints[i].origin, aliveplayers[j].origin) * weight);
				}
			}

			if(isdefined(validvehicles))
			{
				one_vehicle_already = false;
				for(j = 0; j < validvehicles.size; j++)
				{
					weight = 1.0;
					owner = validvehicles[j] getvehicleowner(  );
					owner_on_team = false;	
				
					if ( isdefined(owner) && owner.pers["team"] == self.pers["team"] )
					{
						owner_on_team = true;	
					}
					
					// more heavily weight vehicles with owner
					if(isdefined(owner))
					{
						// if the driver is on spawner team
						if ( owner_on_team )
						{
							weight *= -1.0;
						}
						else
						{
							weight *= 2.0;
						}
					}
					else
					{
						// for now don't factor in empty vehicles
						continue;
					}
					// we want empty vehicles to wiegh very heavily so people spawn near them
					// if vehicle is on spawner team a little bit more weight then unoccupied enemy vehicles
//					else if(isDefined(validvehicles[j].team) && validvehicles[j].team == self.pers["team"])
//					{
//						// only do this if there are no alive players
//						if ( !player_on_my_team )
//							weight *= -3.0;
//					}
//					else
//						weight *= -1.5;
						
					// a small amount of randomness is introduced to keep everything from happening the same
					weight *= 0.8 + randomfloat( 0.4 );
	
					spawn_point_dist = distance(spawnpoints[i].origin, validvehicles[j].origin);
					
					// ignore the vehicles if they are to far away
					if ( !isdefined(owner) && spawn_point_dist > 1000 )
						continue;
						
					dist = dist + (spawn_point_dist * weight);
				}
			}
			
			// the biggest distance is going to be the best place away from the bad guys
			if(dist > distlargest)
			{
				distlargest = dist;
				bestposition = spawnpoints[i];
			}
		}

		spawnpoint = bestposition;
	}
	else
	{
//		println("*** SPAWNING RANDOM: ", self.name);
		spawnpoint = getSpawnpoint_Random(spawnpoints);
	}
	
	if ( !isdefined(spawnpoint) )
	{
		spawnpoint = getSpawnpoint_Random(spawnpoints);
	}
	
	return spawnpoint;
}

// Returns the spawn point closest to the passed in position.
NearestSpawnpoint(aeSpawnpoints, vPosition)
{
	eNearestSpot = aeSpawnpoints[0];
	fNearestDist = distance(vPosition, aeSpawnpoints[0].origin);
	for(i = 1; i < aeSpawnpoints.size; i++)
	{
		fDist = distance(vPosition, aeSpawnpoints[i].origin);
		if(fDist < fNearestDist)
		{
			eNearestSpot = aeSpawnpoints[i];
			fNearestDist = fDist;
		}
	}
	
	return eNearestSpot;
}

getSpawnpoint_SemiRandom(spawnpoints)
{
//	level endon("intermission");

	// There are no valid spawnpoints in the map
	if(!isdefined(spawnpoints))
		return undefined;

	// Make a list of fully connected, non-spectating, alive players
	players = getentarray("player", "classname");
	for(i = 0; i < players.size; i++)
	{
		player = players[i];
		if(player.sessionstate == "spectator" || player.sessionstate == "dead" || player == self)
			continue;
		aliveplayers = add_to_array(aliveplayers, player);
	}

	// Spawn away from players if they exist, otherwise spawn at a random spawnpoint
	if(isdefined(aliveplayers))
	{
		for(i = 0; i < spawnpoints.size; i++)
		{
			if(positionWouldTelefrag(spawnpoints[i].origin))
				continue;

			for(j = 0; j < aliveplayers.size; j++)
			{
				if ( (aliveplayers[j].pers["team"] != self.pers["team"]) && (distancesquared(spawnpoints[i].origin, aliveplayers[j].origin) > (4000000)) )
				{
					semirandomspawns = add_to_array(semirandomspawns, spawnpoints[i]);
					continue;
				}
			}
		}
		if (isdefined(semirandomspawns))
		{
			spawnpoint = getSpawnpoint_Random(semirandomspawns);
		}
		else
		{
			for(i = 0; i < spawnpoints.size; i++)
			{
				if(positionWouldTelefrag(spawnpoints[i].origin))
					continue;
	
				for(j = 0; j < aliveplayers.size; j++)
				{
					if ( (aliveplayers[j].pers["team"] != self.pers["team"]) && (distancesquared(spawnpoints[i].origin, aliveplayers[j].origin) > 1000000) )
					{
						semirandomspawns = add_to_array(semirandomspawns, spawnpoints[i]);
						continue;
					}
				}
			}
			if (isdefined(semirandomspawns))
				spawnpoint = getSpawnpoint_Random(semirandomspawns);
			else
				spawnpoint = getSpawnpoint_Random(spawnpoints);
		}
	}
	else
	{
//		println("*** SPAWNING RANDOM: ", self.name);
		spawnpoint = getSpawnpoint_Random(spawnpoints);
	}
	
	return spawnpoint;
}

getSpawnpoint_MiddleThird(spawnpoints)
{
	//This scores spawnpoints based on where the enemy is and where people just died.
	//It then throws out the best 1/3 and worst 1/3 spawn points and spawns you at random
	//Using the middle 1/3 rated spawn points.
	
	// There are no valid spawnpoints in the map
	if(!isdefined(spawnpoints))
		return undefined;

	// Make an array "badspot" of axis players
	players = getentarray("player", "classname");
	axiscount = -1;
	for(i = 0; i < players.size; i++)
	{
		if(players[i].sessionstate == "spectator" || players[i].sessionstate == "dead" || players[i] == self)
			continue;
		
		if (players[i].pers["team"] != self.pers["team"])
		{
			axiscount++;
			badspot = add_to_array(badspot, (players[i].origin));
		}
	}
	
	// Add the death array to the array "badspot"
	if ( (isdefined(level.deatharray)) && (isdefined(level.deatharray[0])) )
	{
		for (i=0;i<level.deatharray.size;i++)
			badspot = add_to_array(badspot, level.deatharray[i]);
	}
	
	// Give each spawn point a rating
	// Their score is the distance to the closest badspot
	if ( (isdefined (badspot)) && (isdefined (badspot[0])) )
	{	
		for (i=0;i<spawnpoints.size;i++)
		{
			closest = 1000000;
			if(positionWouldTelefrag(spawnpoints[i].origin))
			{
				spawnpoints[i].spawnscore = (-1);
				continue;
			}
			
			spawnpoints[i].spawnscore = 0;
			
			for(j = 0; j < badspot.size; j++)
			{
				distancescore = distance((spawnpoints[i].origin[0],spawnpoints[i].origin[1],(spawnpoints[i].origin[2] * 5)), (badspot[j][0],badspot[j][1],(badspot[j][2] * 5)));
				if (j > axiscount) // THIS IS A DEATH BADSPOT - CAN BE WEIGHTED DIFFERENTLY
					distancescore = (distancescore * 4);
				
				if (distancescore < closest)
					closest = distancescore;
			}
			spawnpoints[i].spawnscore = closest;
		}
		
		// Every spawn point has a score now
		
		// Sort them in order
		for(i = 0; i < spawnpoints.size; i++)
		{
			for(j = i; j < spawnpoints.size; j++)
			{
				if(spawnpoints[i].spawnscore > spawnpoints[j].spawnscore)
				{
					temp = spawnpoints[i];
					spawnpoints[i] = spawnpoints[j];
					spawnpoints[j] = temp;
				}
			}
		}
		
		// Spawn points are sorted by score now
		firsthalf = (spawnpoints.size / 2);
		lastsixth = (spawnpoints.size - (spawnpoints.size / 6));
		
		for (i=firsthalf;i<lastsixth;i++)
		{
			if (!isdefined (GoodSpawnPoints))
				GoodSpawnPoints[0] = spawnpoints[i];
			else
				GoodSpawnPoints[GoodSpawnPoints.size] = spawnpoints[i];
		}
		
		if (GoodSpawnPoints.size < 1)
		{
			spawnpoint = getSpawnpoint_Random(spawnpoints);
			return spawnpoint;
		}
		else
		{
			spawnpoint = getSpawnpoint_Random(GoodSpawnPoints);
			return spawnpoint;
		}
		
	}
	else
	{
		spawnpoint = getSpawnpoint_Random(spawnpoints);
		return spawnpoint;
	}
}

/////////////////////////////////////////////////////////////////////////

getSpawnpoint_DM(spawnpoints)
{
//	level endon("intermission");

	// There are no valid spawnpoints in the map
	if(!isdefined(spawnpoints))
		return undefined;

	// Make a list of fully connected, non-spectating, alive players
	players = getentarray("player", "classname");
	for(i = 0; i < players.size; i++)
	{
		player = players[i];
		
		if(player.sessionstate == "spectator" || player.sessionstate == "dead" || player == self)
			continue;

		aliveplayers = add_to_array(aliveplayers, player);
	}

	// Spawn away from players if they exist, otherwise spawn at a random spawnpoint
	if(isdefined(aliveplayers))
	{
//		println("====================================");
		
		j = 0;
		for(i = 0; i < spawnpoints.size; i++)
		{
			// Throw out bad spots
			if(positionWouldTelefrag(spawnpoints[i].origin))
			{
//				println("Throwing out WouldTelefrag ", spawnpoints[i].origin);
				continue;
			}

			if(isdefined(self.lastspawnpoint) && self.lastspawnpoint == spawnpoints[i])
			{
//				println("Throwing out last spawnpoint ", spawnpoints[i].origin);
//				println("self.lastspawnpoint.origin: ", self.lastspawnpoint.origin);
				continue;
			}
			
			filteredspawnpoints[j] = spawnpoints[i];
			j++;
		}
		
		// if no good spawnpoint, need to failsafe
		if (!isdefined(filteredspawnpoints))
			return getSpawnpoint_Random(spawnpoints);

		for(i = 0; i < filteredspawnpoints.size; i++)
		{
			shortest = 1000000;
			for(j = 0; j < aliveplayers.size; j++)
			{
				current = distance(filteredspawnpoints[i].origin, aliveplayers[j].origin);
//				println("Current distance ", current);
				
				if (current < shortest)
				{
//					println("^4Old shortest: ", shortest, " ^4New shortest: ", current);
					shortest = current;
				}
			}

			filteredspawnpoints[i].spawnscore = shortest + 1;
//			println("^2Spawnscore: ", filteredspawnpoints[i].spawnscore);
		}

		// TODO: Throw out spawnpoints with negative scores
		
		newsize = filteredspawnpoints.size / 3;
		if(newsize < 1)
			newsize = 1;

		total = 0;
		bestscore = 0;
		
		// Find the top 3rd
		for(i = 0; i < newsize; i++)
		{
			for(j = 0; j < filteredspawnpoints.size; j++)
			{
				current = filteredspawnpoints[j].spawnscore;
//				println("Current distance ", current);

				if (current > bestscore)
					bestscore = current;
			}

			for(j = 0; j < filteredspawnpoints.size; j++)
			{
				if(filteredspawnpoints[j].spawnscore == bestscore)
				{
//					println("^3Adding to newarray: ", bestscore);
					newarray[i]["spawnpoint"] = filteredspawnpoints[j];
					newarray[i]["spawnscore"] = filteredspawnpoints[j].spawnscore;
					filteredspawnpoints[j].spawnscore = 0;
					bestscore = 0;			

//					println("^6Old total: ", total, "^6 New total: ", (total + newarray[i]["spawnscore"]), "^6 Added: ", newarray[i]["spawnscore"]);
					total = total + newarray[i]["spawnscore"];

					break;
				}
			}
		}

		randnum = randomInt(total);
//		println("^3Random Number: ", randnum, " ^3Between 0 and ", total);

		for(i = 0; i < newarray.size; i++)
		{
			randnum = randnum - newarray[i]["spawnscore"];
			spawnpoint = newarray[i]["spawnpoint"];

//			println("^2Subtracted: ", newarray[i]["spawnscore"], "^2 Left: ", randnum);
			
			if(randnum < 0)
				break;
		}
		
		self.lastspawnpoint = spawnpoint;
		return spawnpoint;
	}
	else
		return getSpawnpoint_Random(spawnpoints);
}

getSpawnpoint_NearTeam_AwayfromRadios(spawnpoints)
{
	// There are no valid spawnpoints in the map
	if(!isdefined(spawnpoints))
		return undefined;

	// clean out any spawn points that have recent deaths associated with them
//	spawnpoints = clear_spawn_camped(original_spawnpoints);
//	
//	// if everything is spawn camped pick a random spot
//	if ( spawnpoints.size == 0 )
//	{
//		return getSpawnpoint_Random(original_spawnpoints);
//	}

	// Make a list of fully connected, non-spectating, alive players
	aliveplayers = [];
	teammates = 0;
	players = getentarray("player", "classname");
	for(i = 0; i < players.size; i++)
	{
		if(isdefined (players[i].pers["team"]))
			teammates++;
		if(players[i].sessionstate == "spectator" || players[i].sessionstate == "dead" || players[i] == self)		
			continue;
		aliveplayers[aliveplayers.size] = players[i];
	}
	
	// Spawn away from players if they exist, otherwise spawn at a random spawnpoint
	if(isdefined(aliveplayers))
	{
		for(i = 0; i < spawnpoints.size; i++)
		{
			if(positionWouldTelefrag(spawnpoints[i].origin))
			{
				spawnpoints[i].spawnscore = -37483274;
				continue;
			}
			
			spawnpoints[i].spawnscore = 0;
			
			// Measuse the distance to all alive players and modify the spawnpoints score
			for(j = 0; j < aliveplayers.size; j++)
			{
				dist = (distance(spawnpoints[i].origin, aliveplayers[j].origin));
				
				if(aliveplayers[j].pers["team"] == self.pers["team"])
				{
					// If this team is controlling a radio
					if (level.captured_radios[self.pers["team"]] > 0)
						bias = (0.5);
					else // This team doesn't have a radio to increase the bias
						bias = (1.6);
					
					// IF THE PLAYER JUST SPAWNED IN A WAVE MAKE THIS PLAYER VERY VERY VALUEABLE
					if (isdefined (aliveplayers[j].wavespawner))
						bias = (100);
					
					spawnpoints[i].spawnscore -= ( dist * bias );
				}
				else
				{
					if (dist <= 850) // If there is an enemy within 850 units dont spawn a player here
					{
						spawnpoints[i].spawnscore = -37483274;
						continue;
					}
					else
						spawnpoints[i].spawnscore += ( dist * 0.8 );
				}
			}
			
			// Measure the distance to all the shown radios and modify the spawnpoints score
			for(j = 0; j < level.radio.size; j++)
			{
				if ( (level.radio[j].hidden == true) || (level.radio[j].team == "none") )
					continue;
				
				// If the radio is within 700 units of an attacker, the attacker should not spawn there
				if (level.radio[j].team != self.pers["team"])
				{
					dist = (distance(spawnpoints[i].origin, level.radio[j].origin));
					if (dist <= 700)
					{
						spawnpoints[i].spawnscore = -37483274;
						continue;
					}
				}
			}
		}
		
		// Every spawn point has a score now
		
		// Sort them in order
		for(i = 0; i < spawnpoints.size; i++)
		{
			for(j = i; j < spawnpoints.size; j++)
			{
				if(spawnpoints[i].spawnscore < spawnpoints[j].spawnscore)
				{
					temp = spawnpoints[i];
					spawnpoints[i] = spawnpoints[j];
					spawnpoints[j] = temp;
				}
			}
		}
		
		// Spawn points are sorted by score now. Index 0 has highest score
		// A Higher Score is Better
		for(i = 0; i < spawnpoints.size; i++)
		{
			if(positionWouldTelefrag(spawnpoints[i].origin))
				continue;
			if (spawnpoints[i].spawnscore == -37483274)
				continue;
			return spawnpoints[i];
		}
		
		spawnpoint = getSpawnpoint_MiddleThird(spawnpoints);
	}
	else
	{
		spawnpoint = getSpawnpoint_MiddleThird(spawnpoints);
	}
	
	return spawnpoint;
}


// ==========================================================================================================
//	SpawnPlayer
//
//		Spawn the player at the point and keep track of the last time they spawned
//		
// ==========================================================================================================
SpawnPlayer( player )
{
	// spawn the player in
	player spawn(self.origin, self.angles);
	
	// record the time
	player.last_spawn_time = gettime();
	
	player thread Player_WaitForDeath( self );
	player thread Player_WaitForSpawnKillerTimeout( self );
}

// ==========================================================================================================
//	SpawnPlayer
//
//		Spawn the player at the point and keep track of the last time they spawned
//		
// ==========================================================================================================
Player_WaitForDeath( point )
{
	self endon("clear spawn tracker");
	point endon("death");
	
	self waittill("death");
	
	// player died so delay the use of this spawn point 
	point.delay_use = gettime();
}

// ==========================================================================================================
//	Player_WaitForSpawnKillerTimeout
//
//		This waits for a set amount of time and then cleans everything up if no spawn kill happens
//		
// ==========================================================================================================
Player_WaitForSpawnKillerTimeout( point )
{
	self endon("death");
	
	// wait for ten seconds
	wait (10);
	
	// no kill has happened so we are in the clear
	self notify("clear spawn tracker");
}

// ==========================================================================================================
//	clear_spawn_camped
//
//		This removes any spawn points from the list that have recently spawned a player and the player 
//		got killed shortly after spawn.  It also clears any spawnpoints near these points.
//		
// ==========================================================================================================
clear_spawn_camped( original_spawnpoints )
{
	spawnpoints = [];
	valid_spawnpoints = [];
	
	// if the spawn took part in a spawn kill in this time then dont use it
	no_spawn_time = 10000;
	current_time = gettime();
	
	// any spawn point closer than this distance to an invalid point will
	// also be marked as invalid
	invalid_distance = 500 * 500;
	
	// set all points as valid for now
	for ( i = 0; i < original_spawnpoints.size; i++ )
	{
		valid_spawnpoints[valid_spawnpoints.size] = true;
	}
	
	for ( i = 0; i < original_spawnpoints.size; i++ )
	{
		// if this point is already marked not valid skip
		if ( !valid_spawnpoints[i] )
			continue;
			
		// if this is not defined then this point is fine (for now)
		if ( !isdefined(original_spawnpoints[i].delay_use) )
			continue;
			
		// if enough time has passed
		if ( (original_spawnpoints[i].delay_use + no_spawn_time) < current_time)
			continue;
		
		// this is not a valid point
		valid_spawnpoints[i] = false;
//		println( "marked spawnpoint " + original_spawnpoints[i].origin + " as invalid because of spawncamp");
		
		// ok so this is not a good point so whip through the list and flag anything close to it as not valid either
		for ( j = 0; j < original_spawnpoints.size; j++ )
		{
			// if this point is already marked not valid skip
			if ( !valid_spawnpoints[j] )
				continue;
			
			// check distance	
			if ( distancesquared(original_spawnpoints[i].origin, original_spawnpoints[j].origin ) < invalid_distance )
			{
				// this point is close to an invalid point so now mark as not valid as well	
				valid_spawnpoints[j] = false;
//				println( "marked spawnpoint " + original_spawnpoints[j].origin + " as invalid because of proximity to spawncamp");
			}
		}
	}
	
	// now go through and add any valid points remaining to the list
	for ( i = 0; i < original_spawnpoints.size; i++ )
	{
		// if this point is already marked not valid skip
		if ( !valid_spawnpoints[i] )
			continue;
			
//		println( "adding valid spawnpoint " + original_spawnpoints[i].origin);
		spawnpoints[spawnpoints.size] = original_spawnpoints[i];
	}
	
	return spawnpoints;
}

add_to_array(array, ent)
{
	if(!isdefined(ent))
		return array;
		
	if(!isdefined(array))
		array[0] = ent;
	else
		array[array.size] = ent;
	
	return array;	
}

addorigin_to_array(array, ent)
{
	if(!isdefined(ent))
		return array;
		
	if(!isdefined(array))
		array[0] = ent.origin;
	else
		array[array.size] = ent.origin;
	
	return array;	
}

////////////////////////////////////////////////////////////////////////////////////////
//                             old spawnlogic threads                                 //
////////////////////////////////////////////////////////////////////////////////////////

// selects a spawnpoint, preferring ones with heigher weights (or toward the beginning of the array if no weights).
// also does final things like setting self.lastspawnpoint to the one chosen.
// this takes care of avoiding telefragging, so it doesn't have to be considered by any other function.
getSpawnpoint_Final(spawnpoints, weights)
{
	bestspawnpoint = undefined;
	
	if(!isdefined(spawnpoints) || spawnpoints.size == 0)
		return undefined;
	
	if (isdefined(weights) && weights.size == spawnpoints.size)
	{
		// choose spawnpoint with best weight
		// (if a tie, choose randomly from the best)
		bestspawnpoints = [];
		bestweight = undefined;
		for (i = 0; i < spawnpoints.size; i++)
		{
			if(positionWouldTelefrag(spawnpoints[i].origin))
				continue;
	
			if (!isdefined(bestweight) || weights[i] > bestweight) {
				bestspawnpoints = [];
				bestspawnpoints[0] = spawnpoints[i];
				bestweight = weights[i];
			}
			else if (weights[i] == bestweight) {
				bestspawnpoints[bestspawnpoints.size] = spawnpoints[i];
			}
		}
		if (bestspawnpoints.size > 0)
		{
			// pick randomly from the available spawnpoints with the best weight
			bestspawnpoint = bestspawnpoints[randomint(bestspawnpoints.size)];
		}
	}
	else
	{
		// (only place we actually get here from is getSpawnpoint_Random() )
		// no weights. prefer spawnpoints toward beginning of array
		for (i = 0; i < spawnpoints.size; i++)
		{
			if(positionWouldTelefrag(spawnpoints[i].origin))
				continue;
	
			if(isdefined(self.lastspawnpoint) && self.lastspawnpoint == spawnpoints[i])
				continue;
			
			bestspawnpoint = spawnpoints[i];
			break;
		}
		if (!isdefined(bestspawnpoint))
		{
			// Couldn't find a useable spawnpoint. All spawnpoints either telefragged or were our last spawnpoint
			// Our only hope is our last spawnpoint - unless it too will telefrag...
			if (isdefined(self.lastspawnpoint) && !positionWouldTelefrag(self.lastspawnpoint.origin)) {
				// (make sure our last spawnpoint is in the valid array of spawnpoints to use)
				for (i = 0; i < spawnpoints.size; i++) {
					if (spawnpoints[i] == self.lastspawnpoint) {
						bestspawnpoint = spawnpoints[i];
						break;
					}
				}
			}
		}
	}

	if (!isdefined(bestspawnpoint))
	{
		// couldn't find a useable spawnpoint! all will telefrag.
		if (isdefined(weights)) {
			// at this point, forget about weights. just take a random one.
			bestspawnpoint = spawnpoints[randomint(spawnpoints.size)];
		}
		else
			bestspawnpoint = spawnpoints[0];
	}
	
	time = getTime();
	
	self.lastspawnpoint = bestspawnpoint;
	self.lastspawntime = time;
	bestspawnpoint.lastspawnedplayer = self;
	bestspawnpoint.lastspawntime = time;
	return bestspawnpoint;
}

Spawnlogic_Init()
{
	if (isdefined(level.spawnlogic_inited)) {
		updateDeathInfo();
		return;
	}
	level.spawnlogic_inited = true;
	
	// start keeping track of deaths
	level.spawnlogic_deaths = [];
	
	// we need the playerkilled callback, but the gametype is already making use of it.
	// set up our own callback inbetween.
	level.spawnlogic_oldCallbackPlayerKilled = level.callbackPlayerKilled;
	level.callbackPlayerKilled = ::spawnlogic_callbackPlayerKilled;
}

spawnlogic_callbackPlayerKilled(eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration)
{
	deathOccured(self, attacker);
	
	// call the usual callback.
	[[level.spawnlogic_oldCallbackPlayerKilled]](
		eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc
	);
}

deathOccured(dier, killer)
{
	if (!isdefined(killer) || !isdefined(dier) || !isplayer(killer) || !isplayer(dier) || killer == dier)
		return;
	
	time = getTime();
	
	// record kill information
	deathInfo = spawnstruct();
	
	deathInfo.time = time;
	deathInfo.org = dier.origin;
	deathInfo.killOrg = killer.origin;
	deathInfo.killer = killer;
	
	checkForSimilarDeaths(deathInfo);
	level.spawnlogic_deaths[level.spawnlogic_deaths.size] = deathInfo;
	
	// keep track of the most dangerous players in terms of how far they have killed people recently
	dist = distance(dier.origin, killer.origin);
	if (!isdefined(killer.spawnlogic_killdist) || time - killer.spawnlogic_killtime > 1000*30 || dist > killer.spawnlogic_killdist)
	{
		killer.spawnlogic_killdist = dist;
		killer.spawnlogic_killtime = time;
	}
}

checkForSimilarDeaths(deathInfo)
{
	// check if this is really similar to any old deaths, and if so, mark them for removal later
	for (i = 0; i < level.spawnlogic_deaths.size; i++)
	{
		if (level.spawnlogic_deaths[i].killer == deathInfo.killer)
		{
			dist = distance(level.spawnlogic_deaths[i].org, deathInfo.org);
			if (dist > 200) continue;
			dist = distance(level.spawnlogic_deaths[i].killOrg, deathInfo.killOrg);
			if (dist > 200) continue;
			
			level.spawnlogic_deaths[i].remove = true;
		}
	}
}

updateDeathInfo()
{
	time = getTime();
	for (i = 0; i < level.spawnlogic_deaths.size; i++)
	{
		// if the killer has walked away or enough time has passed, get rid of this death information
		deathInfo = level.spawnlogic_deaths[i];
		
		if (time - deathInfo.time > 1000*90 || // if 90 seconds have passed
			!isdefined(deathInfo.killer) ||
			!isalive(deathInfo.killer) ||
			(deathInfo.killer.pers["team"] != "axis" && deathInfo.killer.pers["team"] != "allies") ||
			distance(deathInfo.killer.origin, deathInfo.killOrg) > 400) {
			level.spawnlogic_deaths[i].remove = true;
		}
	}
	
	// remove all deaths with remove set
	oldarray = level.spawnlogic_deaths;
	level.spawnlogic_deaths = [];
	
	// never keep more than the 1024 most recent entries in the array
	start = 0;
	if (oldarray.size - 1024 > 0) start = oldarray.size - 1024;
	
	for (i = start; i < oldarray.size; i++)
	{
		if (!isdefined(oldarray[i].remove))
			level.spawnlogic_deaths[level.spawnlogic_deaths.size] = oldarray[i];
	}
}

getNewSpawnpoint_NearTeam(spawnpoints)
{
	// There are no valid spawnpoints in the map
	if(!isdefined(spawnpoints))
		return undefined;
	
	Spawnlogic_Init();
	
	weights = initWeights(spawnpoints);
	
	allies = getAllAlliedPlayers();
	enemies = getAllEnemyPlayers();
	numplayers = allies.size + enemies.size;
	
	if (numplayers > 0)
	{
		for (i = 0; i < spawnpoints.size; i++)
		{
			allyDistSum = 0;
			enemyDistSum = 0;
			for (j = 0; j < allies.size; j++)
			{
				dist = distance(spawnpoints[i].origin, allies[j].origin);
				allyDistSum += dist;
			}
			for (j = 0; j < enemies.size; j++)
			{
				dist = distance(spawnpoints[i].origin, enemies[j].origin);
				enemyDistSum += dist;
			}
			
			weights[i] = (enemyDistSum - 2*allyDistSum) / numplayers; // high enemy distance is good, high ally distance is bad
		}
	}
	
	weights = avoidSameSpawn(spawnpoints, weights);
	if (getcvar("g_gametype") != "tdm") { // retaining old logic for tdm to keep the fast pace
		weights = avoidSpawnReuse(spawnpoints, weights, true);
		weights = avoidDangerousSpawns(spawnpoints, weights, true);
	}
	
	return getSpawnpoint_Final(spawnpoints, weights);
}

avoidSameSpawn(spawnpoints, weights)
{
	if (!isdefined(self.lastspawnpoint))
		return weights;
	
	for (i = 0; i < spawnpoints.size; i++)
	{
		if (spawnpoints[i] == self.lastspawnpoint) {
			weights[i] -= 50000; // (half as bad as a likely spawn kill)
			break;
		}
	}
	return weights;
}

// uses death information to reduce the weights of spawns that might cause spawn kills
avoidDangerousSpawns(spawnpoints, weights, teambased) // (assign weights to the return value of this)
{
	didSightChecks = [];
	
	maxDist = 400;
	maxDistSquared = maxDist*maxDist;
	for (i = 0; i < spawnpoints.size; i++)
	{
		didSightChecks[i] = false;
		for (d = 0; d < level.spawnlogic_deaths.size; d++)
		{
			// (we've got a lotta checks to do, want to rule them out quickly)
			distSqrd = distanceSquared(spawnpoints[i].origin, level.spawnlogic_deaths[d].org);
			if (distSqrd > maxDistSquared)
				continue;
			
			// make sure the killer in question is on the opposing team
			player = level.spawnlogic_deaths[d].killer;
			if (!isalive(player)) continue;
			if (player == self) continue;
			if (teambased && player.pers["team"] == self.pers["team"]) continue;
			
			// (no sqrt, must recalculate distance)
			dist = distance(spawnpoints[i].origin, level.spawnlogic_deaths[d].org);
			weights[i] -= (1 - dist/maxDist) * 100000; // possible spawn kills are *really* bad
		}
	}
	
	// do some sight checks to try to predict spawn kills before they happen
	maxNumSightChecks = 15;
	numSightChecks = 0;
	numFailures = 0; // after checking enough spawnpoints with all failed sight checks, we give up
	maxNumFailures = 5;
	
	nearbyDist = 1000; // we'll do sight checks for players within this range
	dangerDist = 1600; // or players who tend to kill at this range or higher
	
	lastweight = -1;
	
	time = getTime();
	
	players = getentarray("player", "classname");

	permutation = [];
	for (i = 0; i < players.size; i++)
		permutation[i] = i;
	
	for (i = 0; i < spawnpoints.size; i++)
	{
		// find highest weighted spawnpoint that we haven't tried yet
		highest = undefined;
		for (j = 0; j < spawnpoints.size; j++) {
			if (!didSightChecks[j]) {
				highest = j;
				break;
			}
		}
		if (!isdefined(highest))
			break;
		for (j++; j < spawnpoints.size; j++) {
			if (!didSightChecks[j] && weights[j] > weights[highest])
				highest = j;
		}
		
		j = highest;
		lastweight = weights[j];
		
		dir = anglestoforward(spawnpoints[j].angles);
		
		succeeded = false;
		
		// decide which players to do sight checks on
		checkplayers = [];
		numnearby = 0; // we'll pick 2 nearby players
		numdangerous = 0; // and 2 who tend to kill at a far distance
		
		// (start with a random permutation of all players)
		for(a = 0; a < players.size; a++)
		{
			b = randomInt(players.size);
			temp = permutation[a];
			permutation[a] = permutation[b];
			permutation[b] = temp;
		}
		
		// check each player in random order; if we think a sight check would be good, put them in the checkplayers array
		playersDidntUse = [];
		for (p = 0; p < players.size; p++)
		{
			player = players[permutation[p]];
			if (!isalive(player)) continue;
			if (player == self) continue;
			if (teambased && player.pers["team"] == self.pers["team"]) continue;
			if (player.pers["team"] != "axis" && player.pers["team"] != "allies") continue;
			
			diff = player.origin - spawnpoints[j].origin;
			pdir = anglestoforward(player.angles);
			if (vectordot(dir, diff) < 0 && vectordot(pdir, diff) > 0)
				continue; // both players looking away from each other

			dist = distance(player.origin, spawnpoints[j].origin);
			if (numnearby < 2 && dist <= nearbyDist) {
				checkplayers[numnearby] = player;
				numnearby++;
			}
			else if (numdangerous < 3 && isdefined(player.spawnlogic_killdist) && player.spawnlogic_killdist >= dangerDist) {
				checkplayers[2 + numdangerous] = player;
				numdangerous++;
			}
			else if (playersDidntUse.size < 3)
				playersDidntUse[playersDidntUse.size] = player;
			
			if (numnearby >= 2 && numdangerous >= 3)
				break;
		}
		// if we didn't find 5 players to do sight checks on, add up to 3 more random ones
		for (pduIndex = playersDidntUse.size; pduIndex < 5; pduIndex++)
			playersDidntUse[pduIndex] = undefined;
		pduIndex = 0;
		for (; numnearby < 2; numnearby++) {
			checkplayers[numnearby] = playersDidntUse[pduIndex];
			pduIndex++;
		}
		for (; numdangerous < 3; numdangerous++) {
			checkplayers[2 + numdangerous] = playersDidntUse[pduIndex];
			pduIndex++;
		}

		// do sight checks
		for (p = 0; p < 5; p++)
		{
			player = checkplayers[p];
			if (!isdefined(player)) continue;
			
			// using bullet trace instead of sight trace because sighttrace doesn't seem to see through trees
			losExists = bullettrace(player.origin + (0,0,48), spawnpoints[j].origin + (0,0,48), false, undefined);
			numSightChecks++;
			
			if (losExists) {
				succeeded = true;
				weights[j] -= 100000; // we don't want to spawn here!
				
				// pretend this player killed a person at this spawnpoint, so we don't try to use it again any time soon.
				deathInfo = spawnstruct();
				
				deathInfo.time = time;
				deathInfo.org = spawnpoints[j].origin;
				deathInfo.killOrg = player.origin;
				deathInfo.killer = player;
				deathInfo.los = true;
				
				checkForSimilarDeaths(deathInfo);
				level.spawnlogic_deaths[level.spawnlogic_deaths.size] = deathInfo;
				break;
			}
			
			if (numSightChecks >= maxNumSightChecks)
				break;
		}
		
		didSightChecks[j] = true;
		
		if (!succeeded)
			numFailures++;
		
		if (numFailures >= maxNumFailures || numSightChecks >= maxNumSightChecks)
			break;
	}
	
	return weights;
}

avoidSpawnReuse(spawnpoints, weights, teambased)
{
	time = getTime();
	
	maxtime = 10*1000;
	maxdist = 800;
	
	for (i = 0; i < spawnpoints.size; i++)
	{
		if (!isdefined(spawnpoints[i].lastspawnedplayer) || !isdefined(spawnpoints[i].lastspawntime) ||
			!isalive(spawnpoints[i].lastspawnedplayer))
			continue;

		if (spawnpoints[i].lastspawnedplayer == self) continue;
		if (teambased && spawnpoints[i].lastspawnedplayer.pers["team"] == self.pers["team"]) continue;
		
		timepassed = time - spawnpoints[i].lastspawntime;
		if (timepassed < maxtime)
		{
			dist = distance(spawnpoints[i].lastspawnedplayer.origin, spawnpoints[i].origin);
			if (dist < maxdist)
			{
				weights[i] -= 1000 * (1 - dist/maxdist) * (1 - timepassed/maxtime);
			}
			else
				spawnpoints[i].lastspawnedplayer = undefined; // don't worry any more about this spawnpoint
		}
		else
			spawnpoints[i].lastspawnedplayer = undefined; // don't worry any more about this spawnpoint
	}
	return weights;
}

getAllOtherPlayers()
{
	aliveplayers = [];

	// Make a list of fully connected, non-spectating, alive players
	players = getentarray("player", "classname");
	for(i = 0; i < players.size; i++)
	{
		player = players[i];
		
		if(player.sessionstate == "spectator" || player.sessionstate == "dead" || player == self)
			continue;

		aliveplayers = add_to_array(aliveplayers, player);
	}
	return aliveplayers;
}
// gets an array of living players allied with self (assumes team-based game!)
getAllAlliedPlayers()
{
	livingallies = [];
	
	// Make a list of fully connected, non-spectating, alive players
	players = getentarray("player", "classname");
	for(i = 0; i < players.size; i++)
	{
		player = players[i];
		
		if(player.sessionstate == "spectator" || player.sessionstate == "dead" || player == self)
			continue;

		if (player.pers["team"] == self.pers["team"])
			livingallies = add_to_array(livingallies, player);
	}
	return livingallies;
}
// gets an array of living players that are enemies (assumes team-based game!)
getAllEnemyPlayers()
{
	livingenemies = [];
	
	// Make a list of fully connected, non-spectating, alive players
	players = getentarray("player", "classname");
	for(i = 0; i < players.size; i++)
	{
		player = players[i];
		
		if(player.sessionstate == "spectator" || player.sessionstate == "dead" || player == self)
			continue;

		if (player.pers["team"] != self.pers["team"])
			livingenemies = add_to_array(livingenemies, player);
	}
	return livingenemies;
}

// weight array manipulation code
initWeights(spawnpoints)
{
	weights = [];
	for (i = 0; i < spawnpoints.size; i++)
		weights[i] = 0;
	return weights;
}
