-- ============================================================
-- DUNGEON QUEST AUTO FARM — FINAL v7 (Part 1/8)
-- ============================================================
local P=game:GetService("Players")local LP=P.LocalPlayer
local RS=game:GetService("ReplicatedStorage")local WS=game:GetService("Workspace")
local UIS=game:GetService("UserInputService")local T=game:GetService("TweenService")
local VIM=game:GetService("VirtualInputManager")
local CG local okCG=pcall(function()CG=game:GetService("CoreGui")end)
if okCG and CG then local o=CG:FindFirstChild("DQAF")if o then o:Destroy()end end
local PG=LP:WaitForChild("PlayerGui")local oP=PG:FindFirstChild("DQAF")if oP then oP:Destroy()end

local cfg={WalkFlow=false,ESPLines=false,GroundESP=false,AutoSwing=false,AutoCollect=false,AutoDungeon=false,NoClip=false,Hitbox=false,AutoDodge=false,AutoSkill=false,FreezeNPC=false,HitboxVisual=false,HoverFarm=false,ESPOverlay=false,WalkDelay=0.2,SwingDelay=0.08,CollectRange=250,ESPRange=800,HitboxSize=2.5,DodgeRange=10,DodgeSpeed=12,SwingReach=6,SkillQDelay=1.5,SkillEDelay=1.5,HoverHeight=13,TargetPriority=1}

local CONFIG_FILE="dqaf_config.txt"
local hasFileIO=(writefile and readfile and isfile) and true or false
local function serializeConfig()local p={}for k,v in pairs(cfg)do local t=type(v)if t=="boolean"or t=="number"then table.insert(p,k.."="..tostring(v))end end return table.concat(p,"\n")end
local function parseConfig(str)local r={}for line in string.gmatch(str,"[^\n]+")do local k,v=string.match(line,"^(%w+)=(.+)$")if k and v then if v=="true"then r[k]=true elseif v=="false"then r[k]=false elseif tonumber(v)then r[k]=tonumber(v)end end end return r end
local function loadConfig()if not hasFileIO then print("[DQAF] writefile gak support")return end if not isfile(CONFIG_FILE)then print("[DQAF] Config default")return end local ok,data=pcall(readfile,CONFIG_FILE)if not ok or not data then return end local parsed=parseConfig(data)local c=0 for k,v in pairs(parsed)do if cfg[k]~=nil then cfg[k]=v c=c+1 end end print("[DQAF] Config loaded:",c,"values")end
local function saveConfig()if not hasFileIO then return end pcall(writefile,CONFIG_FILE,serializeConfig())end
local function resetConfig()if hasFileIO and isfile(CONFIG_FILE)then pcall(delfile,CONFIG_FILE)end print("[DQAF] Config dihapus")end
local function snapshot()local t={}for k,v in pairs(cfg)do local ty=type(v)if ty=="boolean"or ty=="number"then t[k]=v end end return t end
local function cfgDiff(a,b)if not a or not b then return true end for k,v in pairs(a)do if b[k]~=v then return true end end return false end
loadConfig()
task.spawn(function()local last=snapshot()while true do task.wait(2)local cu=snapshot()if cfgDiff(last,cu)then last=cu saveConfig()end end end)

local char,hrp,hum
local function rc()char=LP.Character or LP.CharacterAdded:Wait()hrp=char:WaitForChild("HumanoidRootPart",5)hum=char:WaitForChild("Humanoid",5)end
rc()LP.CharacterAdded:Connect(function()task.wait(1)rc()end)

local cur=nil local espCache={} local dodgeLock=0
-- ==================== HELPERS ====================
local function inD()local v=WS:FindFirstChild("dungeonStarted")return v and v:IsA("BoolValue")and v.Value end
local function wv()local v=WS:FindFirstChild("currentWave")return v and v.Value or 0 end
local function isE(m)if not m or not m:IsA("Model")then return false end if m==char then return false end local h=m:FindFirstChildOfClass("Humanoid")if not h or h.Health<=0 then return false end if P:GetPlayerFromCharacter(m)then return false end if not m:FindFirstChild("HumanoidRootPart")then return false end return true end
local function eList()local l={}for _,v in ipairs(WS:GetDescendants())do if isE(v)then local hE=v:FindFirstChild("HumanoidRootPart")if hE then table.insert(l,v)end end end return l end

-- Near: pakai Target Priority (1=Closest, 2=Lowest HP)
local function near()
    if not hrp then return nil end
    local best=nil local bestVal=math.huge
    for _,e in ipairs(eList())do
        local hE=e:FindFirstChild("HumanoidRootPart")
        if hE then
            if cfg.TargetPriority==2 then
                local h=e:FindFirstChildOfClass("Humanoid")
                local hp=h and h.Health or math.huge
                if hp<bestVal then bestVal=hp best=e end
            else
                local d=(hE.Position-hrp.Position).Magnitude
                if d<bestVal then bestVal=d best=e end
            end
        end
    end
    return best
end

local function getT()if cur and cur.Parent and isE(cur)then local hE=cur:FindFirstChild("HumanoidRootPart")if hE and hrp and(hE.Position-hrp.Position).Magnitude<200 then return cur end end cur=near()return cur end
task.spawn(function()while true do if cur then local h=cur:FindFirstChildOfClass("Humanoid")if not h or h.Health<=0 or not cur.Parent then cur=nil end end task.wait(0.1)end end)

local function autoEquip()
    if not char then return end
    local h=char:FindFirstChildOfClass("Humanoid")if not h then return end
    for _,t in ipairs(char:GetChildren())do if t:IsA("Tool")then return end end
    local bp=LP:FindFirstChild("Backpack")if not bp then return end
    for _,t in ipairs(bp:GetChildren())do if t:IsA("Tool")then pcall(function()h:EquipTool(t)end)return end end
end

local function noclipLoop()
    while cfg.NoClip do
        if char then for _,p in ipairs(char:GetDescendants())do if p:IsA("BasePart")then pcall(function()p.CanCollide=false end)end end end
        task.wait(0.2)
    end
    if char then for _,p in ipairs(char:GetDescendants())do if p:IsA("BasePart")and p.Name~="HumanoidRootPart"then pcall(function()p.CanCollide=true end)end end end
end

local toolHitboxOrig={}
local function applyMyHitbox()
    if not char then return end
    for _,tool in ipairs(char:GetChildren())do
        if tool:IsA("Tool")then
            local handle=tool:FindFirstChild("Handle")
            if handle then
                local orig=toolHitboxOrig[tool]
                if orig then
                    if orig.applied~=cfg.HitboxSize then
                        pcall(function()handle.Size=orig.size*cfg.HitboxSize end)
                        orig.applied=cfg.HitboxSize
                    end
                else
                    toolHitboxOrig[tool]={size=handle.Size,applied=cfg.HitboxSize}
                    pcall(function()handle.Size=handle.Size*cfg.HitboxSize handle.CanQuery=true handle.CanTouch=true end)
                end
            end
        end
    end
