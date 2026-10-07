#!/usr/bin/env python3
"""Ashen Oath: three original, deterministic code-authored pixel environments.

The references were inspected for art direction only. No reference image is read,
resampled, traced, recolored, or distributed by this generator. Pillow primitives
and seeded cluster placement author all pixels. Native resolution is 720 x 450;
use nearest filtering and integer 2x presentation in the game.
"""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import random, math, json, hashlib

W,H=720,450
OUT=Path(__file__).resolve().parents[1]/'assets'/'environments'
OUT.mkdir(parents=True,exist_ok=True)

PALETTES={
 'cinder_forest':{
 'sky':['#202936','#303840','#434345','#60504b','#7c6051','#927154'],
 'far':['#4b4b49','#41494b','#354248'],
 'soil':['#292e30','#333735','#3c4039','#4a4940'],
 'stone':['#282e32','#41464a','#575852','#757365','#8e8770'],
 'plant':['#212e2d','#304039','#42503d','#576046','#737451'],
 'accent':['#773b35','#a45038','#ce7950','#e8a86a'],
 'water':['#324342','#435351','#5b6560'],
 },
 'drowned_reliquary':{
 'sky':['#151e36','#202d45','#304159','#405367','#566b78','#697d86'],
 'far':['#3b5362','#304958','#263e4f'],
 'soil':['#202c3a','#2b3a46','#354854','#425564'],
 'stone':['#1e2d3e','#334657','#4b6170','#6c8089','#97a6a8'],
 'plant':['#172d34','#254449','#375b5d','#4c7774','#72a296'],
 'accent':['#355e68','#4b8791','#6eafaf','#a1d6c8'],
 'water':['#263b4d','#345368','#517785'],
 },
 'pale_throne':{
 'sky':['#383d43','#4d5253','#686c65','#858672','#a0a080','#b9b492'],
 'far':['#696e65','#545f5b','#414f50'],
 'soil':['#2f3537','#3b413f','#4d5149','#606153'],
 'stone':['#2b3439','#474f50','#63695f','#838674','#b0ad8b'],
 'plant':['#2d3d3b','#415047','#586451','#738066','#93947a'],
 'accent':['#584047','#7e4844','#a7664d','#c79565'],
 'water':['#3c4b4e','#526261','#728078'],
 }}

def rgb(c):return tuple(int(c[i:i+2],16) for i in (1,3,5)) if isinstance(c,str) else c

def mix(a,b,t):return tuple(int(x*(1-t)+y*t) for x,y in zip(rgb(a),rgb(b)))

