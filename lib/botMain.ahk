﻿#NoEnv
SendMode Input

optDevConsole = 0
__Log("- idolBot v" . version . " by Hachifac (bobby@avoine.ca) -")
__Log("- Crusaders of The Lost Idols bot -")

FileCreateDir, logs
FileCreateDir, settings
FileCreateDir, stats

Gosub, _BotLoadSettings
Gosub, _BotLoadCycles
Gosub, _BotLoadCrusaders
Gosub, _BotSetHotkeys

statsChestsThisRun = 0
statsChestsThisSession = 0
statsIdolsThisSession = 0

Gosub, _BotLoadStats

; Include the lists
#include lib/listKeys.ahk
#include lib/listCampaigns.ahk

; Include the GUIs
#include lib/guiMain.ahk
CoordMode, Pixel, Client
CoordMode, Mouse, Client

lastProgressCheck = 0

botLookingForCursor := false ; Quite important little bool, set to true when the _BotGetCurrentLevel timer occurs, it pauses the loot items phase because threads gets messy
botLevelCursorCoords := [1, 2, 3, 4, 5]
botLevelCursorCoords[1] := [745, 11, 785, 130]
botLevelCursorCoords[2] := [780, 11, 825, 130]
botLevelCursorCoords[3] := [817, 11, 863, 130]
botLevelCursorCoords[4] := [856, 11, 905, 130]
botLevelCursorCoords[5] := [904, 11, 943, 130]
botLevelCurrentCursor = 0
botLevelPreviousCursor = 0
botCurrentLevel = 0
botTrackCurrentLevel := false
botTempTrackCurrentLevel := false
botSprintModeCheck := false
botCurrentLevelTimeout = 0 
botBuffsRarity := ["C", "U", "R", "E"]
botBuffs := ["Gold", "Power", "Speed", "Crit", "Click", "Splash"]
botBuffsCoords := [494, 110]
botBuffsGoldCTimer := botBuffsGoldUTimer := botBuffsGoldRTimer := botBuffsGoldETimer := 0
botBuffsPowerCTimer := botBuffsPowerUTimer := botBuffsPowerRTimer := botBuffsPowerETimer := 0
botBuffsSpeedCTimer := botBuffsSpeedUTimer := botBuffsSpeedRTimer := botBuffsSpeedETimer := 0
botBuffsCritCTimer := botBuffsCritUTimer := botBuffsCritRTimer := botBuffsCritETimer := 0
botBuffsClickCTimer := botBuffsClickUTimer := botBuffsClickRTimer := botBuffsClickETimer := 0
botBuffsSplashCTimer := botBuffsSplashUTimer := botBuffsSplashRTimer := botBuffsSplashETimer := 0

rightKeyInterrupt := false
rightKeyStop := false

Gosub, _BotTimers

botPhase = -1 ; -1 = bot not launched, 0 = bot in campaign selection screen, 1 = initial stuff like looking for overlays, waiting for the game to fully load, 2 = maxing the levels/ main dps and upgrades, 3 = reset phase
botRunLaunchTime := 0
botLastRelaunch := 0
botLaunchTime := 0
botSession = 0
botRelaunched := false
botAutoProgressCheck := false
botResets = 0
idolsCount = 0

now = 0
botRelaunching := false
botSkipJim := false

botMaxAllCount = 0
botBuffsSpeedTimer = 0

botSkipToReset := false
optLastChatRoom := optChatRoom

global currentCIndex := [1, 1]
global currentCCoords := [36, 506]
global botCrusaderPixels := Object()
global botCrusaderPixelsTemp := Object()
global levelCapPixels := Object()