end
local function restoreMyHitbox()
    for tool,orig in pairs(toolHitboxOrig)do
        if tool and tool.Parent then
            local handle=tool:FindFirstChild("Handle")
            if handle then pcall(function()handle.Size=orig.size end)end
        end
    end
    toolHitboxOrig={}
end
local function hitboxLoop()
    while cfg.Hitbox do applyMyHitbox() task.wait(0.3)end
    restoreMyHitbox()
end
LP.CharacterAdded:Connect(function()task.wait(1)toolHitboxOrig={}end)

-- ==================== FREEZE NPC ====================
local frozenNPCs={}
local function freezeNPC(m)
    if not m or not m.Parent then return end
    local h=m:FindFirstChildOfClass("Humanoid")
    local hrpE=m:FindFirstChild("HumanoidRootPart")
    if not h then return end
    if frozenNPCs[h]then
        pcall(function()h.WalkSpeed=0 h.JumpPower=0 h.JumpHeight=0 end)
        if hrpE then pcall(function()hrpE.Anchored=true end)end
        return
    end
    frozenNPCs[h]={walk=h.WalkSpeed,jump=h.JumpPower,jheight=h.JumpHeight}
    pcall(function()h.WalkSpeed=0 h.JumpPower=0 h.JumpHeight=0 end)
    if hrpE then pcall(function()hrpE.Anchored=true end)end
end
local function unfreezeNPC(h)
    if not h then return end
    local orig=frozenNPCs[h]if not orig then return end
    pcall(function()h.WalkSpeed=orig.walk h.JumpPower=orig.jump h.JumpHeight=orig.jheight end)
    local m=h.Parent
    if m then local hrpE=m:FindFirstChild("HumanoidRootPart")if hrpE then pcall(function()hrpE.Anchored=false end)end end
    frozenNPCs[h]=nil
end
local function freezeLoop()
    while cfg.FreezeNPC do
        for _,m in ipairs(eList())do freezeNPC(m)end
        for h,_ in pairs(frozenNPCs)do if not h.Parent then frozenNPCs[h]=nil end end
        task.wait(0.4)
    end
    for h,_ in pairs(frozenNPCs)do unfreezeNPC(h)end
    frozenNPCs={}
end
-- ==================== HOVER FARM ====================
local hoverOrigPlatformStand=false
local function hoverLoop()
    while cfg.HoverFarm do
        if char and hum and hum.Health>0 then
            local t=getT()
            if t then
                local hE=t:FindFirstChild("HumanoidRootPart")
                if hE and hrp then
                    local targetPos=Vector3.new(
                        hE.Position.X,
                        hE.Position.Y+cfg.HoverHeight,
                        hE.Position.Z
                    )
                    pcall(function()
                        hrp.CFrame=CFrame.new(targetPos,Vector3.new(hE.Position.X,hE.Position.Y,hE.Position.Z))
                    end)
                    pcall(function()hum.PlatformStand=true end)
                    local h=t:FindFirstChildOfClass("Humanoid")
                    if not h or h.Health<=0 then cur=nil end
                end
            end
        end
        task.wait(0.05)
    end
    if hum then pcall(function()hum.PlatformStand=false end)end
end

-- ==================== ESP OVERLAY ====================
local espOverlayCache={}
local DrawingSq=Drawing.new("Square")
local SquareSupport=pcall(function()local s=Drawing.new("Square")s:Remove()end)

local function createESPOverlay(model)
    if not SquareSupport then return nil end
    local data={}
    data.box=Drawing.new("Square")
    data.box.Visible=false
    data.box.Color=Color3.fromRGB(255,60,60)
    data.box.Thickness=1
    data.box.Transparency=1
    data.box.Filled=false

    data.hpBg=Drawing.new("Square")
    data.hpBg.Visible=false
    data.hpBg.Color=Color3.fromRGB(30,30,30)
    data.hpBg.Filled=true
    data.hpBg.Transparency=0.6

    data.hpFg=Drawing.new("Square")
    data.hpFg.Visible=false
    data.hpFg.Color=Color3.fromRGB(0,255,100)
    data.hpFg.Filled=true
    data.hpFg.Transparency=1

    data.nameText=Drawing.new("Text")
    data.nameText.Visible=false
    data.nameText.Center=true
    data.nameText.Outline=true
    data.nameText.Color=Color3.fromRGB(255,255,255)
    data.nameText.Size=13
    data.nameText.Font=2

    espOverlayCache[model]=data
    return data
end

local function removeESPOverlay(model)
    local d=espOverlayCache[model]
    if not d then return end
    for _,obj in pairs(d)do pcall(function()obj:Remove()end)end
    espOverlayCache[model]=nil
end

local function clearAllESPOverlay()
    for m,_ in pairs(espOverlayCache)do removeESPOverlay(m)end
    espOverlayCache={}
end

