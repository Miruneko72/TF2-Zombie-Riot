#pragma semicolon 1
#pragma newdecls required

#define CHARGEBLD_CHARGE_COOLDOWN           1.0
#define CHARGEBLD_SWITCH_COOLDOWN           1.0
#define CHARGEBLD_M2_COOLDOWN               5.0
#define CHARGEBLD_SMALL_PHIAL_DAMAGE_MULTI  6.0
#define CHARGEBLD_SMALL_PHIAL_BLAST_RADIUS  10.0
#define CHARGEBLD_LARGE_PHIAL_DIST          90.0
#define CHARGEBLD_LARGE_PHIAL_BASE_DAMAGE   500.0
#define CHARGEBLD_LARGE_PHIAL_BLAST_RADIUS  120.0

#define CHARGEBLD_CHARGE_SND            "items/powerup_pickup_resistance.wav"
#define CHARGEBLD_CHARGE_FAIL_SND       "weapons/dispenser_generate_metal.wav"
#define CHARGEBLD_DEFLECT_SND           "weapons/cleaver_hit_world.wav"
#define CHARGEBLD_PHIAL_EXPLOSION_SND   "npc/roller/mine/rmine_explode_shock1.wav"

#define CHARGEBLD_SMALL_PHIAL_EXPLOSION "arm_muzzleflash_electro"
#define CHARGEBLD_LARGE_PHIAL_EXPLOSION "rocket_explosion_classic"

static Handle ChargeBld_HUDTimer[MAXTF2PLAYERS]={null, ...};
static Handle ChargeBld_ChargeTimer[MAXTF2PLAYERS]={null, ...};

static int ChargeBld_Phials[MAXTF2PLAYERS]={0, ...};
static int ChargeBld_MaxPhials[MAXTF2PLAYERS]={5, ...};
static int ChargeBld_Charge[MAXTF2PLAYERS]={0, ...};
static int ChargeBld_PAP[MAXTF2PLAYERS]={1, ...}; // 1 - NORMAL / 2 - SAVAGE AXE / 3 - ELEMENTAL
static int ChargeBld_Mode[MAXTF2PLAYERS]={1, ...}; // 1 - SWORD / 2 - AXE

static int ChargeBld_AxeRef[MAXTF2PLAYERS];

public void Precache_ChargeBld()
{
    PrecacheSound(CHARGEBLD_CHARGE_SND);
    PrecacheSound(CHARGEBLD_CHARGE_FAIL_SND);
    PrecacheSound(CHARGEBLD_DEFLECT_SND);
    PrecacheSound(CHARGEBLD_PHIAL_EXPLOSION_SND);
    PrecacheEffect(CHARGEBLD_SMALL_PHIAL_EXPLOSION);
    PrecacheEffect(CHARGEBLD_LARGE_PHIAL_EXPLOSION);
}

public void Weapon_ChargeBld_Equip_Normal(int client, int weapon, const char[] classname, bool &result)
{
    ChargeBld_PAP[client] = 1;
    Weapon_ChargeBld_Equip(client, weapon, classname, result);
}

//Hotkeys

public void Weapon_ChargeBld_M1(int client, int weapon, const char[] classname, bool &result)
{
	
}

public void Weapon_ChargeBld_M2(int client, int weapon, bool crit, int slot)
{
    if(ChargeBld_Mode[client] == 2)//Axe mode
    {
        Ability_Apply_Cooldown(client, slot, CHARGEBLD_M2_COOLDOWN);
        ChargeBld_ElementalDischarge(client, weapon);
    }
    else
    {//Sword mode
        
    }
}

