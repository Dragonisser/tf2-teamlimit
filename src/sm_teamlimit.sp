#include <sourcemod>
#include <tf2_stocks>
#include <sdktools_functions>
#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo = {
	name = "Teamlimit",
	author = "Dragonisser",
	description = "Prevents joining a team at a given limit",
	version = "1.0",
	url = "http://www.sourcemod.net/"
};

ConVar sm_team_joinlimit;
ConVar g_cvMustJoinTeam;
int team_spec = 0;
int team_red = 0;
int team_blu = 0;
int team_count = 0;

TFTeam team_new = 0;
TFTeam team_old = 0;

public void OnPluginStart() {
	HookEvent("player_team", EventPlayerTeam);
	HookEvent("game_start", EventGameStart);
	HookEvent("round_start", EventRoundStart);
	
	RegAdminCmd("sm_LimitInfo", Command_LimitInfo, ADMFLAG_SLAY);
	RegAdminCmd("sm_SetTeamLimit", Command_SetTeamLimit, ADMFLAG_SLAY);
	
	AddCommandListener(OnTeamChangeRequested, "jointeam");

	sm_team_joinlimit = CreateConVar("sm_team_joinlimit", "12", "Default total teamlimit");
	//sm_team_joinlimit.AddChangeHook(OnTeamlimitChanged);
	CreateConVar("sm_tl_version", "1.0", "Version of Plugin. Do not change!");
	AutoExecConfig(true, "plugin_teamlimit");
}

public Action Command_LimitInfo(int client, int args) {
	char strTeamName[64];
	int team_joinlimit = FindConVar("sm_team_joinlimit").IntValue;
	team_spec = GetTeamClientCount(1);
	team_red = GetTeamClientCount(2);
	team_blu = GetTeamClientCount(3);
	team_count = team_blu + team_red;
	int client_score = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iTotalScore", _, client);
	TFTeam client_team = TF2_GetClientTeam(client);
	GetTeamName(view_as<int>(client_team), strTeamName, sizeof(strTeamName));
	
	ReplyToCommand(client, "############# TEAMLIMIT ##############");
	ReplyToCommand(client, "[SM] client_score: %d", client_score);
	ReplyToCommand(client, "[SM] client_team: %s", strTeamName);
	ReplyToCommand(client, "[SM] team_spec: %d", team_spec);
	ReplyToCommand(client, "[SM] team_blu: %d", team_blu);
	ReplyToCommand(client, "[SM] team_red: %d", team_red);
	ReplyToCommand(client, "[SM] team_count: %d / sm_team_joinlimit: %d", team_count, team_joinlimit);
	ReplyToCommand(client, "#######################################");
	
	return Plugin_Handled;
}