task.spawn(function()
    local cam=WS.CurrentCamera
    while true do
        if cfg.ESPOverlay and SquareSupport and hrp and cam then
            local enemies=eList()
            for _,e in ipairs(enemies)do
                if not espOverlayCache[e]then createESPOverlay(e)end
            end
            for m,_ in pairs(espOverlayCache)do
                if not m.Parent or not isE(m)then removeESPOverlay(m)end
            end
            for m,d in pairs(espOverlayCache)do
                local hE=m:FindFirstChild("HumanoidRootPart")
                local h=m:FindFirstChildOfClass("Humanoid")
                if hE and h and hrp then
                    local dist=(hE.Position-hrp.Position).Magnitude
                    if dist<=cfg.ESPRange then
                        local pos,on=cam:WorldToViewportPoint(hE.Position)
                        if on then
                            local headPos,headOn=cam:WorldToViewportPoint(hE.Position+Vector3.new(0,3,0))
                            local footPos,footOn=cam:WorldToViewportPoint(hE.Position-Vector3.new(0,3,0))
                            if headOn and footOn then
                                local boxH=math.abs(footPos.Y-headPos.Y)
                                local boxW=boxH*0.6
                                local boxX=pos.X-boxW/2
                                local boxY=headPos.Y

                                d.box.Visible=true
                                d.box.Size=Vector2.new(boxW,boxH)
                                d.box.Position=Vector2.new(boxX,boxY)
                                d.box.Color=(m==cur)and Color3.fromRGB(0,255,100)or Color3.fromRGB(255,60,60)

                                local hpRatio=math.clamp(h.Health/h.MaxHealth,0,1)
                                local hpBarW=boxW
                                local hpBarH=3
                                local hpBarX=boxX
                                local hpBarY=boxY-8

                                d.hpBg.Visible=true
                                d.hpBg.Size=Vector2.new(hpBarW,hpBarH)
                                d.hpBg.Position=Vector2.new(hpBarX,hpBarY)

                                d.hpFg.Visible=true
                                d.hpFg.Size=Vector2.new(hpBarW*hpRatio,hpBarH)
                                d.hpFg.Position=Vector2.new(hpBarX,hpBarY)
                                if hpRatio>0.5 then
                                    d.hpFg.Color=Color3.fromRGB(0,255,100)
                                elseif hpRatio>0.25 then
                                    d.hpFg.Color=Color3.fromRGB(255,200,0)
                                else
                                    d.hpFg.Color=Color3.fromRGB(255,60,60)
                                end

                                d.nameText.Visible=true
                                d.nameText.Text=string.format("%s [%d]",m.Name,math.floor(dist))
                                d.nameText.Position=Vector2.new(pos.X,hpBarY-16)
                                d.nameText.Color=(m==cur)and Color3.fromRGB(0,255,100)or Color3.fromRGB(255,255,255)
                            else
                                d.box.Visible=false d.hpBg.Visible=false d.hpFg.Visible=false d.nameText.Visible=false
                            end
                        else
                            d.box.Visible=false d.hpBg.Visible=false d.hpFg.Visible=false d.nameText.Visible=false
                        end
                    else
                        d.box.Visible=false d.hpBg.Visible=false d.hpFg.Visible=false d.nameText.Visible=false
                    end
                else
                    d.box.Visible=false d.hpBg.Visible=false d.hpFg.Visible=false d.nameText.Visible=false
                end
            end
        else
            for _,d in pairs(espOverlayCache)do
                d.box.Visible=false d.hpBg.Visible=false d.hpFg.Visible=false d.nameText.Visible=false
            end
            task.wait(0.3)
        end
        task.wait(0.03)
    end
end)
-- ==================== ESP LINES ====================
local ESPok=pcall(function()local d=Drawing.new("Line")d:Remove()end)
task.spawn(function()
    local cam=WS.CurrentCamera
    while true do
        if cfg.ESPLines and ESPok and hrp and cam then
            local en=eList()
            for _,e in ipairs(en)do if not espCache[e]then local l=Drawing.new("Line")l.Visible=false l.Color=Color3.fromRGB(255,69,58)l.Thickness=1.5 l.Transparency=1 l.From=Vector2.new(0,0)l.To=Vector2.new(0,0)espCache[e]=l end end
            for m,l in pairs(espCache)do if not m.Parent or not isE(m)then pcall(function()l:Remove()end)espCache[m]=nil end end
            local ss=cam.ViewportSize local bc=Vector2.new(ss.X/2,ss.Y)
            for m,l in pairs(espCache)do
                local hE=m:FindFirstChild("HumanoidRootPart")
                if hE and hrp and(hE.Position-hrp.Position).Magnitude<=cfg.ESPRange then
                    local sp,on=cam:WorldToViewportPoint(hE.Position)
                    if on then
                        l.From=bc l.To=Vector2.new(sp.X,sp.Y)
                        if m==cur then l.Color=Color3.fromRGB(48,209,88)l.Thickness=3
                        else l.Color=Color3.fromRGB(255,69,58)l.Thickness=1.5 end
                        l.Visible=true
                    else l.Visible=false end
                else l.Visible=false end
            end
        else for _,l in pairs(espCache)do l.Visible=false end task.wait(0.3)end
        task.wait(0.02)
    end
end)

-- ==================== GROUND PATH ESP ====================
local groundESP={enabled=false,folder=nil,segments={},maxSegments=12,segmentLength=4,width=1.5,colorMain=Color3.fromRGB(0,200,255),colorTarget=Color3.fromRGB(255,220,0),yOffset=0.1}
local function ensureGroundFolder()if groundESP.folder and groundESP.folder.Parent then return end groundESP.folder=Instance.new("Folder")groundESP.folder.Name="DQAF_GroundPath"groundESP.folder.Parent=workspace end
local function createSegment(i)
    if groundESP.segments[i]then return groundESP.segments[i]end
    local p=Instance.new("Part")p.Name="PathSeg"..i p.Anchored=true p.CanCollide=false p.CanQuery=false p.CanTouch=false p.CastShadow=false p.Material=Enum.Material.Neon p.Size=Vector3.new(groundESP.width,0.1,groundESP.segmentLength)p.Transparency=0.15 p.Color=groundESP.colorMain p.Parent=groundESP.folder
    groundESP.segments[i]=p return p
end
local function clearGroundPath()for _,p in ipairs(groundESP.segments)do if p.Parent then p:Destroy()end end groundESP.segments={}end
local function updateGroundPath()
    ensureGroundFolder()
    local target=cur
    if not(target and target.Parent and isE(target))then target=near()end
    if not target then clearGroundPath()return end
    local tHrp=target:FindFirstChild("HumanoidRootPart")if not tHrp or not hrp then clearGroundPath()return end
    local from=Vector3.new(hrp.Position.X,hrp.Position.Y,hrp.Position.Z)
    local to=Vector3.new(tHrp.Position.X,hrp.Position.Y,tHrp.Position.Z)
    local dir=to-from local dist=dir.Magnitude
    if dist<2 then clearGroundPath()return end
    dir=dir.Unit
    local count=math.min(groundESP.maxSegments,math.floor(dist/groundESP.segmentLength))
    local isActiveTarget=(target==cur)
    for i=count+1,#groundESP.segments do if groundESP.segments[i]then groundESP.segments[i].Transparency=1 end end
    for i=1,count do
        local seg=createSegment(i)
        seg.Transparency=0.15
        seg.Color=isActiveTarget and groundESP.colorTarget or groundESP.colorMain
        local midPos=from+dir*((i-0.5)*groundESP.segmentLength)
        midPos=Vector3.new(midPos.X,hrp.Position.Y+groundESP.yOffset,midPos.Z)
        seg.CFrame=CFrame.new(midPos,midPos+dir)
        seg.Size=Vector3.new(groundESP.width,0.1,groundESP.segmentLength)
    end
end
task.spawn(function()
    while true do
        groundESP.enabled=cfg.GroundESP
        if groundESP.enabled and hrp and hum and hum.Health>0 then pcall(updateGroundPath)else clearGroundPath()task.wait(0.3)end
        task.wait(0.08)
    end
end)

