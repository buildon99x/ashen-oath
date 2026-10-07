"""Original, authored pixel rigs. No third-party image is read or mirrored.
Four separate camera-facing projections preserve anatomical right-hand weapons.
"""
from PIL import Image, ImageDraw
from pathlib import Path
import math,json,hashlib
OUT=Path(__file__).resolve().parents[1]/'assets'/'heroes';OUT.mkdir(parents=True,exist_ok=True)
SIZE=(96,112); ANCHOR=(48,101); DIRECTIONS=['down','left','right','up']
STATES={'idle':(6,6,True),'walk':(8,10,True),'attack':(8,12,False),'hurt':(3,10,False),'death':(6,8,False)}
INK=(30,27,36,255); DARK=(43,39,48,255); GOLD=(181,135,70,255); GOLDHI=(236,202,124,255); SKIN=(201,144,106,255); SKINHI=(245,199,146,255)
PALE=(231,227,202,255); METAL=(121,140,146,255); SHADOW=(63,77,91,255); LIGHT=(190,204,201,255)
PALETTES=[{'cloth':(111,42,51,255),'hi':(170,71,66,255),'shade':(66,30,46,255),'trim':GOLD,'hair':(88,49,37,255)}, {'cloth':(38,91,96,255),'hi':(64,143,143,255),'shade':(30,53,68,255),'trim':(186,174,125,255),'hair':(205,187,139,255)}, {'cloth':(81,49,104,255),'hi':(132,83,140,255),'shade':(43,30,65,255),'trim':(166,153,183,255),'hair':(48,36,61,255)}]

