/**
* Name: InformationCenter
* Based on the internal empty template. 
* Author: henna
* Tags: 
*/


model InformationCenter

global {
	int numberOfPeople <- 10;
	int numberOfStores <- 2;
	int numberOfInfos <- 1;
	int numberOfAuctioneers <- 1;
	int distanceThreshold <- 2;
	graph the_graph;
	point shopLocation;
	point foodLocation;
	point drinkLocation;
	point foodAndDrinkLocation;
	
	init {
		
		create Person number:numberOfPeople;
		create Store number:numberOfStores;
		create Info number:numberOfInfos;
		create Auctioneer number:numberOfAuctioneers;
		
		//numbers for agents
		loop counter from: 1 to: numberOfPeople {
			Person my_agent <- Person[counter - 1];
			my_agent <- my_agent.setName(counter);
		}
	
		loop counter from: 1 to: numberOfStores {
			Store my_agent <- Store[counter - 1];
			my_agent <- my_agent.setName(counter);
		}
		
		loop counter from: 1 to: numberOfInfos {
			Info my_agent <- Info[counter - 1];
			my_agent <- my_agent.setName(counter);
		}
		loop counter from: 1 to: numberOfAuctioneers {
			Auctioneer my_agent <- Auctioneer[counter - 1];
			my_agent <- my_agent.setName(counter);
		}
		
		//random locations
		loop p over: species(Person){
			p.location <- {rnd(0, 100), rnd(0, 100)};
		}
		
		loop s over: species(Store){
			s.location <- {rnd(0, 100), rnd(0, 100)};
		//	write 'Store ' + s + ' location' + s.location;
		}
		
		loop i over: species(Info){
			i.location <- {rnd(0, 100), rnd(0, 100)};
		}
		
		loop a over: species(Auctioneer){
			a.location <- {rnd(0, 100), rnd(0, 100)};
		}
		
		//foodLocation is a place where is food
		loop f over: species(Store){
			if f.hasFood {
				foodLocation <- f.location;
				write foodLocation;
				break;
			}
		}
		
		//dringLocation is a place where is drinks
		loop d over: species(Store){
			if d.hasDrink {
				drinkLocation <- d.location;
				break;
			}
		}
		
		//foodAndDrinkLocation is a place where is food and drinks
		loop b over: species(Store){
			if b.hasDrink and b.hasFood {
				foodAndDrinkLocation <- b.location;
				break;
			}
		}
		
	}
}