-- ==================== HITBOX VISUAL ====================
local visualBoxes={}
local function getOrCreateVisual(part,color)
    if not visualBoxes[part]then
        local box=Instance.new("SelectionBox")
        box.Color3=color box.LineThickness=0.05 box.Transparency=0.5 box.Adornee=part box.Parent=gui
        visualBoxes[part]=box
    end
    return visualBoxes[part]
end
local function clearVisuals()
    for part,box in pairs(visualBoxes)do pcall(function()box:Destroy()end)end
    visualBoxes={}
end
local function updateHitboxVisuals()
    if not hrp or not char then return end
    local myBox=getOrCreateVisual(hrp,Color3.fromRGB(0,150,255))
    myBox.Color3=Color3.fromRGB(0,150,255)myBox.Transparency=0.6
    local enemies=eList()local activeParts={}
    for _,m in ipairs(enemies)do
        local hE=m:FindFirstChild("HumanoidRootPart")
        if hE then
            activeParts[hE]=true
            local dist=(hE.Position-hrp.Position).Magnitude
            local inRange=dist<=cfg.SwingReach
            local color=inRange and Color3.fromRGB(0,255,100)or Color3.fromRGB(255,60,60)
            local box=getOrCreateVisual(hE,color)
            box.Color3=color box.Transparency=inRange and 0.4 or 0.6
        end
    end
    for part,box in pairs(visualBoxes)do
        if part~=hrp and not activeParts[part]then
            pcall(function()box:Destroy()end)visualBoxes[part]=nil
        end
    end
end
task.spawn(function()
    while true do
        if cfg.HitboxVisual then pcall(updateHitboxVisuals)task.wait(0.1)
        else clearVisuals()task.wait(0.5)end
    end
end)
-- ==================== AUTO SWING (WALK-TO-TARGET) ====================
local function swingLoop()
    while cfg.AutoSwing do
        if char and hum and hum.Health>0 then
            autoEquip()
            local t=getT()
            if t then
                local hE=t:FindFirstChild("HumanoidRootPart")
                if hE and hrp then
                    local npcPos=hE.Position
                    local myPos=hrp.Position
                    local flat=Vector3.new(npcPos.X-myPos.X,0,npcPos.Z-myPos.Z)
                    local dist=flat.Magnitude
                    local reach=cfg.SwingReach
                    if dist>0.1 then flat=flat.Unit else flat=Vector3.new(0,0,1)end
                    pcall(function()hrp.CFrame=CFrame.new(myPos,Vector3.new(npcPos.X,myPos.Y,npcPos.Z))end)
                    if not cfg.HoverFarm then
                        if dist>reach then
                            local walkTarget=npcPos-flat*(reach-0.5)
                            walkTarget=Vector3.new(walkTarget.X,myPos.Y,walkTarget.Z)
                            pcall(function()hum:MoveTo(walkTarget)end)
                        else
                            pcall(function()hum:MoveTo(myPos)end)
                        end
                    end
                    if dist<=reach or cfg.HoverFarm then
                        for _,tool in ipairs(char:GetChildren())do
                            if tool:IsA("Tool")then pcall(function()tool:Activate()end)end
                        end
                        pcall(function()
                            local cam=WS.CurrentCamera
                            local cx=cam.ViewportSize.X/2
                            local cy=cam.ViewportSize.Y/2
                            VIM:SendMouseButtonEvent(cx,cy,0,true,game,1)
                            task.wait(0.01)
                            VIM:SendMouseButtonEvent(cx,cy,0,false,game,1)
                        end)
                    end
                end
                local h=t:FindFirstChildOfClass("Humanoid")
                if not h or h.Health<=0 then cur=nil end
            end
            task.wait(cfg.SwingDelay)
        else task.wait(0.5)end
    end
end

-- ==================== AUTO SKILL (Q & E) ====================
local function pressKey(keyCode)
    pcall(function()
        VIM:SendKeyEvent(true,keyCode,false,game)
        task.wait(0.05)
        VIM:SendKeyEvent(false,keyCode,false,game)
    end)
end
local function autoSkillLoop()
    while cfg.AutoSkill do
        if char and hum and hum.Health>0 then
            pressKey(Enum.KeyCode.Q)
            task.wait(cfg.SkillQDelay)
            if not cfg.AutoSkill then break end
            pressKey(Enum.KeyCode.E)
            task.wait(cfg.SkillEDelay)
        else task.wait(0.5)end
    end
end

-- ==================== WALK FLOW ====================
local function walkLoop()
    while cfg.WalkFlow do
        if hrp and hum and hum.Health>0 then
            if cfg.HoverFarm then task.wait(0.2)
            elseif cfg.AutoDodge and tick()-dodgeLock<0.4 then task.wait(0.1)
            else
                local t=getT()
                if t then
                    local hE=t:FindFirstChild("HumanoidRootPart")
                    if hE then
                        local d=(hE.Position-hrp.Position).Magnitude
                        if d>10 then pcall(function()hum:MoveTo(Vector3.new(hE.Position.X,hrp.Position.Y,hE.Position.Z))end)
                        else pcall(function()hum:MoveTo(hrp.Position)end)end
                    else cur=nil end
                end
            end
            task.wait(0.1)
        else task.wait(0.5)end
    end
end

-- ==================== AUTO COLLECT ====================
local function colLoop()
    while cfg.AutoCollect do
        if hrp and hum and hum.Health>0 and not cfg.HoverFarm then
            for _,v in ipairs(WS:GetDescendants())do
                if not cfg.AutoCollect then break end
                if v:IsA("BasePart")and v.Parent then
                    local n=string.lower(v.Name)
                    if string.find(n,"coin")or string.find(n,"gold")or string.find(n,"drop")or string.find(n,"gem")then
                        local d=(v.Position-hrp.Position).Magnitude
                        if d<cfg.CollectRange and d>3 then pcall(function()hum:MoveTo(v.Position)end)task.wait(0.2)end
                    end
                end
            end
        end
        task.wait(0.3)
    end
end

-- ==================== AUTO DUNGEON ====================
local function dunLoop()
    task.wait(1)
    while cfg.AutoDungeon do
        if not inD()then
            local rm=RS:FindFirstChild("remotes")
            if rm then local cv=rm:FindFirstChild("changeStartValue")if cv then pcall(function()cv:FireServer("Desert Temple")end)end end
            task.wait(0.5)
            local rm2=RS:FindFirstChild("remotes")
            if rm2 then local sd=rm2:FindFirstChild("startDungeon")if sd then pcall(function()sd:FireServer()end)end end
            task.wait(2)
            if not inD()then
                local rm3=RS:FindFirstChild("remotes")
                if rm3 then local rp=rm3:FindFirstChild("replayDungeon")if rp then pcall(function()rp:FireServer()end)end end
                task.wait(2)
            end
            task.wait(5)
        else task.wait(2)end
    end
