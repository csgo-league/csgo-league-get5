public Action StartKnifeRound(Handle timer) {
  g_HasKnifeRoundStarted = false;
  g_PendingSideSwap = false;

  Get5_MessageToAll("%t", "KnifeIn5SecInfoMessage");
  if (InWarmup()) {
    EndWarmup(5);
  } else {
    RestartGame(5);
  }

  CreateTimer(10.0, Timer_AnnounceKnife);
  return Plugin_Handled;
}

public Action Timer_AnnounceKnife(Handle timer) {
  for (int i = 0; i < 5; i++) {
    Get5_MessageToAll("%t", "KnifeInfoMessage");
  }

  g_HasKnifeRoundStarted = true;
  EventLogger_KnifeStart();
  return Plugin_Handled;
}

static void PerformSideSwap(bool swap) {
  if (swap) {
    int tmp = g_TeamSide[MatchTeam_Team2];
    g_TeamSide[MatchTeam_Team2] = g_TeamSide[MatchTeam_Team1];
    g_TeamSide[MatchTeam_Team1] = tmp;

    for (int i = 1; i <= MaxClients; i++) {
      if (IsValidClient(i)) {
        int team = GetClientTeam(i);
        if (team == CS_TEAM_T) {
          SwitchPlayerTeam(i, CS_TEAM_CT);
        } else if (team == CS_TEAM_CT) {
          SwitchPlayerTeam(i, CS_TEAM_T);
        } else if (IsClientCoaching(i)) {
          int correctTeam = MatchTeamToCSTeam(GetClientMatchTeam(i));
          UpdateCoachTarget(i, correctTeam);
        }
      }
    }
  } else {
    g_TeamSide[MatchTeam_Team1] = TEAM1_STARTING_SIDE;
    g_TeamSide[MatchTeam_Team2] = TEAM2_STARTING_SIDE;
  }

  g_TeamStartingSide[MatchTeam_Team1] = g_TeamSide[MatchTeam_Team1];
  g_TeamStartingSide[MatchTeam_Team2] = g_TeamSide[MatchTeam_Team2];
  SetMatchTeamCvars();
}

public void EndKnifeRound(bool swap) {
  PerformSideSwap(swap);
  EventLogger_KnifeWon(g_KnifeWinnerTeam, swap);
  ChangeState(Get5State_GoingLive);
  CreateTimer(3.0, StartGoingLive, _, TIMER_FLAG_NO_MAPCHANGE);
}

static bool AwaitingKnifeDecision(int client) {
  bool waiting = g_GameState == Get5State_WaitingForKnifeRoundDecision;
  bool onWinningTeam = IsPlayer(client) && GetClientMatchTeam(client) == g_KnifeWinnerTeam;
  bool admin = (client == 0);
  return waiting && (onWinningTeam || admin);
}

public Action Command_VoteCt(int client, int args) {
  if (AwaitingKnifeDecision(client)) {
    if ((g_bVoteStart) && (g_bPlayerCanVote[client])) {
      g_bPlayerCanVote[client] = false;
      g_iVoteCts++;
      PrintToChat(client, "Vote CT cast.");
    } else if((g_bVoteStart) && (!g_bPlayerCanVote[client])) {
        PrintToChat(client, "You have already voted.");
    } else {
      return Plugin_Stop;
    }
  }

  return Plugin_Handled;
}

public Action Command_VoteT(int client, int args) {
  if (AwaitingKnifeDecision(client)) {
    if ((g_bVoteStart) && (g_bPlayerCanVote[client])) {
      g_bPlayerCanVote[client] = false;
      g_iVoteTs++;
      PrintToChat(client, "Vote T cast.");
    } else if((g_bVoteStart) && (!g_bPlayerCanVote[client])) {
        PrintToChat(client, "You have already voted.");
    } else {
      return Plugin_Stop;
    }
  }
  
  return Plugin_Handled;
}

// public Action Command_Stay(int client, int args) {
//   if (AwaitingKnifeDecision(client)) {
//     EndKnifeRound(false);
//     Get5_MessageToAll("%t", "TeamDecidedToStayInfoMessage",
//                       g_FormattedTeamNames[g_KnifeWinnerTeam]);
//   }
//   return Plugin_Handled;
// }

// public Action Command_Swap(int client, int args) {
//   if (AwaitingKnifeDecision(client)) {
//     EndKnifeRound(true);
//     Get5_MessageToAll("%t", "TeamDecidedToSwapInfoMessage",
//                       g_FormattedTeamNames[g_KnifeWinnerTeam]);
//   } else if (g_GameState == Get5State_Warmup && g_InScrimMode &&
//              GetClientMatchTeam(client) == MatchTeam_Team1) {
//     PerformSideSwap(true);
//   }
//   return Plugin_Handled;
// }

// public void Command_VoteCt(int client) {
//   // This value is now false.
//   PrintToChatAll("g_bPlayerCanVote value Command_VoteCt() Pre If condition: %b", g_bPlayerCanVote[client]);
//   if (AwaitingKnifeDecision(client)) {
//     // This is still false.
//     PrintToChatAll("g_bPlayerCanVote value Command_VoteCt() Post If condition: %b", g_bPlayerCanVote[client]);
//     if(g_bPlayerCanVote[client]) {
//       g_bPlayerCanVote[client] = false;
//       g_iVoteCts++;
//       PrintToChat(client, "Vote CT cast.");
//       return;
//     }
//     else if((g_bVoteStart) && !g_bPlayerCanVote[client]) {
//       PrintToChat(client, "You have already voted.");
//       return;
//     }
//     else
//     {
//       PrintToChat(client, "UwU");
//       return;
//     }
//   }
//   return;
// }

// public void Command_VoteT(int client) {
//   PrintToChatAll("g_bPlayerCanVote value Command_VoteT() Pre If condition: %b", g_bPlayerCanVote[client]);
//   if (AwaitingKnifeDecision(client)) {
//     PrintToChatAll("g_bPlayerCanVote value Command_VoteT() Post If condition: %b", g_bPlayerCanVote[client]);
//     if(g_bPlayerCanVote[client]) {
//       g_bPlayerCanVote[client] = false;
//       g_iVoteTs++;
//       PrintToChat(client, "Vote T cast.");
//       return;
//     }
//     else if(g_bVoteStart && !g_bPlayerCanVote[client]) {
//       PrintToChat(client, "You have already voted.");
//       return;
//     }
//     else
//     {
//       PrintToChat(client, "UwU");
//       return;
//     }
//   }
//   return;
// }

public Action Timer_ForceKnifeDecision(Handle timer) {
  if (g_GameState == Get5State_WaitingForKnifeRoundDecision) {
    EndKnifeRound(false);
    Get5_MessageToAll("%t", "TeamLostTimeToDecideInfoMessage",
                      g_FormattedTeamNames[g_KnifeWinnerTeam]);
  }
}

public Action Timer_VoteSide(Handle timer) {
  if (g_iVoteCts > g_iVoteTs) {
    PrintToChatAll("The team has voted for CT.");
  } else {
    PrintToChatAll("The team has voted for T.");
  }
  g_bVoteStart = false;
  g_iVoteCts = 0;
  g_iVoteTs = 0;

  for (int i = 1; i <= MaxClients; i++) {
    g_bPlayerCanVote[i] = true;
  }

}