; Bot loop
idolBot:
	FileGetSize, Output, logs/logs.txt, M
	if (Output >= 10) {
		FileMove, logs/logs.txt, logs/logs_old.txt
		FileDelete, logs/logs.txt
	}
	IfWinExist, Crusaders of The Lost Idols
	{
		WinActivate, Crusaders of The Lost Idols
		if (optMoveGameWindow > 0) {
			Gosub, _BotMoveGame
		}
		; Self-explanatory
		if (botPhase = -1) {
			__GUIShowPause(true)
			Loop {
				if (botPhase > -1) {
					Break
				}
			}
		}
		; Campaign selection, the bot will either start a campaign or realize one is already started
		if (botPhase = 0) {
			__Log("Launching bot.")
			now := __UnixTime(A_Now)
			botRunLaunchTime := now
			botLastRelaunch := now
			botLaunchTime := now
			__BotCampaignStart()
			botPhase = 1
		}
		; Campaign selected/game screen loaded/game running
		if (botPhase > 0) {
			__Log("Bot launched.")
			; We look for overlays throughout phase 1 & 2
			attempt = 0
			Loop {
				WinActivate, Crusaders of The Lost Idols
				if (botPhase = 1 or botPhase = 2) {
					Gosub, _BotCloseWindows
				}
				if (botPhase = 1) {
					Sleep, 1000 * optBotClockSpeed
					attempt++
					if (attempt > 2 and optCampaign = 1) {
						attempt = 0
						__Log("Event FP not available.  Trying the backup campaign.")
						__BotCampaignStart(optBackupCampaign)
					}
					if (attempt > 5) {
						attempt = 0
						__BotCampaignStart()
						MouseMove, 740, 480
						Click
					}
					botRelaunching := false
					MouseMove, 550, 50
					__Log("Waiting for the campaign to load.")
					; We look at the left arrow in the crusaders bar, if it's there it means the screen is fully loaded
					PixelGetColor, OutputC, 15, 585, RGB
					if (OutputC = 0xA07107 or OutputC = 0xFFB103) {
						__Log("Campaign loaded.")
						; If the left arrow is gold, it means we're not at the beginning of the characters bar, we're moving back until we detect the gold color
						if (Output != 0xA07107) {
							__Log("Moving the characters bar to the beginning.")
							__BotMoveToFirstPage()
						}
						Gosub, _BotUseBuffs
						; Open options window to see if auto progress is on
						__Log("Initial auto progress check...")
						if (optResetType = 2 or optAutoProgressCheck = 1 or optAutoProgress = 2) {
							__BotSetAutoProgress(true)
						} else {
							__BotSetAutoProgress(false)
						}
						skipJim := __UnixTime(A_Now)
						__Log("Looking for Jim's status.")
						Loop {
							; We look at Jim's buy button to know if we can select the formation
							PixelGetColor, Output, 244, 595, RGB
							; If it's not green, we first look if the right arrow is gold, if it is it means the game already started long ago and Jim is probably maxed, meaning we need to put the formation in right now
							; then we click the monsters until we get some cash to initiate the formation
							; If it's green, in a few seconds the bot will max all levels and some crusaders will get in formation, eventually the formation set will kick in
							if (Output != 0x45D402) {
								; Auto click until Jim lvl up button turns green
								if (__UnixTime(A_Now) - skipJim > 60) {
									__Log("Skipping Jim.")
									botSkipJim := true
									Break
								}
								MouseMove, 695, 325
								Click
								Sleep, 40
								MouseMove, 750, 325
								Click
								Sleep, 40
							} else {
								Break
							}
							if (botSkipJim) {
								Break
							}
						}
						; We look at Jim's buy button one last time, if it's green we're good to go to phase 2
						PixelGetColor, Output, 244, 595, RGB
						if (Output = 0x45D402 or Output = 0x226A01 or botSkipJim = true) {
							botPhase = 2
						}
						; Press space bar to close the events/sales tabs
						Send, {Space}
						Gosub, _BotMaxLevels
						__BotSetFormation(optFormation)
						botMaxAllCount++
						botFirstCycle := true
						botCurrentLevelLastTimeout := __UnixTime(A_Now)
						if (optRelaunchGame = 1 and optRelaunchGameFrequency = 1 and botResets > 0) {
							__Log("Relaunching CoTLI.")
							Sleep, 2500
							Gosub, _BotRelaunch
						}
						; Set Chat Room to optChatRoom
						if (optChatRoom > 0 and (botSession = 0 or botRelaunched = true)) {
							__Log("Setting chat room to " . optChatRoom . ".")
							botRelaunched := false
							Gosub, _BotSetChatRoom
						}
						if (optCheatEngine = 1) {
							Gosub, _BotCEOn
						}
					}
				}
				; Sometimes we get a server failed error, shit happens. We search for it and if it pops up, we relaunch the game.
				ImageSearch, OutputX, OutputY, 0, 0, 997, 671, *100 images/game/serverfailed.png
				if (ErrorLevel = 0) {
					__Log("Server failed error. Relaunching the game.")
					Gosub, _BotRelaunch
					if (optCheatEngine = 1) {
						Gosub, _BotCEOn
					}
				}
				; Upgrade all/max all/max main dps. Final phase until reset phase.
				if (botPhase = 2 or botDelayReset = true) {
					if (botCurrentCycleLoop = 0) {
						botCurrentCycleTime := __UnixTime(A_Now)
					}
					if (botSession = 0) {
						botSession = 1
					}
					if (optChatRoom > 0 and (optLastChatRoom != optChatRoom or botRelaunched = true)) {
						botRelaunched := false
						Gosub, _BotSetChatRoom
					} 
					MouseMove, 740, 480
					Sleep, 100 * optBotClockSpeed
					Click
					
					if (optSameLevelTimeout = 1 and botCurrentLevelTimeout > optSameLevelTimeoutDelay and botTrackCurrentLevel = true) {
						__Log("Same level timeout.")
						botPhase = 3
						botSkipToReset := true
					}
					
					if (botSkipToReset = false) {
						if ((botCycles[botCurrentCycle].loop = "" or botCycles[botCurrentCycle].loop = 0) and (botCycles[botCurrentCycle].duration = "" or botCycles[botCurrentCycle].duration = 0) and (botCycles[botCurrentCycle].level = "" or botCycles[botCurrentCycle].level = 0)) {
							botCurrentCycleLoop = 0
						}
						if (botCycles[botCurrentCycle].level = "" or botCycles[botCurrentCycle].level > botCurrentLevel) {
							if (botCycles[botCurrentCycle].duration = "" or (__UnixTime(A_Now) - botCurrentCycleTime < botCycles[botCurrentCycle].duration)) {
								if (botCycles[botCurrentCycle].loop = "" or botCurrentCycleLoop < botCycles[botCurrentCycle].loop) {
									for cL in botCycles[botCurrentCycle].cyclesList {
										if (botSkipToReset = true) {
											Break
										}
										if (StrLen(botCycles[botCurrentCycle].cyclesList[cL]) > 1) {
											if (RegExMatch(botCycles[botCurrentCycle].cyclesList[cL], "iO)PickGold\(([\d]+)\)", f)) {
												__BotPickGold(f.1)
											} else if (RegExMatch(botCycles[botCurrentCycle].cyclesList[cL], "iO)PickGold", f)) {
												__BotPickGold(optLootItemsDuration)
											} else if (RegExMatch(botCycles[botCurrentCycle].cyclesList[cL], "iO)MaxLevels", f)) {
												Gosub, _BotMaxLevels
											} else if (RegExMatch(botCycles[botCurrentCycle].cyclesList[cL], "iO)UpgradeAll", f)) {
												Gosub, _BotUpgAll
											} else if (RegExMatch(botCycles[botCurrentCycle].cyclesList[cL], "iO)MaxAll", f)) {
												Gosub, _BotMaxAll
											} else if (RegExMatch(botCycles[botCurrentCycle].cyclesList[cL], "iO)LevelCrusader\(([\d|\w]+)\)", f)) {
												__BotLevelCrusader(f.1)
											} else if (RegExMatch(botCycles[botCurrentCycle].cyclesList[cL], "iO)LevelMainDPS", f)) {
												if (__UnixTime(A_Now) - botRunLaunchTime > (optMainDPSDelay * 60) and optMainDPS != "None") {
													__BotLevelCrusader(optMainDPS)
												}
											} else if (RegExMatch(botCycles[botCurrentCycle].cyclesList[cL], "iO)SetFormation\(([\d]+)\)", f)) {
												__BotSetFormation(f.1)
											} else if (RegExMatch(botCycles[botCurrentCycle].cyclesList[cL], "iO)SetFormation", f)) {
												__BotSetFormation(optFormation)
											} else if (RegExMatch(botCycles[botCurrentCycle].cyclesList[cL], "iO)Wait\(([\d]+)\)", f)) {
												Sleep, % f.1 * 1000 * optBotClockSpeed
											} else if (RegExMatch(botCycles[botCurrentCycle].cyclesList[cL], "iO)UseSkill\(([\d]+)\)", f)) {
												__BotUseSkill(f.1)
											} else if (RegExMatch(botCycles[botCurrentCycle].cyclesList[cL], "iO)UseSkills", f)) {
												Gosub, __BotUseSkills
											} else if (RegExMatch(botCycles[botCurrentCycle].cyclesList[cL], "iO)UseBuffs", f)) {
												Gosub, _BotUseBuffs
											} else if (RegExMatch(botCycles[botCurrentCycle].cyclesList[cL], "iO)CheatEngineOn", f)) {
												Gosub, _BotCEOn
											} else if (RegExMatch(botCycles[botCurrentCycle].cyclesList[cL], "iO)CheatEngineOff", f)) {
												Gosub, _BotCEOff
											} else if (RegExMatch(botCycles[botCurrentCycle].cyclesList[cL], "iO)ClickingOn", f)) {
												optTempClicking = 1
											} else if (RegExMatch(botCycles[botCurrentCycle].cyclesList[cL], "iO)ClickingOff", f)) {
												optTempClicking = 0
											}
										}
									}
									botCurrentCycleLoop++
								} else {
									__Log("Next cycle.")
									botCurrentCycle++
									botCurrentCycleLoop = 0
								}
							} else {
								__Log("Next cycle.")
								botCurrentCycle++
								botCurrentCycleLoop = 0
							}
						} else {
							__Log("Next cycle.")
							botCurrentCycle++
							botCurrentCycleLoop = 0
						}
					}

						
					; If the last time we did an auto progress check is >= than autoProgressCheckDelay, we initiate an auto progress check
					if ((optResetType = 2 or optAutoProgressCheck = 1) and __UnixTime(A_Now) - lastProgressCheck >= optAutoProgressCheckDelay) {
						; Every autoProgressCheckDelay seconds we take a look if Auto Progress is still activated, if it's not it means we died so achieved the highest zone we could, we have to reset
						lastProgressCheck = % __UnixTime(A_Now)
						__Log("Auto progress check for max progress.")
						if (__BotCheckAutoProgress() = false) {
							if (__UnixTime(A_Now) - botRunLaunchTime < optResetGracePeriod) {
								; Stuck at beginning, might be the formation not active
								__Log("Might be stuck at the beginning.")
								__BotSetFormation(optFormation)
								Sleep, 100 * optBotClockSpeed
								Send, {g}
							} else {
								botPhase = 3
							}
						}
					}
						
					if (optResetType = 3 and __UnixTime(A_Now) - botRunLaunchTime >= (optRunTime * 60)) {
						botSkipToReset := true
						botPhase = 3
					}
					
					if (optResetType = 4) {
						if (botCurrentLevel >= optResetOnLevel) {
							__Log("Level " . optResetOnLevel . " reached.")
							botSkipToReset := true
							botPhase = 3
						}
					}
				}
				; If optRunTime time elapsed or phase is set at 3, we reset
				if (botPhase = 3 and optResetType > 1) {
					if (botCheatEngine = true) {
						Gosub, _BotCEOff
					}
					botDelayReset := false
					resetPhase = 0
					__Log("Cannot progress further, time to reset.")
					; Move to reset crusader
					if (resetPhase = 0) {
						if (optUseChests = 1) {
							__Log("Using chests before reset.")
							MouseMove, 795, 480
							Sleep, 25 * optBotClockSpeed
							Click
							Sleep, 500 * optBotClockSpeed
							MouseMove, 160, 555
							Sleep, 25 * optBotClockSpeed
							Click
							chestFound := false
							Loop {
								if (chestFound == true) {
									Break
								}
								Sleep, 1000 * optBotClockSpeed
								Loop {
									ImageSearch, OutputX, OutputY, 0, 505, 1000, 675, *100 images/game/chests_reset.png
									if (ErrorLevel = 0) {
										Sleep, 100 * optBotClockSpeed
										ImageSearch, OutputX2, OutputY2, 0, 505, 1000, 675, *100 images/game/chests_reset.png
										if (ErrorLevel = 0) {
											if (OutputX2 = OutputX and OutputY2 = OutputY) {
												__Log("Found the chests.")
												Break
											} else {
												if (A_Index > 9) {
													__Log("Cannot find the chests. It seems unstable.")
													Break
												}
											}
										}
									} else {
										if (A_Index > 9) {
											__Log("Cannot find the chests.")
											Break
										}
									}
									Sleep, 1000 * optBotClockSpeed
								}
								Loop {
									ImageSearch, OutputX, OutputY, OutputX - 50, OutputY, OutputX, OutputY + 75, *100 images/game/chests_reset_x%optUseChestsAmount%.png
									if (ErrorLevel = 0) {
										__Log("Using " . optUseChestsAmount . " chests.")
										MouseMove, OutputX + 5, OutputY + 5
										Sleep, 100 * optBotClockSpeed
										Click
										Break
									} else {
										__Log("Cannot open " . optUseChestsAmount . " chests.")
										Break
									}
								}
								Loop {
									Sleep, 1000 * optBotClockSpeed
									ImageSearch, OutputX, OutputY, 345, 345, 495, 385, *100 images/game/chests_reset_yes.png
									if (ErrorLevel = 0) {
										ImageSearch, OutputX, OutputY, 345, 345, 495, 385, *100 images/game/chests_reset_yes.png
										if (ErrorLevel = 0) {
											__Log("Yes button found.")
											MouseMove, OutputX + 5, OutputY + 5
											Sleep, 100 * optBotClockSpeed
											Click
											Break
										}
									} else {
										if (A_Index > 9) {
											__Log("Cannot find the yes button.")
											Break
										}
									}
								}
								Loop {
									Sleep, 500 * optBotClockSpeed
									ImageSearch, OutputX, OutputY, 415, 20, 505, 55, *100 images/game/chest_loot.png
									if (ErrorLevel = 0) {
										__Log("Chests opening window.")
										Loop {
											if (chestFound == true) {
												Break
											}
											MouseMove, 135, 40
											Sleep, 500 * optBotClockSpeed
											ImageSearch, OutputX, OutputY, 885, 5, 930, 45, *100 images/game/close.png
											if (ErrorLevel = 0) {
												MouseMove, OutputX + 5, OutputY + 5
												Sleep, 100 * optBotClockSpeed
												Click
												Loop {
													Sleep, 500 * optBotClockSpeed
													ImageSearch, OutputX, OutputY, 905, 605, 985, 650, *100 images/game/chests_reset_close.png
													if (ErrorLevel = 0) {
														Sleep, 500 * optBotClockSpeed
														ImageSearch, OutputX, OutputY, 905, 605, 985, 650, *100 images/game/chests_reset_close.png
														if (ErrorLevel = 0) {
															__Log("Closing the chests window.")
															MouseMove, OutputX + 5, OutputY + 5
															Sleep, 100 * optBotClockSpeed
															Click
															Sleep, 1000 * optBotClockSpeed
															ImageSearch, OutputX, OutputY, 298, 90, 340, 130, *150 images/game/cog.png
															if (ErrorLevel = 0) {
																MouseMove, 740, 480
																Sleep, 100 * optBotClockSpeed
																Click
																Sleep, 500 * optBotClockSpeed
																chestFound := true
																Break
															} else {
																__Log("Still in the chests window.")
															}
														} else {
															if (A_Index > 9) {
																__Log("Cannot find the close button.")
																Break
															}
														}
													} else {
														if (A_Index > 9) {
															__Log("Cannot find the close button.")
															Break
														}
													}
													Break
												}
											}
										}
									} else {
										if (A_Index > 9) {
											__Log("Couldn't find the chests window.")
											Break
										}
									}
								}
							}
							if (chestFound == false) {
								__Log("Couln't find the chests.")
								MouseMove, 940, 630
								Click
								Sleep, 500 * optBotClockSpeed
								MouseMove, 740, 480
								Click
								Sleep, 500 * optBotClockSpeed
							}
						}
						resetPhase = 1
						Gosub, _BotMaxLevels
					}
					if (resetPhase = 1) {
						resetAttempt = 0
						Loop {
							Click
							__Log("Moving to reset crusader.")
							if (optAutoProgress = 1) {
								__BotSetAutoProgress(false)
								Sleep, 2000
							}
							__BotMoveToFirstPage()
							Sleep, 500 * optBotClockSpeed
							__BotMoveToCrusader("nate")
							Sleep, 2000 * optBotClockSpeed
							Break
						}
						Loop {
							__Log("Waiting for the reset warning window.")
							ImageSearch, OutputRWX, OutputRWY, 281, 116, 717, 235, *100 images/game/resetwarning.png
							if (ErrorLevel = 0) {
								__Log("Reset warning window found.")
								resetPhase = 2
								Break
							} else {
								MouseMove, 675, 650
								Sleep, 100 * optBotClockSpeed
								Click
								Sleep, 100 * optBotClockSpeed
								MouseMove, 760, 650
								Sleep, 100 * optBotClockSpeed
								Click
								MouseMove, 815, 650
								Sleep, 100 * optBotClockSpeed
								Click
								Sleep, 1000
								resetAttempt++
							}
							if (resetAttempt > 10) {
								__Log("Failed attempt.")
								Break
							}
						}
					}
					if (resetPhase = 2) {
						resetPhase = 3
						failedReset := false
						Loop {
							__Log("Waiting for the big red button.")
							ImageSearch, OutputRB, OutputRB, 439, 479, 671, 601, *100 images/game/redbutton.png
							if (ErrorLevel = 0) {
								__Log("Clicking the red button.")
								Break
							} else {			
								; Reset button
								ImageSearch, OutputRWX, OutputRWY, 281, 116, 717, 235, *100 images/game/resetwarning.png
								if (ErrorLevel = 0) {
									MouseMove, 426, 528
									Sleep, 500 * optBotClockSpeed
									Click
									Sleep, 500 * optBotClockSpeed
								}
								ImageSearch,,, 287, 242, 472, 289, *100 images/game/failedreset.png
								if (ErrorLevel = 0) {
									__Log("Failed reset. Relaunching.")
									failedReset := true
									Gosub, _BotRelaunch
									Break
								}
							}
							Sleep, 1000
						}
						if (failedReset = false) {
							Loop {
								ImageSearch, OutputIS, OutputIS, 439, 479, 671, 601, *100 images/game/idolscontinue.png
								if (ErrorLevel = 0) {
									__Log("Calculating the idols.")
									idolsCount := __BotGetIdolsCount()
									FileAppend, % __UnixTime(A_Now) . ":" . idolsCount, stats/idols.txt
									statsIdolsPastDay := 0
									Loop, read, stats/idols.txt
									{
										break := StrSplit(A_LoopReadLine, ":")
										if (__UnixTime(A_Now) - break[1] <= 86400) {
											FileAppend, % break[1] . ":" . break[2] . "`n", stats/idols_temp.txt
											statsIdolsPastDay := statsIdolsPastDay + break[2]
										}
									}
									FileDelete, stats/idols.txt
									FileMove, stats/idols_temp.txt, stats/idols.txt
									
									IniRead, statsIdolsAllTime, stats/stats.txt, Idols, alltime, 0
									statsIdolsAllTime += idolsCount
									statsIdolsThisSession += idolsCount
									
									statsRunTime := __UnixTime(A_Now) - botRunLaunchTime
									
									IniWrite, % statsIdolsAllTime, stats/stats.txt, Idols, alltime
									IniWrite, % statsIdolsPastDay, stats/stats.txt, Idols, pastday
									IniWrite, % idolsCount, stats/stats.txt, Idols, lastrun
									IniWrite, % statsRunTime, stats/stats.txt, Idols, lastruntime
									
									IniWrite, % statsChestsThisRun, stats/stats.txt, Chests, lastrun
									IniWrite, % statsRunTime, stats/stats.txt, Chests, lastruntime
									statsChestsThisRun = 0
									
									botLevelCurrentCursor = 0
									botLevelPreviousCursor = 0
									botCurrentLevel = 0
									botResets++
									
									botCurrentCycle = 1
									botCurrentCycleLoop = 0
									botCurrentCycleTime = 0
									botCurrentLevelTimeout = 0
									
									if (botResets = 1) {
										statsIdolsFirstReset := idolsCount
										botRunTimeFirstReset := statsRunTime
									}
									
									if (botResets > 1) {
										GuiControl, BotGUI:, guiMainStatsIdolsPerHour, % Round((statsIdolsThisSession - statsIdolsFirstReset) / (__UnixTime(A_Now) - botLaunchTime - botRunTimeFirstReset) * 60 * 60)
									}
									
									bI = 1
									Loop, % botBuffs.length() {
										Loop, % botBuffsRarity.length() {
											bB := botBuffs[bI]
											bR := botBuffsRarity[A_Index]
											botBuffs%bB%%bR%Timer := 0
										}
										bI++
									}
									
									MouseMove, 507, 550
									Sleep, 500 * optBotClockSpeed
									Click
									Sleep, 500 * optBotClockSpeed
									Break
								} else {
									MouseMove, 210, 95
									Sleep, 500 * optBotClockSpeed
									Click
									Sleep, 500 * optBotClockSpeed
								}
							}
						}
					}
					if (resetPhase = 3) {
						__Log("Start a new campaign.")
						__BotCampaignStart()
						botSkipJim := false
						botPhase = 1
						Gosub, _BotTimers
						Sleep, 100 * optBotClockSpeed
					}
				}
				if (optRelaunchGame = 1 and optRelaunchGameFrequency > 1) {
					if ((__UnixTime(A_Now) - botLastRelaunch) / 60 >= (optRelaunchGameFrequency - 1) * 60) {
						__Log((optRelaunchGameFrequency - 1) * 60 . " minutes elapsed. Time to reset.")
						Gosub, _BotRelaunch
						if (botCheatEngine = true) {
							Gosub, _BotCEOn
						}
					}
				}
			}
		}
	}
	IfWinNotExist, Crusaders of The Lost Idols
	{
		__Log("Game not found.")
	}
	Return

