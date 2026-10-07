from PIL import Image,ImageDraw
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'assets'/'ui';root.mkdir(exist_ok=True)
for name,edge,fill in [('normal',(122,119,103),(20,31,35)),('gold',(209,172,99),(38,43,42)),('hover',(113,174,165),(31,50,52)),('disabled',(69,77,76),(14,23,27))]:
 im=Image.new('RGBA',(32,32),(9,13,18,255));d=ImageDraw.Draw(im)
 d.rectangle((1,1,30,30),fill=(*edge,255));d.rectangle((3,3,28,28),fill=(46,51,49,255));d.rectangle((4,4,27,27),fill=(*fill,255))
 d.line((3,3,28,3),fill=tuple(min(255,x+30) for x in edge)+(255,));d.line((3,3,3,28),fill=tuple(min(255,x+12) for x in edge)+(255,));d.line((4,28,29,28),fill=(8,16,21,255))
 for x,y in [(1,1),(25,1),(1,25),(25,25)]:
  d.rectangle((x,y,x+5,y+5),fill=(14,20,23,255));d.rectangle((x+1,y+1,x+4,y+4),fill=(*edge,255));d.point((x+2,y+2),fill=(232,210,155,255))
 im.save(root/f'panel_{name}.png')
for name in ['slash','blunt','arcane','pierce','guard']:
 im=Image.new('RGBA',(20,20));d=ImageDraw.Draw(im);ink=(20,23,30);gold=(213,184,116);white=(218,231,217)
 if name=='slash':
  d.polygon([(4,15),(13,3),(17,1),(16,6),(7,17)],fill=white,outline=ink);d.line((3,12,9,18),fill=gold,width=3)
 elif name=='blunt':
  d.line((6,17,12,7),fill=gold,width=3);d.polygon([(7,2),(17,6),(14,12),(4,8)],fill=white,outline=ink)
 elif name=='arcane':
  d.polygon([(10,1),(18,10),(10,19),(2,10)],fill=(77,180,160),outline=ink);d.polygon([(10,4),(14,10),(10,16),(7,10)],fill=white)
 elif name=='pierce':
  d.line((3,17,15,5),fill=gold,width=2);d.polygon([(11,2),(18,1),(17,8)],fill=white,outline=ink);d.line((2,12,7,17),fill=white,width=2)
 else:
  d.polygon([(3,3),(10,1),(17,3),(16,12),(10,19),(4,12)],fill=(85,117,131),outline=ink);d.line((5,5,10,3,15,5),fill=white,width=2);d.line((10,4,10,15),fill=gold,width=2)
 im.save(root/(name+'.png'))