public void Weapon_ChargeBld_R(int client, int weapon, bool crit, int slot)
{
    if(Ability_Check_Cooldown(client, slot) < 0.0)
    {
        if(!(GetClientButtons(client) & IN_DUCK))
        {
            Ability_Apply_Cooldown(client, slot, CHARGEBLD_SWITCH_COOLDOWN);
            if(ChargeBld_Mode[client] == 1)
                ChargeBld_SwitchToAxe(client, weapon);
                Ability_Apply_Cooldown(client, slot, CHARGEBLD_SWITCH_COOLDOWN);//2nd time so both weapons are affected
            else
                ChargeBld_SwitchToSword(client);
                Ability_Apply_Cooldown(client, slot, CHARGEBLD_SWITCH_COOLDOWN);//2nd time so both weapons are affected
        }
        else if ((GetEntityFlags(client) & FL_ONGROUND) != 0)
        {
            Ability_Apply_Cooldown(client, slot, CHARGEBLD_CHARGE_COOLDOWN);
            Weapon_ChargeBld_CrouchR(client, weapon);
        }
    }
}

static void Weapon_ChargeBld_CrouchR(int client, int weapon)
{
    if(ChargeBld_Mode[client] == 1)//Charge Weapon if sword
    {
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, {0.0, 0.0, 0.0});

        SetEntityMoveType(client, MOVETYPE_NONE);   

        if (ChargeBld_Charge[client] >= 50)
            EmitSoundToAll(CHARGEBLD_CHARGE_SND, client, SNDCHAN_STATIC, 85, _, 1.0);
        else
            EmitSoundToAll(CHARGEBLD_CHARGE_FAIL_SND, client, SNDCHAN_STATIC, 85, _, 1.0);
        DataPack pack;
        ChargeBld_ChargeTimer[client] = CreateDataTimer(CHARGEBLD_CHARGE_COOLDOWN, Weapon_ChargeBld_Charge, pack);
        pack.WriteCell(client);
        pack.WriteCell(EntIndexToEntRef(client));
        pack.WriteCell(EntIndexToEntRef(weapon));
    }
}

public void Weapon_ChargeBld_Equip(int client, int weapon, const char[] classname, bool &result)
{
    if(ChargeBld_Mode[client] != 1 && StrContains(classname, "tf_weapon_bottle", true))
    {
        ChargeBld_SwitchToSword(client);
    }
    if(ChargeBld_HUDTimer[client] == null)
    {
        DataPack pack;
        ChargeBld_HUDTimer[client] = CreateDataTimer(0.1, Timer_Management_ChargeBld, pack, TIMER_REPEAT);
        pack.WriteCell(EntIndexToEntRef(client));
        pack.WriteCell(EntIndexToEntRef(weapon));
    }
}

public void Weapon_ChargeBld_Holster(int client, int weapon, const char[] classname, bool &result)
{
    SetEntityMoveType(client, MOVETYPE_WALK);
    TF2_RemoveCondition(client, TFCond_CritDemoCharge);

    if (ChargeBld_ChargeTimer[client])
        delete ChargeBld_ChargeTimer[client];
    if (ChargeBld_HUDTimer[client])
        delete ChargeBld_HUDTimer[client];
}
//Other

public void Weapon_ChargeBld_Hit_Sword(int attacker, int victim, float &damage, int weapon)
{
    if (ChargeBld_Charge[attacker] == 100)
    {
        damage *= 0.1;
        EmitSoundToAll(CHARGEBLD_DEFLECT_SND, attacker, SNDCHAN_STATIC, 80, _, 1.0);
    }
    else
    {
        ChargeBld_Charge[attacker] += 20;
        if (ChargeBld_Charge[attacker] >= 100)
        {
            ChargeBld_Charge[attacker] = 100;
            TF2_AddCondition(attacker, TFCond_CritDemoCharge, 4096.0, 0);
        }
    }
}

public void Weapon_ChargeBld_Hit_Axe(int attacker, int victim, float &damage, int weapon)
{
    if (ChargeBld_Phials[attacker] > 0)
    {
        ChargeBld_Phials[attacker] -= 1;
        DataPack pack;
        CreateDataTimer(0.5, ChargeBld_SmallPhialExplosion, pack);
        pack.WriteCell(EntIndexToEntRef(victim));
        pack.WriteCell(EntIndexToEntRef(attacker));
        pack.WriteCell(EntIndexToEntRef(weapon));
        pack.WriteCell(damage);
    }
}   