class Painter:
 def __init__(self,name,seed):
  self.name=name; self.r=random.Random(seed);self.p={k:list(map(rgb,v)) for k,v in PALETTES[name].items()}
  self.im=Image.new('RGB',(W,H),self.p['sky'][0]);self.d=ImageDraw.Draw(self.im)
 def poly(self,pts,c):self.d.polygon([(int(x),int(y)) for x,y in pts],fill=c)
 def rect(self,b,c):self.d.rectangle(tuple(map(int,b)),fill=c)
 def line(self,p,c,w=1):self.d.line([(int(x),int(y)) for x,y in p],fill=c,width=w)
 def cluster(self,x,y,w,h,c):
  self.poly([(x,y+1),(x+max(1,w//3),y),(x+w-2,y),(x+w,y+max(1,h//2)),(x+w-1,y+h),(x+2,y+h),(x,y+h-1)],c)
 def mist(self,y,c,n=16):
  # Broad, stepped wisps, never a blur or per-pixel noise field.
  for j in range(n):
   x=self.r.randrange(-90,700); yy=y+self.r.randrange(-5,6);w=self.r.randrange(40,145)
   self.cluster(x,yy,w,self.r.randrange(2,5),c)
 def sky(self):
  cs=self.p['sky']
  for y in range(180):
   band=min(5,y//30);self.line([(0,y),(W,y)],cs[band])
   if y%30 in (0,2,4) and band:
    for x in range((y%4)*5,W,16):self.rect((x,y,x+7,y),cs[band-1])
  for k in range(30):
   y=self.r.randrange(9,116);x=self.r.randrange(-70,700);w=self.r.randrange(35,130)
   col=mix(cs[min(4,y//30)],cs[max(0,y//30-1)],.55)
   self.cluster(x,y,w,self.r.randrange(3,8),col)
 def ridge(self,y,amp,col,seed):
  rr=random.Random(seed);pts=[(-10,190),(-10,y)];xx=-10;yy=y
  while xx<W+10:
   xx+=rr.randrange(9,23); yy=int(y+math.sin(xx*.018+seed)*amp+rr.randrange(-5,6));pts.append((xx,yy))
  pts.extend([(730,210)]);self.poly(pts,col)
 def pine(self,x,y,h,col):
  self.rect((x-1,y-h,x+1,y+4),col)
  for i in range(6):
   yy=y-h+i*h*.135;ww=h*(.075+i*.023)
   self.poly([(x,yy),(x-ww*.55,yy+h*.11),(x-ww*.42,yy+h*.11),(x-ww,yy+h*.26),(x-ww*.6,yy+h*.24),(x-ww*1.05,yy+h*.32),(x+ww,yy+h*.31),(x+ww*.6,yy+h*.24),(x+ww,yy+h*.26),(x+ww*.5,yy+h*.11)],col)
 def brick(self,x,y,w,h,colors=None,broken=False):
  c=colors or self.p['stone'];self.rect((x,y,x+w,y+h),c[0])
  self.poly([(x+1,y+1),(x+w-2,y),(x+w-1,y+h-2),(x+2,y+h-1)],self.r.choice(c[1:3]))
  self.line([(x+2,y+1),(x+w-3,y+1)],c[3]);self.line([(x+1,y+2),(x+1,y+h-3)],c[2])
  if w>14:self.line([(x+w-3,y+3),(x+w-2,y+h-2)],c[0])
  if broken or self.r.random()<.25:
   xx=x+self.r.randrange(3,max(4,w-2));self.line([(xx,y+2),(xx-2,y+h//2),(xx+1,y+h-1)],c[0])
  for k in range(max(1,int(w*h/150))):
   xx=x+self.r.randrange(2,max(3,w-2));yy=y+self.r.randrange(2,max(3,h-1));self.cluster(xx,yy,self.r.randrange(2,5),1,c[2])
 def wall(self,x,y,w,h,colors=None):
  c=colors or self.p['stone'];self.rect((x,y,x+w,y+h),c[0])
  for j,yy in enumerate(range(y,y+h,10)):
   for xx in range(x-17*(j%2),x+w,33):
    xa=max(x,xx);xb=min(x+w,xx+31)
    if xb-xa>3:self.brick(xa,yy,xb-xa,min(9,y+h-yy),c)
 def arch(self,x,y,w,h,colors=None,inside=None,broken=False):
  c=colors or self.p['stone'];inside=inside or c[0]
  # Pointed arch with articulated voussoirs and recessed molding.
  outer=[(x,y+h),(x,y+w*.44),(x+w*.13,y+w*.23),(x+w*.5,y),(x+w*.87,y+w*.23),(x+w,y+w*.44),(x+w,y+h)]
  self.poly(outer,c[0]);self.poly([(x+2,y+h),(x+2,y+w*.46),(x+w*.16,y+w*.25),(x+w*.5,y+3),(x+w*.84,y+w*.25),(x+w-2,y+w*.46),(x+w-2,y+h)],c[3])
  t=max(5,int(w*.13));self.poly([(x+t,y+h),(x+t,y+w*.48),(x+w*.23,y+w*.34),(x+w*.5,y+t),(x+w*.77,y+w*.34),(x+w-t,y+w*.48),(x+w-t,y+h)],c[0])
  self.poly([(x+t+2,y+h),(x+t+2,y+w*.5),(x+w*.25,y+w*.36),(x+w*.5,y+t+3),(x+w*.75,y+w*.36),(x+w-t-2,y+w*.5),(x+w-t-2,y+h)],inside)
  for side in (0,1):
   xx=x if side==0 else x+w-t
   for yy in range(int(y+w*.45),int(y+h),11):self.brick(xx,yy,t,min(10,int(y+h-yy)),c)
  for a in range(6):
   t0=a/6;px=x+w*.5-(w*.5)*t0;py=y+w*.43*t0
   self.line([(px,py),(px+3,py+6)],c[1]);self.line([(x+w-(px-x),py),(x+w-(px-x)-3,py+6)],c[1])
  if broken:
   self.poly([(x+w*.70,y+7),(x+w*.87,y+14),(x+w*.90,y+27),(x+w*.76,y+28),(x+w*.69,y+18)],self.p['sky'][4])
 def column(self,x,y,w,h,colors=None,broken=False):
  c=colors or self.p['stone'];self.wall(x,y,w,h,c)
  self.rect((x+2,y+2,x+4,y+h),c[3]);self.rect((x+w-5,y+2,x+w-2,y+h),c[0])
  for yy in range(y+10,y+h,22):self.line([(x+6,yy),(x+w-7,yy+1)],c[1])
  for yy in (y,y+h-6):
   self.brick(x-5,yy,w+10,6,c);self.brick(x-3,yy+6,w+6,3,c)
  if broken:self.poly([(x-6,y-1),(x+2,y-5),(x+6,y-1),(x+10,y-8),(x+w-2,y-4),(x+w+5,y)],c[2])
 def grass(self,x,y,s=1,colors=None):
  c=colors or self.p['plant'];s=max(.4,s)
  self.cluster(x-5*s,y,12*s,2*s,c[0])
  for dx,dy in [(-6,-6),(-3,-9),(0,-11),(3,-7),(6,-5)]:
   self.line([(x,y),(x+dx*s*.6,y+dy*s*.45),(x+dx*s,y+dy*s)],c[1 if dx<0 else 2],max(1,int(s)))
   if dx in (0,3):self.line([(x+dx*s*.6,y+dy*s*.45),(x+dx*s,y+dy*s)],c[3],max(1,int(s)))
 def fern(self,x,y,s=1):
  c=self.p['plant'];self.line([(x,y),(x-1,y-17*s),(x+3*s,y-25*s)],c[1],max(1,int(s)))
  for dy,wi in [(5,10),(10,11),(15,8),(20,5)]:
   yy=y-dy*s
   self.poly([(x,yy),(x-wi*s,yy-6*s),(x-wi*s*.7,yy-1*s),(x-1,yy+2)],c[2])
   self.poly([(x,yy-1),(x+wi*s,yy-5*s),(x+wi*s*.6,yy),(x,yy+2)],c[3])
 def rock(self,x,y,w,h,colors=None):
  c=colors or self.p['stone'];self.cluster(x-w//2-2,y-1,w+5,4,c[0])
  p=[(x-w//2,y),(x-w//2+3,y-h//2),(x-w//4,y-h),(x+w//4,y-h-1),(x+w//2,y-h//3),(x+w//2-2,y+1)]
  self.poly(p,c[0]);self.poly([(x-w//2+2,y-2),(x-w//4,y-h+2),(x+w//4-1,y-h+1),(x+w//2-2,y-h//3),(x+w//2-4,y-1)],c[2])
  self.poly([(x-w//4,y-h+2),(x+w//4-1,y-h+1),(x+w//3,y-h//2),(x-1,y-h//2)],c[3])
  self.line([(x-1,y-h//2),(x-4,y-3)],c[1])
 def ground(self,court=False):
  c=self.p['soil'];self.rect((0,177,W,H),c[1])
  for y in range(177,H):
   band=min(3,(y-177)//60);cc=c[3-band] if y<357 else c[0];self.line([(0,y),(W,y)],cc)
  # Horizontal earth shelves are clustered, not scattered single-pixel noise.
  for k in range(1600):
   y=self.r.randrange(182,450);x=self.r.randrange(W);t=(y-180)/270
   if 175<x<535 and 190<y<288 and self.r.random()<.55:continue
   cc=self.r.choice(c[:3]); self.cluster(x,y,self.r.randrange(3,9+int(t*14)),self.r.randrange(1,3+int(t*2)),cc)
  # Broad irregular courtyard pavers converge into the horizon.
  yy=185;row=0
  while yy<450:
   hh=int(9+(yy-180)*.085);ww=int(33+(yy-180)*.24);xx=-ww+(row%2)*ww//2
   while xx<W:
    if court or 160-(yy-180)*.55 < xx < 535+(yy-180)*.55:
     if self.r.random()<(.92 if court else .68):
      j=self.r.randrange(-3,4);top=yy+j;xp=xx+self.r.randrange(-3,4)
      pts=[(xp+4,top),(xp+ww-7,top-1),(xp+ww-2,top+hh-4),(xp+ww-8,top+hh),(xp+2,top+hh-1),(xp-2,top+4)]
      cc=self.p['stone'];shadow=cc[0];base=mix(cc[1],c[2],self.r.choice([.22,.35,.45,.6,.72]));edge=mix(cc[3],c[2],self.r.choice([.50,.58,.66,.74]))
      self.poly([(x,y+2) for x,y in pts],shadow);self.poly(pts,base)
      self.line(pts[:2],edge);self.line([pts[-1],pts[0]],edge)
      self.line([pts[2],pts[3],pts[4]],shadow)
      if self.r.random()<.45:self.line([(xp+ww*.4,top+2),(xp+ww*.45,top+hh*.5),(xp+ww*.38,top+hh-1)],shadow)
      for n in range(6):
       ax=xp+self.r.randrange(5,max(6,ww-8));ay=top+self.r.randrange(2,max(3,hh-2));self.cluster(ax,ay,self.r.randrange(2,7),self.r.choice([1,1,2]),mix(base,edge,self.r.choice([.18,.3,.42])))
      if self.r.random()<.23:
       ax=xp+self.r.randrange(5,max(6,ww-14));ay=top+2;pc=mix(self.p['plant'][2],base,.5)
       self.cluster(ax,ay,8,2,pc);self.cluster(ax+2,ay+2,4,2,pc)
      if self.r.random()<.25:self.poly([(xp+ww-8,top+hh-1),(xp+ww-11,top+hh-5),(xp+ww-15,top+hh-1)],shadow)
    xx+=ww+self.r.randrange(-4,5)
   yy+=hh+3;row+=1
  for k in range(210):
   y=self.r.randrange(186,450);x=self.r.randrange(W);t=(y-180)/270
   if 163<x<537 and y<289 and self.r.random()<.87:continue
   self.grass(x,y,.36+t*.85)
  for k in range(55):
   y=self.r.randrange(200,450);x=self.r.randrange(W)
   if 175<x<530 and y<290:continue
   self.rock(x,y,self.r.randrange(5,12),self.r.randrange(3,7))
 def tree(self,x,y,h,flip=False):
  # Authored sweeping boughs, scars, root plates, and cool/warm edge planes.
  s=h/170;sg=-1 if flip else 1
  def pts(p):return [(x+sg*xx*s,y+yy*s) for xx,yy in p]
  c=[(20,28,31),(34,36,36),(52,45,40),(73,56,45),(100,71,49)] if self.name=='cinder_forest' else self.p['plant']
  trunk=[(-22,8),(-9,-22),(-8,-62),(-17,-99),(-10,-128),(-16,-169),(-7,-162),(1,-139),(3,-100),(13,-62),(11,-23),(28,8),(11,3),(1,-6),(-6,4)]
  self.poly(pts(trunk),c[0]);self.poly(pts([(-11,2),(-3,-30),(-2,-65),(-12,-105),(-7,-134),(-10,-157),(-3,-140),(-2,-98),(7,-61),(5,-22),(17,3),(5,-2),(-1,-12),(-5,-1)]),c[2])
  self.poly(pts([(-7,-30),(-5,-70),(-12,-104),(-7,-133),(-4,-123),(-7,-103),(1,-70),(0,-34),(-2,-12)]),c[3])
  branches=[[(1,-93),(21,-109),(34,-141),(38,-163),(33,-154),(28,-137),(14,-118),(-1,-114)], [(-10,-110),(-36,-128),(-58,-132),(-85,-157),(-76,-139),(-58,-123),(-30,-118),(-8,-96)],[(7,-64),(41,-78),(58,-98),(78,-103),(83,-113),(61,-107),(51,-98),(35,-88),(9,-80)],[(-9,-139),(-40,-160),(-49,-185),(-50,-168),(-42,-155),(-12,-126)]]
  for b in branches:self.poly(pts(b),c[1]);self.line(pts(b[:3]),c[3],max(1,int(2*s)))
  for z in range(14):
   yy=-self.r.randrange(12,141);xx=self.r.randrange(-8,4);self.line(pts([(xx,yy),(xx-2,yy+9),(xx,yy+15)]),c[self.r.choice([0,1,3])],1)
  for dx,dy in [(-35,8),(38,12),(-42,18),(19,17)]:self.line(pts([(0,-5),(dx*.5,dy*.3),(dx,dy)]),c[1],max(2,int(4*s)));self.line(pts([(0,-5),(dx*.5,dy*.3),(dx,dy)]),c[2],max(1,int(s)))
 def banner(self,x,y,w,h):
  c=self.p['accent'];self.line([(x-5,y),(x+w+5,y)],self.p['stone'][3],2)
  self.poly([(x,y+2),(x+w,y+2),(x+w-2,y+h),(x+w*.56,y+h-8),(x+w*.38,y+h-2),(x+2,y+h-6)],c[0])
  self.poly([(x+3,y+3),(x+w-4,y+3),(x+w-6,y+h-7),(x+w*.55,y+h-13),(x+4,y+h-10)],c[1])
  self.line([(x+4,y+4),(x+5,y+h-13)],c[2]);self.line([(x+w-7,y+4),(x+w-8,y+h-12)],c[0])
  cy=y+h*.35;cx=x+w*.5;self.poly([(cx,cy-5),(cx+4,cy),(cx,cy+6),(cx-4,cy)],self.p['stone'][3]);self.line([(cx,cy-9),(cx,cy+10)],self.p['stone'][3])
 def brazier(self,x,y,s=1):
  c=self.p['stone'];ac=self.p['accent'];self.rect((x-2*s,y-16*s,x+2*s,y),c[0]);self.rect((x-s,y-16*s,x+s,y),c[3]);self.rect((x-5*s,y,x+5*s,y+2*s),c[1]);self.poly([(x-8*s,y-21*s),(x+8*s,y-21*s),(x+5*s,y-16*s),(x-5*s,y-16*s)],c[1]);self.line([(x-7*s,y-21*s),(x+7*s,y-21*s)],c[3])
  self.poly([(x-6*s,y-22*s),(x-5*s,y-28*s),(x-2*s,y-25*s),(x+1*s,y-35*s),(x+3*s,y-29*s),(x+6*s,y-32*s),(x+6*s,y-22*s)],ac[2]);self.poly([(x-2*s,y-22*s),(x,y-30*s),(x+3*s,y-23*s)],ac[3])
 def foreground(self):
  for side in (0,1):
   for k in range(20):
    x=self.r.randrange(0,115) if side==0 else self.r.randrange(610,720);y=self.r.randrange(296,450);self.fern(x,y,self.r.uniform(.6,1.3))
  for x in range(-10,740,9):self.grass(x,448+self.r.randrange(0,12),self.r.uniform(1.3,2.2),[self.p['soil'][0],self.p['plant'][0],self.p['plant'][1],self.p['plant'][2]])
 def finish(self):
  # Deliberate, quantized light planes: preserve the pixel grid and give the
  # stage its brightest value range without a blur or noisy lighting texture.
  px=self.im.load();cache={}
  for y in range(H):
   for x in range(W):
    if y<176:
     field=.07*max(0,1-abs(x-415)/450)-.04*abs(x-360)/360
    else:
     xx=(x//4)*4;yy=(y//3)*3
     pool=max(0,1-((xx-373)/345)**2-((yy-210)/235)**2)
     field=.19*pool-.10*(abs(x-360)/360)**1.4-.11*max(0,(y-280)/170)
    band=int(round(field/.035));col=px[x,y];key=(col,band)
    if key not in cache:
     warm=(1.0,.76,.47) if self.name!='drowned_reliquary' else (.40,.81,1.0)
     cache[key]=tuple(max(0,min(255,int(v*(1+band*.023)+band*warm[i]))) for i,v in enumerate(col))
    px[x,y]=cache[key]
  self.im=self.im.quantize(colors=96,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).convert('RGB')
  self.im.save(OUT/(self.name+'.png'),optimize=True)
  return self.im

def cinder():
 a=Painter('cinder_forest',9157);p=a.p;a.sky()
 # Late sunlight in a bruised overcast sky.
 a.d.ellipse((418,46,459,86),fill=p['sky'][5]);a.cluster(402,64,69,5,p['sky'][4]);a.cluster(429,51,52,3,p['sky'][3])
 for n,(y,am) in enumerate([(122,17),(140,14),(156,10)]):a.ridge(y,am,p['far'][n],36+n)
 for k in range(56):
  x=a.r.randrange(720);y=a.r.randrange(139,175);a.pine(x,y,a.r.randrange(17,50),p['far'][2])
 # Ruined abbey: original broken rose-window façade, side chapel, bell tower.
 far=[mix(c,p['far'][0],.45) for c in p['stone']]
 a.wall(243,100,217,68,far);a.poly([(246,101),(281,83),(297,91),(321,60),(347,75),(364,68),(397,91),(430,92),(460,107)],far[1])
 a.line([(246,101),(281,83),(297,91),(321,60),(347,75)],far[3],2)
 a.wall(272,88,18,91,far);a.wall(424,88,20,87,far)
 a.column(235,96,16,87,far,True);a.column(452,108,17,69,far,True)
 a.arch(307,91,66,80,far,far[0]);a.arch(314,102,52,70,far,mix(p['accent'][0],far[0],.6))
 a.line([(340,123),(340,170)],far[2],2);a.line([(320,147),(359,147)],far[2],2)
 for x in (258,391):a.arch(x,117,23,39,far,p['far'][2]);a.line([(x+11,127),(x+11,153)],far[3])
 # Rose window and fractured upper pediment.
 a.d.ellipse((315,66,363,111),fill=far[0],outline=far[3],width=3);a.d.ellipse((322,73,356,105),fill=p['far'][2],outline=far[2],width=2)
 for th in range(0,360,45):
  ang=math.radians(th);a.line([(339,89),(339+16*math.cos(ang),89+15*math.sin(ang))],far[3],2)
 a.d.ellipse((333,83,345,95),outline=far[3],width=2)
 a.wall(462,48,35,126,far);a.column(458,42,7,133,far);a.column(495,42,7,132,far)
 a.arch(470,65,20,37,far,p['far'][2]);a.poly([(459,44),(463,35),(470,35),(470,28),(479,28),(479,34),(487,34),(487,22),(496,31),(502,46)],far[1]);a.line([(465,44),(493,44)],far[3],2)
 a.rect((474,116,486,141),far[0]);a.line([(472,114),(489,114)],far[3],2)
 for x,y in [(244,132),(282,98),(439,143),(483,151)]:
  for j in range(7):a.cluster(x+a.r.randrange(-4,8),y+j*4,5,3,p['plant'][2])
 a.mist(165,mix(p['far'][0],p['sky'][4],.27),15)
 a.ground()
 # Edge retaining walls and toppled masonry leave the actors' stage quiet.
 for x,y,w in [(4,177,110),(568,176,148)]:
  a.wall(x,y,w,22);a.line([(x,y),(x+w,y)],p['stone'][3],2)
  for j in range(0,w,19):a.cluster(x+j,y-2,a.r.randrange(9,18),3,p['plant'][2])
 for x,y in [(138,181),(549,181),(582,217),(102,223)]:a.rock(x,y,a.r.randrange(18,34),a.r.randrange(9,17))
 a.tree(89,233,214);a.tree(644,234,220,True)
 a.tree(181,178,95,True);a.tree(559,173,108)
 a.brazier(183,210,.9);a.brazier(533,205,.85)
 for k in range(83):
  x=a.r.randrange(720);y=a.r.randrange(184,403)
  if 183<x<523 and y<285:continue
  a.cluster(x,y,a.r.randrange(3,7),2,a.r.choice([p['accent'][0],p['accent'][1],p['plant'][3]]))
 for x,y in [(33,272),(677,277),(127,334),(583,318)]:a.fern(x,y,1.3)
 # A few intentional ember clusters, not star/noise scattering.
 for x,y in [(124,91),(594,83),(171,139),(564,131),(103,161),(622,153)]:a.rect((x,y,x+1,y+2),p['accent'][2]);a.rect((x,y,x,y),p['accent'][3])
 a.foreground();return a.finish()

def drowned():
 a=Painter('drowned_reliquary',24081);p=a.p;a.sky()
 # Moon rendered in discrete planes and crater clusters.
 a.d.ellipse((423,28,477,82),fill=(168,186,182));a.d.ellipse((428,30,473,75),fill=(191,201,187))
 for x,y,w,h in [(431,45,9,5),(452,33,7,4),(446,59,14,7),(462,49,5,8),(439,70,6,3)]:a.cluster(x,y,w,h,(151,174,177))
 a.cluster(453,40,7,3,(218,221,192));a.cluster(409,65,82,4,p['sky'][3])
 for n,(y,am) in enumerate([(130,21),(150,14),(168,9)]):a.ridge(y,am,p['far'][n],84+n)
 far=[mix(c,p['far'][0],.5) for c in p['stone']]
 # Distant drowned towers and aqueducts.
 for x,y,w,h in [(84,110,18,51),(154,91,22,70),(530,98,24,65),(612,128,17,44)]:
  a.wall(x,y,w,h,far);a.poly([(x-2,y),(x+w//2,y-14),(x+w+2,y)],far[1]);a.rect((x+6,y+12,x+w-6,y+28),far[0])
 for x in range(40,670,72):a.arch(x,134,52,47,far,p['far'][2])
 # Central ruined astronomical reliquary ring and recessed sanctuary.
 a.wall(266,113,170,61,far);a.arch(321,100,66,79,far,p['stone'][0]);a.arch(329,111,50,65,far,p['far'][2])
 a.column(263,75,18,103,broken=True);a.column(425,79,18,99,broken=True)
 a.d.ellipse((289,40,414,154),fill=p['stone'][0],outline=p['stone'][3],width=4)
 a.d.ellipse((296,47,407,147),fill=p['stone'][2],outline=p['stone'][1],width=3)
 a.d.ellipse((306,57,397,139),fill=p['sky'][4],outline=p['stone'][4],width=2)
 # Repaint sky-filled center with sunken temple shadow visible through it.
 a.poly([(308,124),(326,105),(341,111),(357,88),(377,113),(395,120),(395,137),(308,137)],p['far'][1])
 a.d.ellipse((326,76,377,123),outline=p['accent'][1],width=2)
 for th in range(0,360,30):
  ang=math.radians(th);xx=352+54*math.cos(ang);yy=97+50*math.sin(ang)
  a.line([(352+48*math.cos(ang),97+45*math.sin(ang)),(xx,yy)],p['stone'][0],2)
  if th%60==0:a.rect((xx-1,yy-1,xx+1,yy+1),p['accent'][2])
 a.line([(352,62),(352,133)],p['stone'][2],2);a.line([(316,98),(388,98)],p['stone'][2],2)
 a.poly([(352,81),(363,98),(352,115),(341,98)],p['accent'][0]);a.poly([(352,87),(358,98),(352,109),(346,98)],p['accent'][2]);a.rect((351,92,352,102),p['accent'][3])
 # The broken ring's missing wedge is authored separately.
 a.poly([(389,47),(408,52),(418,72),(402,80),(395,66),(382,58)],p['sky'][3]);a.rock(452,178,33,18)
 for x in (245,447):a.column(x,121,15,58,broken=True)
 a.mist(164,mix(p['far'][0],p['sky'][5],.26),18)
 a.ground(court=True)
 # Lapping water wings border a gently rising ritual causeway.
 for side in (0,1):
  pts=[(0,177),(193,177),(155,200),(101,239),(0,265)] if side==0 else [(526,177),(720,177),(720,266),(628,239),(568,202)]
  a.poly(pts,p['water'][0])
  for k in range(125):
   y=a.r.randrange(180,257);lim=190-(y-180)*1.8
   if lim<8:continue
   x=a.r.randrange(int(lim)) if side==0 else 720-a.r.randrange(int(lim))
   a.cluster(x,y,a.r.randrange(6,23),1,a.r.choice(p['water']))
 a.line([(189,179),(155,200),(101,239),(0,265)],p['stone'][3],2);a.line([(526,179),(568,202),(628,239),(720,266)],p['stone'][3],2)
 for x,y in [(133,216),(579,214),(83,244),(629,245)]:a.rock(x,y,19,9)
 a.column(111,72,25,132,broken=True);a.column(588,59,29,146,broken=True)
 a.arch(98,67,56,61,inside=p['far'][2],broken=True);a.arch(572,47,61,75,inside=p['far'][1],broken=True)
 for x,y in [(103,77),(591,72),(614,123),(128,147)]:
  for j in range(12):a.cluster(x+a.r.randrange(-2,6),y+j*4,a.r.randrange(2,7),3,p['plant'][2 if j%3 else 3])
 a.brazier(181,211,1);a.brazier(536,211,1)
 # Small submerged tablets and phosphorescent reeds along the waterline.
 for x,y in [(41,202),(675,204),(148,185),(557,185)]:
  a.wall(x,y-15,16,15);a.rect((x+5,y-11,x+10,y-4),p['accent'][1]);a.line([(x+7,y-11),(x+7,y-3)],p['accent'][2])
 for x,y in [(38,235),(72,222),(666,233),(633,220),(21,266),(701,267)]:a.grass(x,y,1.1);a.fern(x+10,y+4,.8)
 a.foreground();return a.finish()

def throne():
 a=Painter('pale_throne',60617);p=a.p;a.sky()
 a.d.ellipse((435,26,496,87),fill=(204,195,153));a.d.ellipse((440,30,491,80),fill=(216,206,166));a.cluster(427,69,93,5,p['sky'][4]);a.cluster(420,81,89,3,p['sky'][3])
 for n,(y,am) in enumerate([(124,15),(146,16),(165,7)]):a.ridge(y,am,p['far'][n],121+n)
 far=[mix(c,p['far'][0],.5) for c in p['stone']]
 # Empty skyline, battlements, and two abandoned galleries.
 for x,y,w,h in [(40,117,93,55),(575,112,113,59)]:
  a.wall(x,y,w,h,far)
  for xx in range(x,x+w,20):a.brick(xx,y-8,12,9,far)
  for xx in range(x+9,x+w-10,25):a.arch(xx,y+13,14,31,far,p['far'][2])
 a.wall(212,141,302,37,far)
 for x in range(222,507,30):a.brick(x,136,23,8,far)
 # Broken halo behind the empty throne. Its segment joints tell scale.
 a.d.arc((286,48,429,177),190,355,fill=p['stone'][1],width=14)
 a.d.arc((286,48,429,177),190,355,fill=p['stone'][3],width=3)
 a.d.arc((300,62,415,166),190,353,fill=p['stone'][0],width=2)
 for th in range(195,350,19):
  ang=math.radians(th);a.line([(357+60*math.cos(ang),113+52*math.sin(ang)),(357+71*math.cos(ang),113+64*math.sin(ang))],p['stone'][0],2)
 # Tiered dais and tall basalt throne, original crest and recesses.
 for j in range(4):
  a.wall(280-j*11,162+j*7,153+j*22,7);a.line([(280-j*11,162+j*7),(433+j*11,162+j*7)],p['stone'][3])
 a.wall(325,100,62,62);a.arch(330,83,52,69,inside=p['stone'][0]);a.arch(337,98,38,50,inside=p['accent'][0])
 a.poly([(340,119),(357,101),(374,119),(372,145),(341,145)],p['accent'][1]);a.line([(357,112),(357,139)],p['stone'][3],2);a.poly([(357,112),(364,121),(357,132),(350,121)],p['stone'][3]);a.poly([(357,116),(360,122),(357,126),(354,122)],p['stone'][0])
 a.brick(321,148,70,9);a.brick(319,142,12,20);a.brick(382,142,12,20)
 a.column(312,88,12,73,broken=True);a.column(389,88,12,73,broken=True)
 a.banner(246,106,22,58);a.banner(451,101,24,66)
 a.mist(169,mix(p['far'][0],p['sky'][4],.25),11)
 a.ground(court=True)
 # Monumental near pillars with carved crown capitals and fallen counterparts.
 for x,y,w,h in [(143,46,31,153),(541,33,32,167)]:
  a.column(x,y,w,h,broken=True);a.brick(x-9,y-8,w+18,8);a.brick(x-5,y-13,w+10,5)
  for dx in (8,16,24):a.line([(x+dx,y+13),(x+dx,y+h-15)],p['stone'][1]);a.line([(x+dx+1,y+13),(x+dx+1,y+h-15)],p['stone'][3])
  a.rect((x+7,y+48,x+w-8,y+68),p['stone'][0]);a.poly([(x+w/2,y+50),(x+w-10,y+57),(x+w/2,y+65),(x+10,y+57)],p['stone'][3])
  # Wing-like eroded finials, deliberately without a copied insignia.
  a.poly([(x+7,y-13),(x+2,y-30),(x-10,y-39),(x-2,y-41),(x+12,y-29),(x+16,y-40),(x+21,y-29),(x+w+8,y-41),(x+w+13,y-35),(x+w-1,y-27),(x+w-5,y-13)],p['stone'][1]);a.line([(x+2,y-30),(x+12,y-21),(x+w-2,y-30)],p['stone'][3],2)
 a.banner(185,78,22,95);a.banner(511,64,21,100)
 for x,y,w in [(55,229,59),(599,230,72)]:
  a.wall(x,y-15,w,15);a.brick(x-4,y-19,w+6,7);a.poly([(x+12,y-19),(x+30,y-29),(x+41,y-22),(x+48,y-19)],p['stone'][2]);a.line([(x+13,y-19),(x+30,y-29),(x+40,y-22)],p['stone'][3])
 # Fractured medallion inset into the fighting ground, low contrast by design.
 cc=mix(p['stone'][2],p['soil'][2],.5)
 a.d.ellipse((300,202,448,253),outline=cc,width=2);a.d.ellipse((308,205,440,250),outline=p['soil'][1],width=2)
 a.line([(327,226),(345,219),(359,226),(380,219),(400,226),(422,220)],cc,2)
 a.line([(367,204),(358,217),(369,228),(359,240),(361,252)],p['stone'][0])
 a.brazier(228,206,.85);a.brazier(484,206,.85)
 for x,y in [(19,214),(686,216),(122,269),(598,282),(52,326),(658,332)]:a.fern(x,y,1.3)
 a.foreground();return a.finish()

if __name__=='__main__':
 ims=[cinder(),drowned(),throne()]
 names=['cinder_forest','drowned_reliquary','pale_throne']
 meta={'title':'Ashen Oath original environment illustrations','native_size':[720,450],'recommended_scale':2,'filter':'nearest','authorship':'Original code-native pixel illustration by the project assistant using authored Pillow primitives and deterministic seeds. No source-game, user-reference, downloaded, generated-model, or third-party image pixels included.','generator':'tools/generate_environments.py','palette_style':'Limited cohesive ramps; clustered texture; no antialiasing, blur or photographic noise.','safe_stage':{'horizon_y':[115,145],'ground_detail_y':[180,285],'character_feet_y':250},'scenes':[]}
 for name in names:
  path=OUT/(name+'.png');meta['scenes'].append({'file':name+'.png','size':[720,450],'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size})
 (OUT/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n')
 # Review sheet, not a runtime image. The three original PNGs remain unscaled.
 sheet=Image.new('RGB',(1200,833),(17,22,29));d=ImageDraw.Draw(sheet)
 for i,(im,name) in enumerate(zip(ims,names)):
  crop=im.crop((0,25,720,292)).resize((1200,445),Image.Resampling.NEAREST)
  # All scene panels show the same battle-visible crop at 1:1-ish sampling.
  thumb=im.resize((400,250),Image.Resampling.NEAREST);sheet.paste(thumb,(i*400,28))
  d.text((i*400+12,10),name.replace('_',' ').upper(),fill=(202,191,163))
  detail=im.crop((155,50,555,300)).resize((400,250),Image.Resampling.NEAREST);sheet.paste(detail,(i*400,305))
  d.text((i*400+12,288),'CENTRAL STAGE / NATIVE PIXELS',fill=(168,180,173))
  detail2=im.crop((130,160,530,410));sheet.paste(detail2,(i*400,583))
  d.text((i*400+12,566),'ARENA MATERIALS / NATIVE PIXELS',fill=(168,180,173))
 sheet.save(OUT/'review-contact.png',optimize=True)
 print(json.dumps(meta,indent=2))
