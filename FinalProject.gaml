/**
* Name: Final Project - Basic Part (Festival)
* Description:
*  - 5 guest types, 50+ agents
*  - 3 meeting places (not roaming): Bar, ChillZone, DanceFloor
*  - 3 traits per guest affect interaction and place choice
*  - FIPA long-distance messaging (Influencer -> others)
*  - Global value monitored: average happiness (chart)
*  - Informative graph: interactions per tick (chart)
*  - Guests continuously reconsider and switch places (boredom + crowding + exploration)
*  - Console stats every 200 ticks + occasional message logs
*/

model FinalProject

global {

	int numberOfGuestsPerType <- 12; // 60 total

	float avg_happiness <- 0.0;

	int interactions_this_tick <- 0;
	int interactions_since_report <- 0;

	init {
		// Places
		create Bar number: 1;
		create ChillZone number: 1;
		create DanceFloor number: 1;

		Bar[0].location <- {30, 60};
		ChillZone[0].location <- {70, 60};
		DanceFloor[0].location <- {50, 25};

		// Guests (5 types)
		create SocialButterfly number: numberOfGuestsPerType;
		create ShyGuest        number: numberOfGuestsPerType;
		create Foodie          number: numberOfGuestsPerType;
		create Influencer      number: numberOfGuestsPerType;
		create GrumpyGuest     number: numberOfGuestsPerType;

		// Random start positions + quick initial reconsider so they spread out
		ask Guest {
			location <- {rnd(10, 90), rnd(10, 90)};
			reconsider_timer <- rnd(0, 6);
		}

		write "Festival started with " + string(numberOfGuestsPerType * 5) + " guests.";
	}

	// Update global metrics each tick
	reflex update_globals {
		interactions_this_tick <- 0;

		avg_happiness <- mean(Guest collect each.happiness);

		// crowding (computed centrally)
		Bar[0].crowding <- length(Guest where (each.current_place = Bar[0]));
		ChillZone[0].crowding <- length(Guest where (each.current_place = ChillZone[0]));
		DanceFloor[0].crowding <- length(Guest where (each.current_place = DanceFloor[0]));
	}

	// Console stats every 200 ticks
	reflex report when: (time mod 200 = 0) and (time > 0) {
		float ah <- round(avg_happiness * 100) / 100;

		write "Time " + string(time)
			+ " | AvgHappy: " + string(ah)
			+ " | Bar: " + string(Bar[0].crowding)
			+ " | Chill: " + string(ChillZone[0].crowding)
			+ " | Dance: " + string(DanceFloor[0].crowding)
			+ " | Interactions(last200): " + string(interactions_since_report);

		interactions_since_report <- 0;
	}
}

