/* 
	AlienBoss
	
	www.ZombieLite.Ru
	www.Alexander3.Ru
*/

#include < amxmodx >
#include < engine >
#include < fakemeta >
#include < hamsandwich >
#include < xs >

#define NAME 			"AlienBoss"
#define VERSION			"3.2"
#define AUTHOR			"Alexander.3"

//#define MAPCHOOSER
#define PLAYER_HP
#define NEW_SEARCH
#define SUPPORT_ZM
//#define HEALTHBAR
#define SPRMIRROR
#define MESSAGE


////////////////////////
/*------- CODE -------*/
////////////////////////
enum {
	RUN,
	ATTACK,
	CAST,
	AGGRESSIVE,
	MAHADASH
}
enum {
	NORMAL,
	REDYELLOW,	// 1
	REDBLUE,	// 2
	REDGREEN,	// 3
	YELLOWBLUE,	// 4
	YELLOWGREEN,	// 5
	BLUEGREEN,	// 6
	PURPLE,		// 7
	MIX,		// 8
	MIX2,		// 9
	WHITE,		// 10
	PARADOX
}

native zl_zombie_create(Float:Origin[3], Health, Speed, Damage)
native zl_colorchat(id, const msg[], any:...)
native zl_boss_valid( e )
native zl_player_alive()
native zl_player_random()
native zl_boss_map()
forward zl_timer(timer, prepare)

new const SoundList[][] = {
	"zl/npc/alien/step1.wav",			// 0
	"zl/npc/alien/step2.wav",			// 1
	"zl/npc/alien/cast.wav",			// 2
	"zl/npc/alien/cast2.mp3",			// 3
	"zl/npc/alien/shokwave.wav",			// 4
	"zl/npc/alien/swing.wav",			// 5
	
	"zl/npc/alien/event_death.wav",			// 6 -
	"zl/npc/alien/event_10.wav",			// 7 -
	"zl/npc/alien/event_10_2.wav",			// 8 -
	"zl/npc/alien/event_blue.wav",			// 9 -
	"zl/npc/alien/event_blue2.wav",			// 10 -
	"zl/npc/alien/event_gravity_death.wav",		// 11 -
	"zl/npc/alien/event_phase2.wav",		// 12 -
	"zl/npc/alien/event_red.wav",			// 13 -
	"zl/npc/alien/event_red2.wav",			// 14 -
	"zl/npc/alien/event_start.wav",			// 15 -
	"zl/npc/alien/event_yellow.wav",		// 16 -
	"zl/npc/alien/event20.wav",			// 17 -
	"zl/npc/alien/event30.wav",			// 18 -
	"zl/npc/alien/event_40.wav",			// 19 -
	
	"zl/prepare2.mp3"				// 20
}

new const Resource[][] = {
	"models/zl/npc/alien/zl_alien_v3.mdl",		// 0
	"models/zl/npc/alien/zl_ship.mdl",		// 1
	"models/zl/npc/alien/zl_light_of_dead.mdl",	// 2
	"sprites/zl/npc/alien/zl_healthbar.spr",	// 3
	"models/zl/npc/alien/zl_attack.mdl",		// 4
	"sprites/zl/npc/alien/fluxing.spr",		// 5
	"sprites/shockwave.spr",			// 6
	"sprites/laserbeam.spr",			// 7
	"models/zl/npc/alien/zl_mine.mdl",		// 8
	"sprites/zl/npc/alien/white.spr",		// 9
	"sprites/zl/npc/alien/zl_stun.spr"		// 10
	
}
new Float:zl_fcvar[6], zl_cvar[25]
new g_Resource[sizeof Resource], g_Alien 
new e_multi, e_center, e_zombie[10], e_bomb[16]
new bool:g_Prepare = true, g_MaxPlayer

//Adding Fixed 
new e_Stunn
/*--END--*/

#define OFFSET_RUN 	30	// 30 in 250.0 spd
#define OFFSET_ZORIGIN	0.0	// Z-Index origin mdl
#define OFFSET_BOSS	29	// offset size position
#define MAX_ZOMBIE	10	// ZombieNum in phase2
#define pev_null	pev_euser1 // Null
#define pev_num		pev_iuser2 // pev_euser1
#define pev_victim	pev_euser3	
#define pev_ability	pev_euser4	
#define pev_color	pev_button
#define pev_zombie	pev_weaponanim
#define pev_healthbar	pev_weaponanim	
#define pev_mine	pev_euser1	// base
#define pev_bool	pev_iuser3
#define pev_speed2	pev_fuser1	
#define pev_time	pev_fuser3
#define mix2		e_center
#if defined MAPCHOOSER
native zl_vote_start()
#else
new boss_nextmap[32]
#endif
#define zl_alien_ability(%0) set_pev(g_Alien, pev_euser4, %0)
#define zl_alien_color(%0) set_pev(g_Alien, pev_button, %0)

public plugin_init() {
	register_plugin(NAME, VERSION, AUTHOR)
	
	if (zl_boss_map() != 2) {
		pause("ad")
		return
	}
	
	RegisterHam(Ham_Player_PreThink, "player", "Player_SpeedHook", 1)
	RegisterHam(Ham_Spawn, "player", "Player_Spawn", 1)
	RegisterHam(Ham_TraceAttack, "info_target", "Alien_TraceAttack")
	RegisterHam(Ham_TakeDamage, "info_target", "Alien_TakeDamage")
	
	register_think("alien_boss", "Alien_Think")
	register_think("alien_health", "Alien_HealthBar")
	register_think("alien_ship", "Alien_Ship")
	register_think("alien_attack", "Alien_Attack")
	register_think("alien_fluxing", "Alien_Fluxing")
	register_think("alien_mine", "Alien_Mine")
	register_think("alien_white", "Alien_White")
	
	register_touch("alien_boss", "*", "Alien_Touch")
	register_touch("classname_zombie", "player", "infect_touch")
	register_touch("player", "player", "infect_touch")
		
	g_MaxPlayer = get_maxplayers()
	MapEvent()
}

