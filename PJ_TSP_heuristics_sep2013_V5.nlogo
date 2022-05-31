;;
globals [k-unfeasible cn-failed-ants cn-lambda-invocations]
breed [handlers a-handler]
breed [nodes a-city]
breed [ants an-ant]
breed [tellers a-teller]
undirected-link-breed [arcs an-arc]
arcs-own    [dm-distance dm-pheromone]
patches-own [dm-zone]
turtles-own [dm-arrival dm-departure dm-cohort]
handlers-own [lambda-event dm-severity dm-next-event ]
ants-own     [lambda-andon  dm-tabu-list dm-best-next-arc dm-last-arc]
nodes-own    [dm-node]
tellers-own  [dm-input]
;;
to setup
  clear-all
  carefully [
    set-default-shape handlers "flag" 
    set-default-shape nodes "circle" 
    set-default-shape ants "sheep" 
    set-default-shape tellers "person"
    ask patches [set dm-zone "geography"]
    ask patches with [11 < pycor]  [set pcolor cyan set dm-zone "FEL"]
    ask patches with [pxcor < -11] [set pcolor gray set dm-zone "arrival"]
    ask patches with [pxcor < -11 and 0 < pycor] [set pcolor turquoise set dm-zone "departure"]
    mt-data-entry
    mt-tour-construction
    reset-ticks
    eh-schedule-event "trigger-arcs" 1  task [eh-trigger-evaporation false]
    eh-schedule-event "trigger-ants" 2  task [eh-trigger-ants ]
    show (word " info! ---------------------------  TRAVEL SALESPERSON ANT COLONY OPTIMIZATION STARTS ... ---------------------------- nodes: "  rpt-full-network-list)
    mt-feedback-dataentry
    mt-label-habitat 
  ] [eh-catch "observer" 0 "setup" error-message ]
end
;;
to go
  carefully [
    if any? handlers with [member? "HALT!" dm-cohort]     [error (word " HALT! order accepted by observer!")]
    if any? handlers with [member? "exch"  dm-cohort]     [error (word " there are reported bugs in the system!")]
    let lv-lane patches with ["FEL" = dm-zone]
    let lv-dead-events (handlers-on patches with ["arrival" = dm-zone]) with [member? "event-" dm-cohort]
    if bu-verify-mode? [show (word  rpt-display-cron   " DEBUG! "  count lv-dead-events  " dead events will now be moved to departure zone.") ]
    ask  lv-dead-events [
      if (ticks < dm-next-event ) [error (word self dm-cohort " in arrival before due " dm-next-event)]
      set dm-departure ticks
      set color violet
      move-to one-of patches with ["departure" = dm-zone]
    ]
    let lv-due-events (handlers-on lv-lane) with [(member? "event-" dm-cohort) and (dm-next-event <= ticks )]
    if bu-verify-mode? [show (word  rpt-display-cron   " DEBUG! "  count lv-due-events  " due events will run now  their lambda. ") ]
    ask lv-due-events [
      set dm-departure ticks
      move-to one-of patches with ["arrival" = dm-zone]
      set color green
      run lambda-event
    ]
    ask arcs [
      set thickness 1.0 - exp ( -1 *  dm-pheromone)
    ]
    update-plots
    tick-advance rpt-adv-cron
  ]  [eh-catch "observer" ticks "go" error-message  stop]  