_BotTimers:
	if (optBotLighter = 1) {
		Gosub, _GUIPos
		SetTimer, _GUIPos, 10000
		SetTimer, _BotScanForChests, Off
		SetTimer, _BotNextLevel, 500
		SetTimer, _BotCloseWindows, 30000
	} else {
		SetTimer, _GUIPos, 100
		SetTimer, _BotScanForChests, 1000
		SetTimer, _BotNextLevel, 100
		SetTimer, _BotCloseWindows, 10000
	}
	SetTimer, _BotGetCurrentLevel, 1000
	SetTimer, _BotBlackWipe, 100
	SetTimer, _BotForceFocus, 1000
	Return
	
; Set the GUI below the game
_GUIPos:
	IfWinExist, Crusaders of The Lost Idols
	{
		WinGetPos, X, Y, W, H, Crusaders of The Lost Idols
		bW = 0
		if (A_OSVersion >= "10." && A_OSVersion < "W") {
			SysGet, bW, 32
		}
		if (X != oldX or Y != oldY) {
			oldX := X
			oldY := Y
			nY := A_ScreenHeight - (A_ScreenHeight - Y) + H - bW
			nW := W
			nX := X + W / 2 - 613 / 2 + 2
			Gui, BotGUI: Show, x%nX% y%nY% w575 h35 NoActivate, idolBot
		}
		if (botPhase > -1) {
			if (optResetType = 3) {
				timeLeft := Round(((optRunTime * 60) - (__UnixTime(A_Now) - botRunLaunchTime)) / 60)
				minutesSTR = minute
				if (timeLeft > 1) {
					minutesSTR := minutesSTR . "s"
				}
				
			}
			if (optResetType = 4) {
				levelsLeft := optResetOnLevel - botCurrentLevel
				GuiControl, BotGUI:, guiMainTimeLeft, Levels left: %levelsLeft%
			}
			
			GuiControl, BotGUI:, guiMainStatsResets, % botResets
			GuiControl, BotGUI:, guiMainStatsBottingTime, % __UnixToTime(__UnixTime(A_Now) - botLaunchTime)
			GuiControl, BotGUI:, guiMainStatsIdolsLastReset, % idolsCount
			GuiControl, BotGUI:, guiMainStatsIdolsTotal, % statsIdolsThisSession
			resetIn = --
			if (optResetType = 3) {
				resetIn := Round(((optRunTime * 60) - (__UnixTime(A_Now) - botRunLaunchTime)) / 60) . "m"
			}
			if (optResetType = 4) {
				resetIn := optResetOnLevel - botCurrentLevel . " levels"
			}
			GuiControl, BotGUI:, guiMainStatsResetIn, % resetIn
		}
	}
	Return

; Pause key
_BotPause:
	CoordMode, Pixel, Client
	CoordMode, Mouse, Client
	if (botPhase = -1) {
		botPhase = 0
		__GUIShowPause(false)
	} else {
		Pause,, 1
		if (botPhase = 2 and !A_IsPaused) {
			rightKeyInterrupt := true
			if (optPromptCurrentLevel = 1 and optResetType = 4) {
				Gosub, _GUICurrentLevel
			}
			rightKeyInterrupt := false
		}
	}
	if (botPhase >= 0) {
		if (A_IsPaused) {
			__Log("Paused.")
			__GUIShowPause(true)
		} else {
			__Log("Unpaused.")
			/*
			SetTitleMatchMode, 3
			WinActivate, idolBot ahk_class AutoHotkeyGUI
			WinActivate, idolBot Dev ahk_class AutoHotkeyGUI
			WinActivate, Crusaders of The Lost Idols
			SetTitleMatchMode, 1
			*/
			__GUIShowPause(false)
			if ((botPhase = 1 or botPhase = 2) and optResetType != 2 and optAutoProgressCheck = 0 and optAutoProgress = 1) {
				Gosub, _BotCloseWindows
				__BotSetAutoProgress(false)
			}
			if ((botPhase = 1 or botPhase = 2) and optAutoProgress = 2) {
				Gosub, _BotCloseWindows
				__BotSetAutoProgress(true)
			}
		}
	}
	WinActivate, Crusaders of The Lost Idols
	Return
	
; Force start key
_BotForceStart:
	__Log("Force starting the bot.")
	if (botPhase < 0) {
		now := __UnixTime(A_Now)
		botRunLaunchTime := now
		botLastRelaunch := now
		botLaunchTime := now
		botCurrentLevelLastTimeout := __UnixTime(A_Now)
		Gosub, _BotPause
		; Open options window to see if auto progress is on
		__Log("Initial auto progress check...")
		if (optResetType = 2 or optAutoProgressCheck = 1 or optAutoProgress = 2) {
			__BotSetAutoProgress(true)
		} else {
			__BotSetAutoProgress(false)
		}
		if (botCheatEngine = true) {
			Gosub, _BotCEOn
		}
		botPhase = 2
	} else {
		if (botPhase = 1) {
			botSkipJim := true
		}
	}
	Return
	
; Force reset key
_BotForceReset:
	__Log("Force resetting the bot.")
	botPhase = 3
	botSkipToReset := true
	botFirstCycle := false
	Return
	
; Next cycle key
_BotNextCycle:
	if (botCurrentCycle < botCycles.MaxIndex()) {
		__Log("Advancing to the next cycle.")
		botCurrentCycle++
		botCurrentCycleLoop = 0+
	}
	Return
	
; Dev console key = ~
#IfWinActive Crusaders of The Lost Idols
SC029::
#IfWinActive idolBot ahk_class AutoHotkeyGUI
SC029::
	if (optDevConsole = 0) {
		optDevConsole = 1
		WinGetPos, X, Y, W, H, Crusaders of The Lost Idols
		nX := X + W
		nY := Y + H - 677
		Gui, BotGUIDev: Show, x%nX% y%nY% w300 h675 NoActivate, idolBot Dev
		if (optDevLogging != 1) {
			Gosub, _GUIDevLogging
		}
	} else {
		optDevConsole = 0
		Gui, BotGUIDev: Hide
	}
	Return
#IfWinActive

_BotSetHotkeys:
	if (optPauseHotkey2) {
		Hotkey, %optPauseHotkey1% & %optPauseHotkey2%, _BotPause
	} else {
		Hotkey, $%optPauseHotkey1%, _BotPause
	}
	if (optReloadHotkey2) {
		optReloadHotkey = %optReloadHotkey1% & %optReloadHotkey2%
	} else {
		optReloadHotkey := optReloadHotkey1
	}
	Hotkey, %optReloadHotkey%, _BotReload
	if (optExitHotkey2) {
		optExitHotkey = %optExitHotkey1% & %optExitHotkey2%
	} else {
		optExitHotkey := optExitHotkey1
	}
	Hotkey, %optExitHotkey%, _BotExit
	if (optForceStartHotkey2) {
		optForceStartHotkey = %optForceStartHotkey1% & %optForceStartHotkey2%
	} else {
		optForceStartHotkey := optForceStartHotkey1
	}
	Hotkey, %optForceStartHotkey%, _BotForceStart
	if (optForceResetHotkey2) {
		optForceResetHotkey = %optForceResetHotkey1% & %optForceResetHotkey2%
	} else {
		optForceResetHotkey := optForceResetHotkey1
	}
	Hotkey, %optForceResetHotkey%, _BotForceReset
	if (optNextCycleHotkey2) {
		optNextCycleHotkey = %optNextCycleHotkey1% & %optNextCycleHotkey2%
	} else {
		optNextCycleHotkey := optNextCycleHotkey1
	}
	Hotkey, %optNextCycleHotkey%, _BotNextCycle
	Return

; Self-explanatory
__GUIShowPause(status) {
	Global optResetType
	if (status = false) {
		GuiControl, BotGUI:, BotStatus, images/gui/running.png
	} else {
		GuiControl, BotGUI:, BotStatus, images/gui/paused.png
		GuiControl, BotGUI:Choose, guiMainTabs, 1
	}
	Return
}

_BotCloseWindows:
	if (botAutoProgressCheck = false and (botPhase = 1 or botPhase = 2)) {
		CoordMode, Pixel, Client
		CoordMode, Mouse, Client
		PixelGetColor, OutputCW, 15, 585, RGB
		if (OutputCW = 0x503803  or OutputCW = 0x805901) {
			__Log("Might have found an overlay.")
			ImageSearch, OutputCWX, OutputCWY, 0, 0, 997, 671, *100 images/game/close.png
			if (ErrorLevel = 0) {
				__Log("Overlay closed.")
				MouseMove, OutputCWX + 10, OutputCWY + 10
				Sleep, 100 * optBotClockSpeed
				Click
			}
		}
		ImageSearch, OutputGRX, OutputGRY, 815, 370, 935, 410, *100 images/game/gimmerubies.png
		if (ErrorLevel = 0) {
			__Log("Obtaining rubies from a daily quest.")
			MouseMove, OutputGRX, OutputGRY
			Click
		}
		ImageSearch, OutputDQX, OutputDQY, 921, 237, 938, 318, *100 images/game/dailyquest_close.png
		if (ErrorLevel = 0) {
			__Log("Closing a daily quest popup.")
			MouseMove, OutputDQX, OutputDQY
			Click
		} 
		ImageSearch, OutputECX, OutputECY, 0, 0, 997, 671, *100 images/game/error_close.png
		if (ErrorLevel = 0) {
			__Log("Closing error message.")
			MouseMove, OutputECX, OutputECY
			Click
		}
	}
	Return

