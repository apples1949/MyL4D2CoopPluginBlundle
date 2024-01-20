#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Plugin myinfo = 
{
	name 			= "击杀/爆头提示音",
	author 			= "夜羽真白",
	description 	= "When killed a common infected or special infected then will announce by a sound, when headshot will display a special sound",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// Global Defines
#define Team_Survivor 2
#define Team_Infected 3
#define HeadShot_Sound "level/bell_normal.wav"

// Convar
ConVar g_hEnable;
ConVar g_hOtherEnable;
int g_iEnable, g_iOtherEnable;

public void OnPluginStart()
{
	// 游戏检测
	char game[32];
	GetGameFolderName(game, sizeof(game));
	if (!StrEqual(game, "left4dead", false) && !StrEqual(game, "left4dead2", false))
	{
		SetFailState("该插件只支持L4D或L4D2");
	}
	// Create ConVar
	g_hEnable = CreateConVar("sound_enable", "1", "是否启用击杀提示音：0 = 关闭， 1 = 启用", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hOtherEnable = CreateConVar("other_sound", "0", "当小ss或特感死于土制炸弹爆炸或燃烧瓶时，是否启用击杀提示音：0 = 关闭， 1 = 启用", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hEnable.AddChangeHook(ConVarChanged_Cvars);
	g_hOtherEnable.AddChangeHook(ConVarChanged_Cvars);
	g_iEnable = g_hEnable.IntValue;
	g_iOtherEnable = g_hOtherEnable.IntValue;
	// Events Hook
	HookEvent("player_death", evt_PlayerDeath);
}

// 地图开始时加载声音文件
public void OnMapStart()
{
	PrecacheSound(HeadShot_Sound, true);
}

// 杀死特感
public Action evt_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int killer = GetClientOfUserId(event.GetInt("attacker"));
	int victim = GetClientOfUserId(event.GetInt("userid"));
	char weapon[32];
	event.GetString("weapon", weapon, sizeof(weapon));
	bool headshot = GetEventBool(event, "headshot");
	// PrintToChatAll("[Debug] damage type: %s", weapon);
	if (0 < killer <= MaxClients && victim !=0 && !IsFakeClient(killer) && IsClientInGame(killer) && GetClientTeam(killer) == Team_Survivor)
	{
		int ZombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		if (ZombieClass != 7 && ZombieClass != 8)
		{
			if (g_iEnable == 1)
			{
				if ((strcmp(weapon, "pipe_bomb") == 0 || strcmp(weapon, "inferno") == 0) && g_iOtherEnable == 0)
				{
				}
				PlaySound(killer, headshot);
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Handled;
}

public void PlaySound(int m_client, int m_headshot)
{
	if (m_headshot == 1)
	{
		EmitSoundToClient(m_client, HeadShot_Sound, _, SNDCHAN_AUTO, SNDLEVEL_CONVO, _, SNDVOL_NORMAL);
	}
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iEnable = g_hEnable.IntValue;
	g_iOtherEnable = g_hOtherEnable.IntValue;
}