public Alien_Think( boss ) {
	if (pev(boss, pev_deadflag) == DEAD_DYING)
		return
	
	not_player_alive( boss )
	
	static ability, color
	ability = pev(boss, pev_ability)
	color = pev(boss, pev_color)
	
	if (pev(boss, pev_deadflag) == DEAD_RESPAWNABLE) {
		set_pev(boss, pev_deadflag, DEAD_NO)
		set_pev(boss, pev_takedamage, DAMAGE_YES)
		set_pev(boss, pev_movetype, MOVETYPE_PUSHSTEP)
		set_pev(boss, pev_time, get_gametime() + float(zl_cvar[22]))
		zl_anim(boss, 3, 1.0)
		
		new HealthBar = zl_create_entity(
			Float:{0.0, 0.0, 0.0}, Resource[3], _, 0.1, 
			SOLID_NOT, MOVETYPE_FOLLOW, DAMAGE_NO, DEAD_NO, 
			"info_target", "alien_health")
		
		set_pev(boss, pev_healthbar, HealthBar)
		set_pev(HealthBar, pev_body, 1)
		set_pev(HealthBar, pev_skin, boss)
		set_pev(HealthBar, pev_aiment, boss) 
		set_pev(HealthBar, pev_scale, zl_fcvar[0])
		set_pev(HealthBar, pev_num, 100)
	}
	
	switch (ability) {
		case RUN: {
			new Float:Velocity[3], Float:Angle[3]
			if (!is_user_alive(pev(boss, pev_victim))) {
				set_pev(boss, pev_victim, zl_player_random())
				set_pev(boss, pev_nextthink, get_gametime() + 0.1)
				return
			}
			
			if (pev(boss, pev_sequence) != 3) { // 3 - Run animation
				//if (pev_valid(pev(boss, pev_null))) {
				if (pev_valid(e_Stunn)) {
					set_rendering(pev(boss, pev_healthbar))
					engfunc(EngFunc_RemoveEntity, e_Stunn)
					e_Stunn = 0
					//set_pev(boss, pev_null, 0)
				}
				
				set_pev(boss, pev_iuser1, 0)
				set_pev(boss, pev_movetype, MOVETYPE_PUSHSTEP)
				zl_anim(boss, 3, 1.0)
			}
			
			#if defined NEW_SEARCH
			new Len, LenBuff = 99999
			new i
			for(i = 1; i <= g_MaxPlayer; i++) {
				if (!is_user_alive(i))
					continue
						
				Len = zl_move(boss, i)
				if (Len < LenBuff) {
					LenBuff = Len
					set_pev(boss, pev_victim, i)
				}
			}
			#endif
			new Float:speed = float(zl_cvar[2])
			switch(color) {
					case NORMAL: speed = float(zl_cvar[2])
					case REDYELLOW: speed *= 1.0
					case REDBLUE: speed /= 1.3
					case YELLOWGREEN: speed *= 1.0
					default: speed = float(zl_cvar[2])
				}
			zl_move(boss, pev(boss, pev_victim), speed, Velocity, Angle)
			Velocity[2] = 0.0
			set_pev(boss, pev_velocity, Velocity)
			set_pev(boss, pev_angles, Angle)			
		}
		case ATTACK: {
			attack_effect( boss )
			
			new victim = pev(boss, pev_victim)
			
			if (!is_user_alive(victim)) {
				set_pev(boss, pev_nextthink, get_gametime() + 1.4)
				set_pev(boss, pev_ability, RUN)
				return
			}
			
			if (get_entity_distance(boss, victim) < 280) {
				switch(color) {
					case NORMAL: function_damage(victim, zl_cvar[4], {255, 0, 0})
					case REDYELLOW: ExecuteHamB(Ham_Killed, victim, victim, 2)
					case REDBLUE: function_damage(victim, floatround(zl_cvar[4] / 1.5), {255, 0, 0})
					case REDGREEN: function_damage(victim, zl_cvar[4], {255, 0, 0})
					case YELLOWBLUE: function_damage(victim, zl_cvar[4], {255, 0, 0})
					case YELLOWGREEN: function_damage(victim, floatround(zl_cvar[4] * 1.5), {255, 0, 0})
					default: function_damage(victim, zl_cvar[4], {255, 0, 0})
				}
			}
			set_pev(boss, pev_nextthink, get_gametime() + 1.4)
			set_pev(boss, pev_ability, RUN)
			return
		}
		case CAST: {
			static fluxing
			switch(pev(boss, pev_num)) {
				case 0: {
					if (pev(boss, pev_sequence) != 3) { // 3 - Run animation
						set_pev(boss, pev_iuser1, 0)
						set_pev(zl_cvar[22], pev_bool, 0)
						set_pev(boss, pev_movetype, MOVETYPE_PUSHSTEP)
						zl_anim(boss, 3, 1.0)
					}
					if (color > 6) {
						set_pev(boss, pev_num, 1)
						set_pev(boss, pev_nextthink, get_gametime() + 0.1)
						return
					}
					
					// 4e pontbl popytal
					static Float:Velocity[3], Float:Angle[3], Len
					Len = zl_move(boss, e_center, 450.0, Velocity, Angle)
					if (Len <= (430 + OFFSET_ZORIGIN)) {
						set_pev(boss, pev_movetype, MOVETYPE_NONE)
						set_pev(boss, pev_nextthink, get_gametime() + 1.0)
						set_pev(boss, pev_num, 1)
						set_pev(boss, pev_iuser1, 0)
						return
					}
					set_pev(boss, pev_iuser1, 1)
					set_pev(boss, pev_velocity, Velocity)
					set_pev(boss, pev_angles, Angle)
				}
				case 1: {
					#if defined MESSAGE
					switch (color) {
						case REDYELLOW: zl_colorchat(0, "!n[!gAlienBoss!n] Босс смешал !gКрасный!n и !gЖелтый !nцвет")
						case REDBLUE: zl_colorchat(0, "!n[!gAlienBoss!n] Босс смешал !gКрасный!n и !gСиний !nцвет")
						case REDGREEN: zl_colorchat(0, "!n[!gAlienBoss!n] Босс смешал !gКрасный!n и !gЗеленый !nцвет")
						case YELLOWBLUE: zl_colorchat(0, "!n[!gAlienBoss!n] Босс смешал !gЖелтый!n и !gСиний !nцвет")
						case YELLOWGREEN: zl_colorchat(0, "!n[!gAlienBoss!n] Босс смешал !gЖелтый!n и !gЗеленый !nцвет")
						case BLUEGREEN: zl_colorchat(0, "!n[!gAlienBoss!n] Босс смешал !gСиний!n и !gЗеленый !nцвет")
						case PURPLE: zl_colorchat(0, "!n[!gAlienBoss!n] Босс использует !gПурпурный !nцвет")
						case MIX: zl_colorchat(0, "!n[!gAlienBoss!n] Босс использует !gКрасный!n цвет !g(резист)")
						case MIX2: {
							switch ( pev(mix2, pev_num) ) {
								case 0: { zl_colorchat(0, "!n[!gAlienBoss!n] Босс получает комплект цветов!"); zl_colorchat(0, "!n[!gAlienBoss!n] Босс использует !gСерый !nцвет !g(Гравитационный)"); }
								case 1: zl_colorchat(0, "!n[!gAlienBoss!n] Босс использует !gСиний !nцвет !g(Паралич)")
								case 2: zl_colorchat(0, "!n[!gAlienBoss!n] Босс использует !gКрасный !nцвет !g(Уничтожение)")
							}
						}
						case WHITE: zl_colorchat(0, "!n[!gAlienBoss!n] Босс использует !gБелый !nцвет")
						case PARADOX: zl_colorchat(0, "!n[!gAlienBoss!n] PARADOX Ability")
					}
					#endif
					zl_anim(boss, 2, 1.0)
					set_pev(boss, pev_nextthink, get_gametime() + 3.0)
					set_pev(boss, pev_num, 2)
					fluxing = function_fluxing( boss, fluxing)
					
					switch (color) {
						case PARADOX: engfunc(EngFunc_LightStyle, 0, "b")
					}
					
					/* Attaching sprite hidden */
					set_rendering(pev(boss, pev_healthbar), kRenderFxNone, 255, 255, 255, kRenderTransAdd, 0)
					return
				}
				case 2: {
					set_pev(boss, pev_nextthink, get_gametime() + 0.1)
					engfunc(EngFunc_RemoveEntity, fluxing)
					if (color != MIX) set_rendering(boss)
					set_pev(boss, pev_num, 3)
					//zl_anim(boss, 4, 1.0)
					
					/* Return invise hp bar */
					set_rendering(pev(boss, pev_healthbar))
					
					return
				}
				case 3: { // CastSound
					//switch (color) {
					//	case 1..6: zl_sound(0, SoundList[2]) 
					//}
					set_pev(boss, pev_num, 4)
					set_pev(boss, pev_nextthink, get_gametime() + 2.5)
					zl_anim(boss, 4, 1.0)
					return
				}
				case 4: {
					// u 6blTb Mo]l[eT Mbl CTaHeM gpyr gpyry Hy]l[Hee
					if (color != PURPLE) zl_sound(0, SoundList[4])
					function_shockwave( boss )	// ShockWave Function
					(color == MIX) ? set_pev(boss, pev_num, 5) : set_pev(boss, pev_num, 0)
					
					switch( color ) {
						case MIX: set_pev(boss, pev_num, 5)
						default: set_pev(boss, pev_num, 0)
					}
					
					
					set_pev(boss, pev_nextthink, get_gametime() + 0.3)
					switch(color) {
						case PURPLE: {
							function_bomb()
							dllfunc(DLLFunc_Use, e_multi, e_multi)
						}
						case MIX: {
							zl_anim(boss, 2, 1.0)
							set_pev(boss, pev_nextthink, get_gametime() + 10.0)
							return
						}
						case MIX2: { 
							set_pev(mix2, pev_num, pev(mix2, pev_num) + 1)
							if (pev(mix2, pev_num) >= 3) {
								new i = 1
								for (i = 1; i <= g_MaxPlayer; ++i)
									set_pev(i, pev_speed2, 0.0)
								set_pev(mix2, pev_num, 0)
								set_pev(boss, pev_ability, RUN)
								return
							}
							set_pev(boss, pev_ability, CAST)
							return
						}
						case PARADOX: set_lights("#OFF")
						 
					}
					set_pev(boss, pev_ability, RUN)
					return
				}
				case 5: { // Special FOR MIX COLOR ( Using Mix Color )
					set_rendering(boss)
					set_pev(boss, pev_color, 0)
					set_pev(boss, pev_ability, RUN)
					set_pev(boss, pev_num, 0)
				}
			}
		}
		case AGGRESSIVE: {
			switch(pev(boss, pev_num)) {
				case 0: {			
					static Float:Velocity[3], Float:Angle[3], Len
					Len = zl_move(boss, e_center, 450.0, Velocity, Angle)
					if (Len <= (430 + OFFSET_ZORIGIN)) {
						set_pev(boss, pev_movetype, MOVETYPE_NONE)
						set_pev(boss, pev_takedamage, DAMAGE_NO)
						set_pev(boss, pev_nextthink, get_gametime() + 5.6)
						set_pev(boss, pev_num, 1)
						set_pev(boss, pev_iuser1, 0)
						zl_anim(boss, 5, 0.4)
						zl_sound(0, SoundList[12])
						return
					}
					set_pev(boss, pev_iuser1, 1)
					set_pev(boss, pev_velocity, Velocity)
					set_pev(boss, pev_angles, Angle)
					set_pev(boss, pev_color, NORMAL)
				}
				case 1: {
					zl_sound(0, SoundList[3])
					new i
					for( i = 1; i <= g_MaxPlayer; ++i ) {
						if (!is_user_alive(i))
							continue
							
						client_cmd(i, "drop")
						
						new weapon = get_pdata_cbase(i, 373, 5)
						if (weapon > 0) ExecuteHamB(Ham_Weapon_RetireWeapon, weapon)
						client_cmd(i, "drop")
						set_pev(i, pev_velocity, Float:{0.0, 0.0, 800.0})
					}
					zl_screenshake(0, 15, 3)
					set_pev(boss, pev_nextthink, get_gametime() + 4.5)
					set_pev(boss, pev_num, 2)
					zl_anim(boss, 6, 0.0)
					return
				}
				case 2: {
					set_pev(zl_cvar[20], pev_button, 1)
					set_pev(boss, pev_nextthink, get_gametime() + 0.8)
					set_pev(boss, pev_takedamage, DAMAGE_YES)
					set_pev(boss, pev_ability, RUN)
					set_pev(boss, pev_num, 0)
					zl_anim(boss, 7, 1.0)
					return
				}
			}
		}
		case MAHADASH: {
			static Float:v[3], Float:a[3]
			switch(pev(boss, pev_num)) {
				case 0: {
					zl_move(boss, zl_player_random(), 3000.0, v, a)
					set_pev(boss, pev_movetype, MOVETYPE_NONE)
					set_pev(boss, pev_angles, a)
					set_pev(boss, pev_nextthink, get_gametime() + 0.8)
					set_pev(boss, pev_num, 1)
					zl_anim(boss, 9, 1.0)
					return
				}
				case 1: {
					set_pev(boss, pev_movetype, MOVETYPE_FLY)
					v[2] = 1.0
					set_pev(boss, pev_velocity, v)
					set_pev(boss, pev_num, 0)
					set_pev(boss, pev_ability, RUN)
					set_pev(boss, pev_nextthink, get_gametime() + 1.3)
					set_pev(zl_cvar[22], pev_bool, 1)
					zl_beamfollow(boss, 1, 50, {255, 0, 0})
					return
				}
			}
		}
	}
	
	if ( (ability == RUN) && (pev(boss, pev_time) < get_gametime()) ) {
		set_pev(boss, pev_ability, MAHADASH)
		set_pev(boss, pev_time, get_gametime() + float(zl_cvar[22]))
	}
	
	static Float:paradox_timer
	if ( (ability == RUN) && paradox_timer < get_gametime() && pev(zl_cvar[20], pev_button) != 1) {
		if (paradox_timer) {
			set_pev(boss, pev_color, PARADOX)
			set_pev(boss, pev_ability, CAST)
		}
		paradox_timer = get_gametime() + 60.0
	}
	
	set_pev(boss, pev_nextthink, get_gametime() + 0.1)
}

