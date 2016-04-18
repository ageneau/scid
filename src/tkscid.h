/////////////////////////////////////////////////////////////////////
//
//  FILE:       tkscid.h
//              Scid extensions to Tcl/Tk interpreter
//
//  Part of:    Scid (Shane's Chess Information Database)
//
//  Notice:     Copyright (c) 1999-2004 Shane Hudson.  All rights reserved.
//              Copyright (c) 2006-2007 Pascal Georges
//              Copyright (c) 2013 Benini Fulvio
//
//  Author:     Shane Hudson (sgh@users.sourceforge.net)
//
//////////////////////////////////////////////////////////////////////

#ifndef NODEJS
#include "tcl.h"
#else
typedef void *ClientData;
#endif

class Progress;
struct scidBaseT;



// Macro SCID_ARGS expands to the argument-type list that any
// Tcl command function takes.
#define SCID_ARGS  ClientData cd, UI_handle_t ti, int argc, const char ** argv


int sc_eco_base       (SCID_ARGS);
int sc_eco_game       (SCID_ARGS);
int sc_eco_read       (SCID_ARGS);
int sc_eco_summary    (SCID_ARGS);
int sc_eco_translate  (SCID_ARGS);

int sc_filter_first   (SCID_ARGS);
int sc_filter_freq    (scidBaseT* dbase, const HFilter& filter, UI_handle_t ti, int argc, const char ** argv);
int sc_filter_last    (SCID_ARGS);
int sc_filter_next    (SCID_ARGS);
int sc_filter_prev    (SCID_ARGS);
int sc_filter_stats   (SCID_ARGS);

int sc_game_crosstable (SCID_ARGS);
int sc_game_find      (SCID_ARGS);
int sc_game_firstMoves (SCID_ARGS);
int sc_game_import    (SCID_ARGS);
int sc_game_info      (SCID_ARGS);
int sc_game_load      (SCID_ARGS);
int sc_game_merge     (SCID_ARGS);
int sc_game_moves     (SCID_ARGS);
int sc_game_novelty   (SCID_ARGS);
int sc_game_new       (SCID_ARGS);
int sc_game_pgn       (SCID_ARGS);
int sc_game_pop       (SCID_ARGS);
int sc_game_push      (SCID_ARGS);
int sc_game_save      (SCID_ARGS);
int sc_game_scores    (SCID_ARGS);
int sc_game_startBoard (SCID_ARGS);
int sc_game_strip     (SCID_ARGS);
int sc_game_summary   (SCID_ARGS);
int sc_game_tags      (SCID_ARGS);
int sc_game_tags_get  (SCID_ARGS);
int sc_game_tags_set  (SCID_ARGS);
int sc_game_tags_reload (SCID_ARGS);
int sc_game_tags_share (SCID_ARGS);

int sc_info_fsize     (SCID_ARGS);
int sc_info_limit     (SCID_ARGS);
int sc_info_suffix    (SCID_ARGS);
int sc_info_tb        (SCID_ARGS);

int sc_move_add       (SCID_ARGS);
int sc_move_addSan    (SCID_ARGS);
int sc_move_addUCI    (SCID_ARGS);
int sc_move_back      (SCID_ARGS);
int sc_move_forward   (SCID_ARGS);
int sc_move_pgn       (SCID_ARGS);

int sc_name_correct   (SCID_ARGS);
int sc_name_edit      (SCID_ARGS);
int sc_name_info      (SCID_ARGS);
int sc_name_match     (SCID_ARGS);
int sc_name_plist     (SCID_ARGS);
int sc_name_read      (SCID_ARGS);

int sc_report_create  (SCID_ARGS);
int sc_report_select  (SCID_ARGS);

int sc_pos_addNag     (SCID_ARGS);
int sc_pos_analyze    (SCID_ARGS);
int sc_pos_bestSquare (SCID_ARGS);
int sc_pos_getNags    (SCID_ARGS);
int sc_pos_hash       (SCID_ARGS);
int sc_pos_html       (SCID_ARGS);
int sc_pos_isAt       (SCID_ARGS);
int sc_pos_isLegal    (SCID_ARGS);
int sc_pos_isPromo    (SCID_ARGS);
int sc_pos_matchMoves (SCID_ARGS);
int sc_pos_moves      (SCID_ARGS);
int sc_pos_pgnBoard   (SCID_ARGS);
int sc_pos_probe      (SCID_ARGS);
int sc_pos_probe_board (SCID_ARGS);
int sc_pos_setComment (SCID_ARGS);

int sc_tree_move      (SCID_ARGS);
int sc_tree_search    (SCID_ARGS);
int sc_tree_cachesize (SCID_ARGS);
int sc_tree_cacheinfo (SCID_ARGS);

int sc_var_delete     (SCID_ARGS);
int sc_var_delete_free(SCID_ARGS);
int sc_var_enter      (SCID_ARGS);
int sc_var_first      (SCID_ARGS);
int sc_var_list       (SCID_ARGS);

errorT search_index(const scidBaseT* base, HFilter& filter, int argc, const char ** argv, const Progress& progress);
int sc_search_board   (SCID_ARGS);
int sc_search_material (SCID_ARGS);
int sc_search_header  (ClientData cd, UI_handle_t ti, scidBaseT* base, HFilter& filter, int argc, const char ** argv);
int sc_search_rep_add (SCID_ARGS);
int sc_search_rep_go  (SCID_ARGS);

int sc_book_load      (SCID_ARGS);
int sc_book_close     (SCID_ARGS);
int sc_book_moves     (SCID_ARGS);
int sc_book_positions (SCID_ARGS);
int sc_book_update    (SCID_ARGS);
int sc_book_movesupdate (SCID_ARGS);
//////////////////////////////////////////////////////////////////////
/// END of tkscid.h
//////////////////////////////////////////////////////////////////////