public Action Timer_Management_ChargeBld(Handle timer, DataPack pack)
{
    //basically the prismatic wand hud logic
    pack.Reset();
    int client = EntRefToEntIndex(pack.ReadCell());
    if(!IsValidClient(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		ChargeBld_HUDTimer[client] = null;
		return Plugin_Stop;
	}
    if(!Weapon_ChargeBld_HUDLoop(client, EntRefToEntIndex(pack.ReadCell())))
    {
        ChargeBld_HUDTimer[client] = null;
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

static bool Weapon_ChargeBld_HUDLoop(int client, int weapon)
{
    if(IsValidEntity(weapon))
	{
        int weapon_holding = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
        if(CheckEquippedChargeBld(weapon) && weapon_holding == weapon)
        {
            char HUDText[32];
            for (int i = 0; i < ChargeBld_MaxPhials[client]; i++)
            {
                if (ChargeBld_Phials[client] > i)
                    Format(HUDText, sizeof(HUDText), "%s%s", HUDText, "⍔");
                else
                    Format(HUDText, sizeof(HUDText), "%s%s", HUDText, "⎕");
            }

            if(ChargeBld_Charge[client] == 100)
                SetDefaultHudPosition(client, 255, 0, 0, 1.0);
            else if(ChargeBld_Charge[client] >= 80)
                SetDefaultHudPosition(client, 255, 40, 10, 1.0);
            else if(ChargeBld_Charge[client] >= 50)
                SetDefaultHudPosition(client, 200, 150, 50, 1.0);
            else 
                SetDefaultHudPosition(client, 200, 200, 200, 1.0);

            ShowSyncHudText(client, SyncHud_Notifaction, "%s", HUDText);
        }
        else
            return false;
    }
    else
        return false;
    return true;
}

static Action Weapon_ChargeBld_Charge(Handle timer, DataPack pack)
{
    int client;
    int weapon;
    pack.Reset();
    int orignal_client = pack.ReadCell();
    ChargeBld_ChargeTimer[orignal_client] = null;
    client = EntRefToEntIndex(pack.ReadCell());
    weapon = EntRefToEntIndex(pack.ReadCell());
    if(IsValidClient(client) && IsValidEntity(weapon))
    {
        if(ChargeBld_Charge[client] >= 80)
        {
            ChargeBld_Phials[client] = ChargeBld_MaxPhials[client];

            ChargeBld_Charge[client] = 0;

        }
        else if(ChargeBld_Charge[client] > 50)
        {
            ChargeBld_Phials[client] += 3;

            ChargeBld_Charge[client] = 0;
            if (ChargeBld_Phials[client] > ChargeBld_MaxPhials[client])
                ChargeBld_Phials[client] = ChargeBld_MaxPhials[client];
        }
        SetEntityMoveType(client, MOVETYPE_WALK);
        TF2_RemoveCondition(client, TFCond_CritDemoCharge);
    }
    return Plugin_Stop;
}

static void ChargeBld_SwitchToAxe(int client, int weapon)
{   //Most is borrowed from Judgment of Iberia

    int weapon_new = Store_GiveSpecificItem(client, "Charge Blade Axe");
    if(IsValidEntity(weapon_new) && IsValidEntity(weapon))
    {
        ChargeBld_Mode[client] = 2;
        ChargeBld_AxeRef[client] = EntIndexToEntRef(weapon_new);
        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon_new);
        ViewChange_Switch(client, weapon_new, "tf_weapon_sword");
    }
}

static void ChargeBld_SwitchToSword(int client)
{
    ChargeBld_Mode[client] = 1;
    Store_RemoveSpecificItem(client, "Charge Blade Axe");
    
    int ChargeBld_Axe = EntRefToEntIndex(ChargeBld_AxeRef[client]);
    if(IsValidEntity(ChargeBld_Axe))
    {
        TF2_RemoveItem(client, ChargeBld_Axe);
        FakeClientCommand(client, "use tf_weapon_bottle");
    }
    //Store_RemoveSpecificItem(client, "Charge Blade Savage Axe");
    //Store_RemoveSpecificItem(client, "Charge Blade Elemental Axe");
}

static void ChargeBld_ElementalDischarge(int client, int weapon)
{
    float eyeAng[3];
    GetClientEyeAngles(client, eyeAng);
    float fwd[3];
    float right[3];
    float up[3];
    GetAngleVectors(eyeAng, fwd, right, up);
    ScaleVector(fwd, CHARGEBLD_LARGE_PHIAL_DIST);
    float nextPos[3];
    float originPos[3];
    GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", originPos);
    originPos[2] += 8; //Height offset to go slighly above ground
    nextPos = originPos;
    for (int i = 0; i < ChargeBld_Phials[client]; i++)
    {
        AddVectors(nextPos, fwd, nextPos);
        DataPack pack;
        CreateDataTimer(0.4 * i, ChargeBld_LargePhialExplosion, pack);
        pack.WriteCell(EntIndexToEntRef(client));
        pack.WriteFloat(nextPos[0]);
        pack.WriteFloat(nextPos[1]);
        pack.WriteFloat(originPos[2]); //Stay in line with player's height
        pack.WriteCell(EntIndexToEntRef(weapon));
    }
    ChargeBld_Phials[client] = 0;
    ClientCommand(client, "");
}

static Action ChargeBld_SmallPhialExplosion(Handle timer, DataPack pack)
{
    pack.Reset();
    int victim = EntRefToEntIndex(pack.ReadCell());
    int client = EntRefToEntIndex(pack.ReadCell());
    int weapon = EntRefToEntIndex(pack.ReadCell());
    float damage = pack.ReadCell();
    if(IsValidEntity(victim) && IsValidEntity(client) && IsValidEntity(weapon))
    {
        float EntLoc[3];
        GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", EntLoc);

        TE_Particle(CHARGEBLD_SMALL_PHIAL_EXPLOSION, EntLoc, NULL_VECTOR, NULL_VECTOR, _, _, _, _, _, _, _, _, _, _, 0.0);

        damage *= CHARGEBLD_SMALL_PHIAL_DAMAGE_MULTI;
        Explode_Logic_Custom(damage, client, weapon, -1, EntLoc,CHARGEBLD_SMALL_PHIAL_BLAST_RADIUS,_,_,false);

        EmitSoundToAll(CHARGEBLD_PHIAL_EXPLOSION_SND, victim, SNDCHAN_STATIC, 85, _, 1.0);
    }
    return Plugin_Stop;
}

static Action ChargeBld_LargePhialExplosion(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = EntRefToEntIndex(pack.ReadCell());
    float posx = pack.ReadFloat();
    float posy = pack.ReadFloat();
    float posz = pack.ReadFloat();
    int weapon = EntRefToEntIndex(pack.ReadCell());

    float pos[3];
    pos[0] = posx;
    pos[1] = posy;
    pos[2] = posz;
    if(IsValidEntity(weapon) && IsValidEntity(client))
    {
        TE_Particle(CHARGEBLD_LARGE_PHIAL_EXPLOSION, pos, NULL_VECTOR, NULL_VECTOR, _, _, _, _, _, _, _, _, _, _, 0.0);

        float damage = CHARGEBLD_LARGE_PHIAL_BASE_DAMAGE;
        damage *= Attributes_Get(weapon, 1, 1.0);
        damage *= Attributes_Get(weapon, 2, 1.0);

        Explode_Logic_Custom(damage, client, weapon, -1, pos,CHARGEBLD_LARGE_PHIAL_BLAST_RADIUS,_,_,false);

        EmitAmbientSound(CHARGEBLD_PHIAL_EXPLOSION_SND, pos, SNDCHAN_STATIC, 85, _, 1.0);
    }
    return Plugin_Stop;
}

static bool CheckEquippedChargeBld(int weapon)
{
    return ((i_CustomWeaponEquipLogic[weapon] == WEAPON_CHARGE_BLADE) || (i_CustomWeaponEquipLogic[weapon] == WEAPON_CHARGE_BLADE_AXE));
}