species Person skills:[moving, fipa] {
	bool isHungry <- false;
	bool isThirsty <- false;
	string personName <- "undefined";
	bool canStart <- false;
	int whenHungry <- 0 update: rnd(0,500);
	int whenThirsty <- 0 update: rnd(0,500);
	point recievedContent;
//	float speed <- 0.1;
	bool noFLocation <- true;
	bool noDLocation <- true;
	bool noBLocation <- true;
	float distanceF <-9999.0;
	float distanceD <-9999.0;
	point targetFLocation;
	point targetDLocation;
	point targetBLocation;
	string receivedContent;
	int willingPrice;
	
	//number for Person
	action setName(int num) {
		personName <- "Person " + num;
	}
	
	//random hungry
	reflex {
		if numberOfPeople = whenHungry {
			isHungry <- true;
		}
	}
	
	//random thirsty
	reflex {
		if numberOfPeople = whenThirsty {
			isThirsty <- true;
		}
	}
	
	//customer colors
	aspect base {
		rgb agentColor <- rgb("gray");
		if (isHungry and isThirsty) {
			agentColor <- rgb("red");
		} else if (isThirsty) {
			agentColor <- rgb ("blue");
		} else if (isHungry) {
			agentColor <- rgb ("green");
		}
		
		//shape and color
		draw circle(1) color: agentColor border: #black;
	}
	
	//ask Store location from Info
	reflex question {
		if isHungry and !empty(Info at_distance distanceThreshold){
			write '(Time ' + time +'): ' + name + ' asks where can I get food?';
			do start_conversation to: [(one_of(species(Info)))] protocol: 'no-protocol' performative: 'inform' contents: ["foodRequest"];
		}
		else if isThirsty and !empty(Info at_distance distanceThreshold) {
			write '(Time ' + time +'): ' + name + ' asks where can I get drinks?';
			do start_conversation to: [(one_of(species(Info)))] protocol: 'no-protocol' performative: 'inform' contents: ["drinkRequest"];
		}
		else if isThirsty and isHungry and !empty(Info at_distance distanceThreshold) {
			write '(Time ' + time +'): ' + name + ' asks where can I get drinks and food?';
			do start_conversation to: [(one_of(species(Info)))] protocol: 'no-protocol' performative: 'inform' contents: ["bothRequest"];
		}
	}
	
	reflex receiveFoodLocation when: !empty(informs) {
    	message receivedLocation <- informs at 0;
    	list msgContent <- (receivedLocation.contents) as list;
    	string requestType <- msgContent at 0;
    	point locationData <- msgContent at 1;
    	
		write msgContent at 0;
		write msgContent at 1;
		
    	write "Received message contents: " + msgContent;
   
	    if msgContent contains_any ["foodRequest"] { 
	    	targetFLocation <- locationData;
	    	write locationData;
	    	write targetFLocation;
			noFLocation <- false;
			write 'Heading to food';
		}
	    else if msgContent contains_any ["drinkRequest"] { 
	    	targetDLocation <- locationData;
	    	write targetDLocation;
			noDLocation <- false;
			write 'Heading to drink';
		}
	    else if msgContent contains_any ["bothRequest"] { 
		    targetBLocation <- locationData;
		    write targetBLocation;
			noBLocation <- false;
			write 'Heading to both';
		}
		
	}
	
	
	reflex auction when: !empty(proposes){
		message msg <- proposes at 0;
		list msgContent <- msg.contents as list;
		string requestType <- msgContent at 0;
		
		if msgContent contains_any ["Start Auction"] {
			int minDutch <- int(msgContent at 1);
			willingPrice <- rnd(minDutch/5, minDutch/1.5);
			write self.name + " is willing to pay " + willingPrice;
		}
		else if msgContent contains_any ["Current price is "] {
			int curPrice <- int(msgContent at 1);
			if curPrice > willingPrice{
				do reject_proposal message: msg contents: ["No", self];
			}
			else {
				write self.name + " accepts!";
				do accept_proposal message: msg contents: ["yes", self];
			}
		}
	}
	
	//move to info if hungry or thirsty
	//move to Store if hungry or thirsty and location
	//else wander
	reflex move {
		//goto Info
		if (isHungry or isThirsty) and (noFLocation and noDLocation and noBLocation) {
			do goto(one_of(species(Info)).location);
		}
		//goto info if isThirsty and have food location
		else if (isThirsty) and (!noFLocation and noDLocation and noBLocation) {
			do goto(one_of(species(Info)).location);
		}
		//goto info is isHungry and have drink location
		else if (isHungry) and (noFLocation and !noDLocation and noBLocation) {
			do goto(one_of(species(Info)).location);
		}
		else if (isHungry and isThirsty) and (!noFLocation and !noDLocation and noBLocation) and targetBLocation != nil {
			do goto(one_of(species(Info)).location);
		}
		else if isHungry and !noFLocation and targetFLocation != nil {
			do goto(targetFLocation);	
		}
		else if isThirsty and !noDLocation and targetDLocation != nil{
			do goto(targetDLocation);
		}
		else if isThirsty and isHungry and !noBLocation and targetBLocation != nil{
			do goto(targetBLocation);
		}
		else if isThirsty and isHungry and !noBLocation and targetBLocation = nil and targetFLocation != nil{
			do goto(targetFLocation);
		}
		else if isThirsty and isHungry and !noBLocation and targetBLocation = nil and targetDLocation != nil{
			do goto(targetDLocation);
		}
		else {
			do wander;     
		}
    }

    //distance to drink and food
	reflex distanceToDrink{
		if isThirsty and drinkLocation != nil {
		 	float distanceD <- sqrt((self.location.x - drinkLocation.x)^2 + (self.location.y - drinkLocation.y)^2);
			write "Distance to drink: " + distanceD;
			if distanceD = 0.0 {
				isThirsty <- false;
				write 'isThirsty false';
			}
		}
	}
	
	reflex distanceToFood{
		if isHungry and foodLocation != nil {
	 		float distanceF <- sqrt((self.location.x - foodLocation.x)^2 + (self.location.y - foodLocation.y)^2);
			write "Distance to food: " + distanceF;
			if distanceF = 0.0 {
				isHungry <- false;
				write 'isHungry false';
			}
		}
	}
	
	reflex distanceToBoth {
		if isHungry and isThirsty and foodAndDrinkLocation != nil {
		 	float distanceB <- sqrt((self.location.x - foodAndDrinkLocation.x)^2 + (self.location.y - foodAndDrinkLocation.y)^2);
			write "Distance to food & drink: " + distanceB;
			if distanceB = 0.0 {
				isHungry <- false;
				isThirsty <- false;
				write 'isHungry and isThirsty false';	
			}
		}
	}
}

