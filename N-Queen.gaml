/**
* Name: NQueen
* Based on the internal skeleton template. 
* Author: Daniel
* Tags: 
*/

model NQueen

global {
	/** Insert the global definitions, variables and actions here */
	int numberOfQueens <- 8;

	
	
	
	init{
		create Tile number: numberOfQueens*numberOfQueens;
		create Queen number: numberOfQueens;
		
		loop counter from: 1 to: numberOfQueens {
			Queen my_agent <- Queen[counter - 1];
			my_agent <- my_agent.setName(counter - 1);
			my_agent <- my_agent.setLocation((counter * -1) -1);
		}
		loop counter from: 1 to: numberOfQueens*numberOfQueens {
			Tile my_agent <- Tile[counter - 1];
			my_agent <- my_agent.setName(counter - 1);
		}
		
		Queen q <- Queen[0];
		q <- q.checkPos();
	}
}

species Tile {
	string name;
	int x;
	int y;
	
	action setName(int n){
		self.name <- "Tile " + n;
		self.x <- n mod numberOfQueens;
		self.y <- n / numberOfQueens;
		location <- {x*4 + 2, y*4 + 2};
		write name + " x:" + x + " y:" + y;
	}
	
	
	aspect base {
		draw square(4) color: #white border:#black;
	}
	
}

species Queen skills:[fipa]{
	string name;
	int x;
	int y;
	list tried <- [];
	bool paused <- false;
	list memory <- [];
	
	
	action setName(int n){
		self.name <- "Queen " + n;
		self.y <- n;
		
	}
	
	action setLocation(int x){
		self.x <- x;
		location <- {self.x * 4 + 2 , self.y*4 + 2};
	}
	
	action checkPos{
		if self.x < -2 {
			self.x <- -1;
		}
		do start_conversation to: list(Queen) protocol: "fipa-contract-net" performative: "propose" contents: ["My coords", x, y];
	}
	
	reflex requestedMove when: !empty(informs){
		
	}
	
	reflex unavailablePos when: !empty(reject_proposals) and !paused{
		if length(self.tried) < numberOfQueens{
			self.tried <- self.tried + self.x;
			if self.x = numberOfQueens{
				self.x <- -1;
			}
			write tried;
			do setLocation(self.x + 1);
			do checkPos;
		}
		else {
			self.tried <- [];
			self.paused <- true;
			Queen pred <- Queen[self.y - 1];
			pred.paused <- false;
			pred <- pred.checkPos();
		}
	}
	
	
	reflex respondCheck when: !empty(proposes){
		message msg <- proposes at 0;
		list msgContent <- msg.contents as list;
		string requestType <- msgContent at 0;
		
		if msgContent contains_any ["My coords"]{
			int otherX <- int(msgContent at 1);
			int otherY <- int(msgContent at 2);
			if (otherX = self.x){
				write "Queen " + (otherY) + " is on my column!";
				do reject_proposal message: msg contents: ["Same X", self];
			}
    	else if (self.y = otherY - 1 or self.y = otherY + 1) and (self.x = otherX - 1 or self.x = otherX + 1){
    			write "Queen " + (otherY) + " is on my diagonal!";
    			do reject_proposal message: msg contents: ["Same diagonal", self];
			}
		}
		else {
			do accept_proposal message: msg contents: ["Fine", self];
		}
	}
	
	
	
	aspect base {
		draw circle(1) color:#red border:#black;
	}
}

experiment NQueen type: gui {
	/** Insert here the definition of the input and output of the model */
	output {
		display myDisplay{
			species Tile aspect:base;
			species Queen aspect:base;
		}
	}
}