public function_white() {
	if (pev(g_Alien, pev_deadflag) == DEAD_DYING)
		return	
	new i, p, a = zl_player_alive()
	new num = zl_cvar[23] ? zl_cvar[23] : a
	if (num > a) num = a
	for(i=1; i <= num; ++i) {
		
		p = zl_player_random()
		
		if (!is_user_alive(p))
			continue
			
		new Float:o[3]
		pev(p, pev_origin, o)
		o[2] -= 35.0
		new L = zl_create_entity(
			o, Resource[9], _, zl_fcvar[2], 
			SOLID_NOT, MOVETYPE_FLY, DAMAGE_NO, DEAD_NO, 
			"info_target", "alien_white")
			
		o[0] = 90.0
		o[1] = random_float(0.0, 100.0)
		o[2] = 0.0
		set_pev(L, pev_angles, o)
	}
	set_task(zl_fcvar[2], "function_white")
}

public Alien_White( e ) {	
	static victim = -1
	new Float:Origin[3]; pev(e, pev_origin, Origin)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(0)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	engfunc(EngFunc_WriteCoord, Origin[0]) 
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 1000.0)
	write_short(g_Resource[6])
	write_byte(1)
	write_byte(5)
	write_byte(2)
	write_byte(20)
	write_byte(80)
	write_byte(200)
	write_byte(200)
	write_byte(200)
	write_byte(200)
	write_byte(200)
	message_end()
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_SPARKS)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	message_end()
	
	while ((victim = engfunc(EngFunc_FindEntityInSphere, victim, Origin, 80.0)))    
		if (is_user_alive(victim)) {
			static d
			d ? ( d = 0 ) : ( zl_sound(0, SoundList[8]) )
			ExecuteHamB(Ham_Killed, victim, victim, 2)
			d = 1
		}
	engfunc(EngFunc_RemoveEntity, e)
}

public function_bomb() {
	if (pev(g_Alien, pev_color) != PURPLE)
		return
		
	new const bomb_num = (zl_cvar[18] >= 16) ? ( sizeof e_bomb ) : zl_cvar[18]
	new i, j, b, a[16]
	for(i = 0; i < sizeof a; i++)
		a[i] = i
		    
	for(i = 0; i < sizeof a; i++) {
		j = random(sizeof a - 1)
		b = a[i]
		a[i] = a[j]
		a[j] = b
	}
	for(i = 0; i < bomb_num; ++i) {
		new Float: Origin[3]
		pev(e_bomb[a[i]], pev_origin, Origin)
		Origin[2] += 1000.0
		new bomb = zl_create_entity(
				Origin, Resource[8], _, 5.0, 
				SOLID_BBOX, MOVETYPE_TOSS, DAMAGE_NO, DEAD_NO, 
				"info_target", "alien_mine", Float:{-5.0, -5.0, -1.0}, Float:{5.0, 5.0, 5.0})
		
		zl_beamfollow(bomb, 1, 5, {255, 255, 255})
		set_pev(bomb, pev_mine, e_bomb[a[i]])
	}
	set_task(5.1, "function_bomb")
}

public Alien_Mine( e ) {
	dllfunc(DLLFunc_Use, pev(e, pev_mine), pev(e, pev_mine))
	engfunc(EngFunc_RemoveEntity, e)
}