; Relaunch the game, pretty much self-explanatory
_BotRelaunch:
	__Log("Closing the game.")
	botRelaunching := true
	botRelaunchLoadingAttempts = 0
	WinClose, Crusaders of The Lost Idols
	__Log("Waiting on the game to close.")
	WinWaitClose, Crusaders of The Lost Idols,,180
	Loop {
		Process, Exist, Crusaders of The Lost Idols.exe
		if (ErrorLevel > 0) {
			Process, Close, ErrorLevel
		} else {
			Break
		}
		Sleep, 500 * optBotClockSpeed
	}
	__Log("Game closed. Relaunching.")
	Run, steam://Rungameid/402840,,UseErrorLevel
	__Log("Waiting on the game to launch.")
	WinWait, Crusaders of The Lost Idols,,300
	WinActivate, Crusaders of The Lost Idols
	WinMove, Crusaders of The Lost Idols,,15,15
	seen = 0
	__Log("Searching for the start button.")
	Loop {
		ImageSearch, OutputX, OutputY, 358, 512, 640, 560, *150 images/game/start.png
		if (ErrorLevel = 0) {
			seen = 1
			MouseMove, 498, 540
			Sleep, 500 * optBotClockSpeed
			Click
		} else {
			if (seen = 1) {
				Loop {
					PixelGetColor, OutputBR, 371, 523, RGB
					if (OutputBR = 0x989898) {
						botRelaunchLoadingAttempts++
						Sleep, 500
					} else {
						Break
					}
					if (botRelaunchLoadingAttempts > 50) {
						Goto, _BotRelaunch
					}
				}
				botRelaunched := true
				botRelaunching := false
				botLastRelaunch := __UnixTime(A_Now)
				if (optMoveGameWindow > 0) {
					Gosub, _BotMoveGame
				}
				Break
			} else {
				Loop {
					PixelGetColor, OutputBR, 348, 531, RGB
					if (OutputBR = 0x165154) {
						botRelaunchLoadingAttempts++
						Sleep, 500
					} else {
						Break
					}
					if (botRelaunchLoadingAttempts > 50) {
						Goto, _BotRelaunch
					}
				}
			}
		}
		Sleep, 1000 * optBotClockSpeed
	}
	Return

_BotMoveGame:
	WinGetPos,,, OutputW, OutputH
	SysGet, OutputX, 76
	SysGet, OutputX2, 78
	SysGet, OutputY, MonitorWorkArea, 1
	centerX := (A_ScreenWidth - OutputW) / 2
	centerY := (OutputYBottom - OutputH) / 2
	if (optMoveGameWindow = 2) {
		WinMove, OutputX, centerY
	} else if (optMoveGameWindow = 3) {
		WinMove, OutputX, OutputYTop
	} else if (optMoveGameWindow = 4) {
		WinMove, centerX, OutputYTop
	} else if (optMoveGameWindow = 5) {
		WinMove, OutputX2 + OutputX - OutputW, OutputYTop
	} else if (optMoveGameWindow = 6) {
		WinMove, OutputX2 + OutputX - OutputW, centerY
	} else if (optMoveGameWindow = 7) {
		WinMove, centerX, centerY
	}
	Return
	
; Campaign screen, well at least triggered when we think it's the campaign screen or we just did a reset
__BotCampaignStart(campaign := 0) {
	Global botRunLaunchTime
	Global botMaxAllCount
	Global botSkipToReset
	Global optRelaunchGame
	Global optRelaunchGameFrequency
	Global optBotClockSpeed
	Global optCampaign
	if (campaign = 0) {
		campaign := optCampaign
	}
	__Log("Searching for campaign header.")
	Loop {
		; If the campaign.png is found (which is the big campaign text at the top of the screen), we know for sure that's where we are
		; If not found, we look for the cog (settings button), we're instead still/already in the game
		ImageSearch, OutputX, OutputY, 257, 57, 428, 110, *150 images/game/campaign.png
		if (ErrorLevel = 0) {
			__Log("Found the campaign header.")
			__BotSetCampaign(campaign)
			botRunLaunchTime = % __UnixTime(A_Now)
			botMaxAllCount = 0
			botSkipToReset := false
			Break
		} else {
			__Log("Searching for the cog.")
			ImageSearch, OutputX, OutputY, 298, 90, 340, 130, *150 images/game/cog.png
			if (ErrorLevel = 0) {
				__Log("Found the cog.")
				Break
			} else {
				__Log("Didn't find the cog, looking for left arrow instead.")
				PixelGetColor, Output, 15, 585, RGB
				if (Output = 0x503803) {
					Break
				} else {
					__Log("Left arrow not found, looking for the Start button.")
					ImageSearch, OutputX, OutputY, 358, 512, 640, 560, *150 images/game/start.png
					if (ErrorLevel = 0) {
						MouseMove, 498, 540
						Sleep, 500 * optBotClockSpeed
						Click
					}
				}
			}
		}
	}
	Return
}

; Browse the campaign screen to find the desired one, will scan up and down until the proper campaign image is found
__BotSetCampaign(campaign := 0) {
	Global optBotClockSpeed
	Global listCampaigns
	Global optCampaign
	Loop {
		if (campaign = 0) {
			campaign := optCampaign
		}
		if (campaign = 1) {
			MouseMove, 535, 195
			Sleep, 500 * optBotClockSpeed
			Click
			__Log("Starting the event campaign.")
			MouseMove, cX + 508, cY + 83
			Sleep, 100 * optBotClockSpeed
			MouseMove, 785, 570
			Sleep, 25 * optBotClockSpeed
			Click
			Return
		} else {
			__Log("Setting the campaign.")
			fpX = 540
			__Log("Determining if an event is going on.")
			ImageSearch, upX, upY, 565, 150, 610, 185, *150 images/game/campaign_uparrow_active.png
			if (ErrorLevel = 0) {
				__Log("Up arrow active - no event is going on.")
				down = 1
				fpY = 2
			} else {
				ImageSearch, upX, upY, 565, 150, 610, 185, *150 images/game/campaign_uparrow_inactive.png
				if (ErrorLevel = 0) {
					__Log("Up arrow inactive - no event is going on.")
					down = 1
					fpY = 2
				}  else {
					__Log("An event is going on.")
					down = 3
					fpY = 4
				}
			}
			if (down = 1) {
				MouseMove, 585, 165
			} else {
				MouseMove, 585, 310
			}
			Loop, 10 {
				Click
				Sleep, 25 * optBotClockSpeed
			}
			MouseMove, 585, 605
			Loop, % listCampaigns[campaign][down] {
				Click
				Sleep, 250 * optBotClockSpeed
			}
			Sleep, 2000 * optBotClockSpeed
			__Log("Searching for the campaign.")
			ImageSearch, cX, cY, 30, 150, 184, 620, *100 images/game/c%campaign%.png
			if (ErrorLevel = 0) {
				__Log("Found the campaign, starting the free play.")
				MouseMove, cX + 508, cY + 83
				Sleep, 100 * optBotClockSpeed
				Click
				Sleep, 100 * optBotClockSpeed
				MouseMove, 785, 570
				Sleep, 25 * optBotClockSpeed
				Click
				Return
			}
			Sleep, 2000
		}
		ImageSearch, OutputX2, OutputY2, 298, 90, 340, 130, *150 images/game/cog.png
		if (ErrorLevel = 0) {
			__Log("Campaign already started.")
			Return
		}
	}
}

_BotCEOn:
	IfWinExist, Cheat Engine
	{
		rightKeyInterrupt := true
		__Log("Turning Cheat Engine on.")
		WinActivate, Cheat Engine
		SetControlDelay -1
		__Log("Opening the processes.")
		ControlClick, Window9, Cheat Engine
		Sleep, 1000 * optBotClockSpeed
		SetControlDelay -1
		__Log("Opening the process.")
		ControlClick, Button4, Process List
		Sleep, 1000 * optBotClockSpeed
		WinActivate, Cheat Engine
		SetControlDelay -1
		__Log("Enabling speedhack.")
		ControlClick, Enable Speedhack, Cheat Engine
		Sleep, 500 * optBotClockSpeed
		SetControlDelay -1
		__Log("Applying speedhack.")
		ControlClick, Apply, Cheat Engine
		Sleep, 500 * optBotClockSpeed
		WinSet,Bottom,, Cheat Engine
		WinActivate, Crusaders of The Lost Idols
		rightKeyInterrupt := false
		botCheatEngine := true
	}
	Return
	
_BotCEOff:
	IfWinExist, Cheat Engine
	{
		__Log("Turning Cheat Engine off.")
		WinActivate, Cheat Engine
		Sleep, 500 * optBotClockSpeed
		SetControlDelay -1
		ControlClick, Enable Speedhack, Cheat Engine
		Sleep, 500 * optBotClockSpeed
		WinActivate, Crusaders of The Lost Idols
		botCheatEngine := false
	}
	Return
	
; Navigate the crusaders bar to find the desired crusader
; c = crusader
__BotMoveToCrusader(c) {
	global currentCCoords
	global crusaders
	currentCIndex[2] := crusaders[c][2]
	nX := crusaders[c][1] - currentCIndex[1]
	pagesToMove := 0
	if (currentCIndex[1] < crusaders[c][1]) {
		currentCIndex[1] := crusaders[c][1]
		if (nX > 2) {
			pagesToMove := nX - 2
			currentCIndex[1] -= 2
		} else {
			currentCIndex[1] -= nX
		}
	} else {
		currentCIndex[1] := crusaders[c][1]
		pagesToMove := nX
	}
	if (pagesToMove != 0) {
		__BotMoveToPage(pagesToMove)
	}
	currentCCoords[1] := 37 + 315 * (nX - pagesToMove)
	currentCCoords[2] := 506 + 86 * (currentCIndex[2] - 1)
	Return
}

__BotMoveToFirstPage() {
	Global optBotClockSpeed
	currentCIndex := [1, 1]
	Loop {
		PixelGetColor, Output, 15, 585, RGB
		if (Output = 0xA07107) {
			Break
		}
		MouseMove, 15, 585
		Click
		Sleep, 50 * optBotClockSpeed
	}
	Return
}

__BotMoveToLastPage() {
	Global optBotClockSpeed
	Loop {
		PixelGetColor, Output, 985, 585, RGB
		if (Output = 0xA07107) {
			Break
		}
		MouseMove, 985, 585
		Click
		Sleep, 50 * optBotClockSpeed
	}
	Return
}

__BotMoveToPage(p) {
	Global optBotClockSpeed
	Global rightKeyInterrupt
	rightKeyInterrupt := true
	if (p > 0) {
		aX = 985
		d = 1
	} else {
		aX = 15
		p *= -1
		d = 0
	}
	Loop, %p% {
		MouseMove, aX, 585
		PixelGetColor, Output, aX, 585, RGB
		if (Output != 0x000000) {
			Click
		}
		Sleep, 200 * optBotClockSpeed
	}
	rightKeyInterrupt := false
	Return
}

__BotSetCrusadersPixels() {
	Sleep, 1000 * optBotClockSpeed
	initialX = 42
	i = 0
	j = 0
	Loop, 24 {
		if (A_Index = 9 or A_Index = 17) {
			j++
			i = 0
		}
		i++
		PixelGetColor, Output, initialX + (i - 1) * 4, 506 + j * 2, RGB
		botCrusaderPixels[A_Index] := Output
	}
	Return
}

__BotCompareCrusadersPixels() {
	initialX = 42
	i = 0
	j = 0
	Loop, 24 {
		if (A_Index = 9 or A_Index = 17) {
			j++
			i = 0
		}
		i++
		PixelGetColor, Output, initialX + (i - 1) * 4, 506 + j * 2, RGB
		botCrusaderPixelsTemp[A_Index] := Output
	}
	j = 0
	for i, e in botCrusaderPixelsTemp {
		if (botCrusaderPixels[i] = botCrusaderPixelsTemp[i]) {
			j++
		}
	}
	if (j = botCrusaderPixels.MaxIndex()) {
		Return, true
	}
	Return, false
}

; Max levels
_BotMaxLevels:
	__Log("Max all levels.")
	MouseMove, 985, 630
	Click
	Sleep, 500 * optBotClockSpeed
	i = 0
	Loop {
		PixelGetColor, Output, 985, 610, RGB
		if (Output != 0x226501) {
			Break
		}
		Sleep, 10 * optBotClockSpeed
	}
	Return

