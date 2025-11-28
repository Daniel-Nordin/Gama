model Challenge1

////////////////////////////////////////////////////////
//                      GLOBAL
////////////////////////////////////////////////////////

global {

    int numberOfGuests <- rnd(12,18);
    int numberOfStages <- 4;

    list<Stage> allStages;
    list<Guest> allGuests;

    float previousGlobalUtility <- -1.0;
    bool optimumReached <- false;

    init {

        create Stage number:numberOfStages {
            location <- {rnd(20,80), rnd(20,80)};
        }

        create Guest number:numberOfGuests {
            location <- {rnd(5,95), rnd(5,95)};
        }

        create Leader number:1;

        allStages <- species(Stage);
        allGuests <- species(Guest);

        write "=== STATIC STAGE PARAMETERS ===";
        loop s over: allStages {
            int sid <- index_of(allStages, s);
            write "Stage " + string(sid) + 
                  " L:" + string(round(s.lightshow*100)/100) +
                  " S:" + string(round(s.speaker*100)/100) +
                  " M:" + string(round(s.music*100)/100);
        }
        write "================================";
    }
}



////////////////////////////////////////////////////////
//                      STAGE
////////////////////////////////////////////////////////

species Stage skills:[fipa] {

    int id;
    float lightshow <- rnd(0.2,1.0);
    float speaker   <- rnd(0.2,1.0);
    float music     <- rnd(0.2,1.0);

    init {
        id <- index_of(species(Stage), self);
    }

    reflex provideInfo when: !empty(informs) {
        message m <- informs at 0;
        list msg <- m.contents;

        if (msg at 0 = "INFO_REQUEST") {
            do inform message:m contents:[
                "STAGE_INFO",
                id,
                lightshow,
                speaker,
                music
            ];
        }
    }

    aspect base {
        draw circle(2) color:#blue border:#black;
        draw ("Stage " + string(id)) color:#black size:14;
    }
}



////////////////////////////////////////////////////////
//                    GUEST
////////////////////////////////////////////////////////

species Guest skills:[fipa, moving] {

    float pref_light   <- rnd(0.2,1.0);
    float pref_speaker <- rnd(0.2,1.0);
    float pref_music   <- rnd(0.2,1.0);

    float crowdPreference <- rnd(0,1);

    list<float> baseUtilities;
    list<float> finalUtilities;
    list<int> stageIDs;

    Stage bestStage <- nil;
    int chosenStageID <- -1;

    string state <- "REQUESTING";


    ////////////////////////////////////////////////////////
    // REQUEST STAGE INFO
    ////////////////////////////////////////////////////////
    reflex requestInfo when: state = "REQUESTING" {

        baseUtilities <- [];
        finalUtilities <- [];
        stageIDs <- [];

        loop s over: species(Stage) {
            do start_conversation
                to:[s]
                performative:'inform'
                contents:["INFO_REQUEST"];
        }

        state <- "WAIT_INFO";
    }


    ////////////////////////////////////////////////////////
    // RECEIVE ONLY STAGE_INFO
    ////////////////////////////////////////////////////////
    reflex receiveInfo when: state = "WAIT_INFO" and !empty(informs) {

        loop m over: informs {

            list data <- m.contents;

            // Ignore anything that is NOT STAGE_INFO
            if (!(data at 0 = "STAGE_INFO")) {
                continue;
            }

            int sid <- int(data at 1);
            float L <- float(data at 2);
            float S <- float(data at 3);
            float M <- float(data at 4);

            float util <- pref_light * L +
                          pref_speaker * S +
                          pref_music * M;

            add util to: baseUtilities;
            add sid to: stageIDs;
        }

        if (length(baseUtilities) = length(species(Stage))) {

            float bestVal <- max(baseUtilities);
            int idx <- baseUtilities index_of bestVal;
            chosenStageID <- stageIDs[idx];

            write "Guest " + string(self) +
                  " initial choice: Stage " + string(chosenStageID);

            do start_conversation
                to:(species(Leader) collect each)
                performative:'inform'
                contents:["INITIAL_CHOICE", chosenStageID, bestVal, crowdPreference];

            state <- "WAIT_LEADER";
        }
    }



    ////////////////////////////////////////////////////////
    // HANDLE LEADER MESSAGES
    ////////////////////////////////////////////////////////
    reflex leaderResponse when: state = "WAIT_LEADER" and !empty(informs) {

        loop m over: informs {
            list msg <- m.contents;

            ////////////////////////////////////////////////
            // FINAL SOLUTION
            ////////////////////////////////////////////////
            if (msg at 0 = "FINAL_ASSIGNMENTS") {

                list<int> finalChoices <- msg at 1;
                int myIndex <- index_of(species(Guest), self);

                chosenStageID <- finalChoices[myIndex];
                bestStage <- species(Stage)[chosenStageID];

                write "Guest " + string(self) +
                      " FINAL stage = " + string(chosenStageID);

                state <- "GO";
            }

            ////////////////////////////////////////////////
            // CROWD LEVELS FOR RE-EVALUATION
            ////////////////////////////////////////////////
            if (msg at 0 = "CROWD_LEVELS") {

                list<float> crowdLevels <- msg at 1;
                finalUtilities <- [];

                if (length(crowdLevels) != length(baseUtilities)) {
                    write "WARNING: crowdLevels/baseUtilities mismatch for guest " + string(self);
                    continue;
                }

                loop i from: 0 to: length(baseUtilities)-1 {

                    float baseU <- baseUtilities[i];
                    float mass  <- crowdLevels[i];

                    float crowdU;

                    if (crowdPreference > 0.5) {
                        crowdU <- crowdPreference * mass;
                    } else {
                        crowdU <- -(1 - crowdPreference) * mass;
                    }

                    add (baseU + crowdU) to: finalUtilities;
                }

                float bestVal2 <- max(finalUtilities);
                int idx2 <- finalUtilities index_of bestVal2;
                chosenStageID <- stageIDs[idx2];

                write "Guest " + string(self) +
                      " re-evaluated to Stage " + string(chosenStageID);

                do start_conversation
                    to:(species(Leader) collect each)
                    performative:'inform'
                    contents:["REVISED_CHOICE", chosenStageID, bestVal2];
            }
        }
    }


    ////////////////////////////////////////////////////////
    // MOVE TO FINAL STAGE
    ////////////////////////////////////////////////////////
    reflex moveToStage when: state = "GO" and bestStage != nil {
        do goto target: bestStage.location speed:1.5;
    }


    aspect base {
        draw circle(1) color:#red border:#black;
    }
}