function_shockwave( boss ) {
	new Float:o[3], Len = 450, Width = 140, Color[3] = {255, 255, 255}
	pev(boss, pev_origin, o)
	o[2] -= OFFSET_ZORIGIN
	switch (pev(boss, pev_color)) {
		case REDYELLOW:{	Len = 450; Width = 35; Color = {255, 165, 0}; function_zombie(zl_cvar[6], zl_cvar[11] * 2, zl_cvar[9] * 2, zl_cvar[10] * 2);}
		case REDBLUE:{		Len = 250; Width = 140; Color = {255, 0, 255}; function_zombie(zl_cvar[7], zl_cvar[11] / 2, zl_cvar[9] / 2, zl_cvar[10] / 2);}
		case REDGREEN:{		Len = 450; Width = 35; Color = {255, 255, 0}; function_zombie(zl_cvar[8], zl_cvar[11], zl_cvar[9], zl_cvar[10]); function_green(0, zl_cvar[13]);}
		case YELLOWBLUE:{	Len = 450; Width = 140; Color = {0, 255, 0}; }
		case YELLOWGREEN:{	Len = 450; Width = 35; Color = {127, 255, 0}; }
		case BLUEGREEN:{	Len = 250; Width = 140; Color = {0, 255, 255}; }
		case PURPLE:{		Len = 450; Width = 35; Color = {255, 0, 255}; }
		case MIX:{		Len = 450; Width = 35; Color = {255, 0, 0}; }
		case MIX2:{
			switch (pev(mix2, pev_num)) {
				case 0: { Len = 450; Width = 140; Color = {255, 255, 255}; }
				case 1: { Len = 450; Width = 140; Color = {0, 0, 255}; }
				case 2: { Len = 450; Width = 140; Color = {255, 0, 0}; }
			}
		}
		case WHITE: {		Len = 450; Width = 35; Color = {255, 255, 255}; function_white();}
		case PARADOX: {
			Color[0] = random(255)
			Color[1] = random(255)
			Color[2] = random(255)
			Len = random_num(250, 800)
			Width = random(300)
		}
	}
	zl_shockwave(Float:o, Width, Len, Color)
	
	new i = 1
	for(i = 1; i <= g_MaxPlayer; ++i ) {
		if (!is_user_alive(i))
			continue
			
		new L
		L = zl_move(boss, i)
		L -= 175
		if (L > Len) continue
		
		/*if (~pev(i, pev_flags) & FL_ONGROUND)
			if (pev(boss, pev_color) == REDYELLOW || pev(boss, pev_color) == REDGREEN || pev(boss, pev_color) == YELLOWGREEN || pev(boss, pev_ab)
				continue
		*/
		switch (pev(boss, pev_color)) {
			case REDYELLOW: if (pev(i, pev_flags) & FL_ONGROUND) ExecuteHamB(Ham_Killed, i, i, 2)
			case REDBLUE: { function_damage(i, zl_cvar[5], {255, 0, 255}); function_blue(i, (zl_cvar[12] / 2), (zl_fcvar[1] * 2), {255, 0, 255}); }
			case REDGREEN: if (pev(i, pev_flags) & FL_ONGROUND) function_damage(i, zl_cvar[5], {255, 255, 0})
			case YELLOWBLUE: { function_damage(i, zl_cvar[5], {0, 255, 0}); function_blue(i, (zl_cvar[12] * 2), (zl_fcvar[1] / 2.0), {0, 255, 0}); }
			case YELLOWGREEN: { if (pev(i, pev_flags) & FL_ONGROUND) { function_damage(i, zl_cvar[5] * 2, {127, 255, 0}); function_green(1, (zl_cvar[13] * 2)); }}
			case BLUEGREEN: { function_damage(i, zl_cvar[5] / 2, {0, 255, 255}); function_blue(i, zl_cvar[12], zl_fcvar[1], {0, 255, 255}); function_green(1, (zl_cvar[13] / 2)); }
			case PURPLE: function_damage(i, zl_cvar[5], {255, 0, 255})
			case MIX: if (pev(i, pev_flags) & FL_ONGROUND) ExecuteHamB(Ham_Killed, i, i, 2)
			case MIX2:{
				switch (pev(mix2, pev_num)) {
					case 0: {
						new Float:p[3], Float:b[3], Float:v[3]
						pev(i, pev_origin, p)
						pev(boss, pev_origin, b)
						xs_vec_sub(p, b, v)
						xs_vec_normalize(v, v)
						xs_vec_mul_scalar(v, 1500.0, v)
						v[2] = 500.0
						set_pev(i, pev_velocity, v)
					}
					case 1: { if(~pev(i, pev_flags) & FL_FROZEN) set_pev(i, pev_flags, pev(i, pev_flags) | FL_FROZEN); }
					case 2: ExecuteHamB(Ham_Killed, i, i, 2)
				}
			}
			case PARADOX: {
				if (Width > 150) {
					 if(~pev(i, pev_flags) & FL_ONGROUND)
						continue
				}
				switch(random(3)) {
					case 0: { // Slap
						new Float:a, Float:b, Float:c
						a = random_float(100.0, 1000.0)
						b = random_float(100.0, 1000.0)
						c = 1.0
						set_pev(i, pev_velocity, a, b, c)
						function_damage(i, random(100), Color)
					}
					case 1: { // Drop
						client_cmd(i, "drop")
						new weapon = get_pdata_cbase(i, 373, 5)
						if (weapon > 0) ExecuteHamB(Ham_Weapon_RetireWeapon, weapon)
						client_cmd(i, "drop")
					}
					case 2: { // ScreenFade
						zl_screenshake(i, 5, 2)
					}
				}
			}
			default:function_damage(i, zl_cvar[5], {255, 255, 255})
		}
	}
}

function_fluxing( boss, fluxing) {
	fluxing = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"))
	engfunc(EngFunc_SetModel, fluxing, Resource[5])
	new Float:origin[3]
	pev(boss, pev_origin, origin)
	origin[2] -= (OFFSET_ZORIGIN - 85.0)
	engfunc(EngFunc_SetOrigin, fluxing, origin)
	set_pev(fluxing, pev_classname, "alien_fluxing")
	set_pev(fluxing, pev_nextthink, get_gametime() + 1.1)
	set_pev(fluxing, pev_framerate, 5.0)
	
	/* TESTING RENDERING */
	//set_rendering(fluxing, kRenderFxNone, 255, 255, 255, kRenderTransAdd, 255); set_rendering(boss, kRenderFxGlowShell, 255, 255, 255, kRenderNormal, 50); zl_sound(0, SoundList[7]); 
	//set_rendering(fluxing, kRenderFxNone, 255, 165, 0, kRenderTransAdd, 255); set_rendering(boss, kRenderFxExplode, 255, 165, 0, kRenderNormal, 155); zl_sound(0, SoundList[16])
		
	switch (pev(boss, pev_color)) {
		case REDYELLOW:		{ set_rendering(fluxing, kRenderFxNone, 255, 165, 0, kRenderTransAdd, 255); set_rendering(boss, kRenderFxNone, 255, 165, 0, kRenderTransAdd, 255); zl_sound(0, SoundList[16]); }
		case REDBLUE:		{ set_rendering(fluxing, kRenderFxNone, 255, 0, 255, kRenderTransAdd, 255); set_rendering(boss, kRenderFxNone, 255, 0, 255, kRenderTransAdd, 255); zl_sound(0, SoundList[14]); }
		case REDGREEN:		{ set_rendering(fluxing, kRenderFxNone, 255, 255, 0, kRenderTransAdd, 255); set_rendering(boss, kRenderFxNone, 255, 255, 0, kRenderTransAdd, 255); zl_sound(0, SoundList[13]); }
		case YELLOWBLUE:	{ set_rendering(fluxing, kRenderFxNone, 0, 255, 0, kRenderTransAdd, 255);   set_rendering(boss, kRenderFxNone, 0, 255, 0, kRenderTransAdd, 255);   zl_sound(0, SoundList[9]); }
		case YELLOWGREEN:	{ set_rendering(fluxing, kRenderFxNone, 127, 255, 0, kRenderTransAdd, 255); set_rendering(boss, kRenderFxNone, 127, 255, 0, kRenderTransAdd, 255); zl_sound(0, SoundList[11]); }
		case BLUEGREEN:		{ set_rendering(fluxing, kRenderFxNone, 0, 255, 255, kRenderTransAdd, 255); set_rendering(boss, kRenderFxNone, 0, 255, 255, kRenderTransAdd, 255); zl_sound(0, SoundList[10]); }
		case PURPLE:		{ set_rendering(fluxing, kRenderFxNone, 255, 0, 255, kRenderTransAdd, 255); set_rendering(boss, kRenderFxGlowShell, 255, 0, 255, kRenderNormal, 50); zl_sound(0, SoundList[19]); }
		case MIX:		{ set_rendering(fluxing, kRenderFxNone, 255, 0, 0, kRenderTransAdd, 255); set_rendering(boss, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 50); zl_sound(0, SoundList[18]); }
		case MIX2: {
			switch ( pev( mix2, pev_num ) ) {
				case 0: { set_rendering(fluxing, kRenderFxNone, 255, 255, 255, kRenderTransAdd, 255); set_rendering(boss, kRenderFxGlowShell, 255, 255, 255, kRenderNormal, 50); zl_sound(0, SoundList[17]); }
				case 1: { set_rendering(fluxing, kRenderFxNone, 0, 0, 255, kRenderTransAdd, 255); set_rendering(boss, kRenderFxGlowShell, 0, 0, 255, kRenderNormal, 50); }
				case 2: { set_rendering(fluxing, kRenderFxNone, 255, 0, 0, kRenderTransAdd, 255); set_rendering(boss, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 50); }
			}
		}
		case WHITE: { set_rendering(fluxing, kRenderFxNone, 255, 255, 255, kRenderTransAdd, 255); set_rendering(boss, kRenderFxGlowShell, 255, 255, 255, kRenderNormal, 50); zl_sound(0, SoundList[7]); }
		case PARADOX: { set_rendering(fluxing, kRenderFxNone, 255, 255, 255, kRenderTransAdd, 255); set_rendering(boss, kRenderFxHologram, 255, 255, 255, kRenderTransAdd, random(255)); }
	}
	dllfunc(DLLFunc_Spawn, fluxing)
	return fluxing
}

