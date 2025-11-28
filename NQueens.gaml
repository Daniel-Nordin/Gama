/***
* Name: NQueens
* Author: Daniel, Mihailo
***/

model queen

global {
    int neighbors <- 8;
    int queens <- 10;

    init {
        create Queen number: queens;
    }

    list<chessBoardCell> allCells;
    list<Queen> allQueens;

    bool isCalculating <- false;
}

species Queen {

    chessBoardCell myCell <- one_of (chessBoardCell);
    list<list<int>> occupancyGrid;

    //------------------------------------------------------
    // Convert grid coordinates to chess notation (A1, B5...)
    //------------------------------------------------------
    string cellName(int gx, int gy) {
        string col <- string(char(65 + gx));        // A,B,C...
        string row <- string(queens - gy);          // row 1 at bottom
        return col + row;
    }

    init {
        //Assign a free cell
        loop cell over: myCell.neighbours {
            if cell.queen = nil {
                myCell <- cell;
                break;
            }
        }
        location <- myCell.location;
        myCell.queen <- self;

        add self to: allQueens;

        do refreshOccupancyGrid;
    }

    action refreshOccupancyGrid {
        self.occupancyGrid <- [];
        loop m from: 0 to: queens - 1 {
            list<int> mList;
            loop n from: 0 to: queens - 1 {
                add 0 to: mList;
            }
            add mList to: occupancyGrid;
        }
    }

    action calculateOccupancyGrid {
        do refreshOccupancyGrid;

        // Mark occupied cells
        loop cell over: allCells {
            if cell.queen != nil and cell.queen != self {
                self.occupancyGrid[cell.grid_x][cell.grid_y] <- 1000;
            }
        }

        // Propagate threat lines
        loop cell over: allCells {
            int m <- cell.grid_x;
            int n <- cell.grid_y;

            if self.occupancyGrid[m][n] = 1000 {
                loop i from: 1 to: queens {

                    int mi <- m + i;
                    int n_mi <- m - i;
                    int ni <- n + i;
                    int n_ni <- n - i;

                    if mi < queens        { self.occupancyGrid[mi][n] <- self.occupancyGrid[mi][n] + 1; }
                    if n_mi > -1          { self.occupancyGrid[n_mi][n] <- self.occupancyGrid[n_mi][n] + 1; }
                    if ni < queens        { self.occupancyGrid[m][ni] <- self.occupancyGrid[m][ni] + 1; }
                    if n_ni > -1          { self.occupancyGrid[m][n_ni] <- self.occupancyGrid[m][n_ni] + 1; }

                    if mi < queens and ni < queens     { self.occupancyGrid[mi][ni] <- self.occupancyGrid[mi][ni] + 1; }
                    if n_mi > -1 and ni < queens       { self.occupancyGrid[n_mi][ni] <- self.occupancyGrid[n_mi][ni] + 1; }
                    if mi < queens and n_ni > -1       { self.occupancyGrid[mi][n_ni] <- self.occupancyGrid[mi][n_ni] + 1; }
                    if n_mi > -1 and n_ni > -1         { self.occupancyGrid[n_mi][n_ni] <- self.occupancyGrid[n_mi][n_ni] + 1; }
                }
            }
        }
    }

    list<point> availableallCells(int val) {
        list<point> Checks;
        loop cell over: allCells {
            int m <- cell.grid_x;
            int n <- cell.grid_y;
            if self.occupancyGrid[m][n] = val
                and !(m = myCell.grid_x and n = myCell.grid_y) {
                add {m, n} to: Checks;
            }
        }
        return Checks;
    }

    Queen findQueenInSightbyLocation(int x) {
        list<Queen> queensInSight;

        loop cell over: allCells {
            int m <- cell.grid_x;
            int n <- cell.grid_y;

            if self.occupancyGrid[m][n] > 999 {

                if m = self.myCell.grid_x or n = self.myCell.grid_y {
                    add cell.queen to: queensInSight;

                } else {
                    int diff_x <- abs(m - self.myCell.grid_x);
                    int diff_y <- abs(n - self.myCell.grid_y);
                    if diff_x = diff_y {
                        add cell.queen to: queensInSight;
                    }
                }
            }
        }

        if length(queensInSight) > 0 {
            Queen sight <- queensInSight[rnd(0, length(queensInSight)-1)];
            return sight;
        } else {
            return nil;
        }
    }


    //---------------------------------------------------------
    // MOVEMENT LOGIC 
    //---------------------------------------------------------
    action needToMove {
        do calculateOccupancyGrid;

        if self.occupancyGrid[myCell.grid_x][myCell.grid_y] != 0 {

            list<point> possibleChecks <- availableallCells(0);

            //-------------------------------
            // CASE 1: Free safe cells exist
            //-------------------------------
            if length(possibleChecks) > 0 {

                point chosen <- possibleChecks[rnd(0, length(possibleChecks)-1)];

                loop c over: allCells {
                    if c.grid_x = chosen.x and c.grid_y = chosen.y and c.queen = nil {

                        myCell.queen <- nil;
                        myCell <- c;
                        location <- c.location;
                        myCell.queen <- self;

                        // Pretty-print safe cells in chess notation
                        list<string> pretty;
                        loop p over: possibleChecks {
                            add cellName(p.x, p.y) to: pretty;
                        }

                 
                        write "Queen " + name + " relocating";
                        write "Safe options: " + pretty;
                        write "Moving to " + cellName(c.grid_x, c.grid_y);
   

                        break;
                    }
                }

            } else {

                //----------------------------------------
                // CASE 2: No safe cells → ask another queen
                //----------------------------------------

                write "Queen " + name + " is trapped at " + cellName(myCell.grid_x, myCell.grid_y);

                Queen sight <- findQueenInSightbyLocation(0);

                if sight != nil {

                    chessBoardCell sightCell;

                    ask sight {
                        write "Queen " + myself.name + " requests help from queen at " +
                              cellName(myCell.grid_x, myCell.grid_y);
                        sightCell <- self.myCell;
                    }

                    chessBoardCell target;
                    float distance <- 1000.0;

                    loop s over: sightCell.neighbours {
                        float dist <- myCell.location distance_to s.location;
                        if dist < distance and dist != 0 and s.queen = nil {
                            distance <- dist;
                            target <- s;
                        }
                    }

                    write "Queen " + name + " moves to " + cellName(target.grid_x, target.grid_y);

                    myCell.queen <- nil;
                    myCell <- target;
                    location <- target.location;
                    myCell.queen <- self;
                }
            }
        }
    }

    // REFLEX
    reflex amIsafe when: !isCalculating {
        isCalculating <- true;
        do needToMove;
        isCalculating <- false;
    }
    
    aspect base {
        draw circle(1.0) color: #blue;
    }
}

grid chessBoardCell width: queens height: queens neighbors: neighbors {
    list<chessBoardCell> neighbours <- (self neighbors_at 2);
    Queen queen <- nil;

    init {
        add self to: allCells;
    }
}

experiment ChessBoard type: gui {
    output {
        display main_display {
            grid chessBoardCell border: #black;
            species Queen aspect: base;
        }
    }
}



