###
### tacgame.tcl: part of Scid.
### Copyright (C) 2006  Pascal Georges
###

namespace eval tacgame {
  ######################################################################
  ### Tacgame window: uses a chess engine (Phalanx) in easy mode and
  ### another engine (for example Crafty) to track blunders
  
  #   The maximum number of log message lines to be saved in a log file.
  set analysisCoach(logMax) 500
  
  # analysisCoach(log_stdout):
  #   Set this to 1 if you want Scid-Engine communication log messages
  #   to be echoed to stdout.
  set analysisCoach(log_stdout) 0
  
  set startFromCurrent 0
  
  set level 1500
  set randomLevel 0
  set levelMin 1200
  set levelMax 2200
  
  # default value for considering the engine (Phalanx) blundering
  set threshold 0.9
  set resignCount 0
  
  # if true, follow a specific opening
  set isOpening 0
  set chosenOpening ""
  set openingMovesList {}
  set openingMovesHash {}
  set openingMoves ""
  set outOfOpening 0
  
  # list of fen positions played to detect 3 fold repetition
  set lFen {}
  
  set index1 0
  set index2 0
  
  set lastblundervalue 0.0
  set prev_lastblundervalue 0.0
  set blundermissed false
  set blunderwarning false
  set blunderwarningvalue 0.0
  set blundermissedvalue 0.0
  
  set blunderWarningLabel $::tr(Noblunder)
  set scoreLabel 0.0
  
  set blunderpending 0
  set prev_blunderpending 0
  set showblunder 1
  set showblundervalue 1
  set showblunderfound 1
  set showmovevalue 1
  set showevaluation 1
  set isLimitedAnalysisTime 1
  set analysisTime 10
  set currentPosHash 0
  set lscore {}
  
  set analysisCoach(automove1) 0
  
  # ======================================================================
  # resetValues
  #   Resets all blunders data.
  # ======================================================================
  proc resetValues {} {
    set ::tacgame::level 1500
    set ::tacgame::threshold 0.9
    set ::tacgame::blundermissed false
    set ::tacgame::blunderwarning false
    set ::tacgame::blunderwarningvalue 0.0
    set ::tacgame::lastblundervalue 0.0
    set ::tacgame::prev_lastblundervalue 0.0
    set ::tacgame::prev_blunderpending 0
    set ::tacgame::currentPosHash [sc_pos hash]
    set ::tacgame::lscore {}
    set ::tacgame::resignCount 0
  }
  
  # ======================================================================
  # resetEngine:
  #   Resets all engine-specific data.
  # ======================================================================
  proc resetEngine {n} {
    
    global ::tacgame::analysisCoach
    set analysisCoach(pipe$n) ""             ;# Communication pipe file channel
    set analysisCoach(seen$n) 0              ;# Seen any output from engine yet?
    set analysisCoach(seenEval$n) 0          ;# Seen evaluation line yet?
    set analysisCoach(score$n) 0             ;# Current score in centipawns
    set analysisCoach(moves$n) ""            ;# PV (best line) output from engine
    set analysisCoach(movelist$n) {}         ;# Moves to reach current position
    set analysisCoach(nonStdStart$n) 0       ;# Game has non-standard start
    set analysisCoach(has_analyze$n) 0       ;# Engine has analyze command
    set analysisCoach(has_setboard$n) 0      ;# Engine has setboard command
    set analysisCoach(send_sigint$n) 0       ;# Engine wants INT signal
    set analysisCoach(wants_usermove$n) 0    ;# Engine wants "usermove" before moves
    set analysisCoach(isCrafty$n) 0          ;# Engine appears to be Crafty
    set analysisCoach(wholeSeconds$n) 0      ;# Engine times in seconds not centisec
    set analysisCoach(analyzeMode$n) 0       ;# Scid has started analyze mode
    set analysisCoach(invertScore$n) 1       ;# Score is for side to move, not white
    set analysisCoach(automove$n) 0
    set analysisCoach(automoveThinking$n) 0
    set analysisCoach(automoveTime$n) 2000
    set analysisCoach(lastClicks$n) 0
    set analysisCoach(after$n) ""
    set analysisCoach(log$n) ""              ;# Log file channel
    set analysisCoach(logCount$n) 0          ;# Number of lines sent to log file
    set analysisCoach(wbEngineDetected$n) 0  ;# Is this a special Winboard engine?
  }
  