; Upgrade all
_BotUpgAll:
	__Log("Buy all upgrades.")
	MouseMove, 985, 540
	Click
	Sleep, 500 * optBotClockSpeed
	Loop {
		PixelGetColor, Output, 985, 515, RGB
		if (Output != 0x194D80) {
			Break
		}
		Sleep, 10 * optBotClockSpeed
	}
	Return

_BotMaxAll:
	Gosub, _BotMaxLevels
	botMaxAllCount++
	if (botMaxAllCount >= optUpgAllUntil) {
		__BotPickGold(1)
		Gosub, _BotUpgAll
		botMaxAllCount = 0
	}
	Return

; Use a skill, 0 to use all skills
__BotUseSkill(s) {
	Global optSkillsRoyalCommand
	if (s = 0) {
		Loop, 8 {
			if (A_Index = 6) {
				if (optSkillsRoyalCommand = 1) {
					Send, %A_Index%
				}
			} else {
				Send, %A_Index%
			}
			Sleep, 25 * optBotClockSpeed
		}
	} else {
		Send, %s%
	}
	Return
}

; Sets the auto progress to false
__BotSetAutoProgress(s) {
	t = true
	if (s = 0) {
		t = false
	}
	__Log("Setting auto progress to " . t . ".")
	Global lastProgressCheck
	lastProgressCheck = % __UnixTime(A_Now)
	if (__BotCheckAutoProgress() != s) {
		Send, {g}
	}
	Return
}

; Check if the auto progress is set to true or false
__BotCheckAutoProgress() {
	Global optBotClockSpeed
	Global botAutoProgressCheck
	botAutoProgressCheck := true
	Loop {
		MouseMove, 317, 111
		Sleep, 100 * optBotClockSpeed
		Click
		Sleep, 500 * optBotClockSpeed
		ImageSearch, OutputX2, OutputY2, 395, 180, 543, 242, *100 images/game/options.png
		Sleep, 500 * optBotClockSpeed
		; If the big options header is found, it means the options window is open
		if (ErrorLevel = 0) {
			__Log("Options header found.")
			c = 0
			; Here I use a loop because I've had lots of trouble with AHK giving me the wrong color, so now the bot loops until it finds the proper color
			; (will get stuck here infinitely until the color is found, this seriously can take a few seconds)
			Loop {
				PixelGetColor, Output, 212, 337, RGB
				if (Output = 0xE8CDC5) {
					Break
				} else {
					if (Output = 0x742814 or Output = 0xF7EDEA) {
						c++
						Break
					}
				}
			}
			Loop {
				ImageSearch, OutputX, OutputY, 712, 150, 758, 219, *100 images/game/close.png
				if (ErrorLevel = 0) {
					Loop {
						MouseMove, OutputX + 10, OutputY + 10
						Click
						Sleep, 350 * optBotClockSpeed
						PixelGetColor, Output, 15, 585, RGB
						if (Output = 0xA07107 or Output = 0xFFB103) {
							Break
						} else {
							__Log("Waiting for the options window to close...")
						}
					}
					Break
				}
			}
			if (c = 0) {
				Break
			} else {
				__Log("Auto progress check returned false.")
				botAutoProgressCheck := false
				Return, false
			}
		}
	}
	botAutoProgressCheck := false
	__Log("Auto progress check returned true.")
	Return, true
}

_BotSetChatRoom:
	MouseMove, 1135, 10
	Sleep, 100 * optBotClockSpeed
	Click
	if (optChatRoom > 10) {
		optChatRoom = 10
	}
	MouseMove, 1135, 18 + (21 * optChatRoom)
	Sleep, 100 * optBotClockSpeed
	Click
	optLastChatRoom := optChatRoom
	Return

__BotGetIdolsCount() {
	Loop {
		ImageSearch, lastX, lastY, 415, 205, 720, 285, *100 images/game/iplus.png
		if (ErrorLevel = 0) {
			idols := null
			lastX += 15
			Loop, 9 {
				i := 0
				Loop, 10 {
					WinActivate, Crusaders of The Lost Idols
					ImageSearch, OutputX, OutputY, lastX, lastY - 5, lastX + 20, lastY + 23, *100 images/game/i%i%.png
					if (ErrorLevel = 0) {
						idols := idols . i
						lastX := OutputX + 8
						Break
					}
					i++
				}
				if (ErrorLevel = 1) {
					Break
				}
			}
		}
		__Log("Idols: " . idols)
		Return, idols
	}
}

_BotGetCurrentLevel:
	if (botPhase = 2 and botRelaunching = false and botTrackCurrentLevel = true) {
		CoordMode, Pixel, Client
		CoordMode, Mouse, Client
		rightKeyInterrupt := true
		cC = 1
		Loop {
			PixelGetColor, OutputCL, 308, 104, RGB
			if (OutputCL != 0x290F07) {
				if (cC > 5) {
					cC = 1
				}
				ImageSearch, OutputCLX, OutputCLY, botLevelCursorCoords[cC][1], botLevelCursorCoords[cC][2], botLevelCursorCoords[cC][3], botLevelCursorCoords[cC][4], *25 images/game/lArrow.png
				if (ErrorLevel = 0) {
					if (botLevelCurrentCursor = 0) {
						botLevelPreviousCursor := cC
						botCurrentLevel := cC
					}
					botLevelCurrentCursor := cC
					botLookingForCursor := false 
					Break
				} else {
					cC++
					if (cC > 5) {
						Loop {
							ImageSearch,,, 742, 12, 956, 138, *75 images/game/chest1.png
							if (ErrorLevel = 0) {
								__Log("A chest might be preventing the bot from reading the current level. Waiting.")
								Sleep, 1000
							} else {
								Break
							}
						}
					}
				}
				Sleep, 25 * optBotClockSpeed
			} else {
				Break
			}
		}
		rightKeyInterrupt := false
		if (botLevelCurrentCursor > botLevelPreviousCursor) {
			botCurrentLevelLastTimeout := __UnixTime(A_Now)
			if (botLevelCurrentCursor = 5 and botLevelPreviousCursor = 1) {
				if (botCheatEngine = false) {
					;__Log("Interrupting the right key.")
					;rightKeyStop := true
				}
				botCurrentLevel--
				botLevelPreviousCursor = 5 
			} else {
				if (botLevelCurrentCursor - botLevelPreviousCursor > 1) { ; Lost count
					__Log("Lost level count... Reset might not occur.")
					botLevelPreviousCursor := botLevelCurrentCursor
				} else {
					botCurrentLevel++
					botLevelPreviousCursor++
				}
				rightKeyStop := false
			}
			Sleep, 750 
		} else if (botLevelCurrentCursor < botLevelPreviousCursor) {
			botCurrentLevelLastTimeout := __UnixTime(A_Now)
			if (botLevelCurrentCursor = 1 and botLevelPreviousCursor = 5) {
				rightKeyStop := false
				botCurrentLevel++
				botLevelPreviousCursor = 1
			} else {
				if (botLevelPreviousCursor - botLevelCurrentCursor > 1) { ; Lost count
					__Log("Lost level count... Reset might not occur.")
					botLevelPreviousCursor := botLevelCurrentCursor 
				} else {
					if (botCheatEngine = false) {
						;__Log("Interrupting the right key.")
						;rightKeyStop := true
					}
					botCurrentLevel--
					botLevelPreviousCursor := botLevelCurrentCursor
				}
			}
			Sleep, 750
		}
	}
	Return

_BotBlackWipe:
	if ((botPhase = 2) and botRelaunching = false and botTrackCurrentLevel = true) {
		CoordMode, Pixel, Client
		CoordMode, Mouse, Client
		if (botLevelCurrentCursor = botLevelPreviousCursor) {
			if (botLevelCurrentCursor = 5) {
				if (botSprintModeCheck = false) {
					PixelGetColor, OutputBW, 35, 25, RGB
					if (OutputBW = 0x000000) {
						__Log("Black wipe detected.")
						botSprintModeCheck := true
						Sleep, 750
					}
				} else {
					__Log("Sprint mode! +5 to current level (" . botCurrentLevel + 5 . ").")
					botSprintModeCheck := false
					botCurrentLevel += 5
					botCurrentLevelLastTimeout := __UnixTime(A_Now)
					Sleep, 750
				}
			}
			botCurrentLevelTimeout := __UnixTime(A_Now) - botCurrentLevelLastTimeout
		}
	}
	Return
	
_BotNextLevel:
	if (botPhase = 2 and rightKeyInterrupt = false and botRelaunching = false and rightKeyStop = false) {
		Send, {Right}
	}
	Return
	
_BotScanForChests:
	if (botRelaunching = false and (botPhase = 1 or botPhase = 2)) {
		ImageSearch, OutputX, OutputY, 742, 12, 956, 138, *75 images/game/chest1.png
		if (ErrorLevel = 0) {
			FileAppend, % __UnixTime(A_Now) . ":S", stats/chests.txt
			chestsPastDay = 0
			Loop, read, stats/chests.txt
			{
				break := StrSplit(A_LoopReadLine, ":")
				if (__UnixTime(A_Now) - break[1] <= 86400) {
					FileAppend, % break[1] . ":" . break[2] . "`n", stats/chests_temp.txt
					chestsPastDay++
				}
			}
			statsChestsThisRun++
			statsChestsThisSession++
			FileDelete, stats/chests.txt
			FileMove, stats/chests_temp.txt, stats/chests.txt
			IniRead, chestsAllTime, stats/stats.txt, Chests, alltime, 0
			chestsAllTime += 1
			IniWrite, % chestsAllTime, stats/stats.txt, Chests, alltime
			IniWrite, % chestsPastDay, stats/stats.txt, Chests, pastday
			IniWrite, % statsChestsThisRun, stats/stats.txt, Chests, thisrun
			IniWrite, % statsChestsThisSession, stats/stats.txt, Chests, thissession
			Sleep, 9000
		}
	}
	Return
	
_BotForceFocus:
	IfWinExist, Crusaders of The Lost Idols
	{
		if (botPhase > -1) {
			WinActivate, Crusaders of The Lost Idols
		}
	}
	Return

__BotPickGold(d) {
	Global optTempClicking
	Global optClickDelay
	if (d > 1) {
		__Log("Get the gold and quest items for " . d . " seconds.")
	} else {
		__Log("Get the gold and quest items for " . d . " second.")
	}
	now = % __UnixTime(A_Now)
	i = 1
	Send, {Space}
	max = 8
	if (optTempClicking = 1) {
		max = 4
	}
	while (__UnixTime(A_Now) - now <= d) {
		if (i > max) {
			i = 1
		}
		MouseMove, 650 + i * 30, 320
		if (optTempClicking = 1) {
			Click
		}
		i++
		Sleep, % optClickDelay
	}
	Return
}

__BotSetFormation(f:=0) {
	Global optFormationKey
	if (f > 0) {
		if (f = 1) {
			Send, {q}
		}
		if (f = 2) {
			Send, {w}
		}
		if (f = 3) {
			Send, {e}
		}
	}
	Return
}

__BotLevelCrusader(f) {
	Global rightKeyInterrupt
	Global botCrusaderPixels
	Global currentCCoords
	Global optBotClockSpeed
	rightKeyInterrupt := true
	__Log("Moving to " . f . ".")
	if (botCrusaderPixels.length() = 0) {
		__BotMoveToFirstPage()
		__BotMoveToCrusader(f)
		Sleep, 1000 * optBotClockSpeed
		__BotSetCrusadersPixels()
	} else {
		if (__BotCompareCrusadersPixels() = false) {
			__Log("We might have moved from " . f . ", let's go back.")
			__BotMoveToFirstPage()
			Sleep, 500 * optBotClockSpeed
			__BotMoveToCrusader(f)
			Sleep, 500 * optBotClockSpeed
			__BotSetCrusadersPixels()
		}
	}
	Log("Maxing " . f . ".")
	MouseMove, currentCCoords[1] + 252, currentCCoords[2] + 2
	send, {ctrl down}
	sleep, 100 * optBotClockSpeed
	click
	send, {ctrl up}
	sleep, 100 * optBotClockSpeed
	rightKeyInterrupt := false
}