////////////////////////////////////////////////////////
//                    LEADER
////////////////////////////////////////////////////////

species Leader skills:[fipa] {

    int expected <- 0;
    int received <- 0;

    list<int> stageChoices;
    list<float> utilities;

    float previousGlobalUtility <- -1.0;

    // NEW: best result tracking
    float bestUtility <- -1.0;
    list<int> bestAssignment <- [];

    bool optimumReached <- false;

    init {
        expected <- length(species(Guest));
        stageChoices <- [];
        utilities <- [];
    }

    ///////////////////////////////////////////////////////////
    // RECEIVE GUEST MESSAGES
    ///////////////////////////////////////////////////////////
    reflex receiveChoices when: (!empty(informs) and !optimumReached) {

        loop m over: informs {

            list msg <- m.contents;

            // Fix nested [[...]]
            if ((length(msg) = 1) and (length(msg at 0) > 1)) {
                msg <- msg at 0;
            }

            if (length(msg) < 3) { continue; }

            string tag <- msg at 0;

            if (tag != "INITIAL_CHOICE" and tag != "REVISED_CHOICE") {
                continue;
            }

            int sid <- int(msg at 1);
            float util <- float(msg at 2);

            add sid to: stageChoices;
            add util to: utilities;

            received <- received + 1;

            if (received = expected) {
                do evaluateGlobalUtility;
            }
        }
    }


    ///////////////////////////////////////////////////////////
    // GLOBAL UTILITY — FIXED VERSION
    ///////////////////////////////////////////////////////////
    action evaluateGlobalUtility {

        float total <- sum(utilities);
        write "\nGlobal Utility = " + string(round(total * 100) / 100);

        ///////////////////////////////////////////////////////////////
        // CASE 1 — IMPROVED UTILITY
        ///////////////////////////////////////////////////////////////
        if (total > previousGlobalUtility) {

            previousGlobalUtility <- total;

            // SAVE BEST RESULT
            bestUtility <- total;
            bestAssignment <- stageChoices;   // ← IMPORTANT FIX

            list<float> crowdLevels <- [];

            loop s from: 0 to: length(species(Stage)) - 1 {

                int count <- 0;

                loop gID from: 0 to: length(stageChoices) - 1 {
                    if (stageChoices[gID] = s) {
                        count <- count + 1;
                    }
                }

                float mass <- float(count) / float(expected);
                add mass to: crowdLevels;
            }

            write "Sending CROWD_LEVELS: " + string(crowdLevels);

            do start_conversation
                to: (species(Guest) collect each)
                performative:'inform'
                contents:["CROWD_LEVELS", crowdLevels];

            stageChoices <- [];
            utilities <- [];
            received <- 0;

            return;
        }


        ///////////////////////////////////////////////////////////////
        // CASE 2 — NO IMPROVEMENT → RETURN BEST RESULT
        ///////////////////////////////////////////////////////////////
        write "=== GLOBAL OPTIMUM REACHED ===";
        write "Best Global Utility = " + string(round(bestUtility * 100) / 100);
        write "Final assignments = " + string(bestAssignment);

        optimumReached <- true;

        do start_conversation
            to: (species(Guest) collect each)
            performative:'request'
            contents:["FINAL_ASSIGNMENTS", bestAssignment];
    }


    ///////////////////////////////////////////////////////////
    // VISUAL
    ///////////////////////////////////////////////////////////
    aspect base {
        draw circle(1.5) color:#green border:#black;
        draw "Leader" color:#black size:12;
    }
}







////////////////////////////////////////////////////////
//                    EXPERIMENT
////////////////////////////////////////////////////////

experiment Display type: gui {
    output {
        display map {
            species Stage aspect: base;
            species Guest aspect: base;
            species Leader aspect: base;
        }
    }
}