end

-- ==================== AUTO DODGE (SMOOTH) ====================
local origWalkSpeed=nil
local dodgeActive=false
local lastDodgeTarget=nil
local function dodgeLoop()
    while cfg.AutoDodge do
        if hrp and hum and hum.Health>0 and not cfg.HoverFarm then
            local enemies=eList()
            local nHrp,nDist=nil,math.huge
            for _,e in ipairs(enemies)do
                local hE=e:FindFirstChild("HumanoidRootPart")
                if hE then
                    local d=(hE.Position-hrp.Position).Magnitude
                    if d<nDist then nDist=d nHrp=hE end
                end
            end
            local enterRange=cfg.DodgeRange
            local exitRange=cfg.DodgeRange+5
            local shouldDodge=nHrp and(nDist<(dodgeActive and exitRange or enterRange))
            if shouldDodge then
                if not dodgeActive then
                    dodgeActive=true
                    if not origWalkSpeed then origWalkSpeed=hum.WalkSpeed end
                    hum.WalkSpeed=cfg.DodgeSpeed
                    lastDodgeTarget=nil
                end
                local backDir=hrp.Position-nHrp.Position
                backDir=Vector3.new(backDir.X,0,backDir.Z)
                if backDir.Magnitude<0.1 then backDir=Vector3.new(0,0,1)else backDir=backDir.Unit end
                local target=Vector3.new(hrp.Position.X+backDir.X*25,hrp.Position.Y,hrp.Position.Z+backDir.Z*25)
                local needUpdate=false
                if not lastDodgeTarget then needUpdate=true
                else
                    local diff=(target-lastDodgeTarget).Magnitude
                    if diff>2 then needUpdate=true end
                end
                if needUpdate then lastDodgeTarget=target pcall(function()hum:MoveTo(target)end)end
                dodgeLock=tick()
            else
                if dodgeActive then
                    dodgeActive=false lastDodgeTarget=nil
                    if origWalkSpeed then hum.WalkSpeed=origWalkSpeed origWalkSpeed=nil end
                end
            end
        else
            dodgeActive=false lastDodgeTarget=nil
            if origWalkSpeed and hum then pcall(function()hum.WalkSpeed=origWalkSpeed end)origWalkSpeed=nil end
        end
        task.wait(0.15)
    end
    if origWalkSpeed and hum then pcall(function()hum.WalkSpeed=origWalkSpeed end)origWalkSpeed=nil end
end
-- ==================== UI ====================
local parentGui=PG if okCG and CG then parentGui=CG end
local Mac={Bg=Color3.fromRGB(28,28,30),BgGlass=Color3.fromRGB(38,38,42),Card=Color3.fromRGB(48,48,52),Stroke=Color3.fromRGB(70,70,75),Text=Color3.fromRGB(245,245,247),TextDim=Color3.fromRGB(150,150,155),Accent=Color3.fromRGB(10,132,255),Green=Color3.fromRGB(48,209,88),Red=Color3.fromRGB(255,69,58),Yellow=Color3.fromRGB(255,214,10),ToggleOff=Color3.fromRGB(99,99,102),Font=Enum.Font.Gotham,FontBold=Enum.Font.GothamBold,R=UDim.new(0,12),Rs=UDim.new(0,8),Rp=UDim.new(1,0)}

local gui=Instance.new("ScreenGui")gui.Name="DQAF"gui.ResetOnSpawn=false gui.IgnoreGuiInset=true gui.DisplayOrder=999 gui.Parent=parentGui

local shadow=Instance.new("ImageLabel")shadow.Image="rbxassetid://5028857472"shadow.ScaleType=Enum.ScaleType.Slice shadow.SliceCenter=Rect.new(24,24,276,276)shadow.SliceScale=0.5 shadow.BackgroundTransparency=1 shadow.ImageColor3=Color3.new(0,0,0)shadow.ImageTransparency=0.4 shadow.ZIndex=0 shadow.AnchorPoint=Vector2.new(0.5,0.5)shadow.Position=UDim2.new(0.5,0,0.5,0)shadow.Size=UDim2.new(0,420,0,420)shadow.Visible=false shadow.Parent=gui

local win=Instance.new("Frame")win.AnchorPoint=Vector2.new(0.5,0.5)win.Position=UDim2.new(0.5,0,0.5,0)win.Size=UDim2.new(0,400,0,400)win.BackgroundColor3=Mac.Bg win.BackgroundTransparency=0.05 win.BorderSizePixel=0 win.Visible=false win.ZIndex=1 win.Parent=gui
local cw=Instance.new("UICorner")cw.CornerRadius=Mac.R cw.Parent=win
local sw=Instance.new("UIStroke")sw.Color=Mac.Stroke sw.Thickness=1 sw.Transparency=0.4 sw.Parent=win

local tb=Instance.new("Frame")tb.Size=UDim2.new(1,0,0,36)tb.BackgroundColor3=Mac.BgGlass tb.BackgroundTransparency=0.3 tb.BorderSizePixel=0 tb.ZIndex=2 tb.Parent=win
local ctb=Instance.new("UICorner")ctb.CornerRadius=Mac.R ctb.Parent=tb
local tbf=Instance.new("Frame")tbf.Size=UDim2.new(1,0,0,12)tbf.Position=UDim2.new(0,0,1,-12)tbf.BackgroundColor3=Mac.BgGlass tbf.BackgroundTransparency=0.3 tbf.BorderSizePixel=0 tbf.ZIndex=2 tbf.Parent=tb

local function dot(x,color)local d=Instance.new("TextButton")d.Text=""d.Size=UDim2.fromOffset(12,12)d.Position=UDim2.fromOffset(x,12)d.BackgroundColor3=color d.BorderSizePixel=0 d.AutoButtonColor=false d.ZIndex=3 d.Parent=tb local c=Instance.new("UICorner")c.CornerRadius=Mac.Rp c.Parent=d return d end
local redBtn=dot(14,Mac.Red)local ylwBtn=dot(32,Mac.Yellow)local grnBtn=dot(50,Mac.Green)

local titleLbl=Instance.new("TextLabel")titleLbl.Text="Dungeon Quest"titleLbl.Font=Mac.FontBold titleLbl.TextSize=12 titleLbl.TextColor3=Mac.Text titleLbl.BackgroundTransparency=1 titleLbl.Size=UDim2.new(1,-80,1,0)titleLbl.Position=UDim2.fromOffset(70,0)titleLbl.ZIndex=3 titleLbl.Parent=tb

