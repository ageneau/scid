/*
# Copyright (C) 2014 Fulvio Benini

* This file is part of Scid (Shane's Chess Information Database).
*
* Scid is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation.
*
* Scid is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with Scid. If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef SCIDBASE_H
#define SCIDBASE_H

#include "misc.h"
#include "index.h"
#include "namebase.h"
#include "gfile.h"
#include "undoredo.h"
#include "game.h"
#include "tree.h"
#include "stored.h"
#include <vector>


struct scidBaseT {
	struct Stats {
		uint flagCount [IDX_NUM_FLAGS]; // Num of games with each flag set.
		dateT minDate;
		dateT maxDate;
		uint64_t nYears;
		uint64_t sumYears;
		uint nResults [NUM_RESULT_TYPES];
		uint nRatings;
		uint64_t sumRatings;
		uint minRating;
		uint maxRating;

		Stats(const scidBaseT* dbase);

		struct Eco {
			uint count;
			uint results [NUM_RESULT_TYPES];

			Eco();
		};
		const Eco* getEcoStats(const char* ecoStr) const;

	private:
		Eco ecoEmpty_;
		Eco ecoValid_;
		Eco ecoStats_ [(1 + (1<<16)/131)*27];
		Eco ecoGroup1_[(1 + (1<<16)/131)/100];
		Eco ecoGroup2_[(1 + (1<<16)/131)/10];
		Eco ecoGroup3_[(1 + (1<<16)/131)];
	};

	struct TreeStat {
		colorT toMove;
		std::string SAN;
		int resultW, resultD, resultB;
		double exp;
		int ngames, nexp;

	public:
		TreeStat();
		void add(int result, int eloW, int eloB);
		bool operator<(const TreeStat& cmp) const { return ngames > cmp.ngames; }

	private:
		static double expVect_[1600];
	};

	scidBaseT() { Init(); }
	~scidBaseT();

	errorT Open (fileModeT mode,
	             const char* filename = "",
	             bool create = true,
	             const Progress& progress = Progress());

	errorT Close ();

	std::string newFilter();
	void deleteFilter(const char* filterName);
	HFilter getFilter(const char* filterName) const;

	const std::string& getFileName() const { return fileName_; }
	bool isReadOnly() const { return (fileMode==FMODE_ReadOnly); }
	gamenumT numGames() const { return idx->GetNumGames(); }
	errorT getExtraInfo(const std::string& tagname, std::string* res) const;
	errorT setExtraInfo(const std::string& tagname, const char* new_value);

	const IndexEntry* getIndexEntry(gamenumT g) const {
		return idx->GetEntry(g);
	}
	const NameBase* getNameBase() const {
		return nb;
	}
	FastGame getGame(const IndexEntry* ie) const {
		return gfile->ReadGame(ie->GetOffset(), ie->GetLength());
	}
	errorT getGame(const IndexEntry* ie, ByteBuffer* bb) const {
		return gfile->ReadGame(bb, ie->GetOffset(), ie->GetLength());
	}

	errorT importGame(scidBaseT* sourceBase, uint gNum);
	errorT importGames(scidBaseT* sourceBase, const HFilter& filter, const Progress& progress);
	template <class T, class P>
	errorT importGames(T& codec, const P& progress, uint& nImported, std::string& errorMsg);

	errorT saveGame(Game* game, bool clearCache, gamenumT idx = IDX_NOT_FOUND);

	bool getFlag(uint flag, uint gNum) const {
		return idx->GetEntry(gNum)->GetFlag (flag);
	}
	errorT setFlag(bool value, uint flag, uint gNum);
	errorT setFlag(bool value, uint flag, const HFilter& filter);
	errorT invertFlag(uint flag, uint gNum);
	errorT invertFlag(uint flag, const HFilter& filter);

	const Stats& getStats() const;
	std::vector<scidBaseT::TreeStat> getTreeStat(const HFilter& filter);
	uint getNameFreq (nameT nt, idNumberT id) {
		if (nameFreq_[nt].size() == 0) calcNameFreq();
		return nameFreq_[nt][id];
	}

	errorT getCompactStat(uint* n_deleted,
	                      uint* n_unused,
	                      uint* n_sparse,
	                      uint* n_badNameId);
	errorT compact(const Progress& progress);

	SortCache* CreateSortCache(const char* criteria) const {
		return idx->CreateSortCache(nb, criteria);
	}
	void FreeSortCache(const char* criteria) const {
		return idx->FreeSortCache(criteria);
	}
	errorT GetRange(const char *criteria, uint idx, uint count, const HFilter& filter, uint *result) const {
		return this->idx->GetRange(nb, criteria, idx, count, filter, result);
	}
	uint GetRangeLocation(const char *criteria, const HFilter& filter, uint gnumber) const {
		return idx->GetRangeLocation(nb, criteria, filter, gnumber);
	}
	uint GetRangeLocation(const char *criteria, const HFilter& filter, const char* text, uint start, bool forward) const {
		return idx->GetRangeLocation(nb, criteria, filter, text, start, forward);
	}

	void setDuplicates(uint* duplicates) {
		if (duplicates_ != NULL) { delete[] duplicates_; duplicates_ = NULL; }
		duplicates_ = duplicates;
	}
	uint getDuplicates(gamenumT gNum) {
		return (duplicates_ == NULL) ? 0 : duplicates_[gNum];
	}

	//TODO: private:
	/* clearCaches:
	    After changing one or more games this function MUST be called
	    (to update all the caches and write the namebase file and index header)
	    - gNum: id of the game changed (IDX_NOT_FOUND update all the games)
	*/
	errorT clearCaches(gamenumT gNum = IDX_NOT_FOUND, bool writeFiles = true);

	Index* idx;       // the Index file in memory for this base.
	NameBase* nb;      // the NameBase file in memory.
	bool inUse;       // true if the database is open (in use).
	treeT tree;
	TreeCache treeCache;
	ByteBuffer* bbuf;
	Filter* dbFilter;
	Filter* treeFilter;


	//TODO: this vars do not belong to scidBaseT class
	Game* game;       // the active game for this base.
	int gameNumber;   // game number of active game.
	bool gameAltered; // true if game is modified
	UndoRedo<Game, 100> gameAlterations;