  # ======================================================================
  #		::tacgame::config
  #   Configure coach games :
  #			- Phalanx engine (because it has an 'easy' option)
  #			- Coach engine (Crafty is the best)
  #			- level of difficulty
  # ======================================================================
  proc config {} {
    
    global ::tacgame::configWin ::tacgame::analysisCoachCommand ::tacgame::analysisCoach \
        engineCoach1 engineCoach2 ::tacgame::level \
        ::tacgame::isLimitedAnalysisTime ::tacgame::analysisTime ::tacgame::index1 ::tacgame::index2 ::tacgame::chosenOpening
    
    # check if game window is already opened. If yes abort previous game
    set w ".coachWin"
    if {[winfo exists $w]} {
      focus .
      destroy $w
    }
    
    # find Phalanx and Crafty engines
    set i 0
    set index1 -1
    set index2 -1
    foreach e $::engines(list) {
      if { $index1 != -1 && $index2 != -1 } { break }
      set name [lindex $e 0]
      if { [ string match -nocase "*phalanx*" $name ]  } {
        set engineCoach1 $name
        set index1 $i
      }
      if { [ string match -nocase "*crafty*" $name ]  } {
        set engineCoach2 $name
        set index2 $i
      }
      incr i
    }
    
    # could not find Crafty or Phalanx
    if { $index1 == -1 || $index2 == -1 } {
      tk_messageBox -title "Scid" -icon warning -type ok -message $::tr(PhalanxOrCraftyMissing)
      return
    }
    
    set w ".configWin"
    if {[winfo exists $w]} {
      focus $w
      # wm attributes $w -topmost
      return
    }
    
    toplevel $w
    wm title $w "$::tr(configurecoachgame)"
    
    bind $w <F1> { helpWindow TacticalGame }
    setWinLocation $w
    
    frame $w.fexplanation
    frame $w.fengines -relief groove -borderwidth 1
    frame $w.flevel1 -relief groove -borderwidth 1
    frame $w.flevel2 -relief groove -borderwidth 1
    frame $w.fcurrent -relief groove -borderwidth 1
    frame $w.fopening -relief groove -borderwidth 1
    frame $w.flimit -relief groove -borderwidth 1
    frame $w.fbuttons
    
    pack $w.flevel1 $w.flevel2 -side top -fill x
    pack $w.fcurrent -side top -fill x
    pack $w.fopening  -side top -fill both -expand 1
    pack $w.flimit $w.fbuttons -side top -fill x
    
    checkbutton $w.flevel1.cbLevelRandom -text $::tr(RandomLevel) -variable ::tacgame::randomLevel
    scale $w.flevel1.lMin -orient horizontal -from 1200 -to 2200 -length 100 -variable ::tacgame::levelMin -tickinterval 0 -resolution 50
    scale $w.flevel1.lMax -orient horizontal -from 1200 -to 2200 -length 100 -variable ::tacgame::levelMax -tickinterval 0 -resolution 50
    pack $w.flevel1.cbLevelRandom -side top
    pack $w.flevel1.lMin $w.flevel1.lMax -side left -expand 1
    
    scale $w.flevel2.difficulty -orient horizontal -from 1200 -to 2200 -length 200 -label $::tr(difficulty)	\
        -variable ::tacgame::level -tickinterval 0 -resolution 50
    label $w.flevel2.easy -font font_Fixed -text $::tr(easy)
    label $w.flevel2.hard -font font_Fixed -text $::tr(hard)
    pack $w.flevel2.easy $w.flevel2.difficulty $w.flevel2.hard -side left -expand yes
    
    # New game or use current position ?
    checkbutton $w.fcurrent.cbPosition -text $::tr(StartFromCurrentPosition) -variable ::tacgame::startFromCurrent
    pack $w.fcurrent.cbPosition
    
    # choose a specific opening
    checkbutton $w.fopening.cbOpening -text $::tr(SpecificOpening) -variable ::tacgame::isOpening
    frame $w.fopening.fOpeningList -relief raised -borderwidth 1
    listbox $w.fopening.fOpeningList.lbOpening -yscrollcommand "$w.fopening.fOpeningList.ybar set" \
        -height 5 -width 50 -list ::tacgame::openingList
    $w.fopening.fOpeningList.lbOpening selection set 0
    scrollbar $w.fopening.fOpeningList.ybar -command "$w.fopening.fOpeningList.lbOpening yview"
    pack $w.fopening.fOpeningList.lbOpening -side right -fill both -expand 1
    pack $w.fopening.fOpeningList.ybar  -side right -fill y
    pack $w.fopening.cbOpening -fill x -side top
    pack $w.fopening.fOpeningList -expand yes -fill both -side top -expand 1
    
    # in order to limit CPU usage, limit the time for analysis (this prevents noise on laptops)
    checkbutton $w.flimit.blimit -text $::tr(limitanalysis) -variable ::tacgame::isLimitedAnalysisTime -relief flat
    scale $w.flimit.analysisTime -orient horizontal -from 5 -to 60 -length 200 -label $::tr(seconds) -variable ::tacgame::analysisTime -resolution 5
    pack $w.flimit.blimit $w.flimit.analysisTime -side left -expand yes
    
    button $w.fbuttons.close -text $::tr(Play) -command {
      focus .
      set ::tacgame::chosenOpening [.configWin.fopening.fOpeningList.lbOpening curselection]
      destroy .configWin
      ::tacgame::play
    }
    button $w.fbuttons.cancel -textvar ::tr(Cancel) -command "focus .; destroy $w"
    
    pack $w.fbuttons.close $w.fbuttons.cancel -expand yes -side left -padx 20 -pady 2
    
    bind $w <Escape> { .configWin.fbuttons.cancel invoke }
    bind $w <Return> { .configWin.fbuttons.close invoke }
    bind $w <F1> { helpWindow TacticalGame }
    bind $w <Destroy> ""
    bind $w <Configure> "recordWinSize $w"
    wm minsize $w 45 0
  }
  # ======================================================================
  #
  #	::tacgame::play
  #
  # ======================================================================
  proc play { } {
    global ::tacgame::analysisCoach ::tacgame::threshold ::tacgame::showblunder ::tacgame::showblundervalue \
        ::tacgame::blunderfound ::tacgame::showmovevalue ::tacgame::level engineCoach1 \
        engineCoach2 ::tacgame::index1 ::tacgame::index2 ::tacgame::chosenOpening \
        ::tacgame::isOpening ::tacgame::openingList ::tacgame::openingMovesList \
        ::tacgame::openingMovesHash ::tacgame::openingMoves ::tacgame::outOfOpening
    
    resetEngine 1
    resetEngine 2
    set ::tacgame::lFen {}
    
    if {$::tacgame::startFromCurrent} {
      set isOpening 0
    }
    
    if {$::tacgame::randomLevel} {
      if {$::tacgame::levelMax < $::tacgame::levelMin} {
        set tmp $::tacgame::levelMax
        set ::tacgame::levelMax $::tacgame::levelMin
        set ::tacgame::levelMin $tmp
      }
      set level [expr int(rand()*($::tacgame::levelMax - $::tacgame::levelMin)) + $::tacgame::levelMin ]
    }
    
    # if will follow a specific opening line
    if {$isOpening} {
      set fields [split [lindex $openingList $chosenOpening] ":"]
      set openingName [lindex $fields 0]
      set openingMoves [string trim [lindex $fields 1]]
      set openingMovesList ""
      set openingMovesHash ""
      set outOfOpening 0
      foreach m [split $openingMoves] {
        # in case of multiple adjacent spaces in opening line
        if {$m =={}} {
          continue
        }
        set n [string trim $m]
        lappend openingMovesList [string trim [regsub {^[1-9]+\.} $m ""] ]
      }
      
      sc_game new
      lappend openingMovesHash [sc_pos hash]
      foreach m  $openingMovesList {
        if {[catch {sc_move addSan $m}]} {
          ::tacgame::logEngine 1 "Error in opening line $m"
        }
        lappend openingMovesHash [sc_pos hash]
      }
    }
    
    # create a new game if a DB is opened
    if {!$::tacgame::startFromCurrent} {
      sc_game new
      sc_game tags set -event "Tactical game"
      if { [::board::isFlipped .board] } {
        sc_game tags set -white "Phalanx - $level ELO"
      } else  {
        sc_game tags set -black "Phalanx - $level ELO"
      }
      sc_game tags set -date [::utils::date::today]
      if {[sc_base inUse [sc_base current]]} { catch {sc_game save 0}  }
    }
    
    updateBoard -pgn
    ::windows::gamelist::Refresh
    updateTitle
    updateMenuStates
    
    set w ".coachWin"
    if {[winfo exists $w]} {
      focus .
      destroy $w
      return
    }
    
    toplevel $w
    wm title $w "$::tr(coachgame) (Elo $level)"
    setWinLocation $w
    
    frame $w.fdisplay -relief groove -borderwidth 1
    frame $w.fthreshold -relief groove -borderwidth 1
    frame $w.finformations -relief groove -borderwidth 1
    frame $w.fclocks -relief raised -borderwidth 2
    frame $w.fbuttons
    pack $w.fdisplay $w.fthreshold $w.finformations $w.fclocks $w.fbuttons -side top -expand yes -fill both
    
    checkbutton $w.fdisplay.b1 -text $::tr(showblunderexists) -variable ::tacgame::showblunder -relief flat
    checkbutton $w.fdisplay.b2 -text $::tr(showblundervalue) -variable ::tacgame::showblundervalue -relief flat
    checkbutton $w.fdisplay.b5 -text $::tr(showscore) -variable ::tacgame::showevaluation -relief flat
    pack $w.fdisplay.b1 $w.fdisplay.b2 $w.fdisplay.b5 -expand yes -anchor w
    
    label $w.fthreshold.l -text $::tr(moveblunderthreshold) -wraplength 300 -font font_Fixed
    scale $w.fthreshold.t -orient horizontal -from 0.0 -to 10.0 -length 200 \
        -variable ::tacgame::threshold -resolution 0.1 -tickinterval 2.0
    pack $w.fthreshold.l $w.fthreshold.t -side top
    
    label $w.finformations.l1 -textvariable ::tacgame::blunderWarningLabel -bg linen
    label $w.finformations.l3 -textvariable ::tacgame::scoreLabel -fg WhiteSmoke -bg SlateGray
    pack $w.finformations.l1 $w.finformations.l3 -padx 5 -pady 5 -side top -fill x
    
    ::gameclock::new $w.fclocks 2 80
    ::gameclock::new $w.fclocks 1 80
    ::gameclock::reset 1
    ::gameclock::start 1
    
    button $w.fbuttons.close -textvar ::tr(Abort) -command ::tacgame::abortGame
    pack $w.fbuttons.close -expand yes -fill both -padx 20 -pady 2
    
    ::tacgame::launchengine $index1 1
    ::tacgame::launchengine $index2 2
    ::tacgame::resetValues
    updateAnalysisText
    
    bind $w <F1> { helpWindow TacticalGame }
    bind $w <Destroy> "after cancel ::tacgame::phalanxGo ; focus . ; \
        ::tacgame::closeEngine 1; ::tacgame::closeEngine 2"
    bind $w <Escape> ::tacgame::abortGame
    bind $w <Configure> "recordWinSize $w"
    wm minsize $w 45 0
    
    # Phalanx engine plays by itself but make sure first that analysis engine is started
    while {!$analysisCoach(has_analyze2) } {
      update
      after 200
    }
    ::tacgame::phalanxGo
  }
  ################################################################################
  #
  ################################################################################
  proc abortGame { { destroyWin 1 } } {
    after cancel ::tacgame::phalanxGo
    if { $destroyWin } { destroy ".coachWin" }
    focus .
    ::tacgame::closeEngine 1
    ::tacgame::closeEngine 2
  }
  # ======================================================================
  #   ::tacgame::launchengine
  #  - launches both engines
  #  - updates values for :
  #						blundermissed (boolean), blunderwarning (boolean)
  #						blunderwarningvalue (real), blundermissedvalue (real)
  #						totalblundersmissed (real), totalblunders (real)
  # ======================================================================
  proc launchengine {index n} {
    global ::tacgame::analysisCoach ::tacgame::level
    
    ::tacgame::resetEngine $n
    
    set engineData [lindex $::engines(list) $index]
    set analysisName [lindex $engineData 0]
    set analysisCommand [ ::toAbsPath [ lindex $engineData 1 ] ]
    set analysisArgs [lindex $engineData 2]
    set analysisDir [ ::toAbsPath [lindex $engineData 3] ]
    
    # turn phalanx book, ponder and learning off, easy on
    if {$n == 1} {
      # convert Elo = 1200 to level 100 up to Elo=2200 to level 0
      set easylevel [expr int(100-(100*($level-1200)/(2200-1200)))]
      append analysisArgs " -b+ -p- -l- -e $easylevel "
    }
    
    # If the analysis directory is not current dir, cd to it:
    set oldpwd ""
    if {$analysisDir != "."} {
      set oldpwd [pwd]
      catch {cd $analysisDir}
    }
    
    # Try to execute the analysis program:
    if {[catch {set analysisCoach(pipe$n) [open "| [list $analysisCommand] $analysisArgs" "r+"]} result]} {
      if {$oldpwd != ""} { catch {cd $oldpwd} }
      tk_messageBox -title "Scid: error starting analysis" \
          -icon warning -type ok \
          -message "Unable to start the program:\n$analysisCommand"
      ::tacgame::resetEngine $n
      return
    }
    
    # Return to original dir if necessary:
    if {$oldpwd != ""} { catch {cd $oldpwd} }
    
    # Open log file if applicable:
    set analysisCoach(log$n) ""
    if {$analysisCoach(logMax) > 0} {
      if {! [catch {open [file join $::scidUserDir "coachengine$n.log"] w} log]} {
        set analysisCoach(log$n) $log
        logEngine $n "Scid-Engine communication log file"
        logEngine $n "Engine: $analysisName"
        logEngine $n "Command: $analysisCommand"
        logEngine $n "Date: [clock format [clock seconds]]"
        logEngine $n ""
        logEngine $n "This file was automatically generated by Scid."
        logEngine $n "It is rewritten every time an engine is started in Scid."
        logEngine $n ""
      }
    }
    
    # Configure pipe for line buffering and non-blocking mode:
    fconfigure $analysisCoach(pipe$n) -buffering line -blocking 0
    
    if {$n == 1} {
      fileevent $analysisCoach(pipe$n) readable "::tacgame::processInput"
      after 1000 "::tacgame::checkAnalysisStarted $n"
    } else {
      fileevent $analysisCoach(pipe$n) readable "::tacgame::processAnalysisInput"
      after 1000 "::tacgame::checkAnalysisStarted $n"
    }
    
  }
  