local st=Instance.new("TextLabel")st.Text="Idle"st.Font=Mac.FontBold st.TextSize=10 st.TextColor3=Mac.TextDim st.TextXAlignment=Enum.TextXAlignment.Left st.BackgroundColor3=Mac.Card st.BorderSizePixel=0 st.Size=UDim2.new(1,-16,0,24)st.Position=UDim2.fromOffset(8,40)st.ZIndex=2 st.Parent=win
local c4=Instance.new("UICorner")c4.CornerRadius=UDim.new(0,6)c4.Parent=st
local sp4=Instance.new("UIPadding")sp4.PaddingLeft=UDim.new(0,10)sp4.Parent=st

local tabBar=Instance.new("Frame")tabBar.Size=UDim2.new(1,-16,0,32)tabBar.Position=UDim2.fromOffset(8,68)tabBar.BackgroundColor3=Mac.Card tabBar.BackgroundTransparency=0.4 tabBar.BorderSizePixel=0 tabBar.ZIndex=2 tabBar.Parent=win
local ctb2=Instance.new("UICorner")ctb2.CornerRadius=UDim.new(0,6)ctb2.Parent=tabBar
local tlay=Instance.new("UIListLayout")tlay.FillDirection=Enum.FillDirection.Horizontal tlay.SortOrder=Enum.SortOrder.LayoutOrder tlay.Padding=UDim.new(0,4)tlay.Parent=tabBar
local tpad=Instance.new("UIPadding")tpad.PaddingLeft=UDim.new(0,4)tpad.PaddingRight=UDim.new(0,4)tpad.PaddingTop=UDim.new(0,4)tpad.PaddingBottom=UDim.new(0,4)tpad.Parent=tabBar

local pagesHolder=Instance.new("Frame")pagesHolder.Size=UDim2.new(1,-16,1,-114)pagesHolder.Position=UDim2.fromOffset(8,104)pagesHolder.BackgroundTransparency=1 pagesHolder.ZIndex=2 pagesHolder.Parent=win

local pages={}local tabs={}local currentTab=nil
local function showTab(name)
    if currentTab==name then return end
    currentTab=name
    for n,page in pairs(pages)do page.Visible=(n==name)end
    for n,btn in pairs(tabs)do
        if n==name then T:Create(btn,TweenInfo.new(0.2),{BackgroundColor3=Mac.Accent,TextColor3=Mac.Text}):Play()
        else T:Create(btn,TweenInfo.new(0.2),{BackgroundColor3=Mac.Card,TextColor3=Mac.TextDim}):Play()end
    end
end
local function makeTab(name,order)
    local btn=Instance.new("TextButton")btn.Text=name btn.Font=Mac.FontBold btn.TextSize=11 btn.TextColor3=Mac.TextDim btn.BackgroundColor3=Mac.Card btn.BorderSizePixel=0 btn.AutoButtonColor=false btn.LayoutOrder=order btn.Size=UDim2.new(0,0,1,0)btn.ZIndex=3 btn.Parent=tabBar
    local c=Instance.new("UICorner")c.CornerRadius=UDim.new(0,4)c.Parent=btn
    btn.Activated:Connect(function()showTab(name)end)
    tabs[name]=btn
end
local function makePage(name)
    local page=Instance.new("ScrollingFrame")page.Size=UDim2.fromScale(1,1)page.BackgroundTransparency=1 page.BorderSizePixel=0 page.ScrollBarThickness=3 page.ScrollBarImageColor3=Mac.TextDim page.CanvasSize=UDim2.new(0,0,0,0)page.AutomaticCanvasSize=Enum.AutomaticSize.Y page.Visible=false page.ZIndex=2 page.Parent=pagesHolder
    local lay=Instance.new("UIListLayout")lay.Padding=UDim.new(0,5)lay.Parent=page
    pages[name]=page return page