private:
	GFile* gfile;
	std::string fileName_; // File name without ".si" suffix
	fileModeT fileMode; // Read-only, write-only, or both.
	std::vector< std::pair<std::string, Filter*> > filters_;
	mutable Stats* stats_;
	std::vector <int> nameFreq_ [NUM_NAME_TYPES];
	uint* duplicates_; // For each game: idx of duplicate game + 1 (0 if there is no duplicate).

	scidBaseT(const scidBaseT&);
	scidBaseT& operator=(const scidBaseT&);
	void Init();
	void clear();
	errorT addGameHelper(scidBaseT* sourceBase, uint gNum);
	errorT saveGameHelper(IndexEntry* iE, ByteBuffer* bbuf,  gamenumT oldIdx = IDX_NOT_FOUND);
	void calcNameFreq ();

	Filter* fetchFilter(uint idx) const {
		if (idx == 0) return dbFilter;
		if (idx == 1) return treeFilter;
		idx -= 2;
		if (idx >= filters_.size()) return 0;
		return filters_[idx].second;
	}
	Filter* fetchFilter(const std::string& name) const {
		Filter* res = 0;
		if (name == "dbfilter") res = dbFilter;
		else if (name == "tree") res = treeFilter;
		else {
			for (uint i=0; i < filters_.size(); i++) {
				if (filters_[i].first == name) {
					res = filters_[i].second;
					break;
				}
			}
		}
		return res;
	}
};

inline void scidBaseT::TreeStat::add(int result, int eloW, int eloB) {
	ngames++;
	double r = 0;
	switch (result) {
		case RESULT_White: resultW++; r = 1; break;
		case RESULT_Draw: resultD++; r = 0.5; break;
		case RESULT_Black: resultB++; break;
		default: return;
	}
	if (eloW == 0 || eloB == 0) return;
	int eloDiff = eloB - eloW;
	if (eloDiff < 800 && eloDiff >= -800) {
		exp += r - expVect_[eloDiff+800];
		nexp++;
	}
}

template <class T, class P>
inline errorT scidBaseT::importGames(T& codec, const P& progress, uint& nImported, std::string& errorMsg) {
	errorT res;
	Game g;
	nImported = 0;
	while ((res = codec.parseNext(&g)) != ERROR_NotFound) {
		if (res != OK) continue;

		res = saveGame(&g, false);
		if (res != OK) break;

		if ((++nImported % 200) == 0) {
			if (!progress.report(codec.countParsed(), codec.countTotal())) {
				res = ERROR_UserCancel;
				break;
			}
		}
	}

	errorMsg = codec.getErrors();
	clearCaches();
	progress.report(1,1);

	if (res == ERROR_NotFound) res = OK;
	return res;
}

inline errorT scidBaseT::invertFlag(uint flag, uint gNum) {
	return setFlag(! getFlag(flag, gNum), flag, gNum);
}

inline errorT scidBaseT::invertFlag(uint flag, const HFilter& filter) {
	errorT res = OK;
	for (gamenumT i = 0, n = numGames(); i < n; i++) {
		if (*filter && filter.get(i) == 0) continue;
		res = invertFlag(flag, i);
		if (res != OK) return res;
	}
	return res;
}

inline errorT scidBaseT::setFlag(bool value, uint flag, uint gNum){
	ASSERT(gNum < idx->GetNumGames());
	IndexEntry* ie = idx->FetchEntry (gNum);
	ie->SetFlag (flag, value);
	errorT res = idx->WriteEntry (ie, gNum, false);
	if (stats_ != NULL) { delete stats_; stats_ = NULL;}
	// TODO: necessary only for sortcaches with SORTING_deleted (and SORTING_flags when implemented)
	// idx->IndexUpdated(gNum);
	return res;
}

inline errorT scidBaseT::setFlag(bool value, uint flag, const HFilter& filter) {
	errorT res = OK;
	for (gamenumT gNum = 0, n = numGames(); gNum < n; gNum++) {
		if (*filter && filter.get(gNum) == 0) continue;
		res = setFlag(value, flag, gNum);
		if (res != OK) return res;
	}
	return res;
}



#endif

