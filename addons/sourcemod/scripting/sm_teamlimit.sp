#include <sourcemod>
#include <tf2_stocks>
#include <sdktools_functions>
#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_NAME		"Teamlimit"
#define PLUGIN_AUTHOR	"Dragonisser"
#define PLUGIN_DESC		"Prevents joining a team when the player limit is reached"
#define PLUGIN_VERSION	"1.1.1"
#define PLUGIN_URL		"https://github.com/Dragonisser/tf2-teamlimit"
#define PLUGIN_PREFIX	"[TL]"


public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESC,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

ConVar g_Cvar_JoinLimit;
ConVar g_Cvar_TeamLimitDebug;

int g_iTeamSpec = 0;
int g_iTeamRed = 0;
int g_iTeamBlu = 0;
int g_iTeamCount = 0;

public void OnPluginStart() {
	HookEvent("player_team", EventPlayerTeam);
	HookEvent("game_start", EventGameStart);
	HookEvent("round_start", EventRoundStart);
	
	RegAdminCmd("sm_tl_info", Command_LimitInfo, ADMFLAG_SLAY);
	RegAdminCmd("sm_tl_set", Command_SetTeamLimit, ADMFLAG_SLAY);
	
	g_Cvar_JoinLimit = CreateConVar("sm_tl_joinlimit", "24", "Default total teamlimit", 0, true, 0.0, true, float(MaxClients));
	g_Cvar_TeamLimitDebug = CreateConVar("sm_tl_debug", "0", "Debug mode", 0, true, 0.0, true, 1.0);
	CreateConVar("sm_tl_version", PLUGIN_VERSION, "Version of Plugin. Do not change!", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	AddCommandListener(OnTeamChangeRequested, "jointeam");
	HookConVarChange(g_Cvar_JoinLimit, CvarHookJoinLimit);

	AutoExecConfig(true, "plugin_teamlimit");
}

public Action Command_LimitInfo(int client, int args) {
	char cTeamName[32];
	g_iTeamSpec = GetTeamClientCount(1);
	g_iTeamRed = GetTeamClientCount(2);
	g_iTeamBlu = GetTeamClientCount(3);
	g_iTeamCount = g_iTeamBlu + g_iTeamRed;
	int iClientScore = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iTotalScore", _, client);
	TFTeam clientTeam = TF2_GetClientTeam(client);
	GetTeamName(view_as<int>(clientTeam), cTeamName, sizeof(cTeamName));
	
	ReplyToCommand(client, "############# TEAMLIMIT ##############");
	ReplyToCommand(client, "[TL] client_score: %d", iClientScore);
	ReplyToCommand(client, "[TL] client_team: %s", cTeamName);
	ReplyToCommand(client, "[TL] team spec: %d", g_iTeamSpec);
	ReplyToCommand(client, "[TL] team blue: %d", g_iTeamBlu);
	ReplyToCommand(client, "[TL] team red: %d", g_iTeamRed);
	ReplyToCommand(client, "[TL] team count: %d / sm_tl_joinlimit: %d", g_iTeamCount, g_Cvar_JoinLimit.IntValue);
	ReplyToCommand(client, "#######################################");
	
	return Plugin_Handled;
}

public Action Command_SetTeamLimit(int client, int args) {
	char arg1[1];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	SetConVarInt(g_Cvar_JoinLimit, StringToInt(arg1));
	ReplyToCommand(client, "[TL] Set TeamLimit to %d", StringToInt(arg1));
	
	HandleJoinLimitChange();

	return Plugin_Handled;
}

public Action EventGameStart(Event event, const char[] name, bool dontBroadcast) {
	g_iTeamRed = GetTeamClientCount(2);
	g_iTeamBlu = GetTeamClientCount(3);
	g_iTeamCount = g_iTeamBlu + g_iTeamRed;
	
	if (g_iTeamCount < g_Cvar_JoinLimit.IntValue) {
		PrintToChatAll("[TL] Teams are no longer full (%d/%d).", g_iTeamCount, g_Cvar_JoinLimit.IntValue);
	} else {
		PrintToChatAll("[TL] Teams are now full (%d/%d).", g_iTeamCount, g_Cvar_JoinLimit.IntValue);
	}

	return Plugin_Continue;
}

public Action EventRoundStart(Event event, const char[] name, bool dontBroadcast) {
	g_iTeamRed = GetTeamClientCount(2);
	g_iTeamBlu = GetTeamClientCount(3);
	g_iTeamCount = g_iTeamBlu + g_iTeamRed;
	
	if (g_iTeamCount < g_Cvar_JoinLimit.IntValue) {
		PrintToChatAll("[TL] Teams are no longer full (%d/%d).", g_iTeamCount, g_Cvar_JoinLimit.IntValue);
	} else {
		PrintToChatAll("[TL] Teams are now full (%d/%d).", g_iTeamCount, g_Cvar_JoinLimit.IntValue);
	}

	return Plugin_Continue;
}

public Action OnTeamChangeRequested(int client, const char[] name, int argc) {
	g_iTeamRed = GetTeamClientCount(2);
	g_iTeamBlu = GetTeamClientCount(3);

	int teamRemove = 0;
	TFTeam teamNew;
	TFTeam teamOld;
	
	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));

	if (strcmp(arg1, "red") == 0) {
		teamNew = TFTeam_Red;
	} else if (strcmp(arg1, "blue") == 0) {
		teamNew = TFTeam_Blue;
	} else if (strcmp(arg1, "spectate") == 0) {
		teamNew = TFTeam_Spectator;
	} else if (strcmp(arg1, "unassigned") == 0) {
		teamNew = TFTeam_Unassigned;
	}
	teamOld = TF2_GetClientTeam(client);

	if (teamNew == TFTeam_Red) {
		g_iTeamRed = g_iTeamRed + 1;
		if (teamOld == TFTeam_Blue) {
			g_iTeamBlu = g_iTeamBlu -1;
		}
	} else if (teamNew == TFTeam_Blue) {
		g_iTeamBlu = g_iTeamBlu + 1;
		if (teamOld == TFTeam_Red) {
			g_iTeamRed = g_iTeamRed - 1;
		}
	} else if (teamNew == TFTeam_Spectator || teamNew == TFTeam_Unassigned) {
		if (teamOld == TFTeam_Red || teamOld == TFTeam_Blue) {
			teamRemove = -1;
		}
	}
	
	g_iTeamCount = g_iTeamBlu + g_iTeamRed + teamRemove;

	char clientName[64];
	GetClientName(client, clientName, sizeof(clientName));

	SendDebugMessage("###JoinTeamCommand###");
	SendDebugMessage("client: %s", clientName);
	SendDebugMessage("team old: %d", teamOld);
	SendDebugMessage("team new: %d", teamNew);
	SendDebugMessage("team red: %d", g_iTeamRed);
	SendDebugMessage("team blu: %d", g_iTeamBlu);
	SendDebugMessage("team remove: %d", teamRemove);
	SendDebugMessage("team count: %d", g_iTeamCount);

	if (g_iTeamCount == g_Cvar_JoinLimit.IntValue - 1) {
		PrintToChatAll("[TL] Teams are no longer full (%d/%d).", g_iTeamCount, g_Cvar_JoinLimit.IntValue);
	} else if (g_iTeamCount == g_Cvar_JoinLimit.IntValue) {
		PrintToChatAll("[TL] Teams are now full (%d/%d).", g_iTeamCount, g_Cvar_JoinLimit.IntValue);
	}

	if (g_iTeamCount >= g_Cvar_JoinLimit.IntValue + 1) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action EventPlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	TFTeam teamNew;
	TFTeam teamOld;

	g_iTeamRed = GetTeamClientCount(2);
	g_iTeamBlu = GetTeamClientCount(3);

	teamNew = view_as<TFTeam>(GetEventInt(event, "team"));
	teamOld = view_as<TFTeam>(GetEventInt(event, "oldteam"));

	SendDebugMessage("###TeamChangeEvent###");
	SendDebugMessage("team old: %d", teamOld);
	SendDebugMessage("team new: %d", teamNew);

	return Plugin_Continue;
}