  # ======================================================================
  # ::tacgame::closeEngine
  #   Close an engine.
  # ======================================================================
  proc closeEngine {n} {
    global windowsOS ::tacgame::analysisCoach
    
    # Check the pipe is not already closed:
    if {$analysisCoach(pipe$n) == ""} {
      return
    }
    
    # Send interrupt signal if the engine wants it:
    if {(!$windowsOS)  &&  $analysisCoach(send_sigint$n)} {
      catch {exec -- kill -s INT [pid $analysisCoach(pipe$n)]}
    }
    
    # Some engines in analyze mode may not react as expected to "quit"
    # so ensure the engine exits analyze mode first:
    sendToEngine $n "exit"
    sendToEngine $n "quit"
    catch { flush $analysisCoach(pipe$n) }
    
    # Uncomment the following line to turn on blocking mode before
    # closing the engine (but probably not a good idea!)
    #   fconfigure $analysisCoach(pipe$n) -blocking 1
    
    # Close the engine, ignoring any errors since nothing can really
    # be done about them anyway -- maybe should alert the user with
    # a message box?
    catch {close $analysisCoach(pipe$n)}
    
    if {$analysisCoach(log$n) != ""} {
      catch {close $analysisCoach(log$n)}
      set analysisCoach(log$n) ""
    }
    set analysisCoach(pipe$n) ""
  }
  # ======================================================================
  # sendToEngine:
  #   Send a command to a running analysis engine.
  # ======================================================================
  proc sendToEngine {n text} {
    logEngine $n "Scid  : $text"
    catch {puts $::tacgame::analysisCoach(pipe$n) $text}
  }
  
