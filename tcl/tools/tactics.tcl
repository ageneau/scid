### tactics.tcl: part of Scid.
### Copyright (C) 2007  Pascal Georges
###
######################################################################
### Solve tactics (mate in n moves for example)
# use Site token in pgn notation to store progress
#

namespace eval tactics {
  
  set infoEngineLabel ""
  
  set basePath $::scidBasesDir
  
  set baseList {}
  set solved "problem solved"
  set failed "problem failed"
  set prevScore 0
  set prevLine ""
  set nextEngineMove ""
  set matePending 0
  set cancelScoreReset 0
  set askToReplaceMoves_old 0
  set showSolution 0
  set  labelSolution ". . . . . . "
  set lastGameLoaded 0
  set prevFen ""
  set engineSlot 5
  # Don't try to find the exact best move but to win a won game (that is a mate in 5 is ok even if there was a pending mate in 2)
  set winWonGame 0
  
  ################################################################################
  # Configuration dialog
  ################################################################################
  proc config {} {
    global ::tactics::basePath ::tactics::baseList
    set basePath $::scidBasesDir
    
    # check if tactics window is already opened. If so, abort serial.
    set w .tacticsWin
    if {[winfo exists $w]} {
      destroy $w
    }
    
    set w ".configTactics"
    if {[winfo exists $w]} {
      focus $w
      return
    }
    toplevel $w
    wm title $w $::tr(ConfigureTactics)
    setWinLocation $w
    
    if {[sc_base count free] == 0} {
      tk_messageBox -type ok -icon info -title "Scid" -message "Too many databases are open; close one first"
      return
    }
    
    set prevBase [sc_base current]
    # go through all bases and take descriptions
    set baseList {}
    set fileList [  lsort -dictionary [ glob -nocomplain -directory $basePath *.si3 ] ]
    foreach file  $fileList {
      if {[sc_base slot $file] == 0} {
        sc_base open [file rootname $file]
        set wasOpened 0
      } else  {
        sc_base switch [sc_base slot $file]
        set wasOpened 1
      }
      
      set solvedCount 0
      for {set g 1 } { $g <= [sc_base numGames]} { incr g} {
        sc_game load $g
        if {[sc_game tags get "Site"] == $::tactics::solved} { incr solvedCount }
      }
      lappend baseList "$file" "[sc_base description] ($solvedCount/[sc_base numGames])"
      if {! $wasOpened } {
        sc_base switch $prevBase
        sc_base close [sc_base slot $file]
      }
    }
    
    updateMenuStates
    updateStatusBar
    updateTitle
    
    frame $w.fconfig -relief raised -borderwidth 1
    label $w.fconfig.l1 -text $::tr(ChooseTrainingBase)
    pack $w.fconfig.l1
    
    frame $w.fconfig.flist
    listbox $w.fconfig.flist.lb -selectmode single -exportselection 0 \
        -yscrollcommand "$w.fconfig.flist.ybar set" -height 10 -width 30
    scrollbar $w.fconfig.flist.ybar -command "$w.fconfig.flist.lb yview"
    pack $w.fconfig.flist.lb $w.fconfig.flist.ybar -side left -fill y
    for {set i 1} {$i<[llength $baseList]} {incr i 2} {
      $w.fconfig.flist.lb insert end [lindex $baseList $i]
    }
    $w.fconfig.flist.lb selection set 0
    
    frame $w.fconfig.reset
    button $w.fconfig.reset.button -text $::tr(ResetScores) \
        -command {::tactics::resetScores [ lindex $::tactics::baseList [expr [.configTactics.fconfig.flist.lb curselection] * 2 ] ]}
    pack $w.fconfig.reset.button -expand yes -fill both
    
    # in order to limit CPU usage, limit the time for analysis (this prevents noise on laptops)
    frame $w.fconfig.flimit
    label $w.fconfig.flimit.blimit -text $::tr(limitanalysis) -relief flat
    scale $w.fconfig.flimit.analysisTime -orient horizontal -from 1 -to 60 -length 120 -label $::tr(seconds) -variable ::tactics::analysisTime -resolution 1
    pack $w.fconfig.flimit.blimit $w.fconfig.flimit.analysisTime -side left -expand yes
    
    frame $w.fconfig.fbutton
    button $w.fconfig.fbutton.ok -text $::tr(Continue) -command {
      set base [ lindex $::tactics::baseList [expr [.configTactics.fconfig.flist.lb curselection] * 2 ] ]
      destroy .configTactics
      ::tactics::start $base
    }
    button $w.fconfig.fbutton.cancel -text $::tr(Cancel) -command "focus .; destroy $w"
    pack $w.fconfig.fbutton.ok $w.fconfig.fbutton.cancel -expand yes -side left -padx 20 -pady 2
    
    pack $w.fconfig $w.fconfig.flist $w.fconfig.reset $w.fconfig.flimit $w.fconfig.fbutton
    bind $w <Configure> "recordWinSize $w"
  }
  ################################################################################
  #
  ################################################################################
  proc start { base } {
    global ::tactics::analysisEngine ::askToReplaceMoves ::tactics::askToReplaceMoves_old
    
    set ::tactics::lastGameLoaded 0
    
    ::tactics::launchengine
    
    set askToReplaceMoves_old $askToReplaceMoves
    set askToReplaceMoves 0
    
    set w .tacticsWin
    if {[winfo exists $w]} { focus $w ; return }
    
    toplevel $w
    wm title $w $::tr(Tactics)
    setWinLocation $w
    # because sometimes the 2 buttons at the bottom are hidden
    wm minsize $w 170 170
    frame $w.f1 -relief groove -borderwidth 1
    label $w.f1.labelInfo -textvariable ::tactics::infoEngineLabel -bg linen
    checkbutton $w.f1.cbWinWonGame -text $::tr(WinWonGame) -variable ::tactics::winWonGame
    pack $w.f1.labelInfo $w.f1.cbWinWonGame -expand yes -fill both -side top
    
    frame $w.fclock
    ::gameclock::new $w.fclock 1 80 0
    ::gameclock::reset 1
    ::gameclock::start 1
    
    frame $w.f2 -relief groove
    checkbutton $w.f2.cbSolution -text $::tr(ShowSolution) -variable ::tactics::showSolution -command ::tactics::toggleSolution
    label $w.f2.lSolution -textvariable ::tactics::labelSolution -wraplength 120
    pack $w.f2.cbSolution $w.f2.lSolution -expand yes -fill both -side top
    
    frame $w.fbuttons -relief groove -borderwidth 1
    pack $w.f1 $w.fclock $w.f2 $w.fbuttons -expand yes -fill both
    
    setInfoEngine $::tr(LoadingBase)
    
    button $w.fbuttons.next -text $::tr(Next) -command {
      ::tactics::stopAnalyze
      ::tactics::loadNextGame }
    button $w.fbuttons.close -textvar ::tr(Abort) -command ::tactics::endTraining
    pack $w.fbuttons.next $w.fbuttons.close -expand yes -fill both -padx 20 -pady 2
    bind $w <Destroy> { ::tactics::endTraining }
    bind $w <Configure> "recordWinSize $w"
    
    ::tactics::loadBase [file rootname $base]
    
    setInfoEngine "---"
    ::tactics::loadNextGame
    ::tactics::mainLoop
  }
  ################################################################################
  #
  ################################################################################
  proc endTraining {} {
    set w .tacticsWin
    ::tactics::stopAnalyze
    after cancel ::tactics::mainLoop
    catch { sc_base close }
    updateMenuStates
    updateStatusBar
    updateTitle
    set ::askToReplaceMoves $::tactics::askToReplaceMoves_old
    focus .
    destroy $w

    catch { ::uci::closeUCIengine $::tactics::engineSlot }
  }
  ################################################################################
  #
  ################################################################################
  proc toggleSolution {} {
    global ::tactics::showSolution ::tactics::labelSolution ::tactics::analysisEngine
    if {$showSolution} {
      set labelSolution "$analysisEngine(score) : $analysisEngine(moves)"
    } else  {
      set labelSolution ". . . . . . "
    }
  }
  ################################################################################
  #
  ################################################################################
  proc resetScores {name} {
    global ::tactics::cancelScoreReset ::tactics::baseList
    
    set base [file rootname $name]
    
    set wasOpened 0
    
    if {[sc_base count free] == 0} {
      tk_messageBox -type ok -icon info -title "Scid" -message "Too many databases are opened\nClose one first"
      return
    }
    # check if the base is already opened
    if {[sc_base slot $name] != 0} {
      sc_base switch [sc_base slot $name]
      set wasOpened 1
    } else  {
      if { [catch { sc_base open $base }] } {
        tk_messageBox -type ok -icon warning -title "Scid" -message "Unable to open base"
        return
      }
    }
    
    #reset site tag for each game
    progressWindow "Scid" $::tr(ResettingScore) $::tr(Cancel) "::tactics::sc_progressBar"
    set numGames [sc_base numGames]
    set cancelScoreReset 0
    for {set g 1} { $g <= $numGames } { incr g} {
      if { $cancelScoreReset } { break }
      sc_game load $g
      if { [sc_game tags get "Site"] != ""} {
        sc_game tags set -site ""
        sc_game save [sc_game number]
      }
      if { [expr $g % 100] == 0 } {
        updateProgressWindow $g $numGames
      }
    }
    closeProgressWindow
    if { ! $wasOpened } {
      sc_base close
    }
    # update listbox
    set w ".configTactics"
    set cs [$w.fconfig.flist.lb curselection]
    set idx [expr $cs * 2 +1]
    set tmp [lindex $baseList $idx]
    regsub "\[(\]\[0-9\]+/" $tmp "(0/" tmp
    lset baseList $idx $tmp
    $w.fconfig.flist.lb delete 0 end
    for {set i 1} {$i<[llength $baseList]} {incr i 2} {
      $w.fconfig.flist.lb insert end [lindex $baseList $i]
    }
    $w.fconfig.flist.lb selection set $cs
  }
  ################################################################################
  # cancel score reset loading
  ################################################################################
  proc sc_progressBar {} {
    set ::tactics::cancelScoreReset 1
  }
  ################################################################################
  #
  ################################################################################
  proc loadNextGame {} {
    ::tactics::resetValues
    setInfoEngine $::tr(LoadingGame)
    set newGameFound 0
    # find a game with site tag != problem solved
    for {set g [ expr $::tactics::lastGameLoaded +1 ] } { $g <= [sc_base numGames]} { incr g} {
      sc_game load $g
      set tag [sc_game tags get "Site"]
      if {$tag != $::tactics::solved} { set newGameFound 1 ; break }
    }
    # it seems we finished the serial
    if {! $newGameFound } {
      tk_messageBox -title "Scid" -icon info -type ok -message $::tr(AllExercisesDone)
      return
    }
    set ::tactics::lastGameLoaded $g
    
    if { [sc_pos side] == "white" && [::board::isFlipped .board] || [sc_pos side] == "black" &&  ![::board::isFlipped .board] } {
      ::board::flip .board
    }
    
    ::gameclock::reset 1
    ::gameclock::start 1
    
    updateBoard -pgn
    set ::tactics::prevFen [sc_pos fen]
    ::windows::gamelist::Refresh
    ::tree::refresh
    ::windows::stats::Refresh
    updateMenuStates
    updateTitle
    updateStatusBar
    ::tactics::startAnalyze
    ::tactics::mainLoop
  }
  ################################################################################
  #
  ################################################################################
  proc isPlayerTurn {} {
    if { [sc_pos side] == "white" &&  ![::board::isFlipped .board] || [sc_pos side] == "black" &&  [::board::isFlipped .board] } {
      return 1
    }
    return 0
  }
  ################################################################################
  #
  ################################################################################
  proc exSolved {} {
    ::tactics::stopAnalyze
    ::gameclock::stop 1
    tk_messageBox -title "Scid" -icon info -type ok -message $::tr(MateFound)
    sc_game tags set -site $::tactics::solved
    sc_game save [sc_game number]
    ::tactics::loadNextGame
  }
  ################################################################################
  # Handle the case where position was changed not during normal play but certainly with
  # move back / forward / rewind commands
  ################################################################################
  proc abnormalContinuation {} {
    ::tactics::stopAnalyze
    ::tactics::resetValues
    ::windows::gamelist::Refresh
    ::tree::refresh
    ::windows::stats::Refresh
    updateMenuStates
    updateTitle
    updateStatusBar
    updateBoard -pgn
    if { [sc_pos side] == "white" && [::board::isFlipped .board] || [sc_pos side] == "black" &&  ![::board::isFlipped .board] } {
      ::board::flip .board
    }
    set ::tactics::prevFen [sc_pos fen]
    ::tactics::startAnalyze
    ::tactics::mainLoop
  }
  ################################################################################
  # waits for the user to play and check the move played
  ################################################################################
  proc mainLoop {} {
    global ::tactics::prevScore ::tactics::prevLine ::tactics::analysisEngine ::tactics::nextEngineMove
    
    after cancel ::tactics::mainLoop
    
    if {[sc_pos fen] != $::tactics::prevFen && [sc_pos isAt start]} {
      ::tactics::abnormalContinuation
      return
    }
    
    # is this player's turn (which always plays from bottom of the board) ?
    if { [::tactics::isPlayerTurn] } {
      after 1000  ::tactics::mainLoop
      return
    }
    
    set ::tactics::prevFen [sc_pos fen]
    
    # check if player's move is a direct mate : no need to wait for engine analysis in this case
    set move_done [sc_game info previousMove]
    if { [string index $move_done end] == "#"} { ::tactics::exSolved; return }
    
    # if the engine is still analyzing, wait the end of it
    if {$analysisEngine(analyzeMode)} { vwait ::tactics::analysisEngine(analyzeMode) }
    
    if {[sc_pos fen] != $::tactics::prevFen  && [sc_pos isAt start]} {
      ::tactics::abnormalContinuation
      return
    }
    
    # the player moved and analysis is over : check if his move was as good as expected
    set prevScore $analysisEngine(score)
    set prevLine $analysisEngine(moves)
    ::tactics::startAnalyze
    
    # now wait for the end of analyzis
    if {$analysisEngine(analyzeMode)} { vwait ::tactics::analysisEngine(analyzeMode) }
    if {[sc_pos fen] != $::tactics::prevFen  && [sc_pos isAt start]} {
      ::tactics::abnormalContinuation
      return
    }
    
    # compare results
    set res [::tactics::foundBestLine]
    if {  $res != ""} {
      tk_messageBox -title "Scid" -icon info -type ok -message "$::tr(BestSolutionNotFound)\n$res"
      # take back last move so restore engine status
      set analysisEngine(score) $prevScore
      set analysisEngine(moves) $prevLine
      sc_game tags set -site $::tactics::failed
      sc_game save [sc_game number]
      sc_move back
      updateBoard -pgn
      set ::tactics::prevFen [sc_pos fen]
    } else  {
      catch { sc_move addSan $nextEngineMove }
      set ::tactics::prevFen [sc_pos fen]
      updateBoard -pgn
      if { $::tactics::matePending } {
        # continue until end of game
      } else  {
        setInfoEngine $::tr(GoodMove)
        sc_game tags set -site $::tactics::solved
        sc_game save [sc_game number]
      }
    }
    
    after 1000 ::tactics::mainLoop
  }
  ################################################################################
  # Returns "" if the user played the best line, otherwise an explanation about the missed move :
  # - guessed the same next move as engine
  # - mate found in the minimal number of moves
  # - combinaison's score is close enough (within 0.5 point)
  ################################################################################
  proc foundBestLine {} {
    global ::tactics::analysisEngine ::tactics::prevScore ::tactics::prevLine ::tactics::nextEngineMove ::tactics::matePending
    set score $analysisEngine(score)
    set line $analysisEngine(moves)
    
    set s [ regsub -all "\[\.\]{3} " $line "" ]
    set s [ regsub -all "\[0-9\]+\[\.\] " $s "" ]
    set nextEngineMove [ lindex [ split $s ] 0 ]
    set ply [ llength [split $s] ]
    
    # check if the player played the same move predicted by engine
    set s [ regsub -all "\[\.\]{3} " $prevLine "" ]
    set s [ regsub -all "\[0-9\]+\[\.\] " $s "" ]
    set prevBestMove [ lindex [ split $s ] 1 ]
    if { [sc_game info previousMoveNT] == $prevBestMove} {
      return ""
    }
    
    # Case of mate
    if { [string index $prevLine end] == "#"} {
      set matePending 1
      #  Engine may find a mate then put a score != 300 but rather 10
      if {[string index $line end] != "#"} {
        # Engine line does not end with a # but the score is a mate (we can't count plies here)
        if {[sc_pos side] == "white" && $score < -300 || [sc_pos side] == "black" && $score > 300} {
          return ""
        }
        if {! $::tactics::winWonGame } {
          return $::tr(MateNotFound)
        } else  {
          # win won game but still have to find a mate
          if {[sc_pos side] == "white" && $score < -300 || [sc_pos side] == "black" && $score > 300} {
            return ""
          } else  {
            return $::tr(MateNotFound)
          }
        }
      }
      # Engine found a mate, search in how many plies
      set s [ regsub -all "\[\.\]{3} " $prevLine "" ]
      set s [ regsub -all "\[0-9\]+\[\.\] " $s "" ]
      set prevPly [ llength [ split $s ] ]
      if { $ply > [ expr $prevPly - 1 ] && ! $::tactics::winWonGame } {
        return $::tr(ShorterMateExists)
      } else  {
        return ""
      }
    } else  {
      # no mate case
      set matePending 0
      set threshold 0.5
      if {$::tactics::winWonGame} {
        # Only alert when the advantage clearly changes side
        if {[sc_pos side] == "white" && $prevScore < 0 && $score >= $threshold  || \
              [sc_pos side] == "black" &&  $prevScore >= 0 && $score < [expr 0 - $threshold]  } {
          return "$::tr(ScorePlayed) $score\n$::tr(Expected) $prevScore"
        } else  {
          return ""
        }
      }
      if {[ expr abs($prevScore) ] > 3.0 } { set threshold 1.0 }
      if {[ expr abs($prevScore) ] > 5.0 } { set threshold 1.5 }
      # the player moved : score is from opponent side
      if {[sc_pos side] == "white" && $score < [ expr $prevScore + $threshold ] || \
            [sc_pos side] == "black" && $score > [ expr $prevScore - $threshold ] } {
        return ""
      } else  {
        return "$::tr(ScorePlayed) $score\n$::tr(Expected) $prevScore"
      }
    }
  }
  ################################################################################
  # Loads a base bundled with Scid (in ./bases directory)
  ################################################################################
  proc loadBase { name } {
    
    if {[sc_base count free] == 0} {
      tk_messageBox -type ok -icon info -title "Scid" -message "Too many databases are open; close one first"
      return
    }
    # check if the base is already opened
    if {[sc_base slot $name] != 0} {
      sc_base switch [sc_base slot $name]
    } else  {
      if { [catch { sc_base open $name }] } {
        tk_messageBox -type ok -icon warning -title "Scid" -message "Unable to open base"
        return
      }
    }
    
    ::windows::gamelist::Refresh
    ::tree::refresh
    ::windows::stats::Refresh
    updateMenuStates
    updateBoard -pgn
    updateTitle
    updateStatusBar
  }
  ################################################################################
  ## resetValues
  #   Resets global data.
  ################################################################################
  proc resetValues {} {
    set ::tactics::prevScore 0
    set ::tactics::prevLine ""
    set ::tactics::nextEngineMove ""
    set ::tactics::matePending 0
    set ::tactics::showSolution 0
    set ::tactics::labelSolution ""
    set ::tactics::prevFen ""
  }
  ################################################################################
  #
  ################################################################################
  proc  restoreAskToReplaceMoves {} {
    set ::askToReplaceMoves $::tactics::askToReplaceMoves_old
  }
  ################################################################################
  #
  ################################################################################
  proc setInfoEngine { s { color linen } } {
    set ::tactics::infoEngineLabel $s
    .tacticsWin.f1.labelInfo configure -background $color
  }
  
