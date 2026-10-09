local F=STFW
function F.Admission(p,id)
 local d=F.Load(p);local grant=d and d.admissions and d.admissions[id]
 if grant and grant.expires>os.time() and F.World.leaders[id]==grant.leader then return true,nil,0 end
 local fee=math.max(0,math.floor(F.Config.JoinFees[id] or F.Config.JoinFee))
 if fee==0 then return true,nil,0 end
 if not p.getDarkRPVar or not p.addMoney then return false,"admission_required" end
 local money=p:getDarkRPVar("money")
 if type(money)~="number" or money<fee then return false,"admission_required" end
 return true,nil,fee
end
function F.GrantAdmission(p,sid,revoke)
 if not F.IsLeader(p) or type(sid)~="string" or #sid~=17 or not sid:match("^%d+$") then return false,"unauthorized" end
 local id=F.Load(p).faction;local target
 for _,other in ipairs(player.GetHumans()) do if other:SteamID64()==sid then target=other end end
 if not IsValid(target) or target==p then return false,"denied" end
 local d=F.Load(target);if not d or (d.joined and d.faction==id) then return false,"denied" end
 d=table.Copy(d);d.admissions=d.admissions or {}
 d.admissions[id]=not revoke and {leader=p:SteamID64(),expires=os.time()+F.Config.ApprovalLifetime} or nil
 if not F.Commit(table.Copy(F.World),{[sid]=d},"admission "..id.." "..sid) then return false,"storage" end
 target:ChatPrint(revoke and "Допуск в группировку отозван." or ("Лидер разрешил бесплатное вступление в "..F.Name(id)..". Обратитесь к вербовщику."))
 return true
end
concommand.Add("stfw_approve",function(p,_,args)
 if not IsValid(p) then return end
 local ok,err=F.GrantAdmission(p,args[1],args[2]=="revoke");F.Notify(p,ok and "saved" or (err or "denied"))
end)
