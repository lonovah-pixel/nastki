local A=STALKER_ADMIN
A.Config={
 Title="КОМЕНДАНТ",Version="1.0.0",MaxTargets=16,MaxBanMinutes=525600,MaxReasonBytes=240,
 LogDays=90,MaxPageRows=40,AllowSelfGod=true,
 -- Add your exact SteamID64 here, or use sta_setrole from the server console.
 Owners={}, -- ["76561198000000000"]=true
 GroupRoles={superadmin="superadmin",admin="admin",moderator="moderator",operator="helper"},
 Roles={
  user={label="Сталкер",rank=0,permissions={}},
  helper={label="Наблюдатель",rank=10,permissions={view=true,observe=true,warn=true,teleport=true,logs=true}},
  moderator={label="Модератор",rank=30,permissions={view=true,observe=true,warn=true,kick=true,ban=true,mute=true,freeze=true,teleport=true,logs=true,bans=true}},
  admin={label="Администратор",rank=60,permissions={view=true,observe=true,warn=true,kick=true,ban=true,mute=true,freeze=true,teleport=true,logs=true,bans=true,players=true,noclip=true,loadout=true,announce=true,zone=true}},
  superadmin={label="Комендант",rank=90,permissions={all=true}},
  owner={label="Владелец",rank=100,permissions={all=true}}
 },
 -- Native weapon classes that the panel is allowed to give. No arbitrary entity spawning.
 Weapons={weapon_crowbar=true,weapon_pistol=true,weapon_smg1=true,weapon_shotgun=true,weapon_ar2=true,weapon_physgun=true,gmod_tool=true},
 -- Empty = installed maps from maps/*.bsp. Otherwise only these names.
 Maps={},
}
function A.Int(v,lo,hi) return type(v)=="number" and v==v and v%1==0 and v>=lo and v<=hi end
function A.SID(s) return type(s)=="string" and #s==17 and s:match("^7656119%d+$")~=nil end
function A.Text(s,limit)
 if type(s)~="string" or #s>(limit or A.Config.MaxReasonBytes) or s:find("[%z\1-\31\127]") then return nil end
 return s:match("^%s*(.-)%s*$")
end
