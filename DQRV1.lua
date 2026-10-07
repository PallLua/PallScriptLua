local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local TS=game:GetService("TweenService")
local LP=Players.LocalPlayer
local PG=LP:WaitForChild("PlayerGui")
if PG:FindFirstChild("DQR")then PG.DQR:Destroy()end
local Theme={bgWindow=Color3.fromRGB(30,30,32),bgSidebar=Color3.fromRGB(24,24,26),bgTitle=Color3.fromRGB(38,38,40),bgCard=Color3.fromRGB(44,44,46),bgTrack=Color3.fromRGB(28,28,30),textPri=Color3.fromRGB(245,245,247),textSec=Color3.fromRGB(150,150,155),textHead=Color3.fromRGB(120,120,125),accent=Color3.fromRGB(10,132,255),green=Color3.fromRGB(48,209,88),red=Color3.fromRGB(255,69,58),yellow=Color3.fromRGB(255,214,10),toggleOff=Color3.fromRGB(72,72,74),knob=Color3.fromRGB(255,255,255),font=Enum.Font.Gotham,fontBold=Enum.Font.GothamBold}
local function corner(o,r)local c=Instance.new("UICorner")c.CornerRadius=UDim.new(0,r or 10)c.Parent=o end
local gui=Instance.new("ScreenGui")gui.Name="DQR"gui.ResetOnSpawn=false gui.IgnoreGuiInset=true gui.DisplayOrder=999 gui.Parent=PG
local intro=Instance.new("Frame")intro.Size=UDim2.fromScale(1,1)intro.BackgroundColor3=Color3.fromRGB(12,12,16)intro.BorderSizePixel=0 intro.Parent=gui
local box=Instance.new("Frame")box.Size=UDim2.fromOffset(280,100)box.Position=UDim2.new(0.5,-140,0.5,-50)box.BackgroundColor3=Theme.bgWindow box.BorderSizePixel=0 box.Parent=intro corner(box,12)
local lt=Instance.new("TextLabel")lt.Text="Pall Lua Loaded"lt.Font=Theme.fontBold lt.TextSize=17 lt.TextColor3=Theme.textPri lt.BackgroundTransparency=1 lt.Size=UDim2.new(1,-20,0,30)lt.Position=UDim2.fromOffset(10,14)lt.Parent=box
local pct=Instance.new("TextLabel")pct.Text="0%"pct.Font=Theme.font pct.TextSize=12 pct.TextColor3=Theme.textSec pct.BackgroundTransparency=1 pct.Size=UDim2.new(1,-20,0,18)pct.Position=UDim2.fromOffset(10,46)pct.TextXAlignment=Enum.TextXAlignment.Right pct.Parent=box
local tr=Instance.new("Frame")tr.Size=UDim2.new(1,-24,0,8)tr.Position=UDim2.fromOffset(12,74)tr.BackgroundColor3=Theme.bgTrack tr.BorderSizePixel=0 tr.Parent=box corner(tr,4)
local fl=Instance.new("Frame")fl.Size=UDim2.new(0,0,1,0)fl.BackgroundColor3=Theme.accent fl.BorderSizePixel=0 fl.Parent=tr corner(fl,4)
for i=1,100 do fl.Size=UDim2.new(i/100,0,1,0)pct.Text=i.."%" task.wait(0.08)end
pct.Text="100%  Completed" task.wait(0.45)
TS:Create(intro,TweenInfo.new(0.4),{BackgroundTransparency=1}):Play()
TS:Create(box,TweenInfo.new(0.4),{BackgroundTransparency=1}):Play()
task.wait(0.5)intro:Destroy()
_G.DQR={gui=gui,Theme=Theme,corner=corner,TS=TS,UIS=UIS,LP=LP,PG=PG}
print("[DQR] PART 1 OK · intro selesai")
local D=_G.DQR if not D then warn("PART 1 dulu")return end
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local PFS=game:GetService("PathfindingService")
local VIM=game:GetService("VirtualInputManager")
local Players=game:GetService("Players")
local CFG={autoFarm=false,autoSwing=false,walkFlow=false,noClip=false,autoDodge=false,autoSkill=false,autoDungeon=false,swingDelay=0.08,tweenSpeed=16,dodgeRange=12}
D.CFG=CFG
local char,hrp,hum
local function refresh()char=D.LP.Character or D.LP.CharacterAdded:Wait()hrp=char:WaitForChild("HumanoidRootPart",5)hum=char:WaitForChild("Humanoid",5)end
refresh()D.LP.CharacterAdded:Connect(function()task.wait(0.6)refresh()end)
local function isEnemy(m)if not m or not m:IsA("Model")or m==char then return false end local h=m:FindFirstChildOfClass("Humanoid")if not h or h.Health<=0 then return false end if Players:GetPlayerFromCharacter(m)then return false end if not m:FindFirstChild("HumanoidRootPart")then return false end return true end
local function getEnemies()local t={}for _,v in ipairs(WS:GetDescendants())do if isEnemy(v)then table.insert(t,v)end end return t end
local function getNearest()if not hrp then return nil end local best,dist=nil,math.huge for _,e in ipairs(getEnemies())do local r=e:FindFirstChild("HumanoidRootPart")if r then local d=(r.Position-hrp.Position).Magnitude if d<dist then dist=d best=e end end end return best end
local function autoEquip()if not char or not hum then return end for _,t in ipairs(char:GetChildren())do if t:IsA("Tool")then return end end local bp=D.LP:FindFirstChild("Backpack")if not bp then return end for _,t in ipairs(bp:GetChildren())do if t:IsA("Tool")then pcall(function()hum:EquipTool(t)end)return end end end
local threads={}
local function stop(n)if threads[n]then pcall(task.cancel,threads[n])threads[n]=nil end end
local function start(n,fn)stop(n)threads[n]=task.spawn(fn)end
D.getNearest=getNearest D.autoEquip=autoEquip D.start=start D.stop=stop D.threads=threads
D.FeatSwing=function()while true do if CFG.autoSwing and char and hum and hum.Health>0 then autoEquip()for _,tool in ipairs(char:GetChildren())do if tool:IsA("Tool")then pcall(function()tool:Activate()end)end end pcall(function()local cam=WS.CurrentCamera if not cam then return end local cx,cy=cam.ViewportSize.X/2,cam.ViewportSize.Y/2 VIM:SendMouseButtonEvent(cx,cy,0,true,game,1)task.wait(0.01)VIM:SendMouseButtonEvent(cx,cy,0,false,game,1)end)task.wait(CFG.swingDelay)else task.wait(0.4)end end end
D.FeatFarm=function()while true do if CFG.autoFarm and hrp and hum and hum.Health>0 then local t=getNearest()if t then local r=t:FindFirstChild("HumanoidRootPart")if r then local goal=r.Position+(hrp.Position-r.Position).Unit*4 local dist=(hrp.Position-goal).Magnitude local dur=math.clamp(dist/CFG.tweenSpeed,0.12,3)local tw=D.TS:Create(hrp,TweenInfo.new(dur,Enum.EasingStyle.Linear),{CFrame=CFrame.new(goal)})tw:Play()tw.Completed:Wait()end end end task.wait(0.08)end end
D.FeatNoClip=function()while true do if CFG.noClip and char then for _,p in ipairs(char:GetDescendants())do if p:IsA("BasePart")then pcall(function()p.CanCollide=false end)end end end task.wait(0.2)end end
D.FeatDodge=function()local last=0 while true do if CFG.autoDodge and hrp and hum and hum.Health>0 and tick()-last>=0.9 then for _,m in ipairs(getEnemies())do local r=m:FindFirstChild("HumanoidRootPart")if r and(r.Position-hrp.Position).Magnitude<CFG.dodgeRange then local away=hrp.Position-r.Position if away.Magnitude<0.1 then away=Vector3.new(1,0,0)else away=away.Unit end D.TS:Create(hrp,TweenInfo.new(0.2,Enum.EasingStyle.Quad),{CFrame=CFrame.new(hrp.Position+away*14)}):Play()last=tick()break end end end task.wait(0.05)end end
D.FeatSkill=function()local lQ,lE=0,0 while true do if CFG.autoSkill and char and hum and hum.Health>0 then local n=tick()if n-lQ>=1.5 then pcall(function()VIM:SendKeyEvent(true,Enum.KeyCode.Q,false,game)task.wait(0.05)VIM:SendKeyEvent(false,Enum.KeyCode.Q,false,game)end)lQ=n end if n-lE>=1.5 then pcall(function()VIM:SendKeyEvent(true,Enum.KeyCode.E,false,game)task.wait(0.05)VIM:SendKeyEvent(false,Enum.KeyCode.E,false,game)end)lE=n end end task.wait(0.12)end end
D.FeatDungeon=function()while true do if CFG.autoDungeon then local rm=RS:FindFirstChild("remotes")if rm then local sd=rm:FindFirstChild("startDungeon")or rm:FindFirstChild("replayDungeon")if sd then pcall(function()sd:FireServer()end)end end end task.wait(4)end end
D.FeatWalk=function()
local path=PFS:CreatePath({AgentRadius=2.5,AgentHeight=5,AgentCanJump=true,AgentCanClimb=true,WaypointSpacing=4})
local wps,cwp,lastT,lastC,stuck,lastP={},1,nil,0,0,nil
local lv=hrp and hrp:FindFirstChild("DQR_LV")
if hrp and not lv then lv=Instance.new("LinearVelocity")lv.Name="DQR_LV"lv.MaxForce=math.huge lv.VelocityConstraintMode=Enum.VelocityConstraintMode.Line lv.LineDirection=Vector3.new(1,0,0)lv.LineVelocity=0 lv.Parent=hrp end
local conn=RunService.Heartbeat:Connect(function()
if not CFG.walkFlow or not hrp or not hrp.Parent or not hum or hum.Health<=0 then if lv then lv.LineVelocity=0 end return end
local t=getNearest()if not t then if lv then lv.LineVelocity=0 end return end
local th=t:FindFirstChild("HumanoidRootPart")if not th then return end
local tp=th.Position local dist=(tp-hrp.Position).Magnitude local now=tick()
if (#wps==0 or(lastT and(tp-lastT).Magnitude>8)or now-lastC>1.5)and dist>5 then pcall(function()path:ComputeAsync(hrp.Position,tp)end)if path.Status==Enum.PathStatus.Success then wps=path:GetWaypoints()cwp=2 lastT=tp lastC=now end end
local goal if #wps>0 and cwp<=#wps then local wp=wps[cwp]if wp.Action==Enum.PathWaypointAction.Jump then pcall(function()hum:ChangeState(Enum.HumanoidStateType.Jumping)end)end goal=wp.Position if(wp.Position-hrp.Position).Magnitude<3 then cwp=cwp+1 end else goal=tp end
if not goal then if lv then lv.LineVelocity=0 end return end
local dir=Vector3.new(goal.X-hrp.Position.X,0,goal.Z-hrp.Position.Z)if dir.Magnitude<0.15 then if lv then lv.LineVelocity=0 end return end
dir=dir.Unit if lv then lv.LineDirection=dir lv.LineVelocity=CFG.tweenSpeed end
if lastP then if(hrp.Position-lastP).Magnitude<0.4 then stuck=stuck+1 if stuck>12 then wps={}cwp=1 lastT=nil stuck=0 end else stuck=0 end end lastP=hrp.Position
end)
while CFG.walkFlow do task.wait(0.5)end conn:Disconnect()if lv then lv.LineVelocity=0 end
end
start("farm",D.FeatFarm)start("noclip",D.FeatNoClip)start("dodge",D.FeatDodge)start("skill",D.FeatSkill)start("dungeon",D.FeatDungeon)
print("[DQR] PART 2 OK · fitur siap")
local D=_G.DQR if not D or not D.CFG then warn("PART 1+2 dulu")return end
local Theme,corner,TS,UIS,CFG=D.Theme,D.corner,D.TS,D.UIS,D.CFG
local gui=D.gui
local fab=Instance.new("TextButton")fab.Text="DQ"fab.Font=Theme.fontBold fab.TextSize=14 fab.TextColor3=Theme.textPri fab.BackgroundColor3=Theme.accent fab.Size=UDim2.fromOffset(48,48)fab.Position=UDim2.new(0,14,0,88)fab.Parent=gui corner(fab,24)
local W,H=300,440
local win=Instance.new("Frame")win.Size=UDim2.fromOffset(W,H)win.Position=UDim2.new(0.5,-W/2,0.5,-H/2)win.BackgroundColor3=Theme.bgWindow win.BorderSizePixel=0 win.Visible=true win.Active=true win.Parent=gui corner(win,12)
local tb=Instance.new("Frame")tb.Size=UDim2.new(1,0,0,32)tb.BackgroundColor3=Theme.bgTitle tb.BorderSizePixel=0 tb.Parent=win corner(tb,12)
local function dot(x,col)local d=Instance.new("Frame")d.Size=UDim2.fromOffset(10,10)d.Position=UDim2.fromOffset(x,11)d.BackgroundColor3=col d.BorderSizePixel=0 d.Parent=tb corner(d,5)end
dot(10,Theme.red)dot(24,Theme.yellow)dot(38,Theme.green)
local title=Instance.new("TextLabel")title.Text="Dungeon Quest Reborn"title.Font=Theme.fontBold title.TextSize=11 title.TextColor3=Theme.textPri title.BackgroundTransparency=1 title.Size=UDim2.new(1,-70,1,0)title.Position=UDim2.fromOffset(54,0)title.TextXAlignment=Enum.TextXAlignment.Left title.Parent=tb
local sidebar=Instance.new("Frame")sidebar.Size=UDim2.new(0,72,1,-32)sidebar.Position=UDim2.fromOffset(0,32)sidebar.BackgroundColor3=Theme.bgSidebar sidebar.BorderSizePixel=0 sidebar.Parent=win
local content=Instance.new("ScrollingFrame")content.Size=UDim2.new(1,-72,1,-32)content.Position=UDim2.fromOffset(72,32)content.BackgroundTransparency=1 content.BorderSizePixel=0 content.ScrollBarThickness=2 content.CanvasSize=UDim2.new(0,0,0,0)content.AutomaticCanvasSize=Enum.AutomaticSize.Y content.Parent=win
local lay=Instance.new("UIListLayout")lay.Padding=UDim.new(0,5)lay.SortOrder=Enum.SortOrder.LayoutOrder lay.Parent=content
local pad=Instance.new("UIPadding")pad.PaddingTop=UDim.new(0,8)pad.PaddingLeft=UDim.new(0,8)pad.PaddingRight=UDim.new(0,8)pad.PaddingBottom=UDim.new(0,8)pad.Parent=content
local order=0 local function nextO()order=order+1 return order end
local function section(t)local s=Instance.new("TextLabel")s.Text=string.upper(t)s.Font=Theme.fontBold s.TextSize=9 s.TextColor3=Theme.textHead s.BackgroundTransparency=1 s.Size=UDim2.new(1,0,0,16)s.TextXAlignment=Enum.TextXAlignment.Left s.LayoutOrder=nextO()s.Parent=content end
local function makeToggle(name,key,onE,onD)
local card=Instance.new("Frame")card.Size=UDim2.new(1,0,0,32)card.BackgroundColor3=Theme.bgCard card.BorderSizePixel=0 card.LayoutOrder=nextO()card.Parent=content corner(card,7)
local lbl=Instance.new("TextLabel")lbl.Text=name lbl.Font=Theme.font lbl.TextSize=11 lbl.TextColor3=Theme.textPri lbl.BackgroundTransparency=1 lbl.Size=UDim2.new(1,-50,1,0)lbl.Position=UDim2.fromOffset(10,0)lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Parent=card
local tr=Instance.new("TextButton")tr.Text=""tr.Size=UDim2.fromOffset(36,20)tr.Position=UDim2.new(1,-44,0.5,-10)tr.BackgroundColor3=Theme.toggleOff tr.BorderSizePixel=0 tr.AutoButtonColor=false tr.Parent=card corner(tr,10)
local kn=Instance.new("Frame")kn.Size=UDim2.fromOffset(16,16)kn.Position=UDim2.fromOffset(2,2)kn.BackgroundColor3=Theme.knob kn.BorderSizePixel=0 kn.Parent=tr corner(kn,8)
local st=false
tr.MouseButton1Click:Connect(function()
st=not st CFG[key]=st
TS:Create(tr,TweenInfo.new(0.2),{BackgroundColor3=st and Theme.green or Theme.toggleOff}):Play()
TS:Create(kn,TweenInfo.new(0.2),{Position=st and UDim2.fromOffset(18,2)or UDim2.fromOffset(2,2)}):Play()
if st and onE then onE()end if not st and onD then onD()end
end)
end
local function makeSlider(name,key,minV,maxV,step,def)
local card=Instance.new("Frame")card.Size=UDim2.new(1,0,0,46)card.BackgroundColor3=Theme.bgCard card.BorderSizePixel=0 card.LayoutOrder=nextO()card.Parent=content corner(card,7)
local lbl=Instance.new("TextLabel")lbl.Text=name.."  "..def lbl.Font=Theme.font lbl.TextSize=10 lbl.TextColor3=Theme.textPri lbl.BackgroundTransparency=1 lbl.Size=UDim2.new(1,-14,0,16)lbl.Position=UDim2.fromOffset(10,5)lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Parent=card
local tr=Instance.new("TextButton")tr.Text=""tr.Size=UDim2.new(1,-20,0,7)tr.Position=UDim2.new(0,10,1,-16)tr.BackgroundColor3=Theme.bgTrack tr.BorderSizePixel=0 tr.AutoButtonColor=false tr.Parent=card corner(tr,4)
local ratio=(def-minV)/(maxV-minV)
local fl=Instance.new("Frame")fl.Size=UDim2.new(ratio,0,1,0)fl.BackgroundColor3=Theme.accent fl.BorderSizePixel=0 fl.Parent=tr corner(fl,4)
local kn=Instance.new("Frame")kn.Size=UDim2.fromOffset(14,14)kn.AnchorPoint=Vector2.new(0.5,0.5)kn.Position=UDim2.new(ratio,0,0.5,0)kn.BackgroundColor3=Theme.knob kn.BorderSizePixel=0 kn.Parent=tr corner(kn,7)
CFG[key]=def local drag=false
local function upd(x)local a=tr.AbsolutePosition.X local w=tr.AbsoluteSize.X if w<=0 then return end local r=math.clamp((x-a)/w,0,1)local val=math.floor((minV+r*(maxV-minV))/step+0.5)*step val=math.clamp(val,minV,maxV)local nr=(val-minV)/(maxV-minV)fl.Size=UDim2.new(nr,0,1,0)kn.Position=UDim2.new(nr,0,0.5,0)lbl.Text=name.."  "..val CFG[key]=val end
tr.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true upd(UIS:GetMouseLocation().X)end end)
UIS.InputChanged:Connect(function(i)if drag and(i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch)then upd(UIS:GetMouseLocation().X)end end)
UIS.InputEnded:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end end)
end
local function tab(t,y,on)local b=Instance.new("TextButton")b.Text=t b.Font=Theme.fontBold b.TextSize=10 b.TextColor3=on and Theme.textPri or Theme.textSec b.BackgroundColor3=on and Theme.accent or Theme.bgSidebar b.Size=UDim2.new(1,-10,0,26)b.Position=UDim2.fromOffset(5,y)b.BorderSizePixel=0 b.AutoButtonColor=false b.Parent=sidebar corner(b,7)end
tab("Auto",10,true)tab("Combat",42,false)tab("Visual",74,false)tab("Misc",106,false)
section("Automation")
makeToggle("Auto Farm","autoFarm")
makeToggle("Walk Flow","walkFlow",function()D.start("walk",D.FeatWalk)end,function()D.stop("walk")end)
makeToggle("Auto Swing","autoSwing",function()D.start("swing",D.FeatSwing)end,function()D.stop("swing")end)
makeToggle("Auto Dungeon","autoDungeon")
section("Timing")
makeSlider("Swing Delay","swingDelay",0.02,1,0.02,0.08)
makeSlider("Tween Speed","tweenSpeed",8,40,1,16)
section("Combat")
makeToggle("Auto Skill Q/E","autoSkill")
makeToggle("Auto Dodge","autoDodge")
section("Utility")
makeToggle("No Clip","noClip")
D.win=win D.fab=fab D.tb=tb
print("[DQR] PART 3 OK · UI muncul")
local D=_G.DQR if not D or not D.win then warn("PART 1-3 dulu")return end
local open=true
D.fab.MouseButton1Click:Connect(function()
open=not open D.win.Visible=open
D.fab.BackgroundColor3=open and D.Theme.accent or Color3.fromRGB(60,60,60)
end)
local drag,ds,sp
D.tb.InputBegan:Connect(function(i)
if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
drag=true ds=i.Position sp=D.win.Position end end)
D.UIS.InputChanged:Connect(function(i)
if drag and(i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch)then
local d=i.Position-ds
D.win.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)end end)
D.UIS.InputEnded:Connect(function(i)
if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end end)
print("[DQR] PART 4 OK · full siap")