public void CvarHookJoinLimit(Handle cvar, const char[] oldValue, const char[] newValue) {
	HandleJoinLimitChange();
}

public void HandleJoinLimitChange() {
	int playerOverLimit = g_iTeamCount - g_Cvar_JoinLimit.IntValue;

	if (playerOverLimit > 0) {
		PrintToChatAll("[TL] Teams are no longer full (%d/%d).", g_iTeamCount, g_Cvar_JoinLimit.IntValue);
	} else {
		g_iTeamRed = GetTeamClientCount(2);
		g_iTeamBlu = GetTeamClientCount(3);
		g_iTeamCount = g_iTeamBlu + g_iTeamRed;
		
		int[][] scoreTableRed = new int[MAXPLAYERS][2], scoreTableBlue = new int[MAXPLAYERS][2];
		
		int numValidScoresRed, numValidScoresBlue;
		
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				char client_name[64];
				GetClientName(i, client_name, sizeof(client_name));
				int score = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iTotalScore", _, i);
				int team = GetClientTeam(i);
			
				if (team == 2) {
					scoreTableRed[numValidScoresRed][0] = i;
					scoreTableRed[numValidScoresRed][1] = score;
					numValidScoresRed++;
				} else if (team == 3) {
					scoreTableBlue[numValidScoresBlue][0] = i;
					scoreTableBlue[numValidScoresBlue][1] = score;
					numValidScoresBlue++;
				}
			}
		}
		
		SortCustom2D(scoreTableRed, numValidScoresRed, SortAsc);
		SortCustom2D(scoreTableBlue, numValidScoresBlue, SortAsc);

		int teamRedSpec = 0, teamBlueSpec = 0;
		
		if (playerOverLimit == 1) {
			teamBlueSpec = 1;
		} else if (playerOverLimit % 2 == 0) {
			teamRedSpec = playerOverLimit / 2;
			teamBlueSpec = playerOverLimit / 2;
		} else {
			teamRedSpec = playerOverLimit / 2;
			teamBlueSpec = (playerOverLimit / 2) + 1;
		}
		
		for (int j = 1; j <= playerOverLimit; j++) {
			for (int clientRed = 0; clientRed < teamRedSpec; clientRed++) {
				if (scoreTableRed[clientRed][0] != 0) {
					TF2_ChangeClientTeam(scoreTableRed[clientRed][0], TFTeam_Spectator);
					PrintToChat(clientRed, "[TL] You were moved to Spectator since you were topscoring and the joinlimit was lowered");
				}
			}
			for (int clientBlue = 0; clientBlue < teamBlueSpec; clientBlue++) {
				if (scoreTableBlue[clientBlue][0] != 0) {
					TF2_ChangeClientTeam(scoreTableBlue[clientBlue][0], TFTeam_Spectator);
					PrintToChat(clientBlue, "[TL] You were moved to Spectator since you were topscoring and the joinlimit was lowered");
				}
			}
		}
		PrintToChatAll("[TL] Teams are now full (%d/%d).", g_iTeamCount - playerOverLimit, g_Cvar_JoinLimit.IntValue);
	}
}

public void SendDebugMessage (const char[] message, any ...) {
	char buffer[256];

	if (g_Cvar_TeamLimitDebug.BoolValue) {
		VFormat(buffer, sizeof(buffer), message, 2);
		PrintToServer("%s", buffer);
	}
}

public int SortAsc(int[] a, int[] b, const int[][] table, Handle handle) {
    int aScore = a[1], bScore = b[1];

    if (aScore > bScore) {
        return -1;
    } else if (aScore < bScore) {
        return 1;
    }
    return 0;
}