model InformationCenter

//  GLOBAL SETTINGS
global {
	int numberOfSmart <- 5;
	int numberOfNormal <- 5;
	int numberOfStores <- 4;
	int numberOfInfos <- 1;
	int distanceThreshold <- 2;

	init {

		create SmartPerson number:numberOfSmart;
		create NormalPerson number:numberOfNormal;
		create Store number:numberOfStores;
		create Info number:numberOfInfos;

		// --- random locations ---
		ask SmartPerson { location <- {rnd(0, 100), rnd(0, 100)}; }
		ask NormalPerson { location <- {rnd(0, 100), rnd(0, 100)}; }
		ask Store { location <- {rnd(0, 100), rnd(0, 100)}; }
		ask Info { location <- {rnd(0, 100), rnd(0, 100)}; }

		//  Guarantee 1 store ONLY food and 1 store ONLY drink
		Store foodOnlyStore <- one_of(Store);
		foodOnlyStore.hasFood <- true;
		foodOnlyStore.hasDrink <- false;

		Store drinkOnlyStore <- one_of(Store where (each != foodOnlyStore));
		drinkOnlyStore.hasFood <- false;
		drinkOnlyStore.hasDrink <- true;

		// Randomize the rest
		loop s over: species(Store) {
			if (s != foodOnlyStore) and (s != drinkOnlyStore) {
				s.hasFood <- flip(0.5);
				s.hasDrink <- flip(0.5);
			}
		}
	}

	//  Distance stats every 2000 ticks
	reflex reportStats when: (time mod 2000 = 0) and (time > 0) {
	    list<float> smartDistances <- [];
	    list<float> normalDistances <- [];

	    loop s over: species(SmartPerson) { smartDistances <- smartDistances union [s.distance_travelled]; }
	    loop n over: species(NormalPerson) { normalDistances <- normalDistances union [n.distance_travelled]; }

	    float avgSmart <- (length(smartDistances) > 0) ? mean(smartDistances) : 0.0;
	    float avgNormal <- (length(normalDistances) > 0) ? mean(normalDistances) : 0.0;

	    write "⏱ Time " + string(time)
	        + " → Smart avg: " + string(avgSmart)
	        + " | Normal avg: " + string(avgNormal)
	        + " | ⚖ Difference: " + string(avgNormal - avgSmart);
	}
}