_BotUseBuffs:
	bI = 1
	now := __UnixTime(A_Now)
	Loop, % botBuffs.length() {
		moved := true
		Loop, % botBuffsRarity.length() {
			bB := botBuffs[bI]
			bR := botBuffsRarity[A_Index]
			if (optBuffs%bB%%bR% = 1) {
				if ((now - botBuffs%bB%%bR%Timer) / 60 >= optBuffs%bB%%bR%Interval) {
					if (botBuffs%bB%%bR%Timer > -1) {
						__Log("Using a " . bB . " [" . bR . "] buff.")
						bX := botBuffsCoords[1] + (40 * (bI - 1))
						bY := botBuffsCoords[2]
						if (moved = true) {
							MouseMove, bX, bY
							Sleep, 1000 * optBotClockSpeed
							Click
							moved := false
						}
						bX2 := bX + 95
						bY2 := bY + 53 + (36 * (A_Index - 1))
						MouseMove, bX2, bY2
						Sleep, 500 * optBotClockSpeed
						Click
						if (optBuffs%bB%%bR%Interval = 0) {
							botBuffs%bB%%bR%Timer = -1
						} else {
							botBuffs%bB%%bR%Timer := now
						}
					}
				}
			}
		}
		bI++
	}
	Return

__BotUseSkills:
	if (optStormRiderMagnify = 0) {
		__Log("Using all skills.")
		__BotUseSkill(0)
	} else {
		Gosub, _BotUseMagnifiedStormRider
		__BotUseSkill(1)
		__BotUseSkill(3)
		__BotUseSkill(4)
		__BotUseSkill(5)
		if (optSkillsRoyalCommand = 1) {
			__BotUseSkill(6)
		}
		__BotUseSkill(8)
	}
	Return
	
_BotUseMagnifiedStormRider:
	PixelSearch, OutputX, OutputY, 382, 449, 421, 488, 0x0000FE,, Fast
	if (ErrorLevel != 0) {
		proceed = 0
		PixelSearch, OutputX, OutputY, 582, 449, 621, 488, 0x0000FE,, Fast
		if (ErrorLevel > 0) {
			proceed++
		} else {
			Return
		}
		PixelSearch, OutputX, OutputY, 582, 449, 621, 488, 0x7F0000,, Fast
		if (ErrorLevel > 0) {
			proceed++
		} else {
			Return
		}
		PixelSearch, OutputX, OutputY, 582, 449, 621, 488, 0x000000,, Fast
		if (ErrorLevel > 0) {
			proceed++
		} else {
			Return
		}
		PixelSearch, OutputX, OutputY, 582, 449, 621, 488, 0xFC9C10,, Fast
		if (ErrorLevel > 0) {
			proceed++
		} else {
			Return
		}
		if (proceed = 4) {
			PixelGetColor, Output, 390, 466, RGB
			if (Output != 0x3A3A3A) {
				__Log("Disabling progress.")
				rightKeyInterrupt := true
				Sleep, 500 * optBotClockSpeed
				__Log("Changing to storm rider formation.")
				Loop, 5 {
					Send, {%optStormRiderFormationKey%}
					Sleep, 1000 * optBotClockSpeed
				}
				Loop, 2 {
					Gosub, _BotMaxLevels
					Gosub, _BotUpgAll
				}
				PixelGetColor, Output, 590, 466, RGB
				if (Output != 0x3A3A3A) {
					__Log("Using Storm Rider.")
					Loop, 5 {
						Send, 2
						Sleep, 600 * optBotClockSpeed
						Send, 7
						Sleep, 600 * optBotClockSpeed
					}
				}
			}
			__Log("Changing back to regular formation and enabling progress.")
			__BotSetFormation(optFormation)
			rightKeyInterrupt := false
		}
	}
	Return
	
; __Log function
__Log(log) {
	Global devLogs
	Global optDevConsole
	Global optDevLogging
	FormatTime, TimeOutput, A_Now, yyyy/M/d - HH:mm:ss
	FileAppend, [%TimeOutput%] %log%`n, logs/logs.txt
	if (optDevLogging = 1) {
		FormatTime, TimeOutput, A_Now, HH:mm:ss
		devLogs = %devLogs%`n%TimeOutput%: %log%
		devLogs := regexreplace(devLogs, "^\s+")
		GuiControl, BotGUIDev:, guiDevLogs, % devLogs
		if (!botDevGUIID) {
			WinGet, botDevGUIID, ID, idolBot Dev ahk_class AutoHotkeyGUI
		}
		WM_VSCROLL = 0x115
		SB_BOTTOM = 7
		SendMessage, WM_VSCROLL, SB_BOTTOM, 0, Edit1, ahk_id %botDevGUIID%
	}
	Return
}

; Transforms YYYYMMDDHH24MISS date format to Unix
__UnixTime(time) {
	result := time
	result -= 19700101000000, s
	Return, result
}

__UnixToTime(time) {
	hours := Floor(time / 3600)
	minutes := Floor(Mod(time, 3600) / 60)
	seconds := Mod(time, 60)
	Return, hours . "h " . minutes . "m " . seconds . "s"
}

; Rounds a number (n) to d decimals
__RoundNumber(n, d) {
	Transform, n, Round, n, d
	e := StrSplit(n, ".")
	if (e[2] != null) {
		e[2] := SubStr(e[2], 1, d)
		n := e[1] . "." . e[2]
	}
	Return, n
}

__UpperCaseFL(s) {
	firstLetter := SubStr(s, 1, 1)
	rest := SubStr(s, 2, StrLen(s))
	StringUpper, firstLetter, firstLetter
	Return firstLetter . rest
}

RegExMatchGlobal(ByRef Haystack, NeedleRegEx) {
   Static Options := "U)^[imsxACDJOPSUX`a`n`r]+\)"
   NeedleRegEx := (RegExMatch(NeedleRegEx, Options, Opt) ? (InStr(Opt, "O", 1) ? "" : "O") : "O)") . NeedleRegEx
   Match := {Len: {0: 0}}, Matches := [], FoundPos := 1
   While (FoundPos := RegExMatch(Haystack, NeedleRegEx, Match, FoundPos + Match.Len[0]))
      Matches[A_Index] := Match
   Return Matches
}