// ---------------------------
// PLACES
// ---------------------------
species Place {
	float attraction <- 0.5;
	float crowding <- 0.0;

	aspect base { draw square(4) color: #lightgray border: #black; }
}

species Bar parent: Place {
	float service_quality <- 0.7;
	init { attraction <- 0.65; }

	aspect base {
		draw square(5) color: #red border: #black;
		draw string("BAR") size: 14 color: #white;
	}
}

species ChillZone parent: Place {
	init { attraction <- 0.55; }

	aspect base {
		draw square(5) color: #green border: #black;
		draw string("CHILL") size: 14 color: #white;
	}
}

species DanceFloor parent: Place {
	init { attraction <- 0.70; }

	aspect base {
		draw square(5) color: #blue border: #black;
		draw string("DANCE") size: 14 color: #white;
	}
}

// ---------------------------
// GUEST (base)
// ---------------------------
species Guest skills:[moving, fipa] {

	// 3 traits (0..1)
	float sociability <- rnd(0.0, 1.0);
	float patience <- rnd(0.0, 1.0);
	float mood_sensitivity <- rnd(0.0, 1.0);

	// state
	float happiness <- rnd(0.4, 0.8);
	Place current_place <- nil;

	// preferences influenced by messages
	float pref_bar <- 0.0;
	float pref_chill <- 0.0;
	float pref_dance <- 0.0;

	// switching logic
	int reconsider_timer <- rnd(5, 20);
	int boredom <- rnd(0, 20);
	float explore_prob <- 0.10;

	action clamp_happiness {
		if happiness < 0.0 { happiness <- 0.0; }
		if happiness > 1.0 { happiness <- 1.0; }
	}

	action choose_random_place {
		int r <- rnd(0, 2);
		if r = 0 { current_place <- Bar[0]; }
		else if r = 1 { current_place <- ChillZone[0]; }
		else { current_place <- DanceFloor[0]; }
	}

	// Decide place periodically (and sometimes explore randomly)
	reflex decide_place {

		reconsider_timer <- reconsider_timer - 1;

		// if never chose a place yet, pick one soon
		if current_place = nil and reconsider_timer <= 0 {
			do choose_random_place;
			reconsider_timer <- rnd(8, 16);
		}

		if reconsider_timer <= 0 {

			reconsider_timer <- rnd(12, 28);
			if happiness < 0.4 { reconsider_timer <- rnd(6, 14); }

			Place old <- current_place;

			// exploration helps prevent "everyone locks" patterns
			if flip(explore_prob) {
				do choose_random_place;
			}
			else {
				// score = attraction - crowd_penalty + preference + noise
				float bar_score <- Bar[0].attraction
					- (Bar[0].crowding * (1.0 - patience) * 0.03)
					+ pref_bar + rnd(-0.03, 0.03);

				float chill_score <- ChillZone[0].attraction
					- (ChillZone[0].crowding * (1.0 - patience) * 0.03)
					+ pref_chill + rnd(-0.03, 0.03);

				float dance_score <- DanceFloor[0].attraction
					- (DanceFloor[0].crowding * (1.0 - patience) * 0.03)
					+ pref_dance + rnd(-0.03, 0.03);

				if bar_score >= chill_score and bar_score >= dance_score { current_place <- Bar[0]; }
				else if chill_score >= dance_score { current_place <- ChillZone[0]; }
				else { current_place <- DanceFloor[0]; }
			}

			// rare log (not spammy)
			if old != nil and current_place != old and flip(0.01) {
				write "Guest " + string(self) + " switched to " + string(current_place);
			}
		}
	}

	// Move to chosen place
	reflex move_to_place when: current_place != nil {
		do goto target: current_place.location;
	}

	// Boredom + crowding forces switching
	reflex boredom_and_crowding when: current_place != nil {

		boredom <- boredom + 1;

		// unhappy in very crowded places, especially low patience
		if current_place.crowding > 18 {
			happiness <- happiness - (0.0035 * (1.2 - patience));
			do clamp_happiness;
		}

		// bored => consider leaving
		if boredom > 50 and flip(0.15 + (0.5 - happiness) * 0.35) {
			boredom <- 0;
			reconsider_timer <- 0;
		}

		// emergency: extremely crowded + impatient
		if current_place.crowding > 28 and patience < 0.4 and flip(0.35) {
			boredom <- 0;
			reconsider_timer <- 0;
		}
	}

	// Local interactions (same place)
	reflex local_interactions when: current_place != nil {

		if flip(sociability * 0.20) {

			list here <- Guest where (each != self and each.current_place = current_place);

			if !empty(here) {
				Guest other <- one_of(here);
				do interact_with(other);
			}
		}
	}

	action interact_with(Guest other) {

		float delta <- (0.02 + 0.05 * sociability) * (0.5 + mood_sensitivity);
		delta <- delta + rnd(-0.02, 0.02);

		happiness <- happiness + delta;
		do clamp_happiness;

		other.happiness <- other.happiness + (delta * 0.8);
		ask other { do clamp_happiness; }

		// reset boredom after social contact
		boredom <- 0;
		ask other { boredom <- 0; }

		interactions_this_tick <- interactions_this_tick + 1;
		interactions_since_report <- interactions_since_report + 1;
	}

	// FIPA receive
	reflex receive when: !empty(informs) {
		message m <- informs at 0;
		list msg <- (m.contents) as list;

		// Expected: ["PREF", "BAR"/"CHILL"/"DANCE", float_value]
		if length(msg) >= 3 {
			string kind <- msg at 0;
			string target <- msg at 1;
			float val <- msg at 2;

			if kind = "PREF" {

				if target = "BAR"   { pref_bar <- pref_bar + val; }
				if target = "CHILL" { pref_chill <- pref_chill + val; }
				if target = "DANCE" { pref_dance <- pref_dance + val; }

				if flip(0.35) { reconsider_timer <- 0; }

				happiness <- happiness + (0.01 * val * (0.5 + mood_sensitivity));
				do clamp_happiness;

				if flip(0.02) {
					write "Guest " + string(self) + " received PREF " + target + " " + string(val);
				}
			}
		}
	}

	aspect base {
		rgb c <- #gray;
		if happiness >= 0.75 { c <- #lime; }
		else if happiness <= 0.30 { c <- #red; }
		draw circle(1.2) color: c border: #black;
	}
}

// ---------------------------
// 5 GUEST TYPES
// ---------------------------

species SocialButterfly parent: Guest {
	init {
		sociability <- min(1.0, sociability + 0.25);
		pref_dance <- 0.06;
		explore_prob <- 0.14;
	}
	aspect base { draw circle(1.3) color: #yellow border: #black; }
}

species ShyGuest parent: Guest {
	init {
		sociability <- max(0.0, sociability - 0.25);
		pref_chill <- 0.08;
		explore_prob <- 0.08;
	}

	reflex shy_crowd_penalty when: current_place != nil {
		float c <- current_place.crowding;
		happiness <- happiness - (c * 0.0020 * (1.2 - patience));
		do clamp_happiness;

		if current_place.crowding > 16 and flip(0.25 + (0.6 - happiness) * 0.2) {
			reconsider_timer <- 0;
			boredom <- 0;
		}
	}

	aspect base { draw circle(1.2) color: #purple border: #black; }
}

species Foodie parent: Guest {
	init { pref_bar <- 0.08; }

	reflex bar_experience when: current_place = Bar[0] {
		float gain <- (Bar[0].service_quality * 0.02) - (Bar[0].crowding * 0.0015 * (1.1 - patience));
		happiness <- happiness + gain;
		do clamp_happiness;

		if Bar[0].crowding > 20 and flip(0.25) {
			reconsider_timer <- 0;
			boredom <- 0;
		}
	}

	aspect base { draw circle(1.2) color: #orange border: #black; }
}

species Influencer parent: Guest {
	init {
		sociability <- min(1.0, sociability + 0.10);
		reconsider_timer <- rnd(6, 14);
		explore_prob <- 0.16;
	}

	reflex send_long_distance_message when: flip(0.04) {

		Guest target <- one_of(Guest where (each != self));
		if target != nil {

			float barCrowd <- Bar[0].crowding;
			float danceCrowd <- DanceFloor[0].crowding;

			if barCrowd > 12 {
				do start_conversation to:[target] performative:'inform' contents:["PREF", "BAR", -0.05];
				do start_conversation to:[target] performative:'inform' contents:["PREF", "CHILL", 0.04];
				if flip(0.03) { write "Influencer " + string(self) + " warns: BAR crowded"; }
			}
			else if danceCrowd > 20 {
				do start_conversation to:[target] performative:'inform' contents:["PREF", "DANCE", -0.04];
				do start_conversation to:[target] performative:'inform' contents:["PREF", "CHILL", 0.03];
			}
			else {
				do start_conversation to:[target] performative:'inform' contents:["PREF", "DANCE", 0.04];
			}
		}
	}

	aspect base { draw circle(1.3) color: #cyan border: #black; }
}

species GrumpyGuest parent: Guest {
	init {
		patience <- max(0.0, patience - 0.20);
		pref_chill <- pref_chill + 0.03;
	}

	action interact_with(Guest other) {

		float sign <- (rnd(0.0, 1.0) < (0.55 - patience * 0.3)) ? -1.0 : 1.0;
		float delta <- sign * (0.03 + 0.05 * sociability);

		happiness <- happiness + (delta * 0.6);
		do clamp_happiness;

		other.happiness <- other.happiness + delta;
		ask other { do clamp_happiness; }

		boredom <- 0;
		ask other { boredom <- 0; }

		interactions_this_tick <- interactions_this_tick + 1;
		interactions_since_report <- interactions_since_report + 1;

		if sign < 0 and flip(0.03) {
			write "GrumpyGuest " + string(self) + " negative interaction.";
		}
	}

	aspect base { draw circle(1.2) color: #brown border: #black; }
}

// ---------------------------
// EXPERIMENT
// ---------------------------
experiment festival type: gui {

	output {

		display map {
			species Bar aspect: base;
			species ChillZone aspect: base;
			species DanceFloor aspect: base;

			species SocialButterfly aspect: base;
			species ShyGuest aspect: base;
			species Foodie aspect: base;
			species Influencer aspect: base;
			species GrumpyGuest aspect: base;
		}

		display charts type: chart {
			chart "Average Happiness" type: series {
				data "avg_happiness" value: avg_happiness;
			}
			chart "Interactions per tick" type: series {
				data "interactions" value: interactions_this_tick;
			}
		}
	}
}