end
;;
to eh-catch [#who #when #where #issue]
  show (word " -------------------  system interrupted by "  #who  " at tick " #when " where? " #where " -----------------------------------------------")
  ask one-of patches with ["arrival" = dm-zone] [
    sprout-handlers 1 [
      set dm-cohort ifelse-value (member? "HALT!" #issue) ["HALT!"] ["exch"]
      set shape ifelse-value (member? "HALT!" #issue) ["flag"] ["bug"]
      set dm-arrival #when
      set color ifelse-value (member? "HALT!" #issue) [blue] [violet]
      set size 2
      set dm-severity ifelse-value (member? "HALT!" #issue) ["warning!"]  ["PANIC!"]
      set label (word dm-severity " – "  #issue)
      watch-me
      show (word dm-cohort " – " dm-severity " message: " #issue)
    ]
  ]
end
;;
to eh-schedule-event [#tag #when  #lambda]
  ask one-of patches with ["FEL" = dm-zone] [
    sprout-handlers 1 [
      set dm-cohort (word "event-" #tag)
      set dm-arrival ticks
      set dm-next-event #when
      set color blue
      set size 1.5
      set dm-severity "info!"
      set label (word dm-cohort "@" precision dm-next-event 1)
      if not is-command-task? #lambda [error (word self dm-cohort " expected a lambda when scheduling event! found :" #lambda)]
      set lambda-event #lambda
    ]
  ]
end
;;
to eh-trigger-ants
  carefully [
    if not (is-a-handler? self  and member? "event-" dm-cohort)  [error (word self label " was expected to be an event handler!" ) ]
    if not any? ants [error (word "HALT!  there are no ants to continue exploring solutions!")]
    if bu-verify-mode? [show (word rpt-display-cron label " DEBUG! event lambda runs trigger event acceptor for ants.")]
    ifelse  0 < count ants with ["successful" != dm-cohort] [
      eh-schedule-event "trigger-ants" (2 + ticks) task [eh-trigger-ants ]
      ask ants [
        let k-prob-genchi-genbutsu 0.10
        if (rpt-roulette? k-prob-genchi-genbutsu) [mt-audit-city-of-ant self]
        set cn-lambda-invocations ( 1 + cn-lambda-invocations) 
        run lambda-andon
      ]
    ] [eh-schedule-event "trigger-halt" (1 + ticks) task [eh-trigger-halt ]]
  ]  [eh-catch self ticks "trigger event acceptor for ants" error-message ] 
end
;;
to eh-trigger-halt
  carefully [
    if not (is-a-handler? self  and member? "event-" dm-cohort)  [error (word self label " was expected to be an event handler!" ) ]
    ask ants with ["star" = shape] [set size 1]
    ask min-one-of ants [rpt-my-tour-distance]  [
      show (word label rpt-display-cron dm-cohort " info!  EUREKA: I am an OPTIMAL solution for this problem: " dm-tabu-list " total tour TSP distance:" rpt-my-tour-distance)
      foreach dm-tabu-list [
        show (word " --> " rpt-display-city ? " distance to next city: " rpt-distance-to-next-node ? )
      ]
      set label "*"
      set size 2
    ]
    error (word " HALT! order received!")
  ]  [eh-catch self ticks "trigger HALT! acceptor" error-message ] 
end
;;
to eh-trigger-evaporation [#mode]
  carefully [
    if not (is-boolean? #mode) [error (word #mode " expected boolean!")]
    if not (is-a-handler? self  and member? "event-" dm-cohort)  [error (word self label " was expected to be an event handler!" ) ]
    if bu-verify-mode? [show (word rpt-display-cron label " DEBUG! event lambda runs trigger event acceptor for ARCS.")]
    eh-schedule-event "trigger-ARCS" (2 + ticks)  task [eh-trigger-evaporation not #mode]
    ask arcs [ ifelse #mode [ mt-pheromone-evaporation] [set color yellow] ]
  ]  [eh-catch self ticks "trigger event acceptor for ARCS" error-message ] 
end
;;
to mt-pheromone-evaporation
  carefully [
    if not (is-an-arc? self)  [error (word self label " was expected to be an arc so to evaporate pheromone!" ) ]
    set dm-pheromone (1 - bu-rho) * dm-pheromone
    if bu-verify-mode? [show (word rpt-display-cron label " DEBUG! pheromone after evaporation: " dm-pheromone)]
    set color green
  ]  [eh-catch self ticks "arc evaporates pheromone" error-message ] 
end
;;
to pm-ant-failed-tour
  carefully [
    if not is-an-ant? self [error (word self label " is expected to be an ant!" ) ]
    set color red
    set cn-failed-ants (1 + cn-failed-ants)
    show (word rpt-display-cron rpt-display-self " warning! my tour " dm-tabu-list " has failed; there are some nodes not visited and no arcs to continue... total failed ants:" cn-failed-ants)
    die
  ]  [eh-catch self ticks "ant failed tour" error-message ] 
end
;;
to pm-ant-sucessful-tour
  carefully [
    if not is-an-ant? self [error (word self label " is expected to be an ant!" ) ]
    set color green
    set size 2
    set dm-cohort "successful"
    set shape "star"
    mt-deposit-pheromone  self
    set lambda-andon task []
    show (word rpt-display-cron rpt-display-self " info!  EUREKA: I have completed a TSP tour " dm-tabu-list " to visit all cities; distance: " rpt-my-tour-distance)
  ]  [eh-catch self ticks "ant successful tour" error-message ] 
end
;;
to pm-try-close-tour
  carefully [
    if not is-an-ant? self [error (word self label " is expected to be an ant!" ) ]
    set dm-last-arc rpt-arc  last dm-tabu-list first dm-tabu-list
    ifelse nobody = dm-last-arc [ set lambda-andon task [pm-ant-failed-tour] ]  
                                [ set lambda-andon task [pm-ant-sucessful-tour] ]
    set color green
  ]  [eh-catch self ticks "ant tries to close tour" error-message ] 
end
;;
to pm-check-tour
  carefully [
    if not is-an-ant? self [error (word self label " is expected to be an ant!" ) ]
    set color orange
    ifelse rpt-quasi-complete-tour? self [
      show (word rpt-display-cron rpt-display-self " info! my tour is  almost complete " dm-tabu-list "; just need to go back to origin.")
      set lambda-andon task [pm-try-close-tour]
    ] [
      set lambda-andon task [pm-ant-failed-tour]
    ]
  ]  [eh-catch self ticks "ant checks her tour complete?" error-message ] 
end
;;
to pm-arrival-at-city
  carefully [
    if not is-an-ant? self             [error (word self label " subject arriving at the end of one must must be an ANT!" ) ]
    set color blue
    set dm-tabu-list lput [dm-node] of (rpt-next-node-using-best-arc self) dm-tabu-list
    move-to one-of nodes with [last [dm-tabu-list] of myself = dm-node] 
    set lambda-andon task [pm-pheromone-trail]
    show (word rpt-display-cron rpt-display-self " info! ant arrival at " rpt-display-city patch-here " tabu list:"  dm-tabu-list " tour distance:" rpt-tour-distance self)
  ]  [eh-catch self ticks "ant arrives to node" error-message ] 
end
;;
to pm-visit-arc 
  carefully [
    if not is-an-ant? self             [error (word self label " subject of the arc visit  must be an ant!" ) ]
    set color green
    if ticks >= dm-departure [
      set lambda-andon task [pm-arrival-at-city]
    ]
  ]  [eh-catch self ticks "ant visiting arc" error-message ] 
end
;;
to pm-pheromone-trail
  carefully [
    if not is-an-ant? self [error (word self label " is expected to be an ant to update its pheromone trail!" ) ]
    set color yellow
    set dm-best-next-arc nobody
    let tb-my-next-arcs rpt-feasible-arcs-for  self
    ifelse  (empty? tb-my-next-arcs) [ 
      set lambda-andon task [pm-check-tour] 
      show (word rpt-display-cron rpt-display-self " info! no more feasible arcs found! my tabu: " dm-tabu-list " now ant will check if she can arrive to origin and get a full tour.")
    ] [
       set dm-best-next-arc rpt-select-arc tb-my-next-arcs
       set lambda-andon task [pm-visit-arc ]  set dm-departure (ticks + rpt-walk-duration dm-best-next-arc)
       show (word rpt-display-cron rpt-display-self " info! ant starts walking " rpt-display-arc dm-best-next-arc " and will arrive  next city at " dm-departure)
    ]
  ]  [watch-me set size 4 eh-catch self ticks "update ants pheromone trail" error-message ]  
end
;;
to  mt-deposit-pheromone [#ant]
  if not is-an-ant? #ant [error (word #ant " only ants can pour pheromome over arcs!")]
  ask #ant [
    let tb-arcs rpt-getter-tour #ant
    if not rpt-audit-are-arcs-connected? tb-arcs [error (word #ant " corrupted tour!  arcs " tb-arcs " do not make a chain." )]
    foreach tb-arcs [
      ask ? [ set dm-pheromone ((1 / rpt-tour-distance myself) + dm-pheromone)] 
    ]
    show (word rpt-display-cron rpt-display-self " info!  pour some pheromone on travelled arcs; overall pheromone level : " sum [dm-pheromone] of arcs)  
  ]
end
;;
to  mt-audit-city-of-ant [#ant]
  if not is-an-ant? #ant [error (word #ant " was expected to be an ant when randomly auditing that she is currently placed upon a city-node!")] 
  let lv-city rpt-current-city-of-ant #ant
  if nobody = lv-city [error (word #ant " violates the rule that she must be placed upon a city!")]
  if [dm-node] of lv-city != last [dm-tabu-list] of #ant [
    error (word #ant " tabu list " dm-tabu-list " last item should match node number " [dm-node] of lv-city " of the city " [label] of lv-city " where ant is now!")
  ]
  if bu-verify-mode? [show (word rpt-display-cron rpt-display-ant #ant " DEBUG!  pass AUDIT; placed upon node " rpt-display-city lv-city)]
end
;;
to mt-link [#destination #distance]
  if not is-a-city? #destination  [error (word #destination  label  " was expected to be a destination node!")]
  ask #destination [
    if bu-verify-mode? [show (word label  " DEBUG! distance " #distance " from node# " [label] of myself) ]
    if (k-unfeasible <= #distance)   [show (word label " Warning! this arc with " [label] of myself " is defined as non-feasible! Not created." )  stop]
    create-an-arc-with myself [
      set dm-distance #distance
      set dm-pheromone (1 / dm-distance)
      set label precision dm-distance 1 
    ]
  ] 
end
;;
to  mt-create-arcs [#nodes #arcs]
  if not is-a-city? self [error (word self label " was expected to be a node!")]
  let tb-destinations n-values dm-node [?] 
  if bu-verify-mode? [show (word label " DEBUG! creating arcs from node# " dm-node " with nodes " tb-destinations) ]
  foreach tb-destinations [
    let lv-destination one-of nodes with [dm-node = ?]
    let lv-distance ifelse-value  ("non-FAT" = bu-fat)  [ rpt-input (word " enter distance (or \"NA\" for no-arc) from " label " to node# " ?) task [rpt-valid-distance?] ]  [ (item ? #arcs)]                                                    
    mt-link lv-destination lv-distance
  ]
end
;;
to  mt-create-city [#index #nodes #arcs]
  if not is-list? #arcs  [error (word #arcs " is expected to be a list of distances between this city and its predecessors!")]
  if not is-list? #nodes [error (word #nodes " is expected to be a list of cities!")]
  if not (0 <= #index and #index <= length #nodes) [error (word #index " is an invalid subscriptor for " #nodes)]
  ask one-of patches with ["geography" = dm-zone] [
    sprout-nodes 1 [
      set dm-node #index
      set dm-cohort item #index #nodes
      set label (word dm-node ":" dm-cohort)
      set color lime
      if "?" =  label  [set label user-input "please enter city name"  ]
      if bu-verify-mode? [show (word  label " DEBUG! creating node " #index  "  of the city's network " #nodes "; distances to predecesors: " #arcs)]
      mt-create-arcs #nodes #arcs
    ]
    ask (patch-set self neighbors)  [set dm-zone "node" set pcolor orange]
  ]
end
;;
to mt-data-entry
  set k-unfeasible 1E20
  let tb-cities n-values (bu-num-cities)  ["?"]
  let tb-distance n-values (bu-num-cities)  [ (list ) ] 
  if bu-fat = "Wilson-p751" [
    set tb-cities ["NewYork" "Miami" "Dallas" "Chicago"]
    set bu-num-cities length tb-cities
    let lv-row1 (list 1334)
    let lv-row2 (list 1559 1343)
    let lv-row3 (list  809 1397 921)
    set tb-distance (list [] lv-row1 lv-row2 lv-row3)
  ]
  if bu-fat = "Dasgupta" [
    set tb-cities ["origin" "city1" "city2" "city3" "city4" "city5"]
    set bu-num-cities length tb-cities
    let lv-row1 (list 3)
    let lv-row2 (list 3 4)
    let lv-row3 (list k-unfeasible 5 3)
    let lv-row4 (list k-unfeasible 2 6 4 )
    let lv-row5 (list k-unfeasible k-unfeasible k-unfeasible 3 2 )
    set tb-distance (list [] lv-row1 lv-row2 lv-row3 lv-row4 lv-row5)
  ]
  if bu-fat = "—delta" [
    set tb-cities ["O" "A" "B" "C" ]
    set bu-num-cities length tb-cities
    let lv-row1 (list 10)
    let lv-row2 (list k-unfeasible 20)
    let lv-row3 (list k-unfeasible 30 40)
    set tb-distance (list [] lv-row1 lv-row2 lv-row3 )
  ]
  if bu-fat = "acid-TEST" [
    set tb-cities ["O" "A" "B" "C" "D" "E"]
    set bu-num-cities length tb-cities
    let lv-row1 (list 10)
    let lv-row2 (list 20 k-unfeasible)
    let lv-row3 (list 30 k-unfeasible k-unfeasible )
    let lv-row4 (list 40 k-unfeasible k-unfeasible k-unfeasible k-unfeasible )
    let lv-row5 (list 50 k-unfeasible k-unfeasible k-unfeasible k-unfeasible k-unfeasible )
    set tb-distance (list [] lv-row1 lv-row2 lv-row3 lv-row4 lv-row5)
  ]
  if bu-verify-mode? [show (word " DEBUG! now this list of cities: "  tb-cities  " will be created ...")]
  foreach n-values (bu-num-cities)  [?] [
    mt-create-city  ? tb-cities (item ? tb-distance)
  ]
end
;;
to mt-create-ant-on-node [#node]
  if (not is-a-city? #node)  [error (word #node " was expected to be a city when creating an ant upon it!")]
  ask #node [
    hatch-ants 1 [
      set dm-cohort [label] of myself
      set label ""
      set color blue
      set dm-tabu-list (list [dm-node] of myself) 
      set lambda-andon task [pm-pheromone-trail]
      set dm-last-arc nobody
      set dm-best-next-arc nobody
    ]
  ]
end
;;
to mt-tour-construction
  set cn-lambda-invocations 0 
  set cn-failed-ants 0
  foreach sort-on [dm-node] nodes [
     repeat bu-popsize-per-node [mt-create-ant-on-node ?]
  ]
end
;;
to mt-feedback-dataentry
  foreach sort-on [dm-node] nodes [
    ask ? [
      show (word label " info! city " dm-node " has " rpt-count-ants-on self  " ants on here;  and has connections to neighbor cities...")
      ask my-arcs [
        show (word  "     info! has a connection to " [label] of other-end " at distance " dm-distance)
      ]
    ]
    ask one-of ants-on ? [show (word label " info!  my starting node is " first dm-tabu-list  " and my partial tour is "  but-first dm-tabu-list )]
  ]
  show (word " info! ants will travel : "  rpt-velocity  " units of distance during each tick.")
end
;;
to mt-label-habitat
  ask patches with [member? dm-zone (list "geography" "node" )]  [set dm-zone ""]
  foreach remove-duplicates [dm-zone] of patches [
    ask one-of patches with [rpt-is-patch-inside-zone? ?] [set plabel dm-zone]
  ]
end
;;
to-report rpt-my-strength [#arc]
  report ([dm-pheromone] of #arc ^ bu-alpha) * ([dm-distance] of #arc ^ (-1 * bu-beta))
end
;;
to-report rpt-my-prob-arc [#arc]
  if nobody = #arc  [report 0.0]
  if not is-an-ant? self [error (word self " only ants can calculate probability of arcs in her neighbor!")]
  if not (member? #arc rpt-feasible-arcs-for self) [error (word #arc " only feasible arcs can be asked by an ant about probability!")]
  let ac-pheromone  sum map [rpt-my-strength ?]  (rpt-feasible-arcs-for self)
  let lv-prob rpt-my-strength #arc /  ifelse-value (0 < ac-pheromone) [ac-pheromone] [1.0]
  if not (0 <= lv-prob and lv-prob <= 1 ) [error (word self label " probability "  lv-prob " is out of range!")]
  report lv-prob
end
;;
to-report rpt-count-ants-on [#city]
  if not is-a-city? #city [error (word #city " was expected to be a node!" )]
  report count ants-on ([patch-here] of #city)
end
;;
to-report rpt-valid-distance?
   if not is-a-teller? self [error (word self " was expected to be a teller who takes care for this distance validation!")]
   if  ("NA" = dm-input) [set dm-input k-unfeasible]
   report rpt-positive-number?
end
;;
to-report rpt-positive-number? 
  if not is-a-teller? self [error (word self " was expected to be a teller who takes care for a positive number validation!")]
  if not ( (is-number? dm-input) and (0 < dm-input) ) [user-message (word dm-input  " should be a positive number!") report false]
  if k-unfeasible < dm-input [user-message (word dm-input  " too large! amended to upper bound.") set dm-input k-unfeasible]
  report true
end
;;
to-report rpt-is-string?
  report (is-string? dm-input)
end
;;
to-report rpt-input [#inquiry #is-valid?]
  if not is-reporter-task? #is-valid?  [error (word #is-valid? " was expected to be a reporter task to validate a data entry!")]  
  ask one-of patches with ["arrival" = dm-zone] [
    sprout-tellers 1 [
      set dm-cohort "teller"
      set label (word dm-cohort " : " #inquiry)
      set color red
      set dm-input read-from-string user-input #inquiry
      if (not runresult #is-valid?)  [die report rpt-input #inquiry #is-valid? ] 
      move-to one-of patches with ["departure" = dm-zone]
    ]
  ]
  report [dm-input] of one-of tellers with [(word dm-cohort " : " #inquiry) = label]
end
;;
to-report rpt-other-node [#node #arc]
  if (not is-a-city? #node)  [error (word #node " was expected to be a city when finding the other end of " #arc "!")]
  let lv-next-city nobody
  ask #node [
    if (not is-an-arc? #arc)   [error (word #arc " should be an arc when finding other node of " #node)]
    ask #arc [ set lv-next-city other-end ]
  ]
  report lv-next-city
end
;;
to-report rpt-next-node-using-best-arc [#ant]
  if not is-an-ant? #ant [error (word #ant  " is expected to be an ant when trying to move to next city!")]
  report rpt-other-node (rpt-current-city-of-ant #ant) [dm-best-next-arc] of #ant
end
;;
to-report rpt-my-current-city
  report rpt-current-city-of-ant self
end
;;
to-report rpt-current-city-of-ant [#ant]
  if not is-an-ant? #ant [error (word #ant  " is expected to be an ant, to determine the city in which she is now!")]
  report one-of nodes-on ([patch-here] of #ant)
end
;;
to-report rpt-quasi-complete-tour? [#ant]
  if not is-an-ant? #ant            [error  (word #ant " was expected to be an ant when asking whether her tour is ready to complete or not!")] 
  report (sort [dm-node] of nodes) = (sort [dm-tabu-list] of #ant)
end
;;
to-report rpt-make-chain? [#arc1 #arc2]
  if (not is-an-arc? #arc1) or (not is-an-arc? #arc2) [error (word #arc1 #arc2  " were both expected to be arcs to check if they are inter-connected!")] 
  let tb-nodes []
  foreach  (list #arc1 #arc2) [
    set tb-nodes fput [end2] of ? tb-nodes
    set tb-nodes fput [end1] of ? tb-nodes
  ]
  if (4 !=  length tb-nodes) [error (word #arc1 #arc2 " together they must have 4 nodes!  but got  " length tb-nodes )] 
  let tb-trajectory remove-duplicates tb-nodes
  report (length tb-trajectory < length tb-nodes)
end
;;
to-report rpt-audit-are-arcs-connected? [#arcs]
  if not is-list? #arcs [error (word #arcs " expected to be a list of arcs, when checking if they are connected as in a chain!")]
  if (length #arcs <= 1) [report true]
  report reduce [?1 and ?2 ] (map [rpt-make-chain? ?1 ?2]  but-last #arcs but-first #arcs)
end
;;
to-report rpt-getter-tour [#ant]
  if not is-an-ant? #ant            [error  (word #ant " was expected to be an ant when asking to display her tour!")] 
  let tb-arcs []
  ask #ant [
    set tb-arcs  (map [rpt-arc ?1 ?2]  but-last dm-tabu-list but-first dm-tabu-list)
  ]
  report tb-arcs
end
;;
to-report rpt-is-tabu? [#node #list]
   if (not is-a-city? #node)  [error (word #node " was expected to be a city when checking in a tabu list!")]
   if not (is-list? #list)    [error (word #list " was expected to be a tabu list of nodes.")]
   let sw-member? false
   ask #node [
     set sw-member? (member? dm-node #list)
     if (bu-verify-mode? and rpt-roulette? 0.01) [show (word rpt-display-city #node  " sample DEBUG!  in tabu list " #list  " ? " sw-member?  )] 
   ]
   report sw-member?
end
;;
to-report rpt-neighbors [#ant]
  if not (is-an-ant? #ant)   [error (word #ant  " argument should be an ant to report its arcs connected to her current node!")]
  report arcs with [member? (rpt-current-city-of-ant #ant) both-ends]
end
;;
to-report rpt-acum-prob-arcs [#list]
  let ac-prob 0.0
  foreach #list [
    if not (is-an-arc? ?)   [error (word ? " was expected to be an arc when calculating acum prob of a list of arcs!")]  
    set ac-prob (rpt-my-prob-arc ?) + ac-prob
  ] 
  report ac-prob
end
;;
to-report rpt-select-arc [#list]
  if not (is-an-ant? self)   [error (word self  " was expected to be an ant selecting her next node to visit!")]
  let lv-roulette random-float (rpt-acum-prob-arcs #list)
  if (bu-verify-mode? and rpt-roulette? 0.10)  [show (word rpt-display-cron rpt-display-self " sample DEBUG! selecting next arc, using roulette: " lv-roulette " arcs:" length #list) ]
  let ac-prob 0.0
  foreach #list [
    set ac-prob (rpt-my-prob-arc ?) + ac-prob
    if lv-roulette <= ac-prob [
      if bu-verify-mode? [ show (word rpt-display-cron rpt-display-self  " DEBUG! ant selects arc "  rpt-display-arc ?  " roulette:" lv-roulette " acum arcs prob:"  ac-prob ) ]
      report ?
    ]
  ]
  error (word self " fails selecting  among  the list of feasible arcs: " #list)
end
;;
to-report rpt-feasible-arcs-for  [#ant]
  let lv-feasible-arcs []
  if not (is-an-ant? #ant)  [error (word #ant  " is expected to be an ant when filtering feasible next arcs in her tour!")]
  ask rpt-my-current-city [
    ask   rpt-neighbors #ant [ 
      if not (rpt-is-tabu? other-end [dm-tabu-list] of #ant) [ set lv-feasible-arcs lput self lv-feasible-arcs]
    ]
  ]
  if (bu-verify-mode? and rpt-roulette? 0.05) [
    show (word  rpt-display-cron rpt-display-self " sample DEBUG! finished gathering my feasible arcs " lv-feasible-arcs  " using tabu list " dm-tabu-list)
  ]
  report lv-feasible-arcs
end
;;
to-report rpt-velocity
  report min [dm-distance] of arcs
end
;;
to-report rpt-walk-duration [#arc]
  if not is-an-arc? #arc [error (word #arc " was expected to be an arc in order to calculate walk duration at standarized speed!")]
  report ceiling (rpt-distance #arc / rpt-velocity)
end
;;
to-report rpt-arc [#node-a #node-b]
  let tb-nodes map [one-of nodes with [? = dm-node] ]  (list #node-a #node-b)
  foreach tb-nodes [
    if (nobody = ?)  [show  (word " warning! "  ? " is expected to match a node # when looking for an arc between " #node-a " and " #node-b "!")  report nobody]
  ]
  report  reduce [one-of arcs with [(member? ?1 both-ends) and (member? ?2 both-ends)]] tb-nodes 
end
;;
to-report rpt-distance-to-next-node [#node]
  if not is-an-ant? self [error (word self " expected to be an ant to calculate distance to next node of " #node)]
  let lv-pos position #node dm-tabu-list
  let lv-next-pos (1 + lv-pos) mod (length dm-tabu-list)
  report rpt-distance-between #node item lv-next-pos dm-tabu-list
end
;;
to-report rpt-distance-between [#node-a #node-b]
  report rpt-distance (rpt-arc #node-a #node-b)
end
;;
to-report rpt-distance [#arc]
  if #arc = nobody [report 0.0]
  if not (is-an-arc? #arc)  [error (word #arc " is expected to be an arc so to ask about its distance!")]
  report [dm-distance] of #arc
end
;;
to-report rpt-tour-distance [#ant]
  if not (is-an-ant? #ant) [error (word #ant " is expected to be an ant so to calculate the tour distance already travelled (my tabu list)!")]
  if empty? [dm-tabu-list] of #ant [report 0.0]
  let tb-distances (map  [rpt-distance-between ?1 ?2 ]  but-last [dm-tabu-list] of #ant   but-first [dm-tabu-list] of #ant )
  report sum tb-distances
end
;;
to-report rpt-my-tour-distance
  report rpt-distance dm-last-arc + rpt-tour-distance self
end
;;
to-report rpt-full-network-list
  let tb-node [dm-node] of nodes
  report sort tb-node
end
;;
to-report rpt-is-patch-inside-zone? [#where]
  if not (is-patch? self) [error (word self " was expected to be a patch!")]
  let tb-zones-around  fput dm-zone [dm-zone] of neighbors
  report reduce [?1 and (#where = ?2)] (fput true tb-zones-around )
end
;;
to-report rpt-roulette? [#prob]
  report (random-float 1 < #prob)
end
;;
to-report rpt-adv-cron
  let lv-lane patches with ["FEL" = dm-zone]
  let lv-candidates (handlers-on lv-lane) with [member? "event-" dm-cohort]
  if not (any? lv-candidates) [error (word lv-candidates " Future Event List should not be empty!")]
  let lv-next-due min [dm-next-event] of lv-candidates
  if not (ticks < lv-next-due) [error (word " cron can only move forward! next event scheduled at " lv-next-due)]
  report lv-next-due - ticks
end
;;
to-report rpt-display-city [#node]
  if is-number? #node [report rpt-display-city one-of nodes with [#node = dm-node] ]
  if is-an-ant? #node [report rpt-display-city (rpt-current-city-of-ant #node)]
  if is-patch? #node  [report rpt-display-city one-of nodes-on #node ]
  if (not is-a-city? #node)  [error (word #node " was expected to be a city when displaying node ID!")]
  report (word " "   [label] of #node " ")
end
;;
to-report rpt-display-ant [#ant]
  if not is-an-ant? #ant [error (word #ant " was expected to be an ant when asking to display her ID!")] 
  report (word " origin " first [dm-tabu-list] of #ant ":"  [label] of #ant ", ")  
end
;;
to-report rpt-display-arc [#arc]
  if nobody = #arc [report "nobody"]
  if not is-an-arc? #arc [error (word #arc " expected to be an arc when asking to display its ID!")]
  report (word " arc between " rpt-display-city [end1] of #arc  " and " rpt-display-city [end2] of #arc ", ")
end
;;
to-report rpt-display-self
  if  is-an-ant? self [report  rpt-display-ant  self]
  if  is-an-arc? self [report  rpt-display-arc  self]
  if  is-a-city? self [report  rpt-display-city self] 
end
;;
to-report rpt-display-cron
  report (word " CRON " precision ticks 1 ", ")
end
;;
@#$#@#$#@
GRAPHICS-WINDOW
210
10
649
470
16
16
13.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
19
25
89
58
set up
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
22
76
85
109
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
107
74
170
107
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SWITCH
22
121
184
154
bu-verify-mode?
bu-verify-mode?
1
1
-1000

CHOOSER
23
167
161
212
bu-fat
bu-fat
"non-FAT" "Wilson-p751" "Dasgupta" "—delta" "acid-TEST"
2

SLIDER
23
230
195
263
bu-num-cities
bu-num-cities
2
10
6
1
1
NIL
HORIZONTAL

SLIDER
8
277
201
310
bu-popsize-per-node
bu-popsize-per-node
10
100
10
10
1
ants
HORIZONTAL

SLIDER
21
324
193
357
bu-alpha
bu-alpha
0
1.0
0.6
0.1
1
NIL
HORIZONTAL

SLIDER
27
378
199
411
bu-beta
bu-beta
0
1.00
0.4
0.1
1
NIL
HORIZONTAL

MONITOR
673
25
755
70
# ants alive
count ants
0
1
11

MONITOR
772
87
865
132
# exceptions
count handlers with [member? \"exch\" dm-cohort]
0
1
11

MONITOR
776
149
879
194
# dead events
count (handlers-on patches with [\"departure\" = dm-zone]) with [member? \"event-\" dm-cohort]
0
1
11

MONITOR
669
149
765
194
# total events
count handlers with [member? \"event-\" dm-cohort]
0
1
11

MONITOR
898
147
993
192
# due events 
count (handlers-on patches with [\"arrival\" = dm-zone]) with [member? \"event-\" dm-cohort]
0
1
11

MONITOR
1015
145
1111
190
# alive events
count (handlers-on patches with [\"FEL\" = dm-zone]) with [member? \"event-\" dm-cohort]
0
1
11

MONITOR
672
89
751
134
# handlers
count handlers
0
1
11

MONITOR
773
23
864
68
# arcs
count arcs
0
1
11

MONITOR
890
22
973
67
# cities
count nodes
0
1
11

TEXTBOX
899
84
1156
135
TSP (travel salesperson problem) \nPlease read 'INFO' tab ...
14
122.0
1

SLIDER
26
425
198
458
bu-rho
bu-rho
0.1
0.9
0.3
0.1
1
NIL
HORIZONTAL

MONITOR
1008
21
1111
74
# failed ants
cn-failed-ants
0
1
13

MONITOR
672
213
854
258
computational effort metric
cn-lambda-invocations
0
1
11

MONITOR
675
277
830
322
minimal travel distance
min [rpt-my-tour-distance] of ants with [\"star\" = shape]
1
1
11

MONITOR
674
338
837
383
Best (min distance) Tour
[dm-tabu-list] of min-one-of (ants with [\"star\" = shape and \"*\" = label]) [rpt-my-tour-distance]
0
1
11

PLOT
874
210
1354
437
time-series
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"ants" 1.0 0 -16777216 true "" "plot count ants"
"solutions" 1.0 0 -13840069 true "" "plot count ants with [\"star\" = shape]"

@#$#@#$#@
## WHAT IS IT?

The TSP (travel salesperson problem) is extensively studied in literature  and has attracted since a long time a considerable amount of research effort. The TSP also plays an important role in Ant Colony Optimization.

Intuitively, the TSP is the problem of a salesman who wants to find, starting
from his home town, a shortest possible trip through a given set of customer
cities and to return to its home town. 

TRAVELLING SALESPERSON is classified in NP category of problems, since a permutation of
the cities is a certificate that can be verified.

A Hamiltonian cycle of an undirected graph is a cycle that visits every
vertex exactly once (aka tour).

This is a 739 LOC  (lines of code) model  using ACO approach to solve TSP.

## HOW IT WORKS

In ACO algorithms ants are simple agents which, in the TSP case, construct
tours by moving from city to city on the problem graph. The ants' solu-
tion construction is guided by (artificial) pheromone trails and an a priori
available heuristic information.

Initially, each of the m ants is placed on a randomly chosen city and then iteratively applies at each city a state transition rule. 

At a city i, the ant chooses a still unvisited city j probabilistically, biased by the pheromone trail strength τij (t) on the arc between city i and city j and a locally available heuristic information, which is a function of the arc length.

Ants probabilistically prefer cities which are close and are connected by arcs with a high pheromone trail strength. To construct a feasible solution each ant has a limited form of memory, called tabu list, in which the current partial tour is stored. The memory is used to determine at each construction step the set of cities which still has to be visited and to guarantee that a feasible solution is built. Additionally, it allows the ant to retrace its tour, once it is completed.

After all ants have constructed a tour, the pheromones are updated. This is typically done by first lowering the pheromone trail strengths by a constant factor and then the ants are allowed to deposit pheromone on the arcs they have visited. The trail update is done in such a form that arcs contained in shorter tours and/or visited by many ants receive a higher amount of pheromone and are therefore chosen with a higher probability in the following iterations of the algorithm. In this sense the amount of pheromone τij(t) represents the learned desirability of choosing next city j when an ant is at city i.

Termination condition  may be a certain number of solution constructions or a given CPU-time limit.

## HOW TO USE IT

Before pressing SETUP button, use the bu-fat  control to select  if you want to run a FAT (factory acceptance test)  or to define your own problem.

Use the bu-verify-mode?  control to  stablish if you want a verbose or a silent log in the command center.

Parametrization:

bu-alpha ... if α = 0, the closest cities are more likely to be selected: this corresponds to a classical stochastic greedy algorithm.

bu-beta  ... if β = 0, only pheromone amplification is at work: this method will lead to the rapid emergence of a stagnation situation with the corresponding generation of tours which, in general, are strongly suboptimal.

bu-rho  ... where 0 < ρ ≤ 1 is the pheromone trail evaporation; the parameter ρ is used
to avoid unlimited accumulation of the pheromone trails and it enables the
algorithm to “forget” previously done bad decisions.

## THINGS TO NOTICE

Be aware that the graph that represents the problem is not done at scale!
Distances are displayed in the arcs between cities.
Ants shape is taken form the avaialable default shapes galery.
Computational effort count the number of blocks run.
Be aware that no validation about graph arcs lenght is done (e.g. the traingular inequality)

## THINGS TO TRY

Experiment with different population sizes of ants, with different parameter settings.  You may use the design of experiments techniques, with orthogonal arrays, to reduce the experimental effort, and raise conclusions about main effects and interaction among parameters of the design space.

## EXTENDING THE MODEL

Read the advanced literature about ACO (ant colony optimization) heuristics, and modify ant rules of behavior to compare the required computational effort to solve different FAT (factory acceptance test) problems.

Add your own FAT test  and verify the model  obtains optimnal solutions. Add graphs that have no feasible solutions. Verify if the system handles properly the absence of solutions.

Create a very large problem to check system performance. Does it degrade over time?

## NETLOGO FEATURES

There are many interesting points to highlight about the construction of such a model:

Managing exceptions.
Continuous embedded control.
Use of recursivity.
Use of lambda concept implemented via  run task.

Target quality characteristics:

TEST DRIVEN DEVELOPMENT (FAT factory acceptance test)
Realize that the system has embedded some FAT tests, appart from, naturally, the option to create your own TSP specification and run it.

ROBUST ENGINEERING PRINCIPLES
Preventive defence against modes of failure. Upstream controls checking inputs and assumptions rather than outputs of the blocks of code.
Deep encapsulation, aiming for the minimum required variety to manage complexity.

DESIGN ORIENTED TO HIGH LEVEL OF SLA  (service level agreement)

Permanently debugging mode available so to reproduce an error and gather details for problem statement and system diagnosis.
Embedded documentation. 

VISUAL MANAGEMENT ORIENTATION
visors, basic statistics and general system feedback not only for the expected outcome, (what the system must do),  but also information to make judgements about system behavior.


## RELATED MODELS

It is strongly recommended to explore the NetLogo Models Library, as well as the NetLogo User Community Models website.

## CREDITS AND REFERENCES

(1) for ant colony optimization algorithms (ACO)
http://staff.washington.edu/paymana/swarm/stutzle99-eaecs.pdf

(2) for a discussion on NP-complete problems
http://www.cs.berkeley.edu/~vazirani/algorithms/chap8.pdf

(3) A branch-and-bound algorithm for TSP
http://dspace.mit.edu/bitstream/handle/1721.1/46828/algorithmfortrav00litt.pdf

(4) For a lecture about NP-hard problems
http://www.cs.uiuc.edu/~jeffe/teaching/algorithms/notes/21-nphard.pdf

(5)  This paper introduces the R package TSP which provides a basic infrastructure for handling and solving the traveling salesperson problem.
http://cran.wustl.edu/web/packages/TSP/vignettes/TSP.pdf

(6) A PowerPoint presentation about TSP.
www.ms.unimelb.edu.au/~s620261/powerpoint/chapter9_4.ppt‎


Author:  Jose Costas
         Sep 2013
         josegual@esce.ipvc.pt
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