; Self-explanatory
_BotLoadSettings:
	__Log("Reading settings.")
	IniRead, optCampaign, settings/settings.ini, Settings, campaign, 2
	IniRead, optBackupCampaign, settings/settings.ini, Settings, backupcampaign, 2
	IniRead, optFormation, settings/settings.ini, Settings, formation, 1
	IniRead, optMainDPS, settings/settings.ini, Settings, maindps, Jim
	IniRead, optClicking, settings/settings.ini, Settings, clicking, 0
	IniRead, optResetType, settings/settings.ini, Settings, resettype, 2
	IniRead, optUpgAllUntil, settings/settings.ini, Settings, upgalluntil, 5
	IniRead, optMainDPSDelay, settings/settings.ini, Settings, maindpsdelay, 60
	IniRead, optChatRoom, settings/settings.ini, Settings, chatroom, 0
	IniRead, optClickDelay, settings/settings.ini, Settings, clickdelay, 20
	IniRead, optRunTime, settings/settings.ini, Settings, runtime, 60
	IniRead, optResetOnLevel, settings/settings.ini, Settings, resetonlevel, 100
	IniRead, optRelaunchGame, settings/settings.ini, Settings, relaunchgame, 0
	IniRead, optRelaunchGameFrequency, settings/settings.ini, Settings, relaunchgamefrequency, 1
	IniRead, optMoveGameWindow, settings/settings.ini, Settings, movegamewindow, 1
	IniRead, optAutoProgressCheck, settings/settings.ini, Settings, autoprogresscheck, 0
	IniRead, optAutoProgressCheckDelay, settings/settings.ini, Settings, autoprogresscheckdelay, 120
	IniRead, optAutoProgress, settings/settings.ini, Settings, autoprogress, 1
	IniRead, optPromptCurrentLevel, settings/settings.ini, Settings, promptcurrentlevel, 1
	IniRead, optLootItemsDuration, settings/settings.ini, Settings, lootitemsduration, 30
	IniRead, optUseChests, settings/settings.ini, Settings, usechests, 0
	IniRead, optUseChestsAmount, settings/settings.ini, Settings, usechestsamount, 5
	IniRead, optStormRiderFormation, settings/settings.ini, Settings, stormriderformation, 0
	IniRead, optStormRiderMagnify, settings/settings.ini, Settings, stormridermagnify, 1
	IniRead, optSkillsRoyalCommand, settings/settings.ini, Settings, skillsroyalcommand, 0
	IniRead, optSameLevelTimeout, settings/settings.ini, Settings, sameleveltimeout, 1
	IniRead, optSameLevelTimeoutDelay, settings/settings.ini, Settings, sameleveltimeoutdelay, 300
	IniRead, optCheatEngine, settings/settings.ini, Settings, cheatengine, 0
	
	IniRead, optBuffsGoldC, settings/settings.ini, Settings, buffsgoldc, 0
	IniRead, optBuffsGoldCInterval, settings/settings.ini, Settings, buffsgoldcinterval, 0
	IniRead, optBuffsGoldU, settings/settings.ini, Settings, buffsgoldu, 0
	IniRead, optBuffsGoldUInterval, settings/settings.ini, Settings, buffsgolduinterval, 0
	IniRead, optBuffsGoldR, settings/settings.ini, Settings, buffsgoldr, 0
	IniRead, optBuffsGoldRInterval, settings/settings.ini, Settings, buffsgoldrinterval, 0
	IniRead, optBuffsGoldE, settings/settings.ini, Settings, buffsgolde, 0
	IniRead, optBuffsGoldEInterval, settings/settings.ini, Settings, buffsgoldeinterval, 0
	
	IniRead, optBuffsPowerC, settings/settings.ini, Settings, buffspowerc, 0
	IniRead, optBuffsPowerCInterval, settings/settings.ini, Settings, buffspowercinterval, 0
	IniRead, optBuffsPowerU, settings/settings.ini, Settings, buffspoweru, 0
	IniRead, optBuffsPowerUInterval, settings/settings.ini, Settings, buffspoweruinterval, 0
	IniRead, optBuffsPowerR, settings/settings.ini, Settings, buffspowerr, 0
	IniRead, optBuffsPowerRInterval, settings/settings.ini, Settings, buffspowerrinterval, 0
	IniRead, optBuffsPowerE, settings/settings.ini, Settings, buffspowere, 0
	IniRead, optBuffsPowerEInterval, settings/settings.ini, Settings, buffspowereinterval, 0
	
	IniRead, optBuffsSpeedC, settings/settings.ini, Settings, buffsspeedc, 0
	IniRead, optBuffsSpeedCInterval, settings/settings.ini, Settings, buffsspeedcinterval, 0
	IniRead, optBuffsSpeedU, settings/settings.ini, Settings, buffsspeedu, 0
	IniRead, optBuffsSpeedUInterval, settings/settings.ini, Settings, buffsspeeduinterval, 0
	IniRead, optBuffsSpeedR, settings/settings.ini, Settings, buffsspeedr, 0
	IniRead, optBuffsSpeedRInterval, settings/settings.ini, Settings, buffsspeedrinterval, 0
	IniRead, optBuffsSpeedE, settings/settings.ini, Settings, buffsspeede, 0
	IniRead, optBuffsSpeedEInterval, settings/settings.ini, Settings, buffsspeedeinterval, 0
	
	IniRead, optBuffsCritC, settings/settings.ini, Settings, buffscritc, 0
	IniRead, optBuffsCritCInterval, settings/settings.ini, Settings, buffscritcinterval, 0
	IniRead, optBuffsCritU, settings/settings.ini, Settings, buffscritu, 0
	IniRead, optBuffsCritUInterval, settings/settings.ini, Settings, buffscrituinterval, 0
	IniRead, optBuffsCritR, settings/settings.ini, Settings, buffscritr, 0
	IniRead, optBuffsCritRInterval, settings/settings.ini, Settings, buffscritrinterval, 0
	IniRead, optBuffsCritE, settings/settings.ini, Settings, buffscrite, 0
	IniRead, optBuffsCritEInterval, settings/settings.ini, Settings, buffscriteinterval, 0
	
	IniRead, optBuffsClickC, settings/settings.ini, Settings, buffsclickc, 0
	IniRead, optBuffsClickCInterval, settings/settings.ini, Settings, buffsclickcinterval, 0
	IniRead, optBuffsClickU, settings/settings.ini, Settings, buffsclicku, 0
	IniRead, optBuffsClickUInterval, settings/settings.ini, Settings, buffsclickuinterval, 0
	IniRead, optBuffsClickR, settings/settings.ini, Settings, buffsclickr, 0
	IniRead, optBuffsClickRInterval, settings/settings.ini, Settings, buffsclickrinterval, 0
	IniRead, optBuffsClickE, settings/settings.ini, Settings, buffsclicke, 0
	IniRead, optBuffsClickEInterval, settings/settings.ini, Settings, buffsclickeinterval, 0
	
	IniRead, optBuffsSplashC, settings/settings.ini, Settings, buffssplashc, 0
	IniRead, optBuffsSplashCInterval, settings/settings.ini, Settings, buffssplashcinterval, 0
	IniRead, optBuffsSplashU, settings/settings.ini, Settings, buffssplashu, 0
	IniRead, optBuffsSplashUInterval, settings/settings.ini, Settings, buffssplashuinterval, 0
	IniRead, optBuffsSplashR, settings/settings.ini, Settings, buffssplashr, 0
	IniRead, optBuffsSplashRInterval, settings/settings.ini, Settings, buffssplashrinterval, 0
	IniRead, optBuffsSplashE, settings/settings.ini, Settings, buffssplashe, 0
	IniRead, optBuffsSplashEInterval, settings/settings.ini, Settings, buffssplasheinterval, 0
	
	IniRead, optPauseHotkey1, settings/settings.ini, Settings, pausehotkey1, F8
	IniRead, optPauseHotkey2, settings/settings.ini, Settings, pausehotkey2, %A_Space%
	IniRead, optReloadHotkey1, settings/settings.ini, Settings, reloadhotkey1, F9
	IniRead, optReloadHotkey2, settings/settings.ini, Settings, reloadhotkey2, %A_Space%
	IniRead, optExitHotkey1, settings/settings.ini, Settings, exithotkey1, F10
	IniRead, optExitHotkey2, settings/settings.ini, Settings, exithotkey2, %A_Space%
	IniRead, optForceStartHotkey1, settings/settings.ini, Settings, forcestarthotkey1, F7
	IniRead, optForceStartHotkey2, settings/settings.ini, Settings, forcestarthotkey2, %A_Space%
	IniRead, optForceResetHotkey1, settings/settings.ini, Settings, forceresethotkey1, F11
	IniRead, optForceResetHotkey2, settings/settings.ini, Settings, forceresethotkey2, %A_Space%
	IniRead, optNextCycleHotkey1, settings/settings.ini, Settings, nextcyclehotkey1, F12
	IniRead, optNextCycleHotkey2, settings/settings.ini, Settings, nextcyclehotkey2, %A_Space%
	
	IniRead, optCalcIdolsCount, settings/settings.ini, Settings, calcidolscount, 1
	IniRead, optBotLighter, settings/settings.ini, Settings, botlighter, 0
	IniRead, optBotClockSpeed, settings/settings.ini, Settings, botclockspeed, 1
	IniRead, optCheatEngine, settings/settings.ini, Settings, cheatengine, 0
	IniRead, optResetGracePeriod, settings/settings.ini, Settings, resetgraceperiod, 120
	
	if (optPromptCurrentLevel = 120) {
		optPromptCurrentLevel = 0
	}
	if (optFormation = 1) {
		optFormationKey = q
	}
	if (optFormation = 2) {
		optFormationKey = w
	}
	if (optFormation = 3) {
		optFormationKey = e
	}
	if (optStormRiderFormation = 1) {
		optStormRiderFormationKey = q
	}
	if (optStormRiderFormation = 2) {
		optStormRiderFormationKey = w
	}
	if (optStormRiderFormation = 3) {
		optStormRiderFormationKey = e
	}
	if (optStormRiderFormation = 0) {
		optStormRiderFormationKey = optFormationKey
	}
	
	if (optResetType = 5) {
		optResetType = 3
	} else if (optResetType = 6) {
		optResetType = 4
	}
	
	if (optResetType = 4) {
		botTrackCurrentLevel := true
		botTempTrackCurrentLevel := true
	}
	
	StringLower, optMainDPS, optMainDPS
	StringLower, optResetCrusader, optResetCrusader
	optTempCampaign := optCampaign
	optTempBackupCampaign := optBackupCampaign
	optTempFormation := optFormation
	optTempFormationKey := optFormationKey
	optTempMainDPS := optMainDPS
	optTempResetType := optResetType
	optTempClicking := optClicking
	optTempUpgAllUntil := optUpgAllUntil
	optTempMainDPSDelay := optMainDPSDelay
	optTempChatRoom := optChatRoom
	optTempClickDelay := optClickDelay
	optTempRunTime := optRunTime
	optTempResetOnLevel := optResetOnLevel
	optTempRelaunchGame := optRelaunchGame
	optTempRelaunchGameFrequency := optRelaunchGameFrequency
	optTempMoveGameWindow := optMoveGameWindow
	optTempAutoProgressCheck := optAutoProgressCheck
	optTempAutoProgressCheckDelay := optAutoProgressCheckDelay
	optTempAutoProgress := optAutoProgress
	optTempPromptCurrentLevel := optPromptCurrentLevel
	optTempStormRiderFormation := optStormRiderFormation
	optTempStormRiderFormationKey := optStormRiderFormationKey
	optTempStormRiderMagnify := optStormRiderMagnify
	optTempSkillsRoyalCommand := optSkillsRoyalCommand
	optTempSameLevelTimeout := optSameLevelTimeout
	optTempSameLevelTimeoutDelay := optSameLevelTimeoutDelay
	optTempBotLighter := optBotLighter
	optTempBotClockSpeed := optBotClockSpeed
	optTempCheatEngine := optCheatEngine
	optTempResetGracePeriod := optResetGracePeriod
	botCheatEngine := optCheatEngine
	
	optTempBuffsGoldC := optBuffsGoldC
	optTempBuffsGoldCInterval := optBuffsGoldCInterval
	optTempBuffsGoldU := optBuffsGoldU
	optTempBuffsGoldUInterval := optBuffsGoldUInterval
	optTempBuffsGoldR := optBuffsGoldR
	optTempBuffsGoldRInterval := optBuffsGoldRInterval
	optTempBuffsGoldE := optBuffsGoldE
	optTempBuffsGoldEInterval := optBuffsGoldEInterval
	
	optTempBuffsPowerC := optBuffsPowerC
	optTempBuffsPowerCInterval := optBuffsPowerCInterval
	optTempBuffsPowerU := optBuffsPowerU
	optTempBuffsPowerUInterval := optBuffsPowerUInterval
	optTempBuffsPowerR := optBuffsPowerR
	optTempBuffsPowerRInterval := optBuffsPowerRInterval
	optTempBuffsPowerE := optBuffsPowerE
	optTempBuffsPowerEInterval := optBuffsPowerEInterval
	
	optTempBuffsSpeedC := optBuffsSpeedC
	optTempBuffsSpeedCInterval := optBuffsSpeedCInterval
	optTempBuffsSpeedU := optBuffsSpeedU
	optTempBuffsSpeedUInterval := optBuffsSpeedUInterval
	optTempBuffsSpeedR := optBuffsSpeedR
	optTempBuffsSpeedRInterval := optBuffsSpeedRInterval
	optTempBuffsSpeedE := optBuffsSpeedE
	optTempBuffsSpeedEInterval := optBuffsSpeedEInterval
	
	optTempBuffsCritC := optBuffsCritC
	optTempBuffsCritCInterval := optBuffsCritCInterval
	optTempBuffsCritU := optBuffsCritU
	optTempBuffsCritUInterval := optBuffsCritUInterval
	optTempBuffsCritR := optBuffsCritR
	optTempBuffsCritRInterval := optBuffsCritRInterval
	optTempBuffsCritE := optBuffsCritE
	optTempBuffsCritEInterval := optBuffsCritEInterval
	
	optTempBuffsClickC := optBuffsClickC
	optTempBuffsClickCInterval := optBuffsClickCInterval
	optTempBuffsClickU := optBuffsClickU
	optTempBuffsClickUInterval := optBuffsClickUInterval
	optTempBuffsClickR := optBuffsClickR
	optTempBuffsClickRInterval := optBuffsClickRInterval
	optTempBuffsClickE := optBuffsClickE
	optTempBuffsClickEInterval := optBuffsClickEInterval
	
	optTempBuffsSplashC := optBuffsSplashC
	optTempBuffsSplashCInterval := optBuffsSplashCInterval
	optTempBuffsSplashU := optBuffsSplashU
	optTempBuffsSplashUInterval := optBuffsSplashUInterval
	optTempBuffsSplashR := optBuffsSplashR
	optTempBuffsSplashRInterval := optBuffsSplashRInterval
	optTempBuffsSplashE := optBuffsSplashE
	optTempBuffsSplashEInterval := optBuffsSplashEInterval
	
	optTempUseChests := optUseChests
	optTempUseChestsAmount := optUseChestsAmount
	optTempPauseHotkey1 := optPauseHotkey1
	optTempPauseHotkey2 := optPauseHotkey2
	optTempReloadHotkey1 := optReloadHotkey1
	optTempReloadHotkey2 := optReloadHotkey2
	optTempExitHotkey1 := optExitHotkey1
	optTempExitHotkey2 := optExitHotkey2
	optTempForceStartHotkey1 := optForceStartHotkey1
	optTempForceStartHotkey2 := optForceStartHotkey2
	optTempForceResetHotkey1 := optForceResetHotkey1
	optTempForceResetHotkey2 := optForceResetHotkey2
	optTempNextCycleHotkey1 := optNextCycleHotkey1
	optTempNextCycleHotkey2 := optNextCycleHotkey2
	Return