  # ======================================================================
  # checkAnalysisStarted
  #   Called a short time after an analysis engine was started
  #   to send it commands if Scid has not seen any output from
  #   it yet.
  # ======================================================================
  proc checkAnalysisStarted {n} {
    global ::tacgame::analysisCoach
    if {$analysisCoach(seen$n)} { return }
    
    # Some Winboard engines do not issue any output when
    # they start up, so the fileevent above is never triggered.
    # Most, but not all, of these engines will respond in some
    # way once they have received input of some type.  This
    # proc will issue the same initialization commands as
    # those in processAnalysisInput below, but without the need
    # for a triggering fileevent to occur.
    
    ::tacgame::logEngineNote $n {Quiet engine (still no output); sending it initial commands.}
    set analysisCoach(seen$n) 1
    ::tacgame::sendToEngine $n "xboard"
    ::tacgame::sendToEngine $n "protover 2"
    ::tacgame::sendToEngine $n "post"
    ::tacgame::sendToEngine $n "ponder off"
    
    # Prevent some engines from making an immediate "book"
    # reply move as black when position is sent later:
    ::tacgame::sendToEngine $n "force"
  }
  
  # ======================================================================
  #
  # processInput from the engine blundering (Phalanx)
  #
  # ======================================================================
  proc processInput {} {
    global ::tacgame::analysisCoach ::tacgame::analysis
    
    # Get one line from the engine:
    set line [gets $analysisCoach(pipe1)]
    ::tacgame::logEngine 1 "Engine: $line"
    
    # check that the engine is really Phalanx
    if { ! $analysisCoach(seen1) && $line != "Phalanx XXII-pg" } {
      after cancel ::tacgame::phalanxGo
      ::tacgame::closeEngine 1
      ::tacgame::closeEngine 2
      tk_messageBox -type ok -icon warning -parent . -title "Scid" \
          -message "Please choose the correct Phalanx engine"
      focus .
      destroy .coachWin
      ::tacgame::config
      return
    }
    
    # Check that the engine did not terminate unexpectedly:
    if {[eof $analysisCoach(pipe1)]} {
      fileevent $analysisCoach(pipe1) readable {}
      catch {close $analysisCoach(pipe1)}
      set analysisCoach(pipe1) ""
      ::tacgame::logEngineNote 1 {Engine terminated without warning.}
      tk_messageBox -type ok -icon info -parent . -title "Scid" \
          -message "The analysis engine 1 terminated without warning; it probably crashed or had an internal error."
    }
    
    if {! $analysisCoach(seen1)} {
      # First line of output from the program, so send initial commands:
      ::tacgame::logEngineNote 1 {First line from engine seen; sending it initial commands now.}
      set analysisCoach(seen1) 1
      ::tacgame::sendToEngine 1 "xboard"
      ::tacgame::sendToEngine 1 "post"
    }
    
    ::tacgame::makePhalanxMove $line
    
  }
  