def pixel_art(hero,direction,state,frame):
    im=Image.new('RGBA',SIZE); d=ImageDraw.Draw(im); p=PALETTES[hero]
    side=direction in ['left','right']; sx=1 if direction=='right' else -1
    back=direction=='up'; front=direction=='down'
    cycle=frame*math.tau/(STATES[state][0] if state in ['idle','walk'] else 8)
    gait=math.sin(cycle) if state=='walk' else 0.0
    breath=[0,-1,-1,0,1,0][frame%6] if state=='idle' else (-1 if state=='walk' and frame%4 in [1,2] else 0)
    recoil=[-3,2,0][frame] if state=='hurt' else 0
    attack_phase=[0,-1,-2,2,4,2,1,0][frame] if state=='attack' else 0
    cx=48+(sx*attack_phase if side else 0)+recoil
    by=breath+(attack_phase//2 if front else -attack_phase//2 if back else 0)
    collapsed=state=='death' and frame>=3
    if state=='death': by+=min(frame*3,8)
    def poly(points,fill,outline=INK,width=2):d.polygon([(round(x),round(y)) for x,y in points],fill=fill,outline=outline,width=width)
    def line(points,fill,width=1):d.line([(round(x),round(y)) for x,y in points],fill=fill,width=width)
    def rect(box,fill,outline=None,width=1):d.rectangle(tuple(round(v) for v in box),fill=fill,outline=outline,width=width)
    def ellipse(box,fill,outline=None,width=1):d.ellipse(tuple(round(v) for v in box),fill=fill,outline=outline,width=width)
    def limb(a,b,width,fill,highlight):
        line([a,b],INK,width+4);line([a,b],fill,width);line([(a[0]-1,a[1]),(b[0]-1,b[1]-1)],highlight,max(1,width//3))
    def blade(hand,tip,length=1):
        hx,hy=hand;tx,ty=tip;vx=tx-hx;vy=ty-hy;ln=max(1,math.hypot(vx,vy));nx=-vy/ln;ny=vx/ln
        poly([(hx+nx*3,hy+ny*3),(tx+nx*2,ty+ny*2),(tx+vx/ln*4,ty+vy/ln*4),(tx-nx*2,ty-ny*2),(hx-nx*3,hy-ny*3)],LIGHT,INK,1)
        line([(hx,hy),(tx,ty)],PALE,2)
        line([(hx+nx*6,hy+ny*6),(hx-nx*6,hy-ny*6)],INK,5);line([(hx+nx*5,hy+ny*5),(hx-nx*5,hy-ny*5)],GOLD,2)
        line([(hx-vx/ln*2,hy-vy/ln*2),(hx-vx/ln*8,hy-vy/ln*8)],(87,58,44,255),3)
    if collapsed:
        t=frame-3; xx=cx+(sx*4 if side else (3 if front else -3))
        poly([(xx-24,91-t),(xx-10,78+t),(xx+16,84+t),(xx+27,96),(xx+13,101),(xx-19,101)],p['shade'])
        poly([(xx-17,91),(xx-6,84+t),(xx+14,89+t),(xx+18,97),(xx-12,97)],p['cloth'],p['cloth'],1)
        rect((xx-23,95,xx-10,101),SHADOW,INK);rect((xx-22,95,xx-13,97),LIGHT)
        headx=xx+(15 if direction in ['down','right'] else -15);heady=83+t*2
        ellipse((headx-11,heady-11,headx+11,heady+9),p['hair'],INK,2)
        if not back:ellipse((headx-7,heady-5,headx+7,heady+7),SKIN,INK);line([(headx-5,heady+1),(headx-1,heady+2)],INK);line([(headx+2,heady+2),(headx+6,heady+1)],INK)
        line([(xx+17,99),(xx+35,96)],GOLD,3);line([(xx+22,98),(xx+40,97)],LIGHT,2)
        rect((xx-4,87+t,xx+4,94+t),METAL,INK);return im
    # Separate legs: one support foot stays at the common ground anchor.
    for leg in [0,1]:
        sign=-1 if leg==0 else 1
        phase=gait*sign
        hipx=cx+sign*(5 if not side else 2)
        footx=cx+sign*7+(phase*7 if side else phase*2)
        footy=101-max(0,phase)*5 if state=='walk' else 101
        if state=='death':footx+=sign*frame*2
        knee=(hipx+sign*2+phase*(4 if side else 1),86+max(0,-phase)*2)
        limb((hipx,72+by),knee,8,p['shade'],p['cloth']);limb(knee,(footx,footy-6),7,SHADOW,METAL)
        poly([(footx-5,footy-10),(footx+4,footy-10),(footx+5,footy-3),(footx+7,footy),(footx-6,footy)],(65,54,52,255))
        rect((footx-4,footy-9,footx+3,footy-7),GOLD if hero==0 else p['trim']);line([(footx-4,footy-2),(footx+5,footy-2)],(135,123,104,255),2)
        if hero==0:poly([(knee[0]-5,knee[1]-5),(knee[0]+4,knee[1]-6),(knee[0]+5,knee[1]+3),(knee[0]-4,knee[1]+4)],METAL);line([(knee[0]-3,knee[1]-4),(knee[0]+2,knee[1]-4)],LIGHT,2)
    # Cloak follows a different silhouette in each camera-facing projection.
    sway=round(math.sin(cycle)*2) if state in ['idle','walk'] else -attack_phase
    if side:
        cape_x=cx-sx*9
        poly([(cape_x,44+by),(cape_x-sx*11,54+by),(cape_x-sx*(15+sway),86),(cape_x-sx*4,92),(cx+sx*3,75+by)],p['shade'])
        poly([(cape_x,48+by),(cape_x-sx*7,57+by),(cape_x-sx*(10+sway),83),(cape_x-sx*4,87)],p['cloth'],p['cloth'],1)
        line([(cape_x-sx*4,55+by),(cape_x-sx*(8+sway),81)],p['hi'],2)
    else:
        poly([(cx-14,44+by),(cx+15,44+by),(cx+21+sway,85),(cx+8,92),(cx,86),(cx-15+sway,91),(cx-21,81)],p['shade'])
        poly([(cx-11,48+by),(cx+11,48+by),(cx+15+sway,83),(cx+5,87),(cx-1,82),(cx-12+sway,86)],p['cloth'],p['cloth'],1)
        for x in [-9,0,9]:line([(cx+x,54+by),(cx+x+sway,81)],p['hi'] if x<0 else p['shade'],2)
    # Anatomical right arm holds the weapon; camera-left/right are never image flips.
    arm_defs={'down':((-15,53),(-18,69),(14,53),(15,70)), 'up':((14,51),(18,65),(-13,52),(-16,65)), 'right':((6,53),(13,68),(-7,51),(-10,64)), 'left':((-7,51),(-12,64),(6,54),(11,70))}
    ra,rh,la,lh=arm_defs[direction]
    right_sh=(cx+ra[0],ra[1]+by);left_sh=(cx+la[0],la[1]+by)
    hand=(cx+rh[0]+(attack_phase*sx if side else 0),rh[1]+by-abs(attack_phase))
    offhand=(cx+lh[0]-round(gait*3),lh[1]+by)
    def right_arm():
        limb(right_sh,hand,8,METAL if hero==0 else p['cloth'],LIGHT if hero==0 else p['hi']);ellipse((hand[0]-4,hand[1]-3,hand[0]+4,hand[1]+4),SKINHI,INK)
        # Red wrist wrap remains on anatomical right in all four views.
        line([(hand[0]-4,hand[1]-5),(hand[0]+3,hand[1]-5)],(177,70,62,255),3)
    def left_arm():
        limb(left_sh,offhand,8,METAL if hero==0 else p['cloth'],LIGHT if hero==0 else p['hi']);ellipse((offhand[0]-4,offhand[1]-3,offhand[0]+4,offhand[1]+4),SKIN,INK)
        if hero==1:
            poly([(offhand[0]-7,offhand[1]-2),(offhand[0]+6,offhand[1]-5),(offhand[0]+7,offhand[1]+7),(offhand[0]-6,offhand[1]+9)],(108,61,53,255));line([(offhand[0]-4,offhand[1]),(offhand[0]+3,offhand[1]-2),(offhand[0]+4,offhand[1]+5)],PALE,2)
    if direction in ['left','up']:right_arm()
    else:left_arm()
    # Torso: layered cuirass/cloth, belt, separate lit planes.
    tw=10 if side else 14
    poly([(cx-tw,45+by),(cx+tw,45+by),(cx+tw+2,69+by),(cx+8,79+by),(cx-10,77+by),(cx-tw-2,65+by)],METAL if hero==0 else p['cloth'])
    if back:
        poly([(cx-11,47+by),(cx+11,47+by),(cx+12,70+by),(cx,78+by),(cx-12,70+by)],p['cloth']);line([(cx-8,51+by),(cx-5,70+by)],p['hi'],3)
        if hero==2:
            poly([(cx+3,39+by),(cx+12,41+by),(cx+5,74+by),(cx-4,72+by)],(99,71,49,255));line([(cx+5,41+by),(cx+11,26+by)],GOLD,2);line([(cx+8,42+by),(cx+15,30+by)],LIGHT,2)
    else:
        poly([(cx-tw+3,49+by),(cx+tw-4,49+by),(cx+tw-3,64+by),(cx-7,69+by),(cx-tw+3,61+by)],LIGHT if hero==0 else p['hi'],None,1)
        if hero==0:
            line([(cx-10,52+by),(cx+8,52+by)],PALE,2);line([(cx-6,56+by),(cx-5,66+by)],METAL,2);poly([(cx-4,55+by),(cx+3,55+by),(cx+1,62+by)],GOLDHI,INK,1)
        else:
            line([(cx-2,49+by),(cx-2,69+by)],p['shade'],2)
            for y in [52,58,64]:rect((cx+1,y+by,cx+2,y+1+by),GOLDHI)
    rect((cx-tw-1,70+by,cx+tw+1,75+by),(68,46,43,255),INK);rect((cx-2,70+by,cx+4,76+by),GOLD,INK);rect((cx,72+by,cx+2,74+by),GOLDHI)
    for x in [-8,8]:poly([(cx+x-3,76+by),(cx+x+3,76+by),(cx+x+4,85+by),(cx+x-3,85+by)],p['cloth']);line([(cx+x-2,83+by),(cx+x+2,83+by)],p['trim'],2)
    # Collar, and the deliberately asymmetric left-shoulder brooch.
    poly([(cx-14,43+by),(cx+10,41+by),(cx+15,49+by),(cx+3,55+by),(cx-12,50+by)],p['cloth']);line([(cx-11,45+by),(cx+8,44+by)],p['hi'],3)
    pinx=cx+(10 if front else -10 if back else -5 if direction=='right' else 6)
    ellipse((pinx-3,47+by,pinx+3,53+by),GOLDHI,INK);rect((pinx-1,49+by,pinx+1,51+by),(77,181,155,255))
    # Head has actual front, back and independent side drawings.
    hx=cx+(sx*2 if side else 0);hy=30+by
    if state=='hurt':hy+=1
    if hero==0:
        poly([(hx-14,hy-9),(hx-9,hy-17),(hx+5,hy-19),(hx+14,hy-10),(hx+15,hy+8),(hx+8,hy+16),(hx-8,hy+16),(hx-15,hy+7)],METAL)
        poly([(hx-11,hy-8),(hx-7,hy-15),(hx+3,hy-17),(hx+8,hy-10),(hx+4,hy-2),(hx-10,hy)],LIGHT,None,1)
        line([(hx-9,hy-9),(hx-6,hy-14),(hx+1,hy-15)],PALE,2)
        if back:
            poly([(hx-9,hy+1),(hx+10,hy-1),(hx+11,hy+11),(hx,hy+14),(hx-11,hy+10)],SHADOW);line([(hx,hy-15),(hx+1,hy+12)],GOLD,2)
        elif side:
            nose=hx+sx*13
            poly([(hx+sx*1,hy-2),(nose,hy-5),(nose+sx*4,hy+2),(nose,hy+7),(hx+sx*1,hy+9)],SHADOW)
            line([(hx+sx*4,hy+1),(hx+sx*13,hy)],GOLDHI,2);line([(hx-sx*7,hy-8),(hx-sx*8,hy+10)],GOLD,2)
        else:
            poly([(hx-11,hy),(hx+11,hy),(hx+10,hy+9),(hx,hy+13),(hx-10,hy+8)],SHADOW)
            line([(hx-8,hy+3),(hx+7,hy+3)],GOLDHI,2);rect((hx-1,hy+2,hx+1,hy+10),METAL)
        plume=2+round(math.sin(cycle)*2)
        poly([(hx-1,hy-19),(hx+4,hy-26),(hx+10+plume,hy-25),(hx+12+plume,hy-18),(hx+5,hy-16)],p['cloth']);line([(hx+4,hy-22),(hx+9+plume,hy-21)],p['hi'],2)
    else:
        hood=p['hair'] if hero==1 else p['cloth']
        poly([(hx-15,hy-7),(hx-10,hy-17),(hx+3,hy-20),(hx+14,hy-11),(hx+16,hy+9),(hx+9,hy+17),(hx-10,hy+16),(hx-17,hy+6)],hood)
        if back:
            poly([(hx-9,hy-10),(hx+1,hy-15),(hx+10,hy-8),(hx+9,hy+11),(hx-1,hy+13),(hx-11,hy+8)],p['trim'] if hero==1 else p['hi'],None,1)
            line([(hx-5,hy-8),(hx-2,hy+10)],(240,215,164,255) if hero==1 else p['cloth'],3)
            line([(hx+7,hy-5),(hx+5,hy+10)],p['shade'],2)
        else:
            faceoff=sx*4 if side else 0
            ellipse((hx-10+faceoff,hy-6,hx+9+faceoff,hy+13),SKIN,INK,1)
            poly([(hx-8+faceoff,hy-4),(hx+5+faceoff,hy-6),(hx+7+faceoff,hy+6),(hx-5+faceoff,hy+10)],SKINHI,None,1)
            if side:
                poly([(hx+sx*9,hy+1),(hx+sx*15,hy+4),(hx+sx*11,hy+7)],SKINHI,INK,1)
                eyex=hx+sx*7;rect((eyex-1,hy+1,eyex+1,hy+3),INK)
            else:
                for ex in [-5,5]:
                    if state=='hurt' or (state=='idle' and frame==4):line([(hx+ex-1,hy+3),(hx+ex+2,hy+3)],INK,1)
                    else:rect((hx+ex-1,hy+1,hx+ex+1,hy+4),INK);rect((hx+ex,hy+1,hx+ex,hy+1),PALE)
            line([(hx-1+faceoff,hy+10),(hx+3+faceoff,hy+10)],(116,67,65,255),1)
            # Raised hood rim prevents generic round-head silhouettes.
            line([(hx-13,hy+7),(hx-12,hy-7),(hx-5,hy-14),(hx+4,hy-14),(hx+12,hy-7)],p['trim'],3)
            if hero==1:poly([(hx-8+faceoff,hy+10),(hx+7+faceoff,hy+9),(hx+3+faceoff,hy+17),(hx-3+faceoff,hy+16)],(217,204,163,255),INK,1)
            else:poly([(hx-10,hy-5),(hx-6,hy-13),(hx+5,hy-13),(hx+10,hy-7),(hx+3,hy-4),(hx-2,hy-8)],p['hair'],None,1)
    if direction not in ['left','up']:right_arm()
    else:left_arm()
    # Weapons animate through wind-up, impact, and recovery, independently of the torso.
    if hero==1:
        staffx=hand[0]+(2 if direction in ['right','up'] else -2)
        tipy=max(26,29+by-abs(attack_phase)*2);tipx=max(18,min(78,staffx+(sx*attack_phase*3 if side else attack_phase)))
        line([(staffx,94),(tipx,tipy)],INK,5);line([(staffx-1,92),(tipx-1,tipy)],(154,114,61,255),3);line([(staffx-1,87),(tipx-1,tipy+8)],GOLDHI,1)
        ellipse((tipx-6,tipy-7,tipx+6,tipy+5),GOLD,INK);poly([(tipx-3,tipy),(tipx-5,tipy-10),(tipx,tipy-17-frame%3),(tipx+6,tipy-10),(tipx+3,tipy)],(92,213,184,255),None,1);poly([(tipx,tipy-3),(tipx-2,tipy-10),(tipx+1,tipy-14),(tipx+3,tipy-7)],(215,255,218,255),None,1)
        if state=='attack' and frame in [3,4,5]:
            for j in range(5):
                angle=j*1.8+frame;xx=tipx+math.cos(angle)*(10+frame);yy=tipy+math.sin(angle)*(7+frame)
                rect((xx,yy,xx+2,yy+2),(157,246,207,255))
    else:
        length=30 if hero==0 else 18
        if state=='attack':
            poses={'right':[(50,18),(36,13),(43,9),(80,22),(89,53),(78,74),(69,41),(64,31)],'left':[(46,19),(60,13),(53,9),(16,22),(7,53),(18,74),(27,41),(32,31)],'down':[(23,38),(15,22),(30,10),(69,24),(72,67),(52,89),(31,65),(22,40)],'up':[(75,45),(80,60),(65,74),(29,50),(24,14),(42,7),(69,26),(73,43)]}
            tip=poses[direction][frame]
            if hero==2:tip=(hand[0]+(tip[0]-hand[0])*.70,hand[1]+(tip[1]-hand[1])*.70)
        else:
            tip=(hand[0]+(12 if direction=='right' else -12 if direction=='left' else -10 if front else 10),hand[1]-length)
        blade(hand,tip)
    return im

manifest={'version':1,'frame_size':list(SIZE),'anchor':list(ANCHOR),'directions':DIRECTIONS,'state_order':list(STATES),'states':{k:{'frames':v[0],'fps':v[1],'loop':v[2]} for k,v in STATES.items()},'heroes':[],'equipment_hand':'anatomical right','mirror_used':False,'provenance':'Original authored Python pixel rigs. No reference image bytes or third-party asset files read.'}
for h,name in enumerate(['mara','ivo','sable']):
    atlas=Image.new('RGBA',(96*8,112*20));counts={};bad=[]
    for di,direction in enumerate(DIRECTIONS):
        for si,(state,(n,fps,loop)) in enumerate(STATES.items()):
            row=di*5+si;hashes=[]
            for f in range(n):
                im=pixel_art(h,direction,state,f);bbox=im.getbbox()
                if bbox is None or bbox[0]<1 or bbox[1]<1 or bbox[2]>95 or bbox[3]>103:bad.append((direction,state,f,bbox))
                atlas.alpha_composite(im,(f*96,row*112));hashes.append(hashlib.sha256(im.tobytes()).hexdigest())
            counts[f'{state}_{direction}']={'row':row,'frames':n,'unique_frames':len(set(hashes))}
    path=OUT/(name+'.png');atlas.save(path,optimize=True)
    manifest['heroes'].append({'id':name,'path':'res://assets/heroes/'+name+'.png','animations':counts,'edge_violations':bad,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
# Review contact sheet: each hero, four independent views, idle and attack impact.
review=Image.new('RGB',(96*4*3,112*2),(42,45,49));draw=ImageDraw.Draw(review)
for h in range(3):
 for di,direction in enumerate(DIRECTIONS):
  for row,(state,f) in enumerate([('idle',0),('attack',4)]):
   a=pixel_art(h,direction,state,f);x=h*384+di*96;y=row*112;review.paste(a,(x,y),a);draw.line((x+35,y+102,x+61,y+102),fill=(105,154,133))
review.save(OUT/'review-contact.png')
print(json.dumps({h['id']:{'edge_violations':h['edge_violations'],'unique_min':min(a['unique_frames'] for a in h['animations'].values())} for h in manifest['heroes']},indent=2))