end
makeTab("Auto",1)makeTab("Combat",2)makeTab("Misc",3)
local pageAuto=makePage("Auto")local pageCombat=makePage("Combat")local pageMisc=makePage("Misc")
task.spawn(function()task.wait(0.1)for _,btn in pairs(tabs)do btn.Size=UDim2.new(0,btn.TextBounds.X+20,1,0)end end)
local function mkT(parent,name,key,fn)
    local row=Instance.new("Frame")row.Size=UDim2.new(1,-2,0,40)row.BackgroundColor3=Mac.Card row.BorderSizePixel=0 row.ZIndex=2 row.Parent=parent
    local cr=Instance.new("UICorner")cr.CornerRadius=Mac.Rs cr.Parent=row
    local lbl=Instance.new("TextLabel")lbl.Text=name lbl.Font=Mac.Font lbl.TextSize=12 lbl.TextColor3=Mac.Text lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.BackgroundTransparency=1 lbl.Size=UDim2.new(1,-70,1,0)lbl.Position=UDim2.fromOffset(12,0)lbl.ZIndex=3 lbl.Parent=row
    local track=Instance.new("TextButton")track.Text=""track.Size=UDim2.fromOffset(42,22)track.Position=UDim2.new(1,-54,0.5,-11)track.BackgroundColor3=Mac.ToggleOff track.BorderSizePixel=0 track.AutoButtonColor=false track.ZIndex=3 track.Parent=row
    local ctr=Instance.new("UICorner")ctr.CornerRadius=Mac.Rp ctr.Parent=track
    local knob=Instance.new("Frame")knob.Size=UDim2.fromOffset(18,18)knob.Position=UDim2.fromOffset(2,2)knob.BackgroundColor3=Color3.new(1,1,1)knob.BorderSizePixel=0 knob.ZIndex=4 knob.Parent=track
    local ck=Instance.new("UICorner")ck.CornerRadius=Mac.Rp ck.Parent=knob
    local function setState(on,anim)
        if on then
            if anim then T:Create(track,TweenInfo.new(0.25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{BackgroundColor3=Mac.Green}):Play()T:Create(knob,TweenInfo.new(0.25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.fromOffset(22,2)}):Play()
            else track.BackgroundColor3=Mac.Green knob.Position=UDim2.fromOffset(22,2)end
        else
            if anim then T:Create(track,TweenInfo.new(0.25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{BackgroundColor3=Mac.ToggleOff}):Play()T:Create(knob,TweenInfo.new(0.25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.fromOffset(2,2)}):Play()
            else track.BackgroundColor3=Mac.ToggleOff knob.Position=UDim2.fromOffset(2,2)end
        end
    end
    setState(cfg[key],false)
    track.Activated:Connect(function()cfg[key]=not cfg[key]setState(cfg[key],true)if cfg[key]and fn then task.spawn(fn)end end)
end

local function mkS(parent,name,key,mn,mx,stp,dv)
    local row=Instance.new("Frame")row.Size=UDim2.new(1,-2,0,44)row.BackgroundColor3=Mac.Card row.BorderSizePixel=0 row.ZIndex=2 row.Parent=parent
    local cr=Instance.new("UICorner")cr.CornerRadius=Mac.Rs cr.Parent=row
    local lbl=Instance.new("TextLabel")lbl.Text=name.."  ·  "..dv lbl.Font=Mac.Font lbl.TextSize=11 lbl.TextColor3=Mac.Text lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.BackgroundTransparency=1 lbl.Size=UDim2.new(1,-20,0,16)lbl.Position=UDim2.fromOffset(12,6)lbl.ZIndex=3 lbl.Parent=row
    local barBg=Instance.new("Frame")barBg.Size=UDim2.new(1,-70,0,4)barBg.Position=UDim2.fromOffset(12,30)barBg.BackgroundColor3=Color3.fromRGB(80,80,85)barBg.BorderSizePixel=0 barBg.ZIndex=3 barBg.Parent=row
    local cb=Instance.new("UICorner")cb.CornerRadius=Mac.Rp cb.Parent=barBg
    local barFill=Instance.new("Frame")barFill.Size=UDim2.new((dv-mn)/(mx-mn),0,1,0)barFill.BackgroundColor3=Mac.Accent barFill.BorderSizePixel=0 barFill.ZIndex=4 barFill.Parent=barBg
    local cf=Instance.new("UICorner")cf.CornerRadius=Mac.Rp cf.Parent=barFill
    local v=dv
    local function update()cfg[key]=v lbl.Text=name.."  ·  "..v local ratio=(v-mn)/(mx-mn)T:Create(barFill,TweenInfo.new(0.15,Enum.EasingStyle.Quart),{Size=UDim2.new(ratio,0,1,0)}):Play()end
    local minus=Instance.new("TextButton")minus.Text="−"minus.Font=Mac.FontBold minus.TextSize=15 minus.TextColor3=Mac.Text minus.BackgroundColor3=Color3.fromRGB(60,60,64)minus.BorderSizePixel=0 minus.Size=UDim2.fromOffset(22,22)minus.Position=UDim2.new(1,-58,0.5,-11)minus.AutoButtonColor=false minus.ZIndex=4 minus.Parent=row
    local cm=Instance.new("UICorner")cm.CornerRadius=Mac.Rp cm.Parent=minus
    local plus=Instance.new("TextButton")plus.Text="+"plus.Font=Mac.FontBold plus.TextSize=13 plus.TextColor3=Mac.Text plus.BackgroundColor3=Color3.fromRGB(60,60,64)plus.BorderSizePixel=0 plus.Size=UDim2.fromOffset(22,22)plus.Position=UDim2.new(1,-30,0.5,-11)plus.AutoButtonColor=false plus.ZIndex=4 plus.Parent=row
    local cp=Instance.new("UICorner")cp.CornerRadius=Mac.Rp cp.Parent=plus
    minus.Activated:Connect(function()v=math.max(mn,v-stp)v=math.floor(v*1000+0.5)/1000 update()end)
    plus.Activated:Connect(function()v=math.min(mx,v+stp)v=math.floor(v*1000+0.5)/1000 update()end)
end

-- Target Priority Selector (dropdown ala macOS)
local function mkPriority(parent)
    local row=Instance.new("Frame")row.Size=UDim2.new(1,-2,0,40)row.BackgroundColor3=Mac.Card row.BorderSizePixel=0 row.ZIndex=2 row.Parent=parent
    local cr=Instance.new("UICorner")cr.CornerRadius=Mac.Rs cr.Parent=row
    local lbl=Instance.new("TextLabel")lbl.Text="Target Priority"lbl.Font=Mac.Font lbl.TextSize=12 lbl.TextColor3=Mac.Text lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.BackgroundTransparency=1 lbl.Size=UDim2.new(0.5,0,1,0)lbl.Position=UDim2.fromOffset(12,0)lbl.ZIndex=3 lbl.Parent=row
    local btn=Instance.new("TextButton")btn.Text=(cfg.TargetPriority==2)and "Lowest HP"or "Closest"btn.Font=Mac.FontBold btn.TextSize=11 btn.TextColor3=Mac.Text btn.BackgroundColor3=Mac.Accent btn.BorderSizePixel=0 btn.Size=UDim2.fromOffset(100,26)btn.Position=UDim2.new(1,-112,0.5,-13)btn.AutoButtonColor=false btn.ZIndex=3 btn.Parent=row
    local cb=Instance.new("UICorner")cb.CornerRadius=UDim.new(0,5)cb.Parent=btn
    btn.Activated:Connect(function()
        cfg.TargetPriority=(cfg.TargetPriority==2)and 1 or 2
        btn.Text=(cfg.TargetPriority==2)and "Lowest HP"or "Closest"
    end)
end

mkT(pageAuto,"Auto Dungeon","AutoDungeon",dunLoop)
mkT(pageAuto,"Walk Flow","WalkFlow",walkLoop)
mkT(pageAuto,"Auto Swing","AutoSwing",swingLoop)
mkT(pageAuto,"Auto Skill (Q & E)","AutoSkill",autoSkillLoop)
mkT(pageAuto,"Auto Collect","AutoCollect",colLoop)
mkT(pageAuto,"Hover Farm","HoverFarm",hoverLoop)
mkT(pageCombat,"ESP Lines (screen)","ESPLines",nil)
mkT(pageCombat,"ESP Overlay (box/hp/name)","ESPOverlay",nil)
mkT(pageCombat,"Ground Path ESP","GroundESP",nil)
mkT(pageCombat,"Hitbox Expand (Tool)","Hitbox",hitboxLoop)
mkT(pageCombat,"Auto Dodge (retreat)","AutoDodge",dodgeLoop)
mkT(pageCombat,"No Clip","NoClip",noclipLoop)
mkT(pageCombat,"Freeze NPC","FreezeNPC",freezeLoop)
mkT(pageCombat,"Hitbox Visual","HitboxVisual",nil)

local function head(parent,text)local s=Instance.new("TextLabel")s.Text=text s.Font=Mac.FontBold s.TextSize=9 s.TextColor3=Mac.TextDim s.TextXAlignment=Enum.TextXAlignment.Left s.BackgroundTransparency=1 s.Size=UDim2.new(1,0,0,16)s.Position=UDim2.fromOffset(4,0)s.Parent=parent end
head(pageMisc,"TARGETING")
mkPriority(pageMisc)
head(pageMisc,"TIMING")
mkS(pageMisc,"swing_delay","SwingDelay",0.02,1,0.02,0.08)
mkS(pageMisc,"swing_reach","SwingReach",2,15,0.5,6)
mkS(pageMisc,"walk_delay","WalkDelay",0.1,1,0.05,0.2)
head(pageMisc,"SKILL")
mkS(pageMisc,"skill_q_delay","SkillQDelay",0.2,10,0.1,1.5)
mkS(pageMisc,"skill_e_delay","SkillEDelay",0.2,10,0.1,1.5)
head(pageMisc,"HOVER")
mkS(pageMisc,"hover_height","HoverHeight",5,30,1,13)
head(pageMisc,"COMBAT")
mkS(pageMisc,"esp_range","ESPRange",50,2000,50,800)
mkS(pageMisc,"hitbox_size","HitboxSize",1,10,0.5,2.5)
head(pageMisc,"DODGE")
mkS(pageMisc,"dodge_range","DodgeRange",5,40,1,10)
mkS(pageMisc,"dodge_speed","DodgeSpeed",4,20,1,12)
local resetBtn=Instance.new("TextButton")
resetBtn.Text="Reset Config"
resetBtn.Font=Mac.FontBold resetBtn.TextSize=11 resetBtn.TextColor3=Color3.new(1,1,1)
resetBtn.BackgroundColor3=Mac.Red resetBtn.BorderSizePixel=0
resetBtn.Size=UDim2.new(1,-2,0,32)resetBtn.AutoButtonColor=false resetBtn.Parent=pageMisc
local crb=Instance.new("UICorner")crb.CornerRadius=Mac.Rs crb.Parent=resetBtn
resetBtn.Activated:Connect(function()resetConfig()resetBtn.Text="Reset! Restart"task.delay(2,function()resetBtn.Text="Reset Config"end)end)
local cfgInfo=Instance.new("TextLabel")
cfgInfo.Text=hasFileIO and "✔ Auto-save aktif" or "✘ writefile gak support"
cfgInfo.Font=Mac.Font cfgInfo.TextSize=10
cfgInfo.TextColor3=hasFileIO and Mac.Green or Mac.Red
cfgInfo.TextXAlignment=Enum.TextXAlignment.Left
cfgInfo.BackgroundTransparency=1
cfgInfo.Size=UDim2.new(1,-2,0,16)cfgInfo.Position=UDim2.fromOffset(4,0)cfgInfo.Parent=pageMisc

showTab("Auto")

local isOpen=false local isAnim=false
local function openWindow()
    if isAnim or isOpen then return end
    isAnim=true isOpen=true shadow.Visible=true win.Visible=true
    win.Size=UDim2.new(0,320,0,320)win.BackgroundTransparency=1 shadow.Size=UDim2.new(0,340,0,340)shadow.ImageTransparency=1
    local t1=T:Create(win,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Size=UDim2.new(0,400,0,400),BackgroundTransparency=0.05})
    T:Create(shadow,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Size=UDim2.new(0,420,0,420),ImageTransparency=0.4}):Play()
    t1:Play()t1.Completed:Connect(function()isAnim=false end)