  # ======================================================================
  # processAnalysisInput
  #   Called from a fileevent whenever there is a line of input
  #   from an analysis engine waiting to be processed.
  # ======================================================================
  proc processAnalysisInput { } {
    global ::tacgame::analysisCoach ::tacgame::analysis ::tacgame::lscore
    
    # Get one line from the engine:
    set line [gets $analysisCoach(pipe2)]
    ::tacgame::logEngine 2 "Engine: $line"
    
    # Check that the engine did not terminate unexpectedly:
    if {[eof $analysisCoach(pipe2)]} {
      fileevent $analysisCoach(pipe2) readable {}
      catch {close $analysisCoach(pipe2)}
      set analysisCoach(pipe2) ""
      ::tacgame::logEngineNote 2 {Engine terminated without warning.}
      tk_messageBox -type ok -icon info -parent . -title "Scid" \
          -message "The analysis engine 2 terminated without warning; it probably crashed or had an internal error."
    }
    
    if {! $analysisCoach(seen2)} {
      # First line of output from the program, so send initial commands:
      ::tacgame::logEngineNote 2 {First line from engine seen; sending it initial commands now.}
      set analysisCoach(seen2) 1
      ::tacgame::sendToEngine 2 "xboard"
      ::tacgame::sendToEngine 2 "protover 2"
      ::tacgame::sendToEngine 2 "ponder off"
      ::tacgame::sendToEngine 2 "post"
    }
    
    # Check for "feature" commands so we can determine if the engine
    # has the setboard and analyze commands:
    #
    if {! [string compare [string range $line 0 6] "feature"]} {
      if {[string match "*analyze=1" $line]} { set analysisCoach(has_analyze2) 1 }
      if {[string match "*setboard=1" $line]} { set analysisCoach(has_setboard2) 1 }
      if {[string match "*usermove=1" $line]} { set analysisCoach(wants_usermove2) 1 }
      if {[string match "*sigint=1" $line]} { set analysisCoach(send_sigint2) 1 }
      
      return
    }
    
    # Check for a line starting with "Crafty", so Scid can work well
    # with older Crafty versions that do not recognize "protover":
    #
    if {! [string compare [string range $line 0 5] "Crafty"]} {
      ::tacgame::logEngineNote 2 {Seen "Crafty"; assuming analyze and setboard commands.}
      set major 0
      if {[scan $line "Crafty v%d.%d" major minor] == 2  &&  $major >= 18} {
        ::tacgame::logEngineNote 2 {Crafty version is >= 18.0; assuming scores are from White perspective.}
        set analysisCoach(invertScore2) 0
      }
      # Turn off crafty logging, to reduce number of junk files:
      ::tacgame::sendToEngine 2 "log off"
      # Set a fairly low noise value so Crafty is responsive to board changes,
      # but not so low that we get lots of short-ply search data:
      ::tacgame::sendToEngine 2 "noise 1000"
      set analysisCoach(isCrafty2) 1
      set analysisCoach(has_setboard2) 1
      set analysisCoach(has_analyze2) 1
      return
    }
    
    # Scan the line from the engine for the analysis data:
    #
    set res [scan $line "%d%c %d %d %d %\[^\n\]\n" \
        temp_depth dummy temp_score \
        temp_time temp_nodes temp_moves]
    if {$res == 6} {
      set analysisCoach(score2) $temp_score
      set analysisCoach(moves2) [::tacgame::formatAnalysisMoves $temp_moves]
      # Convert score to pawns from centipawns:
      set analysisCoach(score2) [expr double($analysisCoach(score2)) / 100.0]
      set lscore [lreplace $lscore end end $analysisCoach(score2)]
      ::tacgame::updateAnalysisText
      if {! $analysisCoach(seenEval2)} {
        # This is the first evaluation line seen, so send the current
        # position details to the engine:
        set analysisCoach(seenEval2) 1
      }
      return
    }
    
  }
  # ======================================================================
  # formatAnalysisMoves:
  #   Given the text at the end of a line of analysis data from an engine,
  #   this proc tries to strip out some extra stuff engines add to make
  #   the text more compatible for adding as a variation.
  # ======================================================================
  proc formatAnalysisMoves {text} {
    set text [string trim $text]
    # Crafty adds "<HT>" for a hash table comment. Change it to "{HT}":
    regsub "<HT>" $text "{HT}" text
    return $text
  }
  
