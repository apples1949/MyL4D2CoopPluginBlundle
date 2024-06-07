#define PLUGIN_VERSION	"1.2"
#define PLUGIN_NAME		"Grenade Launcher Effect"
#define PLUGIN_PREFIX	"grenade_launcher_effect"

#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "little_froy",
	description = "game play",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=346513"
};

ConVar C_add;
bool O_add;
ConVar C_model;
char O_model[PLATFORM_MAX_PATH];
ConVar C_scale;
float O_scale;
ConVar C_radius;
int O_radius;
ConVar C_magnitude;
int O_magnitude;
ConVar C_material_type;
int O_material_type;

bool Map_started;
int Model;

public void OnMapStart()
{
    Map_started = true;
    Model = PrecacheModel(O_model, true);
}

public void OnMapEnd()
{
    Map_started = false;
}

stock void next_frame(DataPack dp)
{
    if(!Map_started)
    {
        delete dp;
        return;
    }
    dp.Reset();
    float pos[3];
    for(int i = 0; i < 3; i++)
    {
        pos[i] = dp.ReadFloat();
    }
    delete dp;
    TE_SetupExplosion(pos, Model, O_scale, 0, 0, O_radius, O_magnitude, view_as<float>({0.0, 0.0, 0.0}), O_material_type);
    TE_SendToAll();
}

Action on_te_EffectDispatch(const char[] te_name, const int[] Players, int numClients, float delay)
{
    int table_name = FindStringTable("EffectDispatch");
    if(table_name == INVALID_STRING_TABLE)
    {
        return Plugin_Continue;
    }
    char effect_name[64];
    ReadStringTable(table_name, TE_ReadNum("m_iEffectName"), effect_name, sizeof(effect_name));
    if(strcmp(effect_name, "ParticleEffect") != 0)
    {
        return Plugin_Continue;
    }
    int table_particle = FindStringTable("ParticleEffectNames");
    if(table_particle == INVALID_STRING_TABLE)
    {
        return Plugin_Continue;
    }
    char particle_name[64];
    ReadStringTable(table_particle, TE_ReadNum("m_nHitBox"), particle_name, sizeof(particle_name));
    if(strncmp(particle_name, "weapon_grenadelauncher", 22) == 0)
    {
        if(O_add)
        {
            DataPack dp = new DataPack();
            dp.WriteFloat(TE_ReadFloat("m_vOrigin.x"));
            dp.WriteFloat(TE_ReadFloat("m_vOrigin.y"));
            dp.WriteFloat(TE_ReadFloat("m_vOrigin.z"));
            RequestFrame(next_frame, dp);
        }
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

void get_all_cvars()
{
    O_add = C_add.BoolValue;
    C_model.GetString(O_model, sizeof(O_model));
    O_scale = C_scale.FloatValue;
    O_radius = C_radius.IntValue;
    O_magnitude = C_magnitude.IntValue;
    O_material_type = C_material_type.IntValue;
}

void get_single_cvar(ConVar convar)
{
    if(convar == C_add)
    {
        O_add = C_add.BoolValue;
    }
    else if(convar == C_model)
    {
        C_model.GetString(O_model, sizeof(O_model));
        if(Map_started)
        {
            Model = PrecacheModel(O_model, true);
        }
    }
    else if(convar == C_scale)
    {
        O_scale = C_scale.FloatValue;
    }
    else if(convar == C_radius)
    {
        O_radius = C_radius.IntValue;
    }
    else if(convar == C_magnitude)
    {
        O_magnitude = C_magnitude.IntValue;
    }
    else if(convar == C_material_type)
    {
        O_material_type = C_material_type.IntValue;
    }
}

void convar_changed(ConVar convar, const char[] oldValue, const char[] newValue)
{
	get_single_cvar(convar);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if(GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "this plugin only runs in \"Left 4 Dead 2\"");
        return APLRes_SilentFailure;
    }
    return APLRes_Success;
}

public void OnPluginStart()
{
    C_add = CreateConVar(PLUGIN_PREFIX ... "_add", "1", "1 = enable, 0 = disable. add a custom effect after blocked?");
    C_add.AddChangeHook(convar_changed);
    C_model = CreateConVar(PLUGIN_PREFIX ... "_model", "materials/editor/env_explosion.vmt", "model of effect");
    C_model.AddChangeHook(convar_changed);
    C_scale = CreateConVar(PLUGIN_PREFIX ... "_scale", "1.0", "scale of effect");
    C_scale.AddChangeHook(convar_changed);
    C_radius = CreateConVar(PLUGIN_PREFIX ... "_radius", "400", "radius of effect");
    C_radius.AddChangeHook(convar_changed);
    C_magnitude = CreateConVar(PLUGIN_PREFIX ... "_magnitude", "0", "magnitude of effect");
    C_magnitude.AddChangeHook(convar_changed);
    C_material_type = CreateConVar(PLUGIN_PREFIX ... "_material_type", "0", "material type of effect");
    C_material_type.AddChangeHook(convar_changed);
    CreateConVar(PLUGIN_PREFIX ... "_version", PLUGIN_VERSION, "version of " ... PLUGIN_NAME, FCVAR_NOTIFY | FCVAR_DONTRECORD);
    AutoExecConfig(true, PLUGIN_PREFIX);
    get_all_cvars();

    AddTempEntHook("EffectDispatch", on_te_EffectDispatch);
}