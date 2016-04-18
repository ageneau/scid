'use strict';

var res;
var assert = require('assert');
var scid = require('./build/Debug/scid');

var fn = './Blitz';
var baseId = scid.base("open", fn);
console.log("base ID: " + baseId);
var numGames = scid.base("numGames", baseId)
// scid.filter("count", baseId, "dbfilter")
// scid.base("filename", baseId)
// scid.filter("isWhole", baseId, "dbfilter")
scid.base("sortcache", baseId, "create", "i-d-")
scid.base("gameslist", baseId, 0, 11, "dbfilter", "i-d-")
var autoload = scid.base("extra", baseId, "autoload")
scid.game("load", autoload)
scid.game("number")
scid.game("tag", "get", "Extra")
scid.game("info", "white")
scid.game("info", "welo")
scid.game("pgn", "-symbols", "1", "-indentVar", "1", "-indentCom", "1", "-space", "0", "-format", "color", "-column", "0", "-short", "1", "-markCodes", "0")

// res = scid.base("stats", baseId, "dates")
// console.log("Stats: " + res);
// res = scid.filter("stats", "all")
// console.log("Stats all: " + res);
// res = scid.base("close", baseId)
// console.log("res: " + res);