  # ======================================================================
  # startAnalyzeMode:
  #   Put the engine in analyze mode
  # ======================================================================
  proc startAnalyze { } {
    global ::tacgame::analysisCoach ::tacgame::isLimitedAnalysisTime ::tacgame::analysisTime
    
    if { !$analysisCoach(has_analyze2)} {
      error "No analyze engine"
      return
    }
    # Check that the engine has not already had analyze mode started:
    if {$analysisCoach(analyzeMode2)} {
      ::tacgame::sendToEngine 2 "exit"
    }
    
    set analysisCoach(analyzeMode2) 1
    after cancel ::tacgame::stopAnalyze
    
    ::tacgame::sendToEngine 2 "setboard [sc_pos fen]"
    ::tacgame::sendToEngine 2 "analyze"
    if { $isLimitedAnalysisTime == 1 }  {
      after [expr 1000 * $analysisTime] ::tacgame::stopAnalyze
    }
    
  }
  # ======================================================================
  # stopAnalyzeMode:
  #   Stop the engine analyze mode
  # ======================================================================
  proc stopAnalyze { } {
    global ::tacgame::analysisCoach ::tacgame::isLimitedAnalysisTime ::tacgame::analysisTime
    if { !$analysisCoach(has_analyze2)} {
      error "No analyze engine"
      return
    }
    # Check that the engine has already had analyze mode started:
    if {!$analysisCoach(analyzeMode2)} { return }
    set analysisCoach(analyzeMode2) 0
    ::tacgame::sendToEngine 2 "exit"
  }
  ################################################################################
  # returns true if last move is a mate and stops clocks
  ################################################################################
  proc endOfGame {} {
    if { [string index [sc_game info previousMove] end ] == "#"} {
      ::gameclock::stop 1
      ::gameclock::stop 2
      return 1
    }
    return 0
  }
  # ======================================================================
  # phalanxGo
  #		it is phalanx's turn to play
  # ======================================================================
  proc phalanxGo {} {
    global ::tacgame::analysisCoach ::tacgame::isOpening ::tacgame::openingMovesList \
        ::tacgame::openingMovesHash ::tacgame::openingMoves ::tacgame::outOfOpening
    
    after cancel ::tacgame::phalanxGo
    
    if { [::tacgame::endOfGame] } { return }
    
    # check if Phalanx is already thinking
    if { $analysisCoach(automoveThinking1) == 1 } {
      after 1000 ::tacgame::phalanxGo
      return
    }
    
    if { [sc_pos side] != [::tacgame::getPhalanxColor] } {
      after 1000 ::tacgame::phalanxGo
      return
    }
    
    ::gameclock::stop 1
    ::gameclock::start 2
    repetition
    
    # make a move corresponding to a specific opening, (it is Phalanx's turn)
    if {$isOpening && !$outOfOpening} {
      set index 0
      # Warn if the user went out of the opening line chosen
      if { !$outOfOpening } {
        set ply [ expr [sc_pos moveNumber] * 2 - 1]
        if { [sc_pos side] == "white" } {
          set ply [expr $ply - 1]
        }
        
        if { [lsearch $openingMovesHash [sc_pos hash]] == -1 && [llength $openingMovesList] >= $ply} {
          set answer [tk_messageBox -icon question -parent .board -title $::tr(OutOfOpening) -type yesno \
              -message "$::tr(NotFollowedLine) $openingMoves\n $::tr(DoYouWantContinue)" ]
          if {$answer == no} {
            sc_move back 1
            updateBoard -pgn
            ::gameclock::stop 2
            ::gameclock::start 1
            after 1000 ::tacgame::phalanxGo
            return
          }  else  {
            set outOfOpening 1
          }
        }
      }
      
      set hpos [sc_pos hash]
      # Find a corresponding position in the opening line
      set length [llength $openingMovesHash]
      for {set i 0}   { $i < [expr $length-1] } { incr i } {
        set h [lindex $openingMovesHash $i]
        if {$h == $hpos} {
          set index [lsearch $openingMovesHash $h]
          set move [lindex $openingMovesList $index]
          # play the move
          set action "replace"
          if {![sc_pos isAt vend]} { set action [confirmReplaceMove] }
          if {$action == "replace"} {
            if {[catch {sc_move addSan $move}]} {}
          } elseif {$action == "var"} {
            sc_var create
            if {[catch {sc_move addSan $move}]} {}
          } elseif {$action == "mainline"} {
            sc_var create
            if {[catch {sc_move addSan $move}]} {}
            sc_var exit
            sc_var promote [expr {[sc_var count] - 1}]
            sc_move forward 1
          }
          
          ::utils::sound::AnnounceNewMove $move
          
          updateBoard -pgn -animate
          ::gameclock::stop 2
          ::gameclock::start 1
          repetition
          after 1000 ::tacgame::phalanxGo
          return
        }
      }
      
    }
    
    # Pascal Georges : original Phalanx does not have 'setboard'
    set analysisCoach(automoveThinking1) 1
    sendToEngine 1 "setboard [sc_pos fen]"
    sendToEngine 1 "go"
    after 1000 ::tacgame::phalanxGo
  }
  ################################################################################
  #   add current position for 3fold repetition detection and returns 1 if
  # the position is a repetion
  ################################################################################
  proc repetition {} {
    set elt [lrange [split [sc_pos fen]] 0 2]
    lappend ::tacgame::lFen $elt
    if { [llength [lsearch -all $::tacgame::lFen $elt] ] >=3 } {
      tk_messageBox -type ok -message $::tr(Draw) -parent .board -icon info
      return 1
    }
    return 0
  }
  # ======================================================================
  # makePhalanxMove:
  #
  # ======================================================================
  proc makePhalanxMove { input } {
    global ::tacgame::lscore ::tacgame::analysisCoach ::tacgame::currentPosHash ::tacgame::resignCount
    
    # The input move is of the form "my move is MOVE"
    if {[scan $input "my move is %s" move] != 1} { return 0 }
    
    # Phalanx will move : update the score list to detect any blunder
    if {$analysisCoach(invertScore2)  && (![string compare [sc_pos side] "black"])} {
      lappend lscore [expr {0.0 - $analysisCoach(score2)} ]
    } else  {
      lappend lscore $analysisCoach(score2)
    }
    
    # if the resign value has been reached more than 3 times in a raw, resign
    if { ( [getPhalanxColor] == "black" && [lindex $lscore end] >  $::informant("++-") ) || \
          ( [getPhalanxColor] == "white" && [lindex $lscore end] < [expr 0.0 - $::informant("++-")] ) } {
      incr resignCount
    } else  {
      set resignCount 0
    }
    
    # check the sequence of moves
    # in case of any event (board setup, move back/forward), reset score list
    if { ![sc_pos isAt start] && ![sc_pos isAt vstart]} {
      sc_move back 1
      if { [sc_pos hash] != $currentPosHash} {
        set lscore {}
        updateAnalysisText
      }
      sc_move forward 1
    } else  {
      if { [sc_pos hash] != $currentPosHash} {
        set lscore {}
        updateAnalysisText
      }
    }
    
    # play the move
    set action "replace"
    if {![sc_pos isAt vend]} { set action [confirmReplaceMove] }
    if {$action == "replace"} {
      if {[catch {sc_move addSan $move}]} {
        # No move from Phalanx : remove the score (last element)
        set lscore [lreplace $lscore end end]
        return 0
      }
    } elseif {$action == "var"} {
      sc_var create
      if {[catch {sc_move addSan $move}]} {
        # No move from Phalanx : remove the score (last element)
        set lscore [lreplace $lscore end end]
        return 0
      }
    } elseif {$action == "mainline"} {
      sc_var create
      if {[catch {sc_move addSan $move}]} {
        # No move from Phalanx : remove the score (last element)
        set lscore [lreplace $lscore end end]
        return 0
      }
      sc_var exit
      sc_var promote [expr {[sc_var count] - 1}]
      sc_move forward 1
    }
    
    set analysisCoach(automoveThinking1) 0
    set currentPosHash [sc_pos hash]
    
    # Phalanx has moved : start coach analysis
    if {$analysisCoach(seen2)} {
      ::tacgame::startAnalyze
    }
    ::utils::sound::AnnounceNewMove $move
    updateBoard -pgn -animate
    
    ::gameclock::stop 2
    ::gameclock::start 1
    repetition
    
    if { $resignCount > 3 } {
      tk_messageBox -type ok -message $::tr(Iresign) -parent .board -icon info
      set resignCount 0
    }
    
    return 1
  }
  