end
local function closeWindow()
    if isAnim or not isOpen then return end
    isAnim=true isOpen=false
    local t1=T:Create(win,TweenInfo.new(0.28,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{Size=UDim2.new(0,320,0,320),BackgroundTransparency=1})
    T:Create(shadow,TweenInfo.new(0.28,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{Size=UDim2.new(0,340,0,340),ImageTransparency=1}):Play()
    t1:Play()t1.Completed:Connect(function()win.Visible=false shadow.Visible=false win.Size=UDim2.new(0,400,0,400)win.BackgroundTransparency=0.05 shadow.Size=UDim2.new(0,420,0,420)shadow.ImageTransparency=0.4 isAnim=false end)
end
redBtn.Activated:Connect(closeWindow)
ylwBtn.Activated:Connect(closeWindow)
grnBtn.Activated:Connect(function()
    if win.Size.X.Offset>=400 then
        T:Create(win,TweenInfo.new(0.3,Enum.EasingStyle.Quint),{Size=UDim2.new(0,480,0,480)}):Play()
        T:Create(shadow,TweenInfo.new(0.3,Enum.EasingStyle.Quint),{Size=UDim2.new(0,500,0,500)}):Play()
    else
        T:Create(win,TweenInfo.new(0.3,Enum.EasingStyle.Quint),{Size=UDim2.new(0,400,0,400)}):Play()
        T:Create(shadow,TweenInfo.new(0.3,Enum.EasingStyle.Quint),{Size=UDim2.new(0,420,0,420)}):Play()
    end
end)
for _,btn in ipairs({redBtn,ylwBtn,grnBtn})do
    btn.MouseEnter:Connect(function()T:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=btn.BackgroundColor3:Lerp(Color3.new(1,1,1),0.3)}):Play()end)
    btn.MouseLeave:Connect(function()local orig=btn==redBtn and Mac.Red or btn==ylwBtn and Mac.Yellow or Mac.Green T:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=orig}):Play()end)
end

local dragging,dragStart,startPos
tb.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true dragStart=input.Position startPos=win.Position end end)
UIS.InputChanged:Connect(function(input)if dragging and(input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch)then local d=input.Position-dragStart win.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)shadow.Position=win.Position end end)
UIS.InputEnded:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end end)

local tg=Instance.new("TextButton")tg.Text="DQ"tg.Font=Mac.FontBold tg.TextSize=12 tg.TextColor3=Mac.Text tg.BackgroundColor3=Mac.Accent tg.BorderSizePixel=0 tg.Size=UDim2.fromOffset(44,34)tg.Position=UDim2.new(0,20,0,80)tg.AutoButtonColor=false tg.ZIndex=5 tg.Parent=gui
local ctg=Instance.new("UICorner")ctg.CornerRadius=Mac.Rp ctg.Parent=tg
local stg=Instance.new("UIStroke")stg.Color=Color3.new(0,0,0)stg.Thickness=1 stg.Transparency=0.6 stg.Parent=tg
tg.Activated:Connect(function()if isOpen then closeWindow()else openWindow()end end)

task.wait(0.1)openWindow()

task.spawn(function()
    while gui.Parent do
        if inD()then
            local l=eList()local tn=cur and cur.Name or "none"
            st.Text=string.format("Wave %d  ·  %d musuh  ·  %s",wv(),#l,tn)
            st.TextColor3=Mac.Text
        else
            st.Text="Idle  ·  Lobby"
            st.TextColor3=Mac.TextDim
        end
        task.wait(0.5)
    end
end)
print("[DQAF] FINAL v7 loaded. ESP:",ESPok,"| Square:",SquareSupport,"| Config:",hasFileIO and "auto-save" or "no-save")