public infect_touch(ent, player) {
	if(pev(ent, pev_bool)) {
		set_rendering(ent)
		set_pev(ent, pev_bool, 0)
		zl_screenfade(ent)
		
		set_rendering(player, kRenderFxGlowShell, 0, 255, 0, kRenderNormal, 80)
		set_pev(player, pev_bool, 1)
		zl_screenfade(player, 5, 5, {0, 255, 0}, zl_cvar[14], 4)
	}
}

function_endphase() {
	switch(pev(g_Alien, pev_color)) {
		case 1..6: {
			new i
			for(i = 1; i <= g_MaxPlayer; ++i ) {
				if (!is_user_alive(i))
					continue
				
				if (pev(i, pev_bool)) {
					switch(pev(g_Alien, pev_color)) {
						case REDGREEN: function_damage(i, zl_cvar[15], {0, 255, 0})
						case YELLOWGREEN: function_damage(i, zl_cvar[15] * 2, {0, 255, 0})
						case BLUEGREEN: function_damage(i, zl_cvar[15] / 2, {0, 255, 0})
						default: function_damage(i, zl_cvar[15], {0, 255, 0})
					}
					set_rendering(i)
					set_pev(i, pev_bool, 0)
					zl_screenfade(i)
				}
			}
			set_pev(g_Alien, pev_bool, 0)
		}
		case MIX: dllfunc(DLLFunc_Use, e_multi, e_multi)
		case WHITE: {
			new i
			for(i = 1; i <= g_MaxPlayer; ++i ) {
				if (!is_user_connected(i))
					continue
					
				if(pev(i, pev_flags) & FL_FROZEN) 
					set_pev(i, pev_flags, pev(i, pev_flags) & ~FL_FROZEN)
			}
		}
	}
}

function_green(alive, num) {
	new i
	for(alive ? (i = 1) : (i = 0); i < (alive ? ( (zl_player_alive() <= num) ? (zl_player_alive() + 1): num ) : ((num <= 10) ? (num) : 10)); ++i) {
		if (alive) {
			set_rendering(i, kRenderFxGlowShell, 0, 255, 0, kRenderNormal, 80)
			zl_screenfade(i, 5, 5, {0, 255, 0}, zl_cvar[14], 4)
			set_pev(i, pev_bool, 1)
		} else {
			set_rendering(pev(e_zombie[i], pev_zombie), kRenderFxGlowShell, 0, 255, 0, kRenderNormal, 80)
			set_pev(pev(e_zombie[i], pev_zombie), pev_bool, 1)
		}
	}
}

function_blue( player, spd, Float:timer, color[3]) {
	set_pev(player, pev_speed2, float(spd))
	set_pev(player, pev_time, timer)
	set_pev(g_Alien, pev_bool, 1)
	zl_beamfollow(player, floatround(timer), 10, color)
	zl_screenfade(player, floatround(timer), 2, color, 255, 3)
}
	
function_zombie(zombie, hp, spd, dmg) {
	new i
	for(i = 0; i < ((zombie <= 10) ? (zombie) : 10); ++i) {
		new Float:origin[3]
		pev(e_zombie[i], pev_origin, origin)
		set_pev(e_zombie[i], pev_zombie, zl_zombie_create(origin, hp, spd, dmg))
	}
}

public Alien_Fluxing( e ) {
	static id = 1
	static Float:v[3]
	for(id = 1; id <= g_MaxPlayer; id++) {
		if (!is_user_alive( id ))
			continue

		zl_move(id, e, zl_fcvar[5], v)
		v[2] = 0.0
		set_pev(id, pev_velocity, v)
	}
}

attack_effect( boss ) {
	new Float:OriginKnf[3]; pev(boss, pev_origin, OriginKnf); OriginKnf[2] -= OFFSET_ZORIGIN
	new Float:AnglesKnf[3]; pev(boss, pev_angles, AnglesKnf)
	new Eff =  zl_create_entity(
			OriginKnf, Resource[4], 1, 0.7, 
			SOLID_NOT, MOVETYPE_FLY, DAMAGE_NO, DEAD_NO, 
			"info_target", "alien_attack", Float:{-1.0, -1.0, -1.0}, Float:{1.0, 1.0, 1.0})
	
	set_pev(Eff, pev_nextthink, get_gametime() + 0.1)
	set_pev(Eff, pev_num, 255)
	set_pev(Eff, pev_angles, AnglesKnf)
}

public Alien_Attack( e ) {
	#define OFFSET_FADE 15
	if ((pev(e, pev_num) - OFFSET_FADE) > 0) {
		set_rendering(e, kRenderFxNone, 0, 0, 0, kRenderTransAdd, pev(e, pev_num))
		set_pev(e, pev_nextthink, get_gametime() + 0.1)
		set_pev(e, pev_num, pev(e, pev_num) - OFFSET_FADE)
	} else engfunc(EngFunc_RemoveEntity, e)
}

not_player_alive( e ) {
	if (!zl_player_alive()) {
		set_pev(e, pev_nextthink, get_gametime() + 0.1)
		return
	}
}


function_damage(victim, damage, color[3]) {
	if (pev(victim, pev_health) - float(damage) <= 0)
		ExecuteHamB(Ham_Killed, victim, victim, 2)
	else {
		ExecuteHamB(Ham_TakeDamage, victim, 0, victim, float(damage), DMG_BLAST)
		zl_screenfade(victim, 1, 1, color, 170, 1)
	}
}

public Alien_Touch(boss, touch) {
	if (pev(zl_cvar[22], pev_bool)) {
		if (is_user_alive(touch)) {
			ExecuteHamB(Ham_Killed, touch, touch, 2)
		} else {
			new i
			i = zl_create_entity(
				Float:{0.0, 0.0, 0.0}, Resource[10], _, _, 
				SOLID_NOT, MOVETYPE_FOLLOW, _, _, "env_sprite")
			
			//set_pev(boss, pev_null, i)
			e_Stunn = i
			set_pev(i, pev_aiment, boss)
			set_pev(i, pev_body, 1)
			set_pev(i, pev_skin, boss)
			set_pev(i, pev_framerate, 10.0)
			set_pev(boss, pev_nextthink, get_gametime() + zl_fcvar[3])
			set_rendering(pev(boss, pev_healthbar), kRenderFxNone, 255, 255, 255, kRenderTransAdd, 0)
			set_rendering(i, kRenderFxNone, 255, 255, 255, kRenderTransAdd, 255)
			dllfunc(DLLFunc_Spawn, i)
			zl_anim(boss, 0, 1.0)
			zl_colorchat(0, "!n[!gAlienBoss!n] Босс оглушен !g(Урон х2)")
		}
		set_pev(g_Alien, pev_movetype, MOVETYPE_NONE)
		set_pev(zl_cvar[22], pev_bool, 0)
	}
	
	if (!is_user_alive(touch))
		return
	
	if (pev(boss, pev_deadflag) == DEAD_RESPAWNABLE || pev(boss, pev_iuser1) == 1) {
		ExecuteHamB(Ham_Killed, touch, touch, 2)
		//zl_sound(0, SoundList[11])
		return
	}
		
	if (pev(boss, pev_sequence) != 3)
		return
		
	set_pev(boss, pev_victim, touch)
	set_pev(boss, pev_ability, ATTACK)
	set_pev(boss, pev_nextthink, get_gametime() + 0.6)
	zl_anim(boss, 8, 1.0)
	zl_sound(0, SoundList[5])
}