  # ======================================================================
  # updateAnalysisText
  #   Update the text in an analysis window.
  # ======================================================================
  proc updateAnalysisText { } {
    global ::tacgame::analysisCoach ::tacgame::showblunder ::tacgame::blunderWarningLabel \
        ::tacgame::showblunder ::tacgame::showblundervalue ::tacgame::showblunderfound ::tacgame::showmovevalue \
        ::tacgame::showevaluation ::tacgame::lscore ::tacgame::threshold \
        ::tacgame::lastblundervalue ::tacgame::prev_lastblundervalue ::tacgame::scoreLabel \
        ::tacgame::blunderpending ::tacgame::prev_blunderpending
    
    # There are less than 2 scores in the list
    if {[llength $lscore] < 2} {
      set blunderWarningLabel $::tr(Noinfo)
      set scoreLabel ""
      if {[llength $lscore] == 1 && $showevaluation } {
        set scoreLabel "Score : [lindex $lscore end]"
      }
      return
    }
    
    set sc1 [lindex $lscore end]
    set sc2 [lindex $lscore end-1]
    
    if { $analysisCoach(automoveThinking1) } {
      set blunderWarningLabel $::tr(Noinfo)
    }
    
    # Check if a blunder was made by Phalanx at last move.
    # The check is done during player's turn
    if { $showblunder && [::tacgame::getPhalanxColor] != [sc_pos side] } {
      if {[llength $lscore] >=2} {
        if { ($sc1 - $sc2 > $threshold && [::tacgame::getPhalanxColor] == "black") || \
              ($sc1 - $sc2 < [expr 0.0 - $threshold] && [::tacgame::getPhalanxColor] == "white") } {
          set lastblundervalue [expr $sc1-$sc2]
          # append a ?!, ? or ?? to the move if there is none yet and if the game was not dead yet
          # (that is if the score was -6, if it goes down to -10, this is a normal evolution
          if { [expr abs($sc2)] < $::informant("++-") } {
            sc_pos clearNags
            set b [expr abs($lastblundervalue)]
            if { $b >= $::informant("?!") && $b < $::informant("?") } {
              sc_pos addNag "?!"
            } elseif { $b >= $::informant("?") && $b < $::informant("??") }  {
              sc_pos addNag "?"
            } elseif  { $b >= $::informant("??") } {
              sc_pos addNag "??"
            }
          }
          
          .coachWin.finformations.l1 configure -bg LightCoral
          if { $showblundervalue } {
            set tmp $::tr(blunder)
            append tmp [format " %+8.2f" [expr abs($sc1-$sc2)]]
            set blunderWarningLabel $tmp
            set blunderpending 1
          } else {
            set blunderWarningLabel "$::tr(blunder) !"
          }
        } else {
          sc_pos clearNags
          .coachWin.finformations.l1 configure -bg linen
          set blunderWarningLabel $::tr(Noblunder)
          set blunderpending 0
        }
      }
    } else {
      set blunderWarningLabel "---"
    }
    
    if { !$showblunder || $analysisCoach(automoveThinking1) } {
      set blunderWarningLabel "---"
    }
    
    # displays current score sent by the "good" engine (Crafty)
    if { $showevaluation } {
      set scoreLabel "Score : $sc1"
    } else {
      set scoreLabel ""
    }
  }
  
  # ======================================================================
  # getPhalanxColor
  #   Returns "white" or "black" (Phalanx always plays at top)
  # ======================================================================
  proc getPhalanxColor {} {
    # Phalanx always plays for the upper side
    if { [::board::isFlipped .board] == 0 } {
      return "black"
    } else  {
      return "white"
    }
  }
  
  # ======================================================================
  # logEngine:
  #   Log Scid-Engine communication.
  # ======================================================================
  proc logEngine {n text} {
    global ::tacgame::analysisCoach
    
    # Print the log message to  if applicable:
    if {$analysisCoach(log_stdout)} {
      puts stdout "$n $text"
    }
    
    if {$analysisCoach(log$n) != ""} {
      puts $analysisCoach(log$n) $text
      
      # Close the log file if the limit is reached:
      incr analysisCoach(logCount$n)
      if {$analysisCoach(logCount$n) >= $analysisCoach(logMax)} {
        puts $analysisCoach(log$n) \
            "NOTE  : Log file size limit reached; closing log file."
        catch {close $analysisCoach(log$n)}
        set analysisCoach(log$n) ""
      }
    }
  }
  
