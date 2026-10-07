#!/usr/bin/env python3
"""Original Ashen Oath interlude illustrations, authored in code at 128x96.

No external images, AI API, fonts, copied silhouettes, or reference pixels are
read. Every transparent 256x192 deliverable is an exact nearest-neighbor 2x
render. All materials, clusters, props and character shapes are authored here.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import random, json, hashlib

OUT=Path(__file__).resolve().parents[1]/'assets'/'vignettes'
OUT.mkdir(parents=True,exist_ok=True)
P={
 'ink':'#202329','shadow':'#292c30','soil':'#373b39','earth':'#515146',
 'stone0':'#303a40','stone1':'#48535a','stone2':'#667071','stone3':'#919486','stone4':'#c0bd9b',
 'metal0':'#3b3935','metal1':'#66594a','metal2':'#9c8258','metal3':'#c5ac76','metal4':'#e0cf98',
 'wood0':'#302a2a','wood1':'#554139','wood2':'#795741','wood3':'#9b7755',
 'cloth0':'#303840','cloth1':'#46565a','cloth2':'#64746d','cloth3':'#929b82',
 'red0':'#4f3036','red1':'#79413d','red2':'#a45c43','red3':'#c88355',
 'ember0':'#71352f','ember1':'#a04e34','ember2':'#d98147','ember3':'#efb96e','ember4':'#f4d994',
 'teal0':'#254347','teal1':'#3e6868','teal2':'#69a298','teal3':'#a6cdb2','teal4':'#dde7c2',
 'grass0':'#35453e','grass1':'#52634b','grass2':'#7d8660',
 'skin0':'#674c40','skin1':'#a9815a','skin2':'#c8a778',
}
class Art:
 def __init__(self,seed):self.im=Image.new('RGBA',(128,96));self.d=ImageDraw.Draw(self.im);self.r=random.Random(seed)
 def color(self,c):return P.get(c,c)
 def poly(self,pts,c):self.d.polygon(pts,fill=self.color(c))
 def line(self,pts,c,w=1):self.d.line(pts,fill=self.color(c),width=w)
 def rect(self,b,c):self.d.rectangle(b,fill=self.color(c))
 def ell(self,b,c):self.d.ellipse(b,fill=self.color(c))
 def cluster(self,x,y,w,h,c):self.poly([(x,y+1),(x+2,y),(x+w-2,y),(x+w,y+1),(x+w-1,y+h),(x+1,y+h)],c)
 def base(self):
  self.poly([(10,82),(16,78),(25,79),(30,74),(46,77),(55,73),(73,75),(78,73),(91,77),(106,77),(117,81),(115,85),(106,89),(86,88),(71,91),(52,89),(36,91),(21,87),(12,87)],'shadow')
  self.poly([(15,80),(29,80),(36,76),(54,78),(63,75),(80,78),(91,77),(109,80),(111,85),(97,87),(83,85),(67,88),(50,86),(36,88),(23,85),(15,85)],'soil')
  for k in range(22):
   x=self.r.randrange(20,109);y=self.r.randrange(80,88);self.cluster(x,y,self.r.randrange(2,7),1,self.r.choice(['earth','shadow','stone0']))
 def rock(self,x,y,w=8,h=5):
  self.poly([(x-w//2,y),(x-w//2+1,y-h+2),(x-1,y-h),(x+w//2-1,y-h+1),(x+w//2,y),(x+1,y+2)],'ink')
  self.poly([(x-w//2+1,y),(x-w//2+2,y-h+2),(x-1,y-h+1),(x+w//2-1,y-h+2),(x+w//2-1,y),(x+1,y+1)],'stone1')
  self.line([(x-w//2+2,y-h+2),(x-1,y-h+1),(x+w//2-2,y-h+2)],'stone3')
  self.line([(x+1,y-h+2),(x,y),(x+2,y+1)],'stone0')
 def grass(self,x,y):
  self.line([(x-4,y-2),(x,y),(x-2,y-7)],'grass0')
  self.line([(x,y),(x+1,y-8)],'grass1');self.line([(x,y),(x+4,y-5)],'grass1');self.line([(x+1,y-8),(x+1,y-6)],'grass2')
 def outline(self,pts,c='ink',w=1):self.line(pts+[pts[0]],c,w)
 def finish(self,name):
  out=self.im.resize((256,192),Image.Resampling.NEAREST);out.save(OUT/(name+'.png'),optimize=True);return out

def camp():
 a=Art(4041);a.base()
 # Bedroll: strapped pale-wool blanket with a padded, rolled end and red lining.
 a.poly([(63,65),(87,60),(111,72),(110,81),(96,86),(72,78),(62,73)],'ink')
 a.poly([(66,65),(86,62),(107,73),(106,79),(95,83),(73,76),(65,71)],'cloth0')
 a.poly([(67,65),(86,63),(106,73),(95,78),(76,72)],'cloth2')
 a.poly([(68,66),(76,66),(97,77),(94,79),(74,72)],'cloth3')
 a.line([(78,70),(85,73),(89,73),(95,77)],'cloth1');a.line([(96,79),(104,76)],'cloth1')
 a.poly([(76,64),(79,63),(99,75),(96,78),(96,82),(93,82),(93,77)],'wood0')
 a.line([(78,65),(96,76)],'metal1');a.rect((93,76,96,78),'metal2');a.rect((94,77,95,77),'ink')
 a.poly([(62,65),(64,62),(69,63),(74,68),(75,74),(71,77),(65,74),(62,70)],'ink')
 a.poly([(64,65),(65,64),(68,65),(72,69),(73,73),(70,75),(66,72),(64,69)],'cloth3')
 a.poly([(65,66),(68,66),(71,69),(71,73),(68,73),(65,70)],'cloth1')
 a.poly([(66,67),(68,68),(70,70),(69,72),(67,70)],'cloth0')
 a.rect((67,69,68,70),'cloth2')
 # Travel pack with stitched leather flap and a small hanging tin cup.
 a.poly([(86,58),(88,42),(95,38),(107,41),(112,46),(111,66),(105,72),(89,66)],'ink')
 a.poly([(89,47),(92,42),(105,42),(108,46),(108,63),(104,68),(91,64)],'wood1')
 a.poly([(91,46),(94,41),(103,41),(107,45),(106,53),(94,55),(90,52)],'wood2')
 a.line([(93,44),(104,44),(106,47)],'wood3');a.line([(90,55),(92,63),(103,66)],'wood0')
 a.rect((97,48,100,63),'wood0');a.rect((97,50,100,54),'metal2');a.rect((98,51,99,52),'ink')
 a.line([(91,41),(93,37),(101,37),(104,41)],'ink',2);a.line([(93,40),(95,38),(100,38)],'wood3')
 a.poly([(105,57),(115,57),(115,65),(111,68),(106,65)],'ink');a.poly([(106,59),(114,59),(113,64),(110,66),(107,64)],'stone2')
 a.line([(114,59),(117,59),(117,63),(115,64)],'stone1');a.line([(106,58),(114,58)],'stone3')
 # Small forged ember brazier with splayed legs, carved metal rim, and hot coal.
 a.ell((20,69,66,84),'shadow')
 for pts in [[(31,65),(34,67),(27,80),(23,81),(23,79)],[(49,67),(53,65),(58,79),(56,82),(53,80)],[(40,68),(43,68),(43,83),(39,83)]]:a.poly(pts,'ink')
 a.line([(32,69),(27,78)],'metal1',2);a.line([(52,69),(56,78)],'metal1',2);a.line([(41,71),(41,80)],'metal2')
 a.poly([(20,53),(25,65),(34,71),(49,71),(59,64),(64,53)],'ink')
 a.poly([(23,55),(28,64),(35,68),(48,68),(57,63),(61,55)],'metal1')
 a.poly([(25,55),(30,60),(54,60),(59,55)],'metal2')
 a.line([(28,62),(35,66),(48,66),(55,62)],'metal0');a.line([(36,62),(36,66)],'metal3');a.line([(48,62),(48,65)],'metal3')
 a.poly([(21,53),(26,50),(58,50),(64,53),(60,57),(25,57)],'ink');a.poly([(25,52),(29,51),(57,51),(61,53),(58,55),(27,55)],'ember0')
 for x,y in [(29,53),(36,52),(46,53),(54,52)]:a.cluster(x,y,5,2,'ember2')
 a.line([(25,55),(59,55)],'metal3')
 # Split flame clusters, warm cores and separate drifting cinders.
 a.poly([(29,50),(27,43),(31,39),(30,33),(36,37),(39,32),(39,22),(43,26),(47,36),(51,32),(51,40),(57,44),(54,51)],'ember0')
 a.poly([(31,50),(30,44),(34,39),(34,36),(39,40),(42,34),(41,27),(44,31),(46,40),(50,37),(49,43),(54,46),(52,51)],'ember2')
 a.poly([(36,50),(35,45),(39,44),(42,36),(44,40),(44,46),(48,44),(48,49),(45,51)],'ember3')
 a.poly([(39,50),(40,46),(43,43),(43,48),(45,50)],'ember4')
 for x,y in [(33,27),(49,24),(46,15),(29,35),(55,35)]:a.rect((x,y,x+1,y+2),'ember1');a.rect((x,y,x,y),'ember3')
 a.rock(15,82,7,4);a.rock(65,87,9,5);a.grass(17,81);a.grass(117,85);return a.finish('camp')

def shrine():
 a=Art(4042);a.base()
 # A fractured arch backs the relic; voussoirs are offset planes, not a copied seal.
 a.poly([(29,70),(29,36),(33,28),(41,21),(49,15),(64,11),(78,14),(88,23),(96,36),(96,71),(87,72),(87,39),(81,29),(71,23),(61,22),(47,28),(39,38),(39,71)],'ink')
 a.poly([(31,69),(31,37),(35,29),(43,23),(50,17),(64,13),(77,16),(86,24),(94,37),(94,70),(89,70),(89,39),(83,28),(72,21),(61,20),(46,26),(37,37),(37,69)],'stone1')
 a.line([(32,35),(41,25),(50,18),(64,14),(77,17),(85,24),(92,35)],'stone3')
 a.line([(39,37),(47,28),(61,22),(71,23),(81,30),(86,39)],'stone0',2)
 for pts in [[(35,29),(40,33)],[(44,22),(47,27)],[(54,16),(56,21)],[(66,14),(66,20)],[(77,18),(74,23)],[(86,27),(81,31)],[(92,37),(88,39)]]:a.line(pts,'ink')
 for x in (31,89):
  for y in range(39,70,8):a.line([(x,y),(x+4,y)],'ink');a.line([(x,y+1),(x+4,y+1)],'stone2')
  a.rect((x+1,38,x+1,68),'stone2')
 # Break the upper-right arch with transparent pixels and a displaced fragment.
 a.poly([(77,12),(86,16),(88,23),(79,21),(77,17)],(0,0,0,0));a.poly([(92,17),(98,21),(98,26),(92,23)],'stone1');a.line([(92,17),(97,20)],'stone3')
 # Carved plinth and stepped base.
 a.poly([(41,75),(84,75),(91,81),(85,87),(42,87),(35,81)],'ink')
 a.poly([(41,76),(83,76),(87,80),(82,83),(43,83),(38,80)],'stone2');a.line([(42,77),(82,77)],'stone3')
 a.rect((43,82,81,85),'stone1');a.line([(45,84),(80,84)],'stone0')
 a.poly([(47,48),(76,48),(79,74),(74,79),(49,78),(45,73)],'ink')
 a.poly([(50,49),(73,49),(76,73),(72,76),(50,76),(48,72)],'stone1')
 a.poly([(51,51),(62,51),(62,74),(51,74),(49,71)],'stone2');a.line([(51,51),(51,73)],'stone3');a.line([(70,52),(72,70)],'stone0',2)
 a.poly([(58,55),(66,55),(69,63),(63,70),(57,64)],'stone0')
 a.poly([(63,58),(66,63),(63,67),(60,63)],'metal2');a.rect((62,61,63,64),'metal3')
 a.poly([(43,46),(48,43),(78,43),(83,47),(79,52),(46,52)],'ink')
 a.poly([(47,45),(76,45),(80,47),(77,49),(48,49),(45,47)],'stone3');a.line([(47,50),(77,50)],'stone1')
 # Brass fork holding a glowing faceted seed; broken ring, no lettering.
 a.line([(54,45),(51,39),(51,34)],'metal0',3);a.line([(72,45),(76,39),(76,34)],'metal0',3)
 a.line([(54,44),(52,39),(52,34)],'metal2');a.line([(72,44),(75,39),(75,34)],'metal3');a.line([(56,45),(70,45)],'metal2',2)
 a.poly([(63,20),(72,29),(71,37),(63,44),(55,37),(54,29)],'ink')
 a.poly([(63,22),(70,29),(69,36),(63,42),(57,36),(56,30)],'teal1')
 a.poly([(63,22),(63,41),(57,35),(56,30)],'teal2');a.poly([(63,23),(68,29),(63,31),(58,29)],'teal3')
 a.poly([(63,27),(66,31),(63,37),(60,32)],'teal4')
 a.line([(44,33),(41,33)],'teal1');a.rect((47,23,48,24),'teal2');a.rect((80,29,81,30),'teal2');a.line([(63,14),(63,17)],'teal3')
 for x,y in [(28,73),(96,74),(101,82),(22,82)]:a.rock(x,y,8,5)
 for x,y in [(30,55),(89,45),(36,72)]:
  a.line([(x,y),(x+1,y+10),(x-1,y+15)],'grass0');a.cluster(x-3,y+2,4,2,'grass1');a.cluster(x,y+7,5,2,'grass1')
 a.grass(22,83);a.grass(103,85);return a.finish('relic')

def event():
 a=Art(4043);a.base()
 # Broken roadside oath marker.
 a.poly([(83,30),(85,18),(96,15),(103,21),(101,65),(105,74),(99,79),(80,78),(81,66)],'ink')
 a.poly([(87,20),(95,18),(100,22),(97,67),(101,74),(85,75),(85,65)],'stone1')
 a.poly([(87,22),(94,20),(92,68),(86,73),(87,61)],'stone2');a.line([(88,23),(87,62)],'stone3')
 a.line([(96,25),(92,33),(95,40),(91,48)],'stone0');a.poly([(89,31),(95,30),(95,33),(89,34)],'metal1')
 a.line([(92,28),(91,39)],'metal2');a.line([(87,45),(95,43)],'stone0',2)
 a.poly([(86,54),(92,58),(88,63),(94,68),(89,74),(85,70)],'stone0')
 # Worn pilgrim boots beneath a heavy torn cloak.
 a.poly([(41,67),(50,68),(49,80),(45,85),(34,85),(33,82),(39,78)],'ink')
 a.poly([(53,69),(62,67),(64,80),(69,82),(69,86),(55,86),(54,81)],'ink')
 a.poly([(42,73),(47,73),(46,80),(42,82),(36,82),(41,79)],'wood1');a.line([(36,83),(44,83)],'wood2')
 a.poly([(56,73),(60,72),(61,81),(66,82),(66,83),(57,83)],'wood1');a.line([(58,84),(67,84)],'wood2')
 a.poly([(38,36),(47,30),(58,30),(68,38),(69,51),(64,57),(69,73),(62,76),(58,73),(52,77),(44,74),(39,77),(34,73),(37,56),(32,49)],'ink')
 a.poly([(40,37),(48,33),(57,33),(65,39),(66,49),(61,55),(65,70),(61,72),(57,70),(51,73),(44,70),(40,73),(37,71),(40,54),(35,48)],'cloth0')
 a.poly([(40,40),(47,36),(48,46),(43,56),(42,66),(39,71),(38,68),(41,52),(37,48)],'cloth2')
 a.poly([(49,36),(55,35),(62,40),(59,50),(56,52),(61,70),(56,68),(52,70),(47,67),(48,54)],'cloth1')
 a.line([(49,45),(48,58),(46,67)],'cloth3');a.line([(58,48),(56,55),(59,65)],'cloth0',2)
 a.line([(41,57),(40,65)],'cloth1');a.line([(62,61),(65,69)],'cloth2')
 # Hood, deep face recess, and a narrow visible cheek.
 a.poly([(39,34),(36,28),(38,21),(43,17),(45,12),(51,14),(57,19),(61,27),(60,35),(53,40),(46,40)],'ink')
 a.poly([(40,32),(38,28),(40,22),(45,19),(47,15),(51,17),(56,22),(58,28),(57,34),(52,37),(46,37)],'cloth1')
 a.poly([(40,28),(43,23),(48,19),(50,18),(50,22),(45,26),(44,33),(41,32)],'cloth3')
 a.poly([(44,28),(47,23),(52,24),(56,28),(55,34),(51,36),(46,34)],'ink')
 a.poly([(50,29),(54,29),(53,33),(50,34),(48,32)],'skin0');a.rect((51,30,53,30),'skin1')
 a.line([(43,35),(49,38),(57,34)],'cloth2');a.line([(41,33),(44,34)],'cloth0')
 # Cross-body leather strap and a bound pouch.
 a.line([(39,37),(44,47),(57,58)],'ink',3);a.line([(40,38),(45,47),(57,56)],'wood2')
 a.poly([(51,53),(58,51),(63,55),(61,64),(54,65),(50,61)],'ink');a.poly([(53,54),(58,53),(61,56),(59,62),(55,63),(52,60)],'wood1');a.line([(53,55),(58,55),(60,57)],'wood3');a.rect((56,57,57,59),'metal2')
 # Staff in the forward hand and an empty oath ribbon.
 a.line([(72,26),(74,79),(73,86)],'ink',3);a.line([(72,27),(73,79),(72,84)],'wood2');a.line([(72,31),(72,41)],'wood3')
 a.poly([(68,42),(73,41),(76,44),(75,48),(71,49),(68,47)],'ink');a.poly([(69,43),(73,43),(74,46),(71,47),(69,46)],'skin1');a.rect((71,43,73,44),'skin2')
 a.poly([(72,28),(80,27),(82,31),(79,37),(82,44),(78,42),(75,36),(77,31),(73,31)],'red0');a.line([(77,29),(79,31),(77,36),(79,40)],'red2')
 for x,y in [(24,84),(111,85),(101,75)]:a.grass(x,y)
 a.rock(27,85,10,5);a.rock(97,84,11,6);return a.finish('event')

def reward():
 a=Art(4044);a.base()
 # Open travel coffer: angled box, thick brass straps, dark lining, loose coins.
 a.ell((25,68,108,88),'shadow')
 a.poly([(30,49),(46,40),(98,48),(102,71),(91,83),(39,79),(29,65)],'ink')
 a.poly([(32,51),(45,43),(96,50),(99,69),(89,79),(40,76),(32,64)],'wood1')
 a.poly([(33,51),(82,58),(82,77),(40,74),(33,63)],'wood2')
 a.poly([(85,58),(96,51),(98,68),(87,78),(84,76)],'wood0')
 a.line([(34,56),(81,63)],'wood0');a.line([(36,65),(81,70)],'wood0');a.line([(36,57),(78,63)],'wood3');a.line([(41,72),(78,76)],'wood3')
 a.line([(91,58),(94,67),(89,74)],'wood2');a.line([(86,65),(97,57)],'wood1')
 # Open lid raised backwards, with bevel planes and dark padded interior.
 a.poly([(31,48),(27,27),(31,20),(78,13),(92,18),(99,47),(85,57)],'ink')
 a.poly([(32,46),(29,28),(33,23),(78,16),(90,20),(96,46),(84,54)],'wood2')
 a.poly([(34,27),(77,20),(86,23),(91,44),(82,49),(37,43)],'wood0')
 a.poly([(37,28),(77,22),(84,25),(88,43),(81,46),(39,41)],'red0')
 a.poly([(39,29),(76,24),(82,27),(85,41),(79,43),(41,39)],'red1')
 a.line([(41,29),(76,25)],'red2');a.line([(77,26),(79,38)],'red0');a.line([(45,32),(51,40)],'red0')
 a.line([(33,24),(77,17),(89,21)],'wood3');a.line([(33,46),(84,53),(95,46)],'metal1',2)
 # Outer corner brackets and banding.
 for pts in [[(34,22),(40,21),(44,44),(39,46)],[(75,15),(80,16),(86,45),(81,49)],[(40,53),(45,53),(47,76),(42,76)],[(74,57),(79,58),(80,78),(75,77)]]:
  a.poly(pts,'metal0');a.line(pts[:2]+[pts[2]],'metal2');a.line([pts[0],pts[-1]],'metal3')
 for x,y in [(37,25),(41,41),(78,20),(83,42),(43,57),(45,72),(77,62),(78,74)]:a.rect((x,y,x+1,y+1),'metal4')
 # Recessed treasure well keeps the box open at a glance.
 a.poly([(35,48),(47,42),(92,48),(84,56)],'ink');a.poly([(42,48),(49,44),(88,48),(81,53)],'red0')
 # Coins and crystal fragments: restrained highlights, no lettering.
 for x,y in [(47,47),(56,48),(65,49),(73,48),(78,51),(59,45),(85,80),(94,84),(106,79),(77,86)]:
  a.ell((x-3,y-1,x+3,y+2),'metal0');a.ell((x-2,y-1,x+2,y+1),'metal2');a.line([(x-1,y-1),(x+1,y-1)],'metal4');a.rect((x,y,x+1,y),'metal3')
 a.poly([(66,41),(70,34),(76,36),(78,43),(74,48),(69,47)],'ink');a.poly([(68,41),(71,36),(74,37),(76,42),(73,46),(70,45)],'teal1');a.poly([(71,36),(71,43),(73,46),(68,41)],'teal2');a.line([(71,37),(73,39)],'teal4')
 # Engraved lock and ring pull.
 a.poly([(55,61),(59,59),(64,61),(64,69),(59,73),(55,69)],'ink');a.poly([(56,62),(59,61),(62,63),(62,68),(59,71),(56,68)],'metal2');a.rect((58,63,60,65),'metal4');a.rect((58,65,60,67),'metal0');a.line([(59,66),(59,69)],'metal0')
 # A folded parchment and a red wax seal next to the coffer.
 a.poly([(16,70),(29,67),(36,72),(34,81),(21,85),(15,81)],'ink');a.poly([(18,71),(28,69),(33,72),(31,79),(22,82),(17,79)],'stone4');a.line([(20,74),(28,72)],'metal2');a.line([(21,77),(27,75)],'metal2');a.ell((26,76,31,81),'red0');a.rect((28,77,29,79),'red2')
 a.grass(112,83);a.rock(19,86,7,4);return a.finish('reward')

if __name__=='__main__':
 names=['camp','relic','event','reward'];ims=[camp(),shrine(),event(),reward()]
 manifest={'title':'Ashen Oath original interlude vignettes','generator':'tools/generate_vignettes.py','authorship':'Original code-native pixel illustrations. No external or reference image pixels, external assets, AI image APIs, fonts, or copied source-game artwork.','logical_size':[128,96],'output_size':[256,192],'pixel_scale':2,'filter':'nearest','transparency':'RGBA; transparent canvas with opaque authored clusters.','art_direction':'Muted stone, worn cloth, dark leather, brass, and restrained ember/teal highlights.','assets':[]}
 for n,im in zip(names,ims):
  p=OUT/(n+'.png');bbox=im.getchannel('A').getbbox()
  assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<256 and bbox[3]<192,(n,bbox)
  manifest['assets'].append({'file':n+'.png','size':[256,192],'alpha_bbox':list(bbox),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size})
 (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 # Actual-asset review with nearest 2x display and alternating dark checks.
 sheet=Image.new('RGB',(1048,430),'#171c23');d=ImageDraw.Draw(sheet)
 for i,(n,im) in enumerate(zip(names,ims)):
  x=12+i*260;d.text((x+8,10),n.upper(),fill='#c7ba92')
  for yy in range(34,418,16):
   for xx in range(x,x+256,16):d.rectangle((xx,yy,xx+15,yy+15),fill='#242c32' if ((xx-x)//16+yy//16)%2 else '#20272c')
  # Show at native output resolution, then a zoomed material/detail crop.
  sheet.paste(im,(x,40),im);detail=im.crop((64,32,192,128)).resize((256,192),Image.Resampling.NEAREST);sheet.paste(detail,(x,226),detail)
 sheet.save(OUT/'review-contact.png',optimize=True)
 print(json.dumps(manifest,indent=2))
