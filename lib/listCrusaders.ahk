﻿#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

crusaders := Object()
crusaders["bush"] := [1, 1]
crusaders["rabbit"] := crusaders["graham"] := crusaders["warwick"] := [1, 1]
crusaders["emo"] := crusaders["sally"] := crusaders["karen"] := crusaders["turps"] := [2, 1]
crusaders["hermit"] := crusaders["kyle"] := crusaders["draco"] := crusaders["henry"] := crusaders["grandmora"] := [3, 1]
crusaders["princess"] := crusaders["turkey"] := crusaders["rayna"] := crusaders["baenarall"] := [4, 1]
crusaders["jason"] := crusaders["pete"] := crusaders["broot"] := crusaders["paul"] := [5, 1]
crusaders["khouri"] := crusaders["momma"] := crusaders["brogon"] := crusaders["halfbloodelf"] := crusaders["foresight"] := [6, 1]
crusaders["sarah"] := crusaders["soldierette"] := crusaders["snickette"] := crusaders["sjin"] := [7, 1]
crusaders["sal"] := crusaders["wendy"] := crusaders["robbie"] := crusaders["val"] := [8, 1] 
crusaders["reginald"] := crusaders["siri"] := crusaders["boggins"] := crusaders["squiggles"] := [9, 1] 
crusaders["merci"] := crusaders["petra"] := crusaders["bat"] := crusaders["polly"] := [10, 1]
crusaders["exterminator"] := crusaders["gloria"] := [11, 1]
crusaders["greyskull"] := crusaders["eiralon"] := [12, 1]
crusaders["jim"] := crusaders["pam"] := crusaders["veronica"] := crusaders["arachnobuddy"] := [1, 2]
crusaders["sasha"] := crusaders["groklok"] := crusaders["mindy"] := crusaders["danni"] := [2, 2]
crusaders["kaine"] := crusaders["monkey"] := crusaders["larry"] := crusaders["bernard"] := [3, 2]
crusaders["natalie"] := crusaders["jack"] := crusaders["billy"] := crusaders["karl"] := [4, 2] 
crusaders["lion"] := crusaders["drizzle"] := crusaders["bubba"] := crusaders["sisaron"] := [5, 2]
crusaders["gryphon"] := crusaders["rocky"] := crusaders["montana"] := crusaders["darkhelper"] := [6, 2]
crusaders["panda"] := crusaders["santa"] := crusaders["leerion"] := crusaders["katie"] := [7, 2]
crusaders["phoenix"] := crusaders["alan"] := crusaders["frightotron"] := crusaders["spaceking"] := [8, 2]  
crusaders["thalia"] := crusaders["frosty"] := crusaders["littlefoot"] := crusaders["cindy"] := [9, 2] 
crusaders["nate"] := crusaders["kizlblyp"] := crusaders["rudolph"] := [10, 2]
crusaders["shadowqueen"] :=  crusaders["ilsa"] := [11, 2]
crusaders["priestess"] := [12, 2]