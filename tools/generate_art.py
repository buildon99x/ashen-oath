"""Original deterministic pixel illustration. No imported art or source-game pixels."""
from PIL import Image, ImageDraw, ImageFilter
import math,random,pathlib
OUT=pathlib.Path(__file__).resolve().parents[1]/'assets';OUT.mkdir(exist_ok=True)
r=random.Random(47031)
W,H=720,450
im=Image.new('RGB',(W,H));px=im.load()
for y in range(H):
 for x in range(W):
  glow=max(0,1-math.hypot((x-460)/480,(y-175)/220))
  n=r.randrange(-3,4);px[x,y]=(int(12+glow*28+n),int(22+glow*40+n),int(30+glow*39+n))
d=ImageDraw.Draw(im)
# Moon and far ruins behind the fog.
d.ellipse((450,30,557,137),fill=(149,161,151));d.ellipse((472,15,573,121),fill=(37,58,66))
for layer in range(4):
 col=(23+layer*3,40+layer*5,46+layer*4)
 pts=[(0,H)]+[(x,int(130+layer*29+math.sin(x*.014+layer)*23+math.sin(x*.041+layer)*9)) for x in range(0,W+10,10)]+[(W,H)]
 d.polygon(pts,fill=col)
for x,y,w,h in [(80,162,40,110),(151,151,30,90),(526,142,32,125),(590,177,49,106)]:
 d.rectangle((x,y-h,x+w,y),fill=(30,47,54));d.polygon([(x-6,y-h),(x+w/2,y-h-27),(x+w+6,y-h)],fill=(26,41,49))
 for j in range(2):
  d.rectangle((x+8+j*14,y-h+18,x+12+j*14,y-h+42),fill=(65,77,73))
# Layered distant conifers.
for layer in range(3):
 for k in range(30):
  x=r.randrange(-30,750);y=180+layer*21+r.randrange(-10,11);h=r.randrange(25,75)
  c=(18+layer*3,36+layer*5,39+layer*4)
  d.line((x,y-h,x,y+10),fill=c,width=2)
  for j in range(4):
   yy=y-h+j*h/4;ww=7+j*4
   d.polygon([(x,yy),(x-ww,yy+h*.42),(x+ww,yy+h*.42)],fill=c)
# Terrain perspective and winding earth road.
for y in range(202,H):
 t=(y-202)/(H-202);center=405-85*math.sin(t*2.7);half=30+t*110
 for x in range(W):
  n=r.randrange(-8,9);light=max(0,1-abs(x-420)/380)
  if abs(x-center)<half:
   col=(int(57+light*35+t*10+n),int(63+light*32+t*8+n),int(59+light*20+n))
  else: col=(int(26+light*19+n),int(47+light*35+n),int(37+light*13+n))
  im.putpixel((x,y),tuple(max(0,min(255,c)) for c in col))