  # ======================================================================
  # logEngineNote:
  #   Add a note to the engine communication log file.
  # ======================================================================
  proc logEngineNote {n text} {
    logEngine $n "NOTE  : $text"
  }
  ################################################################################
  #
  ################################################################################
  set openingList [ list \
      "$::tr(Reti): 1.Nf3" \
      "$::tr(English): 1.c4" \
      "$::tr(d4Nf6Miscellaneous): 1.d4 Nf6" \
      "$::tr(Trompowsky): 1.d4 Nf6 2.Bg5" \
      "$::tr(Budapest): 1.d4 Nf6 2.c4 e5" \
      "$::tr(OldIndian): 1.d4 Nf6 2.c4 d6" \
      "$::tr(BenkoGambit): 1.d4 Nf6 2.c4 c5 3.d5 b5" \
      "$::tr(ModernBenoni): 1.d4 Nf6 2.c4 c5 3.d5 e6" \
      "$::tr(DutchDefence): 1.d4 f5" \
      "1.e4" \
      "$::tr(Scandinavian): 1.e4 d5" \
      "$::tr(AlekhineDefence): 1.e4 Nf6" \
      "$::tr(Pirc): 1.e4 d6" \
      "$::tr(CaroKann): 1.e4 c6" \
      "$::tr(CaroKannAdvance): 1.e4 c6 2.d4 d5 3.e5" \
      "$::tr(Sicilian): 1.e4 c5" \
      "$::tr(SicilianAlapin): 1.e4 c5 2.c3" \
      "$::tr(SicilianClosed): 1.e4 c5 2.Nc3" \
      "$::tr(Sicilian): 1.e4 c5 2.Nf3 Nc6" \
      "$::tr(Sicilian): 1.e4 c5 2.Nf3 e6" \
      "$::tr(SicilianRauzer): 1.e4 c5 2.Nf3 d6 3.d4 cxd4 4.Nxd4 Nf6 5.Nc3 Nc6" \
      "$::tr(SicilianDragon): 1.e4 c5 2.Nf3 d6 3.d4 cxd4 4.Nxd4 Nf6 5.Nc3 g6 " \
      "$::tr(SicilianScheveningen): 1.e4 c5 2.Nf3 d6 3.d4 cxd4 4.Nxd4 Nf6 5.Nc3 e6" \
      "$::tr(SicilianNajdorf): 1.e4 c5 2.Nf3 d6 3.d4 cxd4 4.Nxd4 Nf6 5.Nc3 a6" \
      "$::tr(OpenGame): 1.e4 e5" \
      "$::tr(Vienna): 1.e4 e5 2.Nc3" \
      "$::tr(KingsGambit): 1.e4 e5 2.f4" \
      "$::tr(RussianGame): 1.e4 e5 2.Nf3 Nf6" \
      "$::tr(OpenGame): 1.e4 e5 2.Nf3 Nc6" \
      "$::tr(ItalianTwoKnights): 1.e4 e5 2.Nf3 Nc6 3.Bc4" \
      "$::tr(Spanish): 1.e4 e5 2.Nf3 Nc6 3.Bb5" \
      "$::tr(SpanishExchange): 1.e4 e5 2.Nf3 Nc6 3.Bb5 a6 4.Bxc6" \
      "$::tr(SpanishOpen): 1.e4 e5 2.Nf3 Nc6 3.Bb5 a6 4.Ba4 Nf6 5.O-O Nxe4" \
      "$::tr(SpanishClosed): 1.e4 e5 2.Nf3 Nc6 3.Bb5 a6 4.Ba4 Nf6 5.O-O Be7" \
      "$::tr(FrenchDefence): 1.e4 e6" \
      "$::tr(FrenchAdvance): 1.e4 e6 2.d4 d5 3.e5" \
      "$::tr(FrenchTarrasch): 1.e4 e6 2.d4 d5 3.Nd2" \
      "$::tr(FrenchWinawer): 1.e4 e6 2.d4 d5 3.Nc3 Bb4" \
      "$::tr(FrenchExchange): 1.e4 e6 2.d4 d5 3.exd5 exd5" \
      "$::tr(QueensPawn): 1.d4 d5" \
      "$::tr(Slav): 1.d4 d5 2.c4 c6" \
      "$::tr(QGA): 1.d4 d5 2.c4 dxc4" \
      "$::tr(QGD): 1.d4 d5 2.c4 e6" \
      "$::tr(QGDExchange): 1.d4 d5 2.c4 e6 3.cxd5 exd5" \
      "$::tr(SemiSlav): 1.d4 d5 2.c4 e6 3.Nc3 Nf6 4.Nf3 c6" \
      "$::tr(QGDwithBg5): 1.d4 d5 2.c4 e6 3.Nc3 Nf6 4.Bg5" \
      "$::tr(QGDOrthodox): 1.d4 d5 2.c4 e6 3.Nc3 Nf6 4.Bg5 Be7 5.e3 O-O 6.Nf3 Nbd7" \
      "$::tr(Grunfeld): 1.d4 Nf6 2.c4 g6 3.Nc3 d5" \
      "$::tr(GrunfeldExchange): 1.d4 Nf6 2.c4 g6 3.Nc3 d5 4.cxd5" \
      "$::tr(GrunfeldRussian): 1.d4 Nf6 2.c4 g6 3.Nc3 d5 4.Nf3 Bg7 5.Qb3" \
      "$::tr(Catalan): 1.d4 Nf6 2.c4 e6 3.g3 " \
      "$::tr(CatalanOpen): 1.d4 Nf6 2.c4 e6 3.g3 d5 4.Bg2 dxc4" \
      "$::tr(CatalanClosed): 1.d4 Nf6 2.c4 e6 3.g3 d5 4.Bg2 Be7" \
      "$::tr(QueensIndian): 1.d4 Nf6 2.c4 e6 3.Nf3 b6" \
      "$::tr(NimzoIndian): 1.d4 Nf6 2.c4 e6 3.Nc3 Bb4" \
      "$::tr(NimzoIndianClassical): 1.d4 Nf6 2.c4 e6 3.Nc3 Bb4 4.Qc2" \
      "$::tr(NimzoIndianRubinstein): 1.d4 Nf6 2.c4 e6 3.Nc3 Bb4 4.e3" \
      "$::tr(KingsIndian): 1.d4 Nf6 2.c4 g6" \
      "$::tr(KingsIndianSamisch): 1.d4 Nf6 2.c4 g6 4.e4 d6 5.f3" \
      "$::tr(KingsIndianMainLine): 1.d4 Nf6 2.c4 g6 4.e4 d6 5.Nf3" \
      ]
}
###
### End of file: tacgame.tcl
###