  ################################################################################
  #  Will start engine
  ################################################################################
  proc launchengine {} {
    global ::tactics::analysisEngine
    
    ::uci::resetUciInfo $::tactics::engineSlot
    
    set analysisEngine(analyzeMode) 0
    
    # find engine
    set engineFound 0
    set index 0
    foreach e $::engines(list) {
      if { [string equal -nocase -length 4 [lindex $e 0] "toga" ] } {
        set engineFound 1
        break
      }
      incr index
    }
    if { ! $engineFound } {
      tk_messageBox -type ok -icon warning -parent . -title "Scid" -message "Unable to find engine"
      return
    }
    
    ::uci::startEngine $index $::tactics::engineSlot ;# start engine in analysis mode
  }
  
  # ======================================================================
  # sendToEngine:
  #   Send a command to a running analysis engine.
  # ======================================================================
  proc sendToEngine {text} {
    ::uci::sendToEngine $::tactics::engineSlot $text
  }
  
  # ======================================================================
  # startAnalyzeMode:
  #   Put the engine in analyze mode
  # ======================================================================
  proc startAnalyze { } {
    global ::tactics::analysisEngine ::tactics::analysisTime
    setInfoEngine "$::tr(Thinking) ..." PaleVioletRed
    
    # Check that the engine has not already had analyze mode started:
    if {$analysisEngine(analyzeMode)} {
      ::tactics::sendToEngine  "exit"
    }
    
    set analysisEngine(analyzeMode) 1
    after cancel ::tactics::stopAnalyze
    ::tactics::sendToEngine "position fen [sc_pos fen]"
    ::tactics::sendToEngine "go infinite ponder"
    after [expr 1000 * $analysisTime] ::tactics::stopAnalyze
  }
  # ======================================================================
  # stopAnalyzeMode:
  #   Stop the engine analyze mode
  # ======================================================================
  proc stopAnalyze { } {
    global ::tactics::analysisEngine ::tactics::analysisTime
    # Check that the engine has already had analyze mode started:
    if {!$analysisEngine(analyzeMode)} { return }
    
    set pv [lindex $::analysis(multiPV$::tactics::engineSlot) 0]
    set analysisEngine(score) [lindex $pv 1]
    set analysisEngine(moves) [lindex $pv 2]
    
    set analysisEngine(analyzeMode) 0
    ::tactics::sendToEngine  "stop"
    setInfoEngine $::tr(AnalyzeDone) PaleGreen3
  }
  
}
###
### End of file: tactics.tcl
###