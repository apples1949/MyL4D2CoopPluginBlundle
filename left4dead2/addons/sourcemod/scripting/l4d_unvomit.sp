/*
*	UnVomit - Remove Boomer Screen Effect
*	Copyright (C) 2022 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION 		"1.8"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] UnVomit - Remove Boomer Screen Effect
*	Author	:	SilverShot
*	Descrp	:	Removes the visual vomit effect from a survivor.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=320025
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.8 (14-Jul-2022)
	- Fixed not removing the effect on players when taking over a bot who has been covered in vomit. Thanks to "hefiwhfcds2" for reporting.

1.7 (20-Jun-2022)
	- Fixed the glow not removing on player death. Thanks to "hefiwhfcds2" for reporting.

1.6 (14-Nov-2021)
	- Changes to fix warnings when compiling on SourceMod 1.11.
	- Updated GameData signatures to avoid breaking when detoured by the "Left4DHooks" plugin.

1.5 (12-Sep-2021)
	- Added cvar "l4d_unvomit_flags" to specify users with certain flags to allow unvomit.

1.4 (28-Apr-2021) - Update by "Dragokas"
	- Added cvar "l4d_unvomit_particle" to delay removing the vomit particle effect.
	- Prevent glowing errors in L4D1.

1.3 (15-Feb-2021)
	- Fixed the invalid entity error. Thanks to "Dragokas" for reporting.

1.2 (01-Apr-2020)
	- Fixed incorrect L4D1 Linux signature. Thanks to "Dragokas" for reporting.
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.1 (01-Dec-2019)
	- Added new features and cvars, made into a full plugin for release.

1.0 (20-May-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY

ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarChase, g_hCvarDuration, g_hCvarFlags, g_hCvarGlowC, g_hCvarGlowV, g_hCvarParticle;
bool g_bCvarAllow, g_bMapStarted, g_bCvarChase, g_bLeft4Dead2;
int g_iCvarFlags, g_iCvarGlowC, g_iCvarGlowV, g_iChase[MAXPLAYERS+1];
float g_fCvarDuration, g_fCvarParticle, g_fLastVomit[MAXPLAYERS+1];
Handle g_hSDKVomit, g_hSDKUnVomit;



// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] UnVomit - Remove Boomer Screen Effect",
	author = "SilverShot",
	description = "Removes the visual vomit effect from a survivor.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=320025"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	// ====================================================================================================
	// SDKCALLS
	// ====================================================================================================
	GameData hGameData = new GameData("l4d_unvomit");
	if( hGameData == null ) SetFailState("Failed to load gamedata: l4d_unvomit.txt");

	StartPrepSDKCall(SDKCall_Player);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::OnVomitedUpon") == false ) SetFailState("Failed to find signature: CTerrorPlayer::OnVomitedUpon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKVomit = EndPrepSDKCall();
	if( g_hSDKVomit == null ) SetFailState("Failed to create SDKCall: CTerrorPlayer::OnVomitedUpon");

	StartPrepSDKCall(SDKCall_Player);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::OnITExpired") == false ) SetFailState("Failed to find signature: CTerrorPlayer::OnITExpired");
	g_hSDKUnVomit = EndPrepSDKCall();
	if( g_hSDKUnVomit == null ) SetFailState("Failed to create SDKCall: CTerrorPlayer::OnITExpired");

	delete hGameData;



	// ====================================================================================================
	// CVARS
	// ====================================================================================================
	g_hCvarAllow =			CreateConVar(	"l4d_unvomit_allow",			"1",				"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarChase =			CreateConVar(	"l4d_unvomit_chase",			"1",				"0=Off. 1=Attach a info_goal_infected_chase to players for common infected to chase them.", CVAR_FLAGS );
	g_hCvarDuration =		CreateConVar(	"l4d_unvomit_duration",			"20",				"Duration of the effect (game default: 20). How long to keep the chase and glow enabled.", CVAR_FLAGS );
	g_hCvarFlags =			CreateConVar(	"l4d_unvomit_flags",			"",					"Only users with these flags will be unvomited. Empty = allow all players.", CVAR_FLAGS );
	g_hCvarParticle =		CreateConVar(	"l4d_unvomit_particle",			"0.0",				"0.0=Instant. Duration of the particle effect (game default: 10.0). How long to keep the on-screen green effect enabled.", CVAR_FLAGS );
	if( g_bLeft4Dead2 )
	{
		g_hCvarGlowC =		CreateConVar(	"l4d_unvomit_glow_color",		"255 102 0",		"0=Off. L4D2 only: glow outline on players until vomit reset time. Three values between 0-255 separated by spaces. RGB: Red Green Blue.", CVAR_FLAGS );
		g_hCvarGlowV =		CreateConVar(	"l4d_unvomit_glow_versus",		"201 17 183",		"0=Off. L4D2 only: glow outline in Versus gamemode. Displays the same color to both teams.", CVAR_FLAGS );
	}
	g_hCvarModes =			CreateConVar(	"l4d_unvomit_modes",			"",					"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d_unvomit_modes_off",		"",					"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d_unvomit_modes_tog",		"0",				"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	CreateConVar(							"l4d_unvomit_version",			PLUGIN_VERSION,		"UnVomit plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	//AutoExecConfig(true,					"l4d_unvomit");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarChase.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDuration.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarFlags.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarParticle.AddChangeHook(ConVarChanged_Cvars);
	if( g_bLeft4Dead2 )
	{
		g_hCvarGlowC.AddChangeHook(ConVarChanged_Cvars);
		g_hCvarGlowV.AddChangeHook(ConVarChanged_Cvars);
	}



	// ====================================================================================================
	// OTHER
	// ====================================================================================================
	RegAdminCmd("sm_vomit",		CmdVomit,	ADMFLAG_ROOT, "Cover in bile. Usage: sm_vomit [#userid|name]. No args = target self.");
	RegAdminCmd("sm_unvomit",	CmdUnVomit,	ADMFLAG_ROOT, "Remove effect. Usage: sm_unvomit [#userid|name]. No args = target self.");

	// Translations
	LoadTranslations("common.phrases");

	IsAllowed();
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

public void OnConfigsExecuted()
{
	IsAllowed();
}

void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	char sTemp[32];
	g_hCvarFlags.GetString(sTemp, sizeof(sTemp));
	g_iCvarFlags = ReadFlagString(sTemp);
	g_bCvarChase = g_hCvarChase.BoolValue;
	g_fCvarDuration = g_hCvarDuration.FloatValue;
	g_fCvarParticle = g_hCvarParticle.FloatValue;

	if( g_bLeft4Dead2 )
	{
		g_iCvarGlowC = GetColor(g_hCvarGlowC);
		g_iCvarGlowV = GetColor(g_hCvarGlowV);
	}
}

int GetColor(ConVar cvar)
{
	char sTemp[12], sColors[3][4];
	cvar.GetString(sTemp, sizeof(sTemp));
	ExplodeString(sTemp, " ", sColors, 3, 4);

	int color;
	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);
	return color;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		if( g_bLeft4Dead2 )
			HookEvent("player_death",			Event_PlayerDeath);
		HookEvent("player_now_it",				Event_IsIt, EventHookMode_Pre);
		HookEvent("bot_player_replace",			Event_PlayerReplace);
		g_bCvarAllow = true;
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		if( g_bLeft4Dead2 )
			UnhookEvent("player_death",			Event_PlayerDeath);
		UnhookEvent("player_now_it",			Event_IsIt, EventHookMode_Pre);
		UnhookEvent("bot_player_replace",		Event_PlayerReplace);
		g_bCvarAllow = false;
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if( iCvarModesTog != 0 )
	{
		if( g_bMapStarted == false )
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		RemoveEntity(entity);

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}



// ====================================================================================================
//					COMMAND
// ====================================================================================================
Action CmdVomit(int client, int args)
{
	VomitCommand(client, args, false);
	return Plugin_Handled;
}

Action CmdUnVomit(int client, int args)
{
	VomitCommand(client, args, true);
	return Plugin_Handled;
}

void VomitCommand(int client, int args, bool remove)
{
	if( args > 1 )
	{
		ReplyToCommand(client, "Usage: sm_vomit or sm_unvomit [#userid|name]. No args = target self.");
		return;
	}

	if( args == 1 )
	{
		char arg1[32];
		GetCmdArg(1, arg1, sizeof(arg1));

		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;

		if( (target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			return;
		}

		int target;
		for( int i = 0; i < target_count; i++ )
		{
			target = target_list[i];
			if( remove )	SDKCall(g_hSDKUnVomit, target);
			else			SDKCall(g_hSDKVomit, target, target, true);

			ReplyToCommand(client, "[%sVomit] Performed on %N", remove ? "Un" : "", target);
		}
	} else {
		if( client && IsPlayerAlive(client) )
		{
			if( remove )	SDKCall(g_hSDKUnVomit, client);
			else			SDKCall(g_hSDKVomit, client, client, true);

			ReplyToCommand(client, "[%sVomit] Performed on %N", remove ? "Un" : "", client);
		}
	}
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
Action Timer_Unvomit( Handle timer, int UserId )
{
	int client = GetClientOfUserId(UserId);

	if( client && IsClientInGame(client) )
	{
		SDKCall(g_hSDKUnVomit, client);
	}

	return Plugin_Continue;
}

void Event_PlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("player"));
	if( client && IsClientInGame(client) )
	{
		if( GetEntPropFloat(client, Prop_Send, "m_vomitStart") + 20.0 >= GetGameTime() )
		{
			int bot = GetClientOfUserId(event.GetInt("bot"));

			EventIsIt(client, 20.0 - (GetGameTime() - g_fLastVomit[bot]));

			int entity = g_iChase[bot];
			g_iChase[bot] = 0;

			if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
			{
				RemoveEntity(entity);
			}
		}
	}
}

Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if( client && (g_iCurrentMode == 4 ? g_iCvarGlowV : g_iCvarGlowC) )
	{
		if( GetEntProp(client, Prop_Send, "m_iGlowType") == 3 && GetEntProp(client, Prop_Send, "m_glowColorOverride") == (g_iCurrentMode == 4 ? g_iCvarGlowV : g_iCvarGlowC) )
		{
			SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
			SetEntProp(client, Prop_Send, "m_iGlowType", 0);
		}
	}

	return Plugin_Continue;
}

Action Event_IsIt(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if( client && IsFakeClient(client) == false )
	{
		return EventIsIt(client, g_fCvarDuration);
	}
	else
	{
		g_fLastVomit[client] = GetGameTime();
	}

	return Plugin_Continue;
}

Action EventIsIt(int client, float time)
{
	// Flags - specified users only
	if( g_iCvarFlags != 0 )
	{
		int flags = GetUserFlagBits(client);

		if( !(flags & ADMFLAG_ROOT) && !(flags & g_iCvarFlags) )
		{
			return Plugin_Continue;
		}
	}

	// Remove vomit
	if( g_fCvarParticle )
	{
		CreateTimer(g_fCvarParticle, Timer_Unvomit, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	} else {
		SDKCall(g_hSDKUnVomit, client);
	}

	// Otherwise event fires over and over
	if( GetGameTime() - g_fLastVomit[client] < time )
	{
		// Block event
		return Plugin_Handled;
	} else {
		g_fLastVomit[client] = GetGameTime();

		// Reset glow / fire event
		CreateTimer(time, Timer_Reset, GetClientUserId(client));

		// Glow
		if ( g_bLeft4Dead2 )
		{
			int glow = g_iCurrentMode == 4 ? g_iCvarGlowV : g_iCvarGlowC;
			if( glow )
			{
				SetEntProp(client, Prop_Send, "m_iGlowType", 3);
				SetEntProp(client, Prop_Send, "m_glowColorOverride", glow);
			}
		}

		// Chase
		if( g_bCvarChase )
		{
			int entity = CreateEntityByName("info_goal_infected_chase");
			if( entity != -1 )
			{
				g_iChase[client] = EntIndexToEntRef(entity);

				DispatchSpawn(entity);
				float vPos[3];
				GetClientAbsOrigin(client, vPos);
				vPos[2] += 20.0;
				TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

				SetVariantString("!activator");
				AcceptEntityInput(entity, "SetParent", client);

				static char temp[32];
				Format(temp, sizeof temp, "OnUser4 !self:Kill::%f:-1", time);
				SetVariantString(temp);
				AcceptEntityInput(entity, "AddOutput");
				AcceptEntityInput(entity, "FireUser4");
			}
		}
	}

	return Plugin_Continue;
}

Action Timer_Reset(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if( client && IsClientInGame(client) )
	{
		// Glow
		if( g_bLeft4Dead2 && g_iCurrentMode == 4 ? g_iCvarGlowV : g_iCvarGlowC )
		{
			if( GetEntProp(client, Prop_Send, "m_iGlowType") == 3 && GetEntProp(client, Prop_Send, "m_glowColorOverride") == (g_iCurrentMode == 4 ? g_iCvarGlowV : g_iCvarGlowC) )
			{
				SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
				SetEntProp(client, Prop_Send, "m_iGlowType", 0);
			}
		}

		// Chase
		int entity = g_iChase[client];
		g_iChase[client] = 0;
		if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
			RemoveEntity(entity);

		// Fire event - if other plugins require
		Event event = CreateEvent("player_no_longer_it", true);
		event.SetInt("userid", userid);
		event.Fire(false);
	}

	return Plugin_Continue;
}