public Action Command_SetTeamLimit(int client, int args) {
	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	SetConVarInt(sm_team_joinlimit, StringToInt(arg1));
	ReplyToCommand(client, "[SM] Set TeamLimit to %d", StringToInt(arg1));
	
	sm_team_joinlimit = FindConVar("sm_team_joinlimit");
	team_red = GetTeamClientCount(2);
	team_blu = GetTeamClientCount(3);
	team_count = team_blu + team_red;
	
	int[][] scoreTable_red = new int[MAXPLAYERS][2], scoreTable_blue = new int[MAXPLAYERS][2];
	
	int numValidScores_red, numValidScores_blue;
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			char client_name[64];
			GetClientName(i, client_name, sizeof(client_name));
			int score = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iTotalScore", _, i);
			int team = GetClientTeam(i);
		
			if(team == 2) {
				scoreTable_red[numValidScores_red][0] = i;
				scoreTable_red[numValidScores_red][1] = score;
				numValidScores_red++;
			} else if(team == 3) {
				scoreTable_blue[numValidScores_blue][0] = i;
				scoreTable_blue[numValidScores_blue][1] = score;
				numValidScores_blue++;
			}
		}
	}
	
	SortCustom2D(scoreTable_red, numValidScores_red, MySortingFunc);
	SortCustom2D(scoreTable_blue, numValidScores_blue, MySortingFunc);

	if(team_count < sm_team_joinlimit.IntValue){
		PrintToChatAll("[TL] Teams are no longer full (%d/%d).", team_count, sm_team_joinlimit.IntValue);
	} else {
		
		int player_overlimit = team_count - sm_team_joinlimit.IntValue;
		int team_red_spec = 0, team_blue_spec = 0;
		
		if(player_overlimit == 1) {
			team_blue_spec = 1;
		} else if(IsEven(player_overlimit)) {
			team_red_spec = player_overlimit / 2;
			team_blue_spec = player_overlimit / 2;
		} else {
			team_red_spec = player_overlimit / 2;
			team_blue_spec = (player_overlimit / 2) + 1;
		}
		
		for (int j = 1; j <= player_overlimit; j++) {
			for (int k = 0; k < team_red_spec; k++) {
				if (scoreTable_red[k][0] != 0) {
					TF2_ChangeClientTeam(scoreTable_red[k][0], TFTeam_Spectator);
				}
			}
			for (int l = 0; l < team_blue_spec; l++) {
				if (scoreTable_blue[l][0] != 0) {
					TF2_ChangeClientTeam(scoreTable_blue[l][0], TFTeam_Spectator);
				}
			}
		}
		
		PrintToChatAll("[TL] Teams are now full (%d/%d).", team_count - player_overlimit, sm_team_joinlimit.IntValue);
	}
	return Plugin_Handled;
}

public int MySortingFunc(int[] a, int[] b, const int[][] table, Handle handle) {
    int aScore = a[1], bScore = b[1];
    
    if (aScore > bScore) {
        return -1;
    } else if (aScore < bScore) {
        return 1;
    }
    return 0;
}

bool IsEven(int iNum) { 
    return iNum % 2 == 0; 
}

public Action EventGameStart(Event event, const char[] name, bool dontBroadcast) {
	
	sm_team_joinlimit = FindConVar("sm_team_joinlimit");
	team_red = GetTeamClientCount(2);
	team_blu = GetTeamClientCount(3);
	team_count = team_blu + team_red;
	
	if(team_count < sm_team_joinlimit.IntValue){
		PrintToChatAll("[TL] Teams are no longer full (%d/%d).", team_count, sm_team_joinlimit.IntValue);
	} else {
		PrintToChatAll("[TL] Teams are now full (%d/%d).", team_count, sm_team_joinlimit.IntValue);
	}
}
public Action EventRoundStart(Event event, const char[] name, bool dontBroadcast) {
	
	sm_team_joinlimit = FindConVar("sm_team_joinlimit");
	team_red = GetTeamClientCount(2);
	team_blu = GetTeamClientCount(3);
	team_count = team_blu + team_red;
	
	if(team_count < sm_team_joinlimit.IntValue){
		PrintToChatAll("[TL] Teams are no longer full (%d/%d).", team_count, sm_team_joinlimit.IntValue);
	} else {
		PrintToChatAll("[TL] Teams are now full (%d/%d).", team_count, sm_team_joinlimit.IntValue);
	}
}



public Action OnTeamChangeRequested(int client, const char[] name, int argc) {
	sm_team_joinlimit = FindConVar("sm_team_joinlimit");

	int team_remove = 0;
	
	if(team_new == TFTeam_Red){
		team_red = team_red + 1;
	} else if(team_new == TFTeam_Blue){
		team_blu = team_blu + 1;
	} else if(team_new == TFTeam_Spectator || team_new == TFTeam_Unassigned){
		if(team_old == TFTeam_Red || team_old == TFTeam_Blue){
			team_remove = -1;
		} else {
			team_remove = 0;
		}
	}
	
	int team_count = team_blu + team_red + team_remove;

	if (team_count == sm_team_joinlimit) {
		return Plugin_Handled;
	}

}

public Action EventPlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	team_red = GetTeamClientCount(2);
	team_blu = GetTeamClientCount(3);

	TFTeam team_new = view_as<TFTeam>(GetEventInt(event, "team"));
	TFTeam team_old = view_as<TFTeam>(GetEventInt(event, "oldteam"));
}