d=ImageDraw.Draw(im)
# Rocks, scored moss and dense varied ground cover.
for k in range(900):
 y=r.randrange(225,450);t=(y-202)/248;x=r.randrange(W);center=405-85*math.sin(t*2.7);half=30+t*110
 if abs(x-center)<half and r.random()<.92: continue
 size=max(2,int(t*r.randrange(5,17)))
 if k%8==0:
  c=r.choice([(52,66,63),(62,77,74),(78,88,77)])
  d.polygon([(x-size,y),(x-size//2,y-size),(x+size//2,y-size+2),(x+size,y),(x,y+3)],fill=c)
  d.line((x-size//2,y-size,x+size//2,y-size+2),fill=(97,108,92),width=1)
 else:
  h=max(2,int((3+t*13)*r.random()));c=r.choice([(58,85,54),(76,104,62),(39,69,49),(97,116,70),(42,80,66)])
  d.line((x,y,x+r.randrange(-3,4),y-h),fill=c,width=1)
  if k%11==0:d.rectangle((x-1,y-h-2,x+1,y-h),fill=r.choice([(126,146,122),(93,156,148),(158,142,107)]))
# Foreground foliage silhouettes and atmospheric veil.
for k in range(220):
 x=r.randrange(W);y=r.randrange(404,451);h=r.randrange(7,33)
 d.line((x,y,x+r.randrange(-6,7),y-h),fill=(16,37,34),width=2)
for y in range(185,215):
 alpha=int(20*(1-abs(y-200)/15))
 overlay=Image.new('RGBA',(W,H));ImageDraw.Draw(overlay).line((0,y,W,y),fill=(139,168,165,max(0,alpha)));im=Image.alpha_composite(im.convert('RGBA'),overlay)
im.convert('RGB').save(OUT/'cinder_forest.png')
# Textured carved titan, authored as disjoint layers for severing.
for tier in range(1,4):
 base=[(89,111,113),(111,96,124),(139,125,88)][tier-1]
 for part in range(3):
  a=Image.new('RGBA',(256,400));ad=ImageDraw.Draw(a)
  def poly(p,c):ad.polygon(p,fill=c,outline=(23,32,36),width=2)
  if part==0:
   poly([(70,260),(119,267),(112,342),(104,384),(57,387),(53,366),(69,341)],base)
   poly([(137,265),(184,253),(192,339),(210,376),(202,388),(149,385),(141,343)],tuple(c+10 for c in base))
   for x in [68,151]:
    for y in [281,316,351]:ad.rectangle((x,y,x+32,y+11),fill=tuple(c-20 for c in base));ad.line((x,y,x+32,y),fill=tuple(c+35 for c in base),width=2)
  if part==1:
   poly([(67,106),(102,94),(156,99),(184,125),(188,206),(164,279),(94,279),(68,213)],base)
   poly([(70,118),(40,126),(21,186),(13,247),(36,263),(51,237),(57,195),(84,161)],tuple(c-17 for c in base))
   poly([(181,124),(209,141),(228,210),(239,243),(223,265),(201,249),(188,205),(164,159)],tuple(c+9 for c in base))
   poly([(75,133),(120,144),(122,181),(86,164)],tuple(c+25 for c in base))
   poly([(133,141),(173,130),(165,171),(132,181)],tuple(c+38 for c in base))
   poly([(105,173),(145,171),(159,222),(130,249),(98,221)],(27,42,47))
   for z in range(5):
    ad.ellipse((114-z,184-z,144+z,224+z),outline=(72+z*5,119+z*4,120+z*3),width=1)
   ad.polygon([(128,179),(142,203),(128,226),(114,203)],fill=(128,215,194));ad.polygon([(128,187),(135,203),(128,217),(121,203)],fill=(220,240,204))
   for y in range(142,234,13):
    ad.ellipse((34,y,43,y+18),outline=(176,155,107),width=2);ad.ellipse((201,y+14,210,y+32),outline=(163,145,102),width=2)
  if part==2:
   poly([(89,45),(111,28),(153,31),(178,58),(173,93),(148,119),(108,107),(83,81)],base)
   poly([(90,67),(166,58),(165,86),(102,88)],(28,39,46))
   ad.line((103,73,151,70),fill=(240,184,97),width=4)
   ad.polygon([(92,53),(76,11),(99,27),(108,48)],fill=(174,151,100),outline=(28,34,38))
   ad.polygon([(161,45),(180,4),(181,34),(172,67)],fill=(185,159,105),outline=(28,34,38))
   for x in range(111,153,13):ad.polygon([(x,39),(x-5,5-(x%3)*2),(x+8,29)],fill=(191,166,112),outline=(55,50,43))
   ad.line((111,96,146,104,164,90),fill=tuple(c+40 for c in base),width=2)
  # Masked pixel patina: original procedural chisel highlights/moss cracks.
  mask=a.getchannel('A');ap=a.load();rr=random.Random(80+tier*10+part)
  for k in range(3400):
   x=rr.randrange(256);y=rr.randrange(400)
   if mask.getpixel((x,y))==255:
    old=ap[x,y];shift=rr.choice([-18,-10,8,14,20]);ap[x,y]=tuple(max(0,min(255,c+shift)) for c in old[:3])+(255,)
  for k in range(35):
   x=rr.randrange(256);y=rr.randrange(400)
   if mask.getpixel((x,y))==255:
    for z in range(rr.randrange(3,11)):
     xx=x+z//3; yy=y+z
     if xx<256 and yy<400 and mask.getpixel((xx,yy))==255:ap[xx,yy]=(40,56,55,255)
  a.save(OUT/f'titan_{tier}_{part}.png')
# Three distinct original sprite adventurers.
for i in range(3):
 a=Image.new('RGBA',(48,72));d=ImageDraw.Draw(a);cloak=[(149,58,50),(46,111,111),(91,64,115)][i];outline=(22,26,35)
 d.polygon([(15,29),(30,27),(40,62),(8,62)],fill=outline)
 d.polygon([(16,32),(29,30),(36,59),(10,59)],fill=cloak)
 for y in range(35,60,4):d.line((18,y,15,y+3),fill=tuple(min(255,c+30) for c in cloak),width=2)
 d.rectangle((16,55,21,68),fill=(38,40,51));d.rectangle((27,55,31,68),fill=(44,43,53))
 d.rectangle((13,66,22,70),fill=(93,85,76));d.rectangle((26,66,35,70),fill=(99,91,80))
 d.polygon([(15,31),(31,31),(33,48),(16,48)],fill=(94,111,112));d.rectangle((18,34,28,44),fill=(134,149,145));d.rectangle((15,47,32,50),fill=(172,132,73))
 d.ellipse((12,9,33,31),fill=outline);d.ellipse((14,11,31,29),fill=(219,177,131));d.rectangle((18,20,19,23),fill=outline);d.rectangle((27,20,28,23),fill=outline)
 hair=[(65,42,34),(195,191,168),(59,43,68)][i];d.polygon([(13,20),(11,13),(16,6),(20,9),(26,5),(33,11),(33,19),(28,15),(24,17),(18,13)],fill=hair)
 if i==0:
  d.polygon([(34,45),(40,18),(44,14),(43,27),(37,47)],fill=(207,225,224),outline=outline);d.line((32,43,41,46),fill=(189,154,83),width=3)
 elif i==1:
  d.line((39,60,39,14),fill=(146,115,74),width=3);d.ellipse((34,7,44,17),fill=(70,145,148),outline=(197,211,145));d.ellipse((37,10,41,14),fill=(206,241,207))
 else:
  d.polygon([(33,37),(45,28),(39,41)],fill=(180,203,201),outline=outline);d.polygon([(15,31),(30,30),(33,39),(18,38)],fill=(129,98,155));d.line((19,32,8,40),fill=(141,105,157),width=4)
 a.save(OUT/f'hero_{i}.png')
print('Generated original environment, 9 separated titan layers, 3 hero sprites')