public Alien_HealthBar( e ) {	
	if (pev(g_Alien, pev_deadflag) == DEAD_DYING) {
		engfunc(EngFunc_RemoveEntity, e)
		return
	}
	static Float:percent; percent = pev(g_Alien, pev_health) * 100.0 / pev(g_Alien, pev_max_health)
	
	if (percent < pev(e, pev_num) && pev(g_Alien, pev_sequence) == 3) {
		switch (floatround(percent)) {
			case 0..10:  { set_pev(g_Alien, pev_color, WHITE); set_pev(g_Alien, pev_bool, 0); }
			case 11..20: set_pev(g_Alien, pev_color, MIX2)
			case 21..30: set_pev(g_Alien, pev_color, MIX)
			case 31..40: set_pev(g_Alien, pev_color, PURPLE)
			case 41..50: set_pev(g_Alien, pev_ability, AGGRESSIVE) /* Phase 2 ( A Tbl znal 4to Bos93 ( Andrei ) mydak?�) */ 
			case 51..100: set_pev(g_Alien, pev_color, random_num(1, 6))
		}
		function_endphase()
		
		set_pev(e, pev_num, floatround(percent) - 10)
		if (pev(g_Alien, pev_ability) != AGGRESSIVE) set_pev(g_Alien, pev_ability, CAST)			
	}
	
	#if defined HEALTHBAR
	message_begin(MSG_BROADCAST, get_user_msgid("BarTime2"))
	write_short(97999)
	write_short(floatround((percent >= 100.0) ? 99.0 : percent, floatround_floor))
	message_end()		
	#else
		#if defined SPRMIRROR
		percent = 100 - percent
		#endif
	set_pev(e, pev_effects, pev(e, pev_effects) & ~EF_NODRAW)
	set_pev(e, pev_frame, percent)
	#endif
	
	set_pev(e, pev_nextthink, get_gametime() + 0.1)
}

public Alien_Ship( e ) {
	not_player_alive( e )
	
	if (g_Prepare) {
		set_pev(e, pev_nextthink, get_gametime() + 0.1)
		return
	}
	
	static Float:angle[3], Float:velocity[3], Len
	
	switch ( pev(e, pev_num) ) {
		case 0: { // Entity feature
			engfunc(EngFunc_SetModel, e, Resource[1])
			Len = zl_move(e, pev(e, pev_euser2), 250.0, velocity, angle)
			set_pev(e, pev_movetype, MOVETYPE_FLY)
			set_pev(e, pev_velocity, velocity)
			set_pev(e, pev_angles, angle)
			set_pev(e, pev_body, 1)
			
			if (Len <= OFFSET_RUN) {
				set_pev(e, pev_movetype, MOVETYPE_NONE)
				set_pev(e, pev_body, 0)
				set_pev(e, pev_num, 1)
				set_pev(e, pev_nextthink, get_gametime() + 1.0)
				return
			}
		}
		case 1: { // Event PRE BossStart
			static Alpha
			static lamp; lamp = pev(e, pev_iuser3)
			static light; light = pev(e, pev_iuser1)
			
			if (7+Alpha >= 255) {
				engfunc(EngFunc_SetSize, g_Alien, Float:{-42.0, -42.0, -32.0}, Float:{42.0, 42.0, 72.0})
				set_pev(g_Alien, pev_max_health, float(zl_health(zl_cvar[1])))
				set_pev(g_Alien, pev_health, float(zl_health(zl_cvar[1])))
				set_pev(g_Alien, pev_classname, "alien_boss")
				set_pev(g_Alien, pev_solid, SOLID_BBOX)
				set_pev(g_Alien, pev_movetype, MOVETYPE_TOSS)
				set_pev(g_Alien, pev_nextthink, get_gametime() + 8.0)
				set_pev(e, pev_nextthink, get_gametime() + 0.1)
				set_pev(e, pev_num, 2)
				set_rendering(g_Alien)
				zl_anim(g_Alien, 2, 1.0)
				zl_sound(0, SoundList[15])
				engfunc(EngFunc_RemoveEntity, lamp)
				engfunc(EngFunc_RemoveEntity, light)
				return
			}
			if (pev(g_Alien, pev_deadflag) != DEAD_RESPAWNABLE) {
				engfunc(EngFunc_SetModel, light, Resource[2])
				engfunc(EngFunc_SetModel, g_Alien, Resource[0])
				set_rendering(light, kRenderFxNone, 255, 255, 255, kRenderTransAdd, 90)
				set_rendering(lamp, kRenderFxNone, 255, 255, 255, kRenderTransAdd, 90)
				set_pev(g_Alien, pev_deadflag, DEAD_RESPAWNABLE)
				zl_spawnground(g_Alien, 32.0)
			}
			set_rendering(g_Alien, kRenderFxNone, 255, 255, 255, kRenderTransAdd, Alpha)
			Alpha += 7
			
		}
		case 2: {
			Len = zl_move(e, pev(e, pev_button), 500.0, velocity, angle)
			set_pev(e, pev_movetype, MOVETYPE_FLY)
			set_pev(e, pev_velocity, velocity)
			set_pev(e, pev_angles, angle)
			set_pev(e, pev_body, 1)
			
			if (Len <= OFFSET_RUN) {
				engfunc(EngFunc_RemoveEntity, e)
				return
			}
		}
	}
	set_pev(e, pev_nextthink, get_gametime() + 0.1)
}

public zl_timer(timer, Prepare) {
	if(Prepare) return
	
	g_Prepare = false
	
	if (pev_valid(g_Alien) && pev(g_Alien, pev_bool) == 1) {
		new i = 1
		for(i = 1; i <= g_MaxPlayer; ++i ) {
			if(!is_user_connected(i))
				continue
			
			if (pev(i, pev_time) <= 0) {
				set_pev(i, pev_speed2, 0.0)
				set_pev(i, pev_maxspeed, 255.0)
				//set_pev(g_Alien, pev_bool, 0)
				zl_beamkill(i)
				continue
			}
			set_pev(i, pev_time, (pev(i, pev_time) - 1.0))
		}
	}
	
	#if defined SUPPORT_ZM
	if (pev(zl_cvar[20], pev_button) != 1)
		return
	
	static ZombieNum	
	if (pev(e_multi, pev_fuser2) < get_gametime()) {
		if (ZombieNum < (MAX_ZOMBIE - 1)) ZombieNum++
		set_pev(e_multi, pev_fuser2, get_gametime() + float(zl_cvar[20]))
	}
	
	if (pev(e_multi, pev_fuser1) < get_gametime()) {
		for (new i; i < ZombieNum; ++i) {
			new Float:Origin[3]
			pev(e_zombie[i], pev_origin, Origin)
			zl_zombie_create(Origin, zl_cvar[11], zl_cvar[9], zl_cvar[10])
			set_pev(e_multi, pev_fuser1, get_gametime() + float(zl_cvar[21]))
		}
	}
	#endif
	
	static Float:AggressiveDamageTimer
	if (AggressiveDamageTimer <= get_gametime()) {
		AggressiveDamageTimer = get_gametime() + zl_fcvar[4]
		
		if (zl_player_alive() >= zl_cvar[24])
			return
		
		new i
		for(i = 1; i <= g_MaxPlayer; ++i) {
			if (!is_user_alive(i))
				continue
				
			function_damage(i, zl_cvar[3], {255, 0, 0})
		}
		zl_colorchat(0, "!n[!gAlienBoss!n] !tАгония! !nВсе игроки получили урон в размере !g%d !nединиц", zl_cvar[3])
	}
}

public Alien_TraceAttack(v, a, Float:dmg, Float:direction[3], th, dt) {
	if (!zl_boss_valid(v))
		return HAM_IGNORED
	
	if (pev(v, pev_color) == MIX) {
		if (!is_user_alive(a))
			return HAM_IGNORED
		
		function_damage(a, zl_cvar[19], {255, 0, 0})
	}
	return HAM_IGNORED
}

