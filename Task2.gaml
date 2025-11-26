model Task2

global {

    int numberOfGuests <- 6;
    int numberOfStages <- 4;

    init {

        create Stage number:numberOfStages;
        create Guest number:numberOfGuests;

        // random positions
        loop s over: species(Stage) {
            s.location <- {rnd(0,100), rnd(0,100)};
        }
        loop g over: species(Guest) {
            g.location <- {rnd(0,100), rnd(0,100)};
        }

        write "=== STAGE ATTRIBUTE SUMMARY ===";
        loop s over: species(Stage) {
         	string Ls <- string(round(s.lightshow * 100) / 100);
			string Sp <- string(round(s.speaker * 100) / 100);
			string Mu <- string(round(s.music * 100) / 100);

            write "Stage " + string(s) + " -> L:" + Ls + " S:" + Sp + " M:" + Mu;
        }
        write "================================";
    }
}

//////////////////////////////////////
//           STAGE AGENT           //
//////////////////////////////////////

species Stage skills:[fipa] {

    float lightshow <- rnd(0.1,1.0);
    float speaker <- rnd(0.1,1.0);
    float music <- rnd(0.1,1.0);

    // respond to info requests
    reflex respond when: !empty(informs) {

        message m <- informs at 0;
        list content <- (m.contents) as list;
        string req <- content at 0;

        if (req = "INFO_REQUEST") {

            do inform message: m contents:[
                "STAGE_INFO",
                lightshow,
                speaker,
                music
            ];
        }
    }

    aspect base {

	    draw circle(1) color:#blue border:#black;
	
	    string Ls <- string(round(lightshow * 100) / 100);
	    string Sp <- string(round(speaker * 100) / 100);
	    string Mu <- string(round(music * 100) / 100);
	
	    string label <- "L:" + Ls + " S:" + Sp + " M:" + Mu;
	
	    draw label color:#black size:12;
	}
}

//////////////////////////////////////
//           GUEST AGENT           //
//////////////////////////////////////

species Guest skills:[moving, fipa] {

    float pref_light <- rnd(0.1,1.0);
    float pref_speaker <- rnd(0.1,1.0);
    float pref_music <- rnd(0.1,1.0);

    list<Stage> stageList;
    list<float> utilityList;

    Stage bestStage <- nil;
    string state <- "REQUESTING";

    //////////////////////////////////////
    // 1) SEND REQUEST TO ALL STAGES
    //////////////////////////////////////
    reflex sendRequests when: (state = "REQUESTING") {

        stageList <- [];
        utilityList <- [];

        loop s over: species(Stage) {

            add s to: stageList;

            do start_conversation
                to:[s]
                performative:'inform'
                contents:["INFO_REQUEST"];
        }

        state <- "WAIT";
    }

    //////////////////////////////////////
    // 2) RECEIVE INFO + STORE UTILITIES
    //////////////////////////////////////
    reflex handleReplies when: (state = "WAIT") and (!empty(informs)) {

        loop m over: informs {

            list msg <- (m.contents) as list;
            string header <- msg at 0;

            if (header = "STAGE_INFO") {

                float L <- float(msg at 1);
                float S <- float(msg at 2);
                float M <- float(msg at 3);

                float util <- pref_light*L + pref_speaker*S + pref_music*M;

                add util to: utilityList;
            }
        }

        if (length(utilityList) = length(stageList)) {

            write "";
            write "Guest " + string(self) + " utilities:";

            loop i from: 0 to: length(stageList)-1 {
                Stage st <- stageList at i;
                float u <- utilityList at i;

                string Us <- string(round(u * 1000) / 1000);
                string sid <- string(st);

                write "  Stage " + sid + " -> utility = " + Us;
            }

            state <- "CHOOSING";
        }
    }

    //////////////////////////////////////
    // 3) CHOOSE THE BEST STAGE
    //////////////////////////////////////
    reflex chooseStage when: (state = "CHOOSING") {

        float bestVal <- -1.0;
        int bestIndex <- -1;

        loop i from: 0 to: length(utilityList) - 1 {

            float u <- utilityList at i;

            if (u > bestVal) {
                bestVal <- u;
                bestIndex <- i;
            }
        }

        if (bestIndex != -1) {
            bestStage <- stageList at bestIndex;
        }

        write " >> Guest " + string(self) + " chose STAGE " + string(bestStage);

        state <- "GO";
    }

    //////////////////////////////////////
    // 4) MOVE TO BEST STAGE
    //////////////////////////////////////
    reflex goToStage when: (state = "GO") and (bestStage != nil) {

        do goto target: bestStage.location speed:1.2;

        if (location distance_to bestStage.location < 2.0) {
            state <- "DONE";
        }
    }

    aspect base {
        draw circle(0.7) color:#red border:#black;
    }
}

//////////////////////////////////////
//           EXPERIMENT             //
//////////////////////////////////////

experiment Display type: gui {

    output {
        display mapDisplay {
            species Stage aspect: base;
            species Guest aspect: base;
        }
    }
}







