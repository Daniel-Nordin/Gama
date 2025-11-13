model InformationCenter

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

		ask SmartPerson { location <- {rnd(0, 100), rnd(0, 100)}; }
		ask NormalPerson { location <- {rnd(0, 100), rnd(0, 100)}; }
		ask Store { location <- {rnd(0, 100), rnd(0, 100)}; }
		ask Info { location <- {rnd(0, 100), rnd(0, 100)}; }

		// ensure at least one of each
		if length(Store where (each.hasFood)) = 0 { (one_of(Store)).hasFood <- true; }
		if length(Store where (each.hasDrink)) = 0 { (one_of(Store)).hasDrink <- true; }
	}

	reflex reportStats when: (time mod 2000 = 0) and (time > 0) {
	    list<float> smartDistances <- [];
	    list<float> normalDistances <- [];
	
	    loop s over: species(SmartPerson) { smartDistances <- smartDistances union [s.distance_travelled]; }
	    loop n over: species(NormalPerson) { normalDistances <- normalDistances union [n.distance_travelled]; }
	
	    float avgSmart <- (length(smartDistances) > 0) ? mean(smartDistances) : 0.0;
	    float avgNormal <- (length(normalDistances) > 0) ? mean(normalDistances) : 0.0;
	
	    write "⏱ Time " + string(time)
	        + " → Smart avg: " + string(avgSmart)
	        + " | Normal avg: " + string(avgNormal);
	}
	
}

// ======================================================
// STORE
// ======================================================
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

// ======================================================
// INFO CENTER (gives random store each time)
// ======================================================
species Info skills:[fipa] {

	reflex getMessage when: !empty(informs) {
	    message m <- informs at 0;
	    list<string> content <- (m.contents) as list<string>;
	    string req <- content at 0;

	    if req = "foodRequest" {
	        Store s <- one_of(Store where (each.hasFood));
	        if s != nil { do inform message:m contents:["foodRequest", s.location]; }
	    }
	    else if req = "drinkRequest" {
	        Store s <- one_of(Store where (each.hasDrink));
	        if s != nil { do inform message:m contents:["drinkRequest", s.location]; }
	    }
	    else if req = "bothRequest" {
	        Store s <- one_of(Store where (each.hasFood and each.hasDrink));
	        if s != nil { do inform message:m contents:["bothRequest", s.location]; }
	    }
	}

	aspect base { draw triangle(2.2) color:#orange border:#black; }
}

// ======================================================
// SMART PERSON (has memory, occasionally forgets)
// ======================================================
species SmartPerson skills:[moving, fipa] {

	bool isHungry <- false;
	bool isThirsty <- false;
	bool knowsFood <- false;
	bool knowsDrink <- false;
	point foodLoc;
	point drinkLoc;

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

	// forget rarely
	reflex forget when: time mod 400 = 0 {
		if flip(0.15) {
			knowsFood <- false;
			knowsDrink <- false;
		}
	}

	reflex act {
		if (isHungry and !knowsFood) or (isThirsty and !knowsDrink) {
			// go ask info
			point infoLoc <- (one_of(Info)).location;
			do goto target: infoLoc;
			if distance_to(location, infoLoc) < 2 {
				if isHungry and !knowsFood { 
					do start_conversation to:[one_of(Info)] performative:'inform' contents:["foodRequest"]; 
				}
				else if isThirsty and !knowsDrink { 
					do start_conversation to:[one_of(Info)] performative:'inform' contents:["drinkRequest"]; 
				}
			}
		}
		else if isHungry and knowsFood {
			do goto target: foodLoc;
			if distance_to(location, foodLoc) < 1 { isHungry <- false; }
		}
		else if isThirsty and knowsDrink {
			do goto target: drinkLoc;
			if distance_to(location, drinkLoc) < 1 { isThirsty <- false; }
		}
		else { do wander; }
	}

	reflex receive when: !empty(informs) {
		message m <- informs at 0;
		list msg <- (m.contents) as list;
		string req <- msg at 0;
		point loc <- msg at 1;
		if req = "foodRequest" { foodLoc <- loc; knowsFood <- true; }
		if req = "drinkRequest" { drinkLoc <- loc; knowsDrink <- true; }
	}

	aspect base {
		rgb c <- #gray;
		if isHungry and isThirsty { c <- #red; }
		else if isHungry { c <- #green; }
		else if isThirsty { c <- #blue; }
		draw triangle(1.2) color:c border:#black;
	}
}

// ======================================================
// NORMAL PERSON (no memory, always re-asks)
// ======================================================
species NormalPerson skills:[moving, fipa] {

	bool isHungry <- false;
	bool isThirsty <- false;
	point targetLoc;

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
		if (isHungry or isThirsty) and targetLoc = nil {
			point infoLoc <- (one_of(Info)).location;
			do goto target: infoLoc;
			if distance_to(location, infoLoc) < 2 {
				string req <- (isHungry and isThirsty) ? "bothRequest" : (isHungry ? "foodRequest" : "drinkRequest");
				do start_conversation to:[one_of(Info)] performative:'inform' contents:[req];
			}
		}
		else if targetLoc != nil {
			do goto target: targetLoc;
			if distance_to(location, targetLoc) < 1 {
				if isHungry or isThirsty {
					isHungry <- false;
					isThirsty <- false;
				}
				targetLoc <- nil; // forget and re-ask next time
			}
		}
		else { do wander; }
	}

	reflex receive when: !empty(informs) {
		message m <- informs at 0;
		list msg <- (m.contents) as list;
		point loc <- msg at 1;
		targetLoc <- loc;
	}

	aspect base {
		rgb c <- #gray;
		if isHungry and isThirsty { c <- #red; }
		else if isHungry { c <- #green; }
		else if isThirsty { c <- #blue; }
		draw circle(1.2) color:c border:#black;
	}
}

// ======================================================
// EXPERIMENT
// ======================================================
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