public Alien_TakeDamage(boss, w, player, Float:dmg, dt) {
	if (!zl_boss_valid( boss ))
		return HAM_IGNORED
		
	if (!is_user_alive(player) && !is_user_alive(boss))
		return HAM_SUPERCEDE
		
	//if (pev(boss, pev_null)) {
	if (pev_valid(e_Stunn)) {
		SetHamParamFloat(4, dmg * 2.0)
		return HAM_IGNORED
	}
	return HAM_IGNORED
}
public Player_SpeedHook( id ) {
	if (pev(id, pev_speed2) <= 0)
		return HAM_IGNORED
	
	static Float:spd
	pev(id, pev_speed2, spd)
	set_pev(id, pev_maxspeed, spd)
	return HAM_IGNORED
}

public Player_Spawn(id) {	
	//if (pev(g_Alien, pev_button) == 0) {
		if(pev(g_Alien, pev_deadflag) == DEAD_DEAD)
			if(is_user_connected(id))
				zl_sound(id, SoundList[20])
		//else
			//client_cmd(id, "mp3 play ^"sound/%s^"", SoundList[15])
	//} else client_cmd(id, "mp3 play ^"sound/%s^"", SoundList[14])
}

public changemap() {
	#if defined MAPCHOOSER
	zl_vote_start()
	#else
	server_cmd("changelevel ^"%s^"", boss_nextmap)
	#endif
}

MapEvent() {
	new e_base[5], e_laser // Start Event ( Ship ) 0 - Start, 1 - BossPosition, 2 - End
	static i, ClassName[32], szDmg[32]
	formatex(szDmg, charsmax(szDmg), "%d", zl_cvar[17] * 2)
	trim(szDmg)
	for (i = 0; i < 3; ++i) {
		formatex(ClassName, charsmax(ClassName), "ship_%d", i+1)
		e_base[i] = engfunc(EngFunc_FindEntityByString, e_base[i], "targetname", ClassName)
	}
	for (i = 0; i < sizeof e_zombie; ++i) {
		formatex(ClassName, charsmax(ClassName), "zombie_%d", i + 1)
		e_zombie[i] = engfunc(EngFunc_FindEntityByString, e_zombie[i], "targetname", ClassName)
	}
	for (i = 0; i < sizeof e_bomb; ++i) {
		formatex(ClassName, charsmax(ClassName), "bomb%d", i)
		e_bomb[i] = engfunc(EngFunc_FindEntityByString, e_bomb[i], "targetname", ClassName)
		DispatchKeyValue(e_bomb[i], "iMagnitude", szDmg)
	}
	e_base[3] = engfunc(EngFunc_FindEntityByString, e_base[3], "targetname", "glow")
	e_base[4] = engfunc(EngFunc_FindEntityByString, e_base[4], "targetname", "light")
	g_Alien = engfunc(EngFunc_FindEntityByString, g_Alien, "targetname", "boss")
	e_center = engfunc(EngFunc_FindEntityByString, g_Alien, "targetname", "center")
	e_laser = engfunc(EngFunc_FindEntityByString, e_laser, "targetname", "damage")
	e_multi = engfunc(EngFunc_FindEntityByString, e_multi, "targetname", "multi")
	set_pev(e_base[0], pev_euser2, e_base[1])
	set_pev(e_base[0], pev_button, e_base[2])
	set_pev(e_base[0], pev_iuser3, e_base[3])
	set_pev(e_base[0], pev_iuser1, e_base[4])
	set_pev(e_base[0], pev_classname, "alien_ship")
	set_pev(e_base[2], pev_classname, "alien_timer")
	set_pev(e_base[2], pev_nextthink, get_gametime() + 1.0)
	set_pev(e_base[0], pev_nextthink, get_gametime() + float(zl_cvar[0]))
	set_pev(g_Alien, pev_deadflag, DEAD_DEAD)
	
	formatex(szDmg, charsmax(szDmg), "%d", zl_cvar[16] * 2)
	trim(szDmg)
	DispatchKeyValue(e_laser, "damage", szDmg)
	
	// Redacting maps...
	new Float:Origin[3]
	pev(g_Alien, pev_origin, Origin)
	Origin[2] += 240.0
	set_pev(g_Alien, pev_origin, Origin)
	
}

config_load() {
	//if (zl_boss_map() != 2)
	//	return
	
	#if defined BUGFIX
	set_cvar_num("mp_limitteams", 0)
	set_cvar_num("mp_autoteambalance", 0)
	#endif
		
	new path[64]
	get_localinfo("amxx_configsdir", path, charsmax(path))
	format(path, charsmax(path), "%s/zl/zl_alienboss.ini", path)
    
	if (!file_exists(path)) {
		new error[100]
		formatex(error, charsmax(error), "Cannot load customization file %s!", path)
		set_fail_state(error)
		return
	}
    
	new linedata[2048], key[64], value[960], section
	new file = fopen(path, "rt")
    
	while (file && !feof(file)) {
		fgets(file, linedata, charsmax(linedata))
		replace(linedata, charsmax(linedata), "^n", "")
       
		if (!linedata[0] || linedata[0] == '/') continue;
		if (linedata[0] == '[') { section++; continue; }
       
		strtok(linedata, key, charsmax(key), value, charsmax(value), '=')
		trim(key)
		trim(value)
		
		switch (section) { 
			case 1: { // GENERAL
				if (equal(key, "TIME_PREPARE"))
					zl_cvar[0] = str_to_num(value)
				#if !defined MAPCHOOSER
				else if (equal(key, "NEXT_MAP"))
					parse(value, boss_nextmap, charsmax(boss_nextmap))
				#endif
				else if (equal(key, "BOSS_HEALTH"))
					zl_cvar[1] = str_to_num(value)
				else if (equal(key, "BOSS_SPEED"))
					zl_cvar[2] = str_to_num(value)
				else if (equal(key, "BOSS_SPEED_FLUX"))
					zl_fcvar[5] = str_to_float(value)
				else if (equal(key, "BOSS_DMG"))
					zl_cvar[4] = str_to_num(value)
				else if (equal(key, "BOSS_DMG_SW"))
					zl_cvar[5] = str_to_num(value)
				else if (equal(key, "BOSS_TIME_MD"))
					zl_cvar[22] = str_to_num(value)
				else if (equal(key, "BOSS_MD_STUN"))
					zl_fcvar[3] = str_to_float(value)
				else if (equal(key, "SPR_SIZE"))
					zl_fcvar[0] = str_to_float(value)
			}
			case 2: { // Zombie
				if (equal(key, "ZOMBIE_RED"))
					zl_cvar[6] = str_to_num(value)
				else if (equal(key, "ZOMBIE_BLUE"))
					zl_cvar[7] = str_to_num(value)
				else if (equal(key, "ZOMBIE_GREEN"))
					zl_cvar[8] = str_to_num(value)
				else if (equal(key, "ZOMBIE_SPEED"))
					zl_cvar[9] = str_to_num(value)
				else if (equal(key, "ZOMBIE_DMG"))
					zl_cvar[10] = str_to_num(value)
				else if (equal(key, "ZOMBIE_HEALTH"))
					zl_cvar[11] = str_to_num(value)
				else if (equal(key, "ZOMBIE_TIME_ADD"))
					zl_cvar[20] = str_to_num(value)
				else if (equal(key, "ZOMBIE_TIME_SPAWN"))
					zl_cvar[21] = str_to_num(value)
			}
			case 3: { // Blue
				if (equal(key, "BLUE_SPEED"))
					zl_cvar[12] = str_to_num(value)
				else if (equal(key, "BLUE_TIME"))
					zl_fcvar[1] = str_to_float(value)
			}
			case 4: { // Green
				if (equal(key, "GREEN_ZOMBIE"))
					zl_cvar[13] = str_to_num(value)
				else if (equal(key, "GREEN_ALPHA"))
					zl_cvar[14] = str_to_num(value)
				else if (equal(key, "GREEN_DMG"))
					zl_cvar[15] = str_to_num(value)
			}
			case 5: { // Other
				if (equal(key, "PURPLE_DMG_L"))
					zl_cvar[16] = str_to_num(value)
				else if (equal(key, "PURPLE_DMG_B"))
					zl_cvar[17] = str_to_num(value)
				else if (equal(key, "PURPLE_NUM_B"))
					zl_cvar[18] = str_to_num(value)
				else if (equal(key, "MIX_DMG"))
					zl_cvar[19] = str_to_num(value)
				else if (equal(key, "WHITE_NUM"))
					zl_cvar[23] = str_to_num(value)	
				else if (equal(key, "WHITE_TIME"))
					zl_fcvar[2] = str_to_float(value)
					
				else if (equal(key, "AG_TIME"))
					zl_fcvar[4] = str_to_float(value)
				else if (equal(key, "AG_DAMAGE"))
					zl_cvar[3] = str_to_num(value)
				else if (equal(key, "AG_PLAYER"))
					zl_cvar[24] = str_to_num(value)
			}
		}
	}
	if (file) fclose(file)
}