// STORE
species Store {
	bool hasFood <- flip(0.5);
	bool hasDrink <- flip(0.5);

	aspect base {
		rgb c <- #lightgray;
		if hasFood and hasDrink { c <- #red; }
		else if hasFood { c <- #green; }
		else if hasDrink { c <- #blue; }
		draw square(2) color: c border: #black;
	}
}

// INFO CENTER
species Info skills:[fipa] {

	reflex getMessage when: !empty(informs) {
		message m <- informs at 0;
		list<string> content <- (m.contents) as list<string>;
		string req <- content at 0;

		Store chosen <- nil;
		float bestDist <- 999999.0;

		if req = "foodRequest" {
			loop s over: species(Store) {
				if s.hasFood {
					float d <- distance_to(location, s.location);
					if d < bestDist {
						bestDist <- d;
						chosen <- s;
					}
				}
			}
		}
		else if req = "drinkRequest" {
			loop s over: species(Store) {
				if s.hasDrink {
					float d <- distance_to(location, s.location);
					if d < bestDist {
						bestDist <- d;
						chosen <- s;
					}
				}
			}
		}
		else if req = "bothRequest" {
			loop s over: species(Store) {
				if s.hasFood and s.hasDrink {
					float d <- distance_to(location, s.location);
					if d < bestDist {
						bestDist <- d;
						chosen <- s;
					}
				}
			}
		}

		if chosen != nil {
			do inform message: m contents:[req, chosen.location];
		} else {
			do inform message: m contents:[req, nil];
		}
	}

	aspect base {
		draw triangle(2.2) color:#orange border:#black;
	}
}



// SMART PERSON (remembers multiple stores + explores)
species SmartPerson skills:[moving, fipa] {

	bool isHungry <- false;
	bool isThirsty <- false;

	bool knowsFood <- false;
	bool knowsDrink <- false;
	point foodLoc <- nil;
	point drinkLoc <- nil;

	bool exploringFood <- false;
	bool exploringDrink <- false;
	bool waitingForInfo <- false;

	float distance_travelled <- 0.0;
	point last_pos <- location;

	int hunger_timer <- rnd(100,300);     // 🔹 less frequent hunger
	int thirst_timer <- rnd(100,300);     // 🔹 less frequent thirst
	int idleCounter <- 0;                 // 🔹 counts how long stuck at info

	// --- metabolism ---
	reflex metabolism {
		hunger_timer <- hunger_timer - 1;
		thirst_timer <- thirst_timer - 1;

		if hunger_timer <= 0 {
			isHungry <- true;
			hunger_timer <- rnd(200,400); // longer intervals
			if knowsFood and flip(0.2) {
				exploringFood <- true;
				waitingForInfo <- false;
			}
		}
		if thirst_timer <= 0 {
			isThirsty <- true;
			thirst_timer <- rnd(200,400);
			if knowsDrink and flip(0.2) {
				exploringDrink <- true;
				waitingForInfo <- false;
			}
		}
	}

	// --- track distance ---
	reflex track {
		if last_pos != nil { distance_travelled <- distance_travelled + distance_to(location,last_pos); }
		last_pos <- location;
	}

	// --- main behavior ---
	reflex act {

		// 🟠 Fallback: avoid getting stuck at Info
		if distance_to(location, one_of(Info).location) < 1 {
			idleCounter <- idleCounter + 1;
			if idleCounter > 10 {
				waitingForInfo <- false;
				exploringFood <- false;
				exploringDrink <- false;
				do wander;
				idleCounter <- 0;
			}
		} else {
			idleCounter <- 0;
		}

		// 🔹 1️⃣ Exploring → go to a random new store directly
		if isHungry and exploringFood {
			Store randomFood <- one_of(Store where (each.hasFood));
			if randomFood != nil {
				foodLoc <- randomFood.location;
				knowsFood <- true;
				exploringFood <- false;
				waitingForInfo <- false;
				do goto target: foodLoc;
			}
		}
		else if isThirsty and exploringDrink {
			Store randomDrink <- one_of(Store where (each.hasDrink));
			if randomDrink != nil {
				drinkLoc <- randomDrink.location;
				knowsDrink <- true;
				exploringDrink <- false;
				waitingForInfo <- false;
				do goto target: drinkLoc;
			}
		}

		// 🔹 2️⃣ Go to Info center if missing info
		else if ((isHungry and !knowsFood) or (isThirsty and !knowsDrink)) and !waitingForInfo {
			point infoLoc <- (one_of(Info)).location;
			do goto target: infoLoc;

			if distance_to(location, infoLoc) < 2 {
				if isHungry and !knowsFood {
					do start_conversation to:[one_of(Info)] performative:'inform' contents:["foodRequest"];
					waitingForInfo <- true;
				}
				else if isThirsty and !knowsDrink {
					do start_conversation to:[one_of(Info)] performative:'inform' contents:["drinkRequest"];
					waitingForInfo <- true;
				}
			}
		}

		// 🔹 3️⃣ Go to store if info known
		else if isHungry and knowsFood and foodLoc != nil {
			do goto target: foodLoc;
			if distance_to(location, foodLoc) < 1 {
				isHungry <- false;
				exploringFood <- false;
				waitingForInfo <- false;
			}
		}
		else if isThirsty and knowsDrink and drinkLoc != nil {
			do goto target: drinkLoc;
			if distance_to(location, drinkLoc) < 1 {
				isThirsty <- false;
				exploringDrink <- false;
				waitingForInfo <- false;
			}
		}
		else {
			do wander;
		}
	}

	// --- receive info messages ---
	reflex receive when: !empty(informs) {
		message m <- informs at 0;
		list msg <- (m.contents) as list;
		string req <- msg at 0;
		point loc <- msg at 1;

		if req = "foodRequest" and loc != nil {
			foodLoc <- loc;
			knowsFood <- true;
			exploringFood <- false;
		}
		if req = "drinkRequest" and loc != nil {
			drinkLoc <- loc;
			knowsDrink <- true;
			exploringDrink <- false;
		}
		waitingForInfo <- false;
		idleCounter <- 0;
	}

	// --- visuals ---
	aspect base {
		rgb c <- #gray;
		if isHungry and isThirsty { c <- #red; }
		else if isHungry { c <- #green; }
		else if isThirsty { c <- #blue; }
		else if exploringFood or exploringDrink { c <- #purple; } // 🔹 exploring mode color
		draw triangle(1.2) color:c border:#black;
	}
}


// NORMAL PERSON (no memory, handles both separately)
species NormalPerson skills:[moving, fipa] {

	bool isHungry <- false;
	bool isThirsty <- false;
	point targetLoc <- nil;
	string currentGoal <- "";
	bool waitingForInfo <- false;
	bool needBoth <- false;

	float distance_travelled <- 0.0;
	point last_pos <- location;

	int hunger_timer <- rnd(50,150);
	int thirst_timer <- rnd(50,150);

	reflex metabolism {
		hunger_timer <- hunger_timer - 1;
		thirst_timer <- thirst_timer - 1;
		if hunger_timer <= 0 { isHungry <- true; hunger_timer <- rnd(100,200); }
		if thirst_timer <= 0 { isThirsty <- true; thirst_timer <- rnd(100,200); }
	}

	reflex track {
		if last_pos != nil { distance_travelled <- distance_travelled + distance_to(location,last_pos); }
		last_pos <- location;
	}

	reflex act {
		if (isHungry or isThirsty) and targetLoc = nil and !waitingForInfo {
			point infoLoc <- (one_of(Info)).location;
			do goto target: infoLoc;

			if distance_to(location, infoLoc) < 2 {
				if isHungry and isThirsty {
					do start_conversation to:[one_of(Info)] performative:'inform' contents:["bothRequest"];
					waitingForInfo <- true;
					needBoth <- true;
				}
				else {
					string req <- (isHungry ? "foodRequest" : "drinkRequest");
					currentGoal <- req;
					do start_conversation to:[one_of(Info)] performative:'inform' contents:[req];
					waitingForInfo <- true;
				}
			}
		}
		else if targetLoc != nil {
			do goto target: targetLoc;
			if distance_to(location, targetLoc) < 1 {
				if currentGoal = "foodRequest" { isHungry <- false; }
				if currentGoal = "drinkRequest" { isThirsty <- false; }

				targetLoc <- nil;
				waitingForInfo <- false;

				// request next if still has need
				if needBoth and (isHungry or isThirsty) {
					string nextReq <- (isHungry ? "foodRequest" : "drinkRequest");
					currentGoal <- nextReq;
					do start_conversation to:[one_of(Info)] performative:'inform' contents:[nextReq];
					waitingForInfo <- true;
				}
				else { needBoth <- false; }
			}
		}
		else { do wander; }
	}

	reflex receive when: !empty(informs) {
		message m <- informs at 0;
		list msg <- (m.contents) as list;
		string req <- msg at 0;
		point loc <- msg at 1;

		if loc = nil and req = "bothRequest" {
			// fallback: ask separately
			if isHungry {
				do start_conversation to:[one_of(Info)] performative:'inform' contents:["foodRequest"];
				currentGoal <- "foodRequest";
				waitingForInfo <- true;
				needBoth <- true;
			}
			else if isThirsty {
				do start_conversation to:[one_of(Info)] performative:'inform' contents:["drinkRequest"];
				currentGoal <- "drinkRequest";
				waitingForInfo <- true;
				needBoth <- true;
			}
		}
		else if loc != nil {
			targetLoc <- loc;
			currentGoal <- req;
			waitingForInfo <- false;
		}
	}

	aspect base {
		rgb c <- #gray;
		if isHungry and isThirsty { c <- #red; }
		else if isHungry { c <- #green; }
		else if isThirsty { c <- #blue; }
		draw circle(1.2) color:c border:#black;
	}
}

// EXPERIMENT
experiment myExperiment type:gui {
	output {
		display myDisplay {
			species SmartPerson aspect:base;
			species NormalPerson aspect:base;
			species Store aspect:base;
			species Info aspect:base;
		}
	}
}