; Self-explanatory
_BotRewriteSettings:
	__Log("Settings changed.")
	StringLower, optMainDPS, optMainDPS
	StringLower, optResetCrusader, optResetCrusader
	IniWrite, % optCampaign, settings/settings.ini, Settings, campaign
	IniWrite, % optBackupCampaign, settings/settings.ini, Settings, backupcampaign
	IniWrite, % optFormation, settings/settings.ini, Settings, formation
	IniWrite, % optMainDPS, settings/settings.ini, Settings, maindps
	IniWrite, % optClicking, settings/settings.ini, Settings, clicking
	IniWrite, % optResetType, settings/settings.ini, Settings, resettype
	IniWrite, % optUpgAllUntil, settings/settings.ini, Settings, upgalluntil
	IniWrite, % optMainDPSDelay, settings/settings.ini, Settings, maindpsdelay
	IniWrite, % optChatRoom, settings/settings.ini, Settings, chatroom
	IniWrite, % optClickDelay, settings/settings.ini, Settings, clickdelay
	IniWrite, % optRunTime, settings/settings.ini, Settings, runtime
	IniWrite, % optResetOnLevel, settings/settings.ini, Settings, resetonlevel
	IniWrite, % optRelaunchGame, settings/settings.ini, Settings, relaunchgame
	IniWrite, % optRelaunchGameFrequency, settings/settings.ini, Settings, relaunchgamefrequency
	IniWrite, % optMoveGameWindow, settings/settings.ini, Settings, movegamewindow
	IniWrite, % optLootItemsDuration, settings/settings.ini, Settings, lootitemsduration
	IniWrite, % optAutoProgressCheck, settings/settings.ini, Settings, autoprogresscheck
	IniWrite, % optAutoProgressCheckDelay, settings/settings.ini, Settings, autoprogresscheckdelay
	IniWrite, % optAutoProgress, settings/settings.ini, Settings, autoprogress
	IniWrite, % optPromptCurrentLevel, settings/settings.ini, Settings, promptcurrentlevel
	IniWrite, % optUseChests, settings/settings.ini, Settings, usechests
	IniWrite, % optUseChestsAmount, settings/settings.ini, Settings, usechestsamount
	IniWrite, % optStormRiderFormation, settings/settings.ini, Settings, stormriderformation
	IniWrite, % optStormRiderMagnify, settings/settings.ini, Settings, stormridermagnify
	IniWrite, % optSkillsRoyalCommand, settings/settings.ini, Settings, skillsroyalcommand
	IniWrite, % optSameLevelTimeout, settings/settings.ini, Settings, sameleveltimeout
	IniWrite, % optSameLevelTimeoutDelay, settings/settings.ini, Settings, sameleveltimeoutdelay

	IniWrite, % optBotLighter, settings/settings.ini, Settings, botlighter
	IniWrite, % optBotClockSpeed, settings/settings.ini, Settings, botclockspeed
	IniWrite, % optCheatEngine, settings/settings.ini, Settings, cheatengine
	IniWrite, % optResetGracePeriod, settings/settings.ini, Settings, resetgraceperiod
	
	
	IniWrite, % optBuffsGoldC, settings/settings.ini, Settings, buffsgoldc
	IniWrite, % optBuffsGoldCInterval, settings/settings.ini, Settings, buffsgoldcinterval
	IniWrite, % optBuffsGoldU, settings/settings.ini, Settings, buffsgoldu
	IniWrite, % optBuffsGoldUInterval, settings/settings.ini, Settings, buffsgolduinterval
	IniWrite, % optBuffsGoldR, settings/settings.ini, Settings, buffsgoldr
	IniWrite, % optBuffsGoldRInterval, settings/settings.ini, Settings, buffsgoldrinterval
	IniWrite, % optBuffsGoldE, settings/settings.ini, Settings, buffsgolde
	IniWrite, % optBuffsGoldEInterval, settings/settings.ini, Settings, buffsgoldeinterval
	
	IniWrite, % optBuffsPowerC, settings/settings.ini, Settings, buffspowerc
	IniWrite, % optBuffsPowerCInterval, settings/settings.ini, Settings, buffspowercinterval
	IniWrite, % optBuffsPowerU, settings/settings.ini, Settings, buffspoweru
	IniWrite, % optBuffsPowerUInterval, settings/settings.ini, Settings, buffspoweruinterval
	IniWrite, % optBuffsPowerR, settings/settings.ini, Settings, buffspowerr
	IniWrite, % optBuffsPowerRInterval, settings/settings.ini, Settings, buffspowerrinterval
	IniWrite, % optBuffsPowerE, settings/settings.ini, Settings, buffspowere
	IniWrite, % optBuffsPowerEInterval, settings/settings.ini, Settings, buffspowereinterval
	
	IniWrite, % optBuffsSpeedC, settings/settings.ini, Settings, buffsspeedc
	IniWrite, % optBuffsSpeedCInterval, settings/settings.ini, Settings, buffsspeedcinterval
	IniWrite, % optBuffsSpeedU, settings/settings.ini, Settings, buffsspeedu
	IniWrite, % optBuffsSpeedUInterval, settings/settings.ini, Settings, buffsspeeduinterval
	IniWrite, % optBuffsSpeedR, settings/settings.ini, Settings, buffsspeedr
	IniWrite, % optBuffsSpeedRInterval, settings/settings.ini, Settings, buffsspeedrinterval
	IniWrite, % optBuffsSpeedE, settings/settings.ini, Settings, buffsspeede
	IniWrite, % optBuffsSpeedEInterval, settings/settings.ini, Settings, buffsspeedeinterval
	
	IniWrite, % optBuffsCritC, settings/settings.ini, Settings, buffscritc
	IniWrite, % optBuffsCritCInterval, settings/settings.ini, Settings, buffscritcinterval
	IniWrite, % optBuffsCritU, settings/settings.ini, Settings, buffscritu
	IniWrite, % optBuffsCritUInterval, settings/settings.ini, Settings, buffscrituinterval
	IniWrite, % optBuffsCritR, settings/settings.ini, Settings, buffscritr
	IniWrite, % optBuffsCritRInterval, settings/settings.ini, Settings, buffscritrinterval
	IniWrite, % optBuffsCritE, settings/settings.ini, Settings, buffscrite
	IniWrite, % optBuffsCritEInterval, settings/settings.ini, Settings, buffscriteinterval
	
	IniWrite, % optBuffsClickC, settings/settings.ini, Settings, buffsclickc
	IniWrite, % optBuffsClickCInterval, settings/settings.ini, Settings, buffsclickcinterval
	IniWrite, % optBuffsClickU, settings/settings.ini, Settings, buffsclicku
	IniWrite, % optBuffsClickUInterval, settings/settings.ini, Settings, buffsclickuinterval
	IniWrite, % optBuffsClickR, settings/settings.ini, Settings, buffsclickr
	IniWrite, % optBuffsClickRInterval, settings/settings.ini, Settings, buffsclickrinterval
	IniWrite, % optBuffsClickE, settings/settings.ini, Settings, buffsclicke
	IniWrite, % optBuffsClickEInterval, settings/settings.ini, Settings, buffsclickeinterval
	
	IniWrite, % optBuffsSplashC, settings/settings.ini, Settings, buffssplashc
	IniWrite, % optBuffsSplashCInterval, settings/settings.ini, Settings, buffssplashcinterval
	IniWrite, % optBuffsSplashU, settings/settings.ini, Settings, buffssplashu
	IniWrite, % optBuffsSplashUInterval, settings/settings.ini, Settings, buffssplashuinterval
	IniWrite, % optBuffsSplashR, settings/settings.ini, Settings, buffssplashr
	IniWrite, % optBuffsSplashRInterval, settings/settings.ini, Settings, buffssplashrinterval
	IniWrite, % optBuffsSplashE, settings/settings.ini, Settings, buffssplashe
	IniWrite, % optBuffsSplashEInterval, settings/settings.ini, Settings, buffssplasheinterval
	
	IniWrite, % optPauseHotkey1, settings/settings.ini, Settings, pausehotkey1
	IniWrite, % optPauseHotkey2, settings/settings.ini, Settings, pausehotkey2
	IniWrite, % optReloadHotkey1, settings/settings.ini, Settings, reloadhotkey1
	IniWrite, % optReloadHotkey2, settings/settings.ini, Settings, reloadhotkey2
	IniWrite, % optExitHotkey1, settings/settings.ini, Settings, exithotkey1
	IniWrite, % optExitHotkey2, settings/settings.ini, Settings, exithotkey2
	IniWrite, % optForceStartHotkey1, settings/settings.ini, Settings, forcestarthotkey1
	IniWrite, % optForceStartHotkey2, settings/settings.ini, Settings, forcestarthotkey2
	IniWrite, % optForceResetHotkey1, settings/settings.ini, Settings, forceresethotkey1
	IniWrite, % optForceResetHotkey2, settings/settings.ini, Settings, forceresethotkey2
	IniWrite, % optNextCycleHotkey1, settings/settings.ini, Settings, nextcyclehotkey1
	IniWrite, % optNextCycleHotkey2, settings/settings.ini, Settings, nextcyclehotkey2
	
	Gosub, _BotTimers
	
	Return
	
_BotLoadCycles:
	if (!FileExist("settings/cycles.txt")) {
	FileAppend,
	(
	; Documentation: https://github.com/Hachifac/idolBot/blob/master/docs/CYCLES.md`n; Do not touch unless you know what you're doing!`n; If you make a mistake, you can delete this file and let the bot rebuild it.`n`n[1:`n%A_Tab%loop: 1`n%A_Tab%cycle: {`n%A_Tab%%A_Tab%PickGold(5)`n%A_Tab%%A_Tab%MaxLevels`n%A_Tab%%A_Tab%Wait(0.1)`n%A_Tab%%A_Tab%SetFormation`n%A_Tab%%A_Tab%PickGold(1)`n%A_Tab%%A_Tab%UpgradeAll`n%A_Tab%%A_Tab%Wait(0.1)`n%A_Tab%%A_Tab%PickGold(1)`n%A_Tab%%A_Tab%UpgradeAll`n%A_Tab%%A_Tab%PickGold(1)`n%A_Tab%%A_Tab%MaxLevels`n%A_Tab%%A_Tab%Wait(0.1)`n%A_Tab%%A_Tab%SetFormation`n%A_Tab%%A_Tab%PickGold(1)`n%A_Tab%%A_Tab%UpgradeAll`n%A_Tab%}`n]`n[2:`n%A_Tab%cycle: {`n%A_Tab%%A_Tab%PickGold`n%A_Tab%%A_Tab%LevelMainDPS`n%A_Tab%%A_Tab%MaxAll`n%A_Tab%%A_Tab%UseSkills`n%A_Tab%%A_Tab%SetFormation`n%A_Tab%%A_Tab%UseBuffs`n%A_Tab%}`n]
	), settings/cycles.txt
}
	botCurrentCycle = 1
	botCurrentCycleLoop = 0
	botCurrentCycleTime = 0
	FileRead, OutputVar, settings/cycles.txt

	userCycles := RegExMatchGlobal(OutputVar, "iUO)(\[(.|`r`n)+\])")

	botCycles := {}
	for i, cycle in userCycles {
		botCycles[i] := {}
		botCycles[i].value := cycle.Value()
		if (RegExMatch(botCycles[i].value, "iO)loop:\s?([\d]+)", loop)) {
			botCycles[i].loop := loop.1
		}
		if (RegExMatch(botCycles[i].value, "iO)duration:\s?([\d]+)", duration)) {
			botCycles[i].duration := duration.1
		}
		if (RegExMatch(botCycles[i].value, "iO)level:\s?([\d]+)", level)) {
			botCycles[i].level := level.1
		}
		if (RegExMatch(botCycles[i].value, "iUO)cycle:\s?{((.|`r`n)+)}", c)) {
			result := c.1
			StringReplace, result, result, %A_TAB%,, All
			botCycles[i].cycle := result
		}
	}
	for c in botCycles {
		cycles := botCycles[c].cycle
		cycles := StrSplit(cycles, "`n")
		cLI = 1
		for cL in cycles {
			if (StrLen(cycles[cL]) > 1) {
				botCycles[c].cyclesList[cLI] := cycles[cL]
				cLI++
			}
		}
	}
	Return
	
_BotLoadCrusaders:
	crusaders := {}
	crusadersSorted :=  null
	Loop {
		FileReadLine, line, lib/crusaders.txt, %A_Index%
		if (ErrorLevel) {
			Break
		}
		cC := StrSplit(line, ":")
		cL := StrSplit(cC[2], ",")
		cC := StrSplit(cC[1], ",")
		for i, crusader in cL {
			crusaders[crusader] := [cC[1], cC[2]]
			crusadersSorted := crusadersSorted . __UpperCaseFL(crusader) . "`n"
		}
	}
	Sort, crusadersSorted
	StringReplace, crusadersSorted, crusadersSorted, `n, |,,-1
	crusadersSorted := "None|" . SubStr(crusadersSorted, 1, StrLen(crusadersSorted) - 1)
	Return
	
_BotLoadStats:
	__Log("Reading stats.")
	IniRead, statsIdolsAllTime, stats/stats.txt, Idols, alltime, 0
	IniRead, statsIdolsPastDay, stats/stats.txt, Idols, pastday, 0
	IniRead, statsIdolsLastRun, stats/stats.txt, Idols, lastrun, 0
	IniRead, statsIdolsLastRunTime, stats/stats.txt, Idols, lastruntime, 0
	IniRead, statsChestsAllTime, stats/stats.txt, Chests, alltime, 0
	IniRead, statsChestsPastDay, stats/stats.txt, Chests, pastday, 0
	IniRead, statsChestsLastRun, stats/stats.txt, Chests, lastrun, 0
	IniRead, statsChestsLastRunTime, stats/stats.txt, Chests, lastruntime, 0
	Return
	
#include lib/guiLabels.ahk