public plugin_precache() {
	if (zl_boss_map() != 2)
		return
	
	new i
	for (i = 0; i<sizeof Resource; ++i)
		g_Resource[i] = precache_model(Resource[i])
		
	for (i = 0; i<sizeof SoundList; ++i)
		precache_sound(SoundList[i])
		
	config_load()
}

stock zl_create_entity 
	(
		Float:Origin[3], 
		Model[] = "models/player/sas/sas.mdl", 
		HP = 100,
		Float:NextThink = 1.0,
		SOLID_ = SOLID_BBOX, 
		MOVETYPE_ = MOVETYPE_PUSHSTEP, 
		Float:DAMAGE_ = DAMAGE_YES, 
		DEAD_ = DEAD_NO, 
		ClassNameOld[] = "info_target", 
		ClassNameNew[] = "player_entity", 
		Float:SizeMins[3] = {-32.0, -32.0, -36.0}, 
		Float:SizeMax[3] = {32.0, 32.0, 96.0}, 
		bool:invise = false
	) {
	
	new Ent = create_entity(ClassNameOld)
	
	if (!is_valid_ent(Ent))
		return 0
	
	entity_set_model(Ent, Model)
	entity_set_size(Ent, SizeMins, SizeMax)
	entity_set_origin(Ent, Origin)
	if (NextThink > 0.0) entity_set_float(Ent, EV_FL_nextthink, get_gametime() + NextThink)
	if (invise) entity_set_int(Ent, EV_INT_effects, entity_get_int(Ent, EV_INT_effects) & ~EF_NODRAW)
	entity_set_string(Ent, EV_SZ_classname, ClassNameNew)
	entity_set_int(Ent, EV_INT_solid, SOLID_)
	entity_set_int(Ent, EV_INT_movetype, MOVETYPE_)
	entity_set_int(Ent, EV_INT_deadflag, DEAD_)
	entity_set_float(Ent, EV_FL_dmg_take, DAMAGE_)
	entity_set_float(Ent, EV_FL_max_health, float(HP))
	entity_set_float(Ent, EV_FL_health, float(HP))
	
	return Ent
}

stock zl_move(Start, End, Float:speed = 250.0, Float:Velocity[] = {0.0, 0.0, 0.0}, Float:Angles[] = {0.0, 0.0, 0.0}) {
	new Float:Origin[3], Float:Origin2[3], Float:Angle[3], Float:Vector[3], Float:Len
	pev(Start, pev_origin, Origin2)
	pev(End, pev_origin, Origin)
	
	xs_vec_sub(Origin, Origin2, Vector)
	Len = xs_vec_len(Vector)
	
	vector_to_angle(Vector, Angle)
	
	Angles[0] = 0.0
	Angles[1] = Angle[1]
	Angles[2] = 0.0
	
	xs_vec_normalize(Vector, Vector)
	xs_vec_mul_scalar(Vector, speed, Velocity)
	
	return floatround(Len, floatround_round)
}

stock zl_anim(ent, sequence, Float:speed) {		
	set_pev(ent, pev_sequence, sequence)
	set_pev(ent, pev_animtime, halflife_time())
	set_pev(ent, pev_framerate, speed)
	set_pev(ent, pev_frame, 0.0)
}

stock zl_health(hp) {
	new Hp
	#if defined PLAYER_HP
	new Count, id
	for(id = 1; id <= g_MaxPlayer; id++)
		if (is_user_connected(id))
			Count++
			
	Hp = hp * Count
	#else
	Hp = hp
	#endif
	return Hp
}

stock zl_sound(index, sound[]) {
	if (contain(sound, ".wav") == -1) {
		client_cmd(index, "mp3 play ^"sound/%s^"", sound)
	} else {
		message_begin(index ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, get_user_msgid("SendAudio"), _, index)	
		write_byte(index)
		write_string(sound)
		write_short(PITCH_NORM)
		message_end()
	}
}

stock zl_shockwave(Float:o[3], Width, Len, Color[3]) {
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, o, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, o[0]) // x
	engfunc(EngFunc_WriteCoord, o[1]) // y
	engfunc(EngFunc_WriteCoord, o[2] - 35.0) // z
	engfunc(EngFunc_WriteCoord, o[0]) // x axis
	engfunc(EngFunc_WriteCoord, o[1]) // y axis
	engfunc(EngFunc_WriteCoord, o[2] + float(Len * 2)) // z axis
	write_short(g_Resource[6]) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(5) // life (4)
	write_byte(Width) // width (20)
	write_byte(0) // noise
	write_byte(Color[0]) // red
	write_byte(Color[1]) // green
	write_byte(Color[2]) // blue
	write_byte(255) // brightness
	write_byte(0) // speed
	message_end()
}

stock zl_screenshake(id, ampl, timer) {
	if(id) if(!is_user_alive(id)) return
	
	if (ampl > 15)
		ampl = 15
	
	message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, get_user_msgid("ScreenShake"), _, id ? id : 0);
	write_short(ampl << 12)
	write_short(timer << 12)
	write_short(7 << 12)
	message_end()
}

stock zl_screenfade(id, Timer = 1, FadeTime = 1, Colors[3] = {0, 0, 0}, Alpha = 0, type = 1) {
	if(id) if(!is_user_connected(id)) return

	if (Timer > 0xFFFF) Timer = 0xFFFF
	if (FadeTime <= 0) FadeTime = 4
	
	message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, get_user_msgid("ScreenFade"), _, id);
	write_short(Timer * 1 << 12)
	write_short(FadeTime * 1 << 12)
	switch (type) {
		case 1: write_short(0x0000)		// IN ( FFADE_IN )
		case 2: write_short(0x0001)		// OUT ( FFADE_OUT )
		case 3: write_short(0x0002)		// MODULATE ( FFADE_MODULATE )
		case 4: write_short(0x0004)		// STAYOUT ( FFADE_STAYOUT )
		default: write_short(0x0001)
	}
	write_byte(Colors[0])
	write_byte(Colors[1])
	write_byte(Colors[2])
	write_byte(Alpha)
	message_end()
}

stock zl_beamfollow(id, Life, Size, Color[3]) {
	if (is_user_alive(id) || pev_valid(id)) {
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)	// TE_BEAMFOLLOW ( msg #22) create a line of decaying beam segments until entity stops moving
		write_byte(TE_BEAMFOLLOW)	// msg id
		write_short(id)			// short (entity:attachment to follow)
		write_short(g_Resource[7])	// short (sprite index)
		write_byte(Life * 10)		// byte (life in 0.1's)
		write_byte(Size)              	// byte (line width in 0.1's)
		write_byte(Color[0])		// byte (color)
		write_byte(Color[1])		// byte (color)
		write_byte(Color[2])		// byte (color)
		write_byte(255)			// byte (brightness)
		message_end()
	}
}

stock zl_beamkill(id) {
	if (!is_user_connected(id))
		return
		
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_KILLBEAM)
	write_short(id)
	message_end()
}

stock zl_spawnground(entity, Float:offsets) {
	#define ADD_OFFSET 300.0
	new Float:start_origin[3], Float:end_origin[3]
	new tr
	pev(entity, pev_origin, start_origin)
	
	end_origin = start_origin
	start_origin[2] += ADD_OFFSET
	end_origin[2] -= ADD_OFFSET
	
	
	engfunc(EngFunc_TraceLine, start_origin, end_origin, IGNORE_MONSTERS, entity, tr)
	get_tr2(tr, TR_vecEndPos, end_origin)
	
	end_origin[2] += offsets
	set_pev(entity, pev_origin, end_origin)
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1049\\ f0\\ fs16 \n\\ par }
*/