species Info skills: [fipa] {

	string infoName <- "Undefined";
	string recievedContent;
	
	action setName(int num) {
		infoName <- "Info " + num;
	}
	
	//message
	reflex getMessage when: !empty(informs) {
    	message receivedMsg <- informs at 0;
    	list<string> msgContent <- (receivedMsg.contents) as list<string>;
    	string msgContent <- msgContent at 0;

    	write "Received message contents: " + msgContent;
   
	    if msgContent = "foodRequest" { 
	    	write 'foodLocation sent' +  foodLocation;
	        do inform message: receivedMsg contents: ["foodRequest", foodLocation];
	    }
	    else if msgContent = "drinkRequest" { 
	    	write 'drinkLocation sent';
	        do inform message: receivedMsg contents: ["drinkRequest", drinkLocation];
	    }
	    else if msgContent = "bothRequest" { 
	    	write 'bothLocation sent';
	        do inform message: receivedMsg contents: ["bothRequest", foodAndDrinkLocation];
	    }
	}
	
	// Visual
	aspect base {
		rgb agentColor <- rgb("fuchsia");

		draw triangle(2.2) color: agentColor border: #black;
	}
}

species Store {
	bool hasFood <- flip(0.5);
	bool hasDrink <- flip(0.5);
	string storeName <- "Undefined";
	
	action setName(int num) {
		storeName <- "Store " + num;
	}
	// Visual
	aspect base {
		rgb agentColor <- rgb("lightgray");
		if (hasFood and hasDrink) {
			agentColor <- rgb("red");
		} else if (hasFood) {
			agentColor <- rgb ("green");
		} else if (hasDrink) {
			agentColor <- rgb ("blue");
		}
		
		draw square(2) color: agentColor border: #black;
	}
}

species Auctioneer skills: 	[fipa]{
	string aucName <- "undefined";
	int reduction <- 5;
	int minAskingPrice <- 500;
	int curAskingPrice <- 1000;
	Person winner <- nil;
	bool auctionRunning <- false;
	
	
	action setName(int num){
		aucName <- "Auctioneer " + num;
	}
	
	reflex startAuction when: every(4#h) {
    write "Time for Auction!";
    auctionRunning <- true;
    winner <- nil;
    curAskingPrice <- 1000;
    do start_conversation to: list(Person) protocol: "no-protocol" performative: "propose" contents: ["Start Auction", curAskingPrice];
    do start_conversation to: list(Person) protocol: "fipa-contract-net" performative: "propose" contents: ["Current price is ", curAskingPrice];
}

	
	reflex handleResponses when: auctionRunning{
    if !empty(accept_proposals) {
        message m <- accept_proposals at 0;
        winner <- m.sender;
        write "Winner is " + winner + " at " + curAskingPrice + " $";
        auctionRunning <- false;
    }

    if winner = nil and !empty(reject_proposals) {
        curAskingPrice <- curAskingPrice - reduction;
        write "Lowering price to " + curAskingPrice;

        if curAskingPrice <= minAskingPrice {
            write "No winner. Auction ended.";
            auctionRunning <- false;
        } else if auctionRunning{
            do start_conversation to: list(Person) protocol: "fipa-contract-net" performative: "propose" contents: ["Current price is ", curAskingPrice];
        }
    }
}

	
	
	
	aspect base{
		rgb agentColor <- rgb("purple");
		draw circle(1.5) color: agentColor border:#black;
	}
}

experiment myExperiment type:gui {
	output {
		display myDisplay{
			species Person aspect:base;
			species Store aspect:base;
			species Info aspect:base;
			species Auctioneer aspect:base;
		}
	}
}