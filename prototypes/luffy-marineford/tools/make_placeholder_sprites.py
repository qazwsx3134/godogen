#!/usr/bin/env python3
"""Native-grid placeholders; rerun from any cwd:

uv run --with pillow prototypes/luffy-marineford/tools/make_placeholder_sprites.py

Draws each density on its own pixel grid, packs with the shared kit, validates
the resulting cells, and writes nearest-neighbour contact sheets. No AI assets.
"""
import importlib.util
import json
import sys
import tempfile
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
GAME = Path(__file__).resolve().parents[1]
DENSITIES = (("033", .033, 96), ("025", .025, 112), ("020", .02, 128))
OUTLINE = "#202433"
SKIN, SHADE = "#efb980", "#bd795d"
WHITE, COOL = "#f3eedc", "#9bafbd"
RED, DARK_RED = "#d94042", "#8f303f"
BLUE, DARK_BLUE = "#3979b1", "#29466b"
GOLD, STRAW = "#dbaa4f", "#f3d17b"


def draw_legacy(who, height, cell, direction, action, frame):
    """Canvas anchor stays fixed through poses; coordinates describe body height.

    Shapes are rasterized directly at target resolution. The final external
    contour is a four-neighbour, exactly one pixel dilation at every density.
    """
    im = Image.new("RGBA", (cell, cell))
    d = ImageDraw.Draw(im)
    top, ground = cell - 4 - height + 1, cell - 6
    span = ground - top
    cx = cell // 2
    side = (0, .5, 1, .5, 0)[direction]
    back = direction >= 3
    bulk = 1.28 if who == "vice_admiral" else 1
    phase = (.35, 1, -.35, -1)[frame] if action == "walk" else 0
    recoil = -.035 if action == "hit" else 0

    def p(x, y):
        return (round(cx + (x + recoil * (1-y)) * span), round(top + y * span))

    def poly(points, color):
        d.polygon([p(x, y) for x, y in points], fill=color)

    def ellipse(x1, y1, x2, y2, color):
        d.ellipse((*p(x1, y1), *p(x2, y2)), fill=color)

    def line(points, color, width=1):
        d.line([p(x, y) for x, y in points], fill=color, width=width)

    torso = .15 * bulk * (1 - .3 * side)
    # Far limbs first; leg swing changes silhouette without moving the anchor.
    for sign in (-1, 1):
        x = sign * (.085 - .04 * side)
        step = sign * phase * .065
        boot = DARK_BLUE if who != "luffy" else SHADE
        leg = SKIN if who == "luffy" else COOL
        poly([(x-.045, .68), (x+.045, .68),
              (x+.045+step, .94), (x-.045+step, .94)], leg)
        poly([(x-.05+step, .93), (x+.065+step+side*.035, .93),
              (x+.075+step+side*.035, 1), (x-.055+step, 1)], boot)
        if who == "luffy":
            line([(x-.04+step, .955), (x+.055+step, .955)], GOLD)
    if who == "vice_admiral":
        poly([(-.23, .31), (.23, .31), (.29, .87), (.1, .9),
              (0, .81), (-.23, .9)], COOL)
        poly([(-.23, .31), (-.05, .35), (-.08, .87), (-.26, .87)], WHITE)
        poly([(.05, .35), (.23, .31), (.28, .87), (.1, .87)], WHITE)

    shirt = RED if who == "luffy" else WHITE
    poly([(-torso, .32), (torso, .32), (torso*.9, .7), (-torso*.9, .7)], shirt)
    poly([(torso*.45, .34), (torso, .34), (torso*.9, .7), (torso*.45, .7)],
         DARK_RED if who == "luffy" else COOL)
    if who == "luffy":
        poly([(-torso, .64), (torso, .64), (torso+.015, .77),
              (.025, .77), (0, .72), (-.025, .77), (-torso-.015, .77)], BLUE)
        if not back:
            poly([(-.04+side*.04, .32), (.04+side*.04, .32), (.025+side*.04, .6),
                  (-.025+side*.04, .6)], SKIN)
            for y in (.4, .5, .6):
                ellipse(-.07+side*.04, y, -.05+side*.04, y+.02, GOLD)
    elif not back:
        poly([(-torso, .32), (torso, .32), (.025, .46), (-.025, .46)], BLUE)
        poly([(-.025, .43), (.025, .43), (.04, .59), (0, .63)], DARK_BLUE)
        line([(0, .65), (0, .7)], GOLD)
    if who == "vice_admiral":
        for sign in (-1, 1):
            ellipse(sign*.19-.065, .31, sign*.19+.065, .37, GOLD)
        if back:
            # Stylized symmetric dark rank insignia, not rasterized font text.
            for y in (.43, .53):
                line([(-.08, y), (.08, y)], DARK_BLUE)
            line([(0, .4), (0, .62)], DARK_BLUE)
            line([(-.07, .46), (-.07, .61), (.08, .61)], DARK_BLUE)

    # Arms: short foreshortened punch in front/back, long extension at side.
    arm = SKIN if who == "luffy" else WHITE
    for sign in (-1, 1):
        x = sign * (torso + .035)
        swing = phase * sign * .045 + (frame * sign * .025 if action == "idle" else 0)
        poly([(x-.04, .36), (x+.04, .36), (x+.055+swing, .59),
              (x-.025+swing, .62)], arm)
        ellipse(x-.03+swing, .57, x+.055+swing, .66, SKIN)
    if action == "punch" and frame == 1:
        end = .2 + side*.36
        poly([(.07, .4), (end, .39), (end+.02, .47), (.08, .49)], SKIN)
        ellipse(end-.025, .37, end+.075, .49, SKIN)
        line([(end+.025, .395), (end+.025, .46)], SHADE)
    elif action == "punch":
        ellipse(.07, .37 if frame == 0 else .5, .2, .48 if frame == 0 else .61, SKIN)
    if action == "hit":
        line([(-.2, .46), (-.12, .4), (-.06, .5)], SHADE)

    # Distinct face / profile / back-of-head silhouettes.
    hx = side * .035
    ellipse(hx-.115, .12, hx+.115, .34, SKIN)
    if back:
        ellipse(hx-.12, .12, hx+.11, .31, OUTLINE)
        if direction == 3:
            poly([(.075, .2), (.145, .24), (.1, .29), (.07, .28)], SKIN)
    else:
        if side:
            poly([(.09, .2), (.17 if direction == 2 else .145, .245),
                  (.1, .27)], SKIN)
        if direction < 2:
            for eye in (-.045+side*.055, .055+side*.055):
                line([(eye, .225), (eye, .25)], OUTLINE)
            line([(-.025+side*.055, .285), (.04+side*.055, .285)], SHADE)
        else:
            line([(.09, .22), (.09, .245)], OUTLINE)
        if action == "hit":
            line([(.025, .215), (.075, .245), (.025, .26)], OUTLINE)
    if who == "luffy":
        if not back:
            poly([(-.12, .12), (.12, .12), (.09, .22), (.04, .18),
                  (0, .22), (-.05, .18), (-.11, .23)], OUTLINE)
        ellipse(-.18+.025*side, 0, .18-.015*side, .18 if back else .14, GOLD)
        ellipse(-.14+.025*side, 0, .14-.015*side, .105, STRAW)
        poly([(-.14, .09), (.14, .09), (.14, .125), (-.14, .125)], RED)
        ellipse(-.235+.04*side, .115, .235-.02*side, .18, GOLD)
        line([(-.17, .135), (.15, .135)], STRAW)
    else:
        ellipse(-.13, 0, .13, .16, COOL)
        ellipse(-.125, 0, .105, .12, WHITE)
        poly([(-.13, .115), (.13, .115), (.13, .155), (-.13, .155)], BLUE)
        if not back:
            poly([(-.1+side*.1, .14), (.145+side*.065, .14),
                  (.16+side*.065, .18), (-.1+side*.1, .18)], WHITE)
            line([(.015, .055), (.04, .085), (.065, .055)], BLUE)
    return im


# Ordered catalog is also the manifest/reference-pose order. No external artwork.
# tuple: standing height in meters, tier, stored direction policy, action frame counts.
CAST = {
    "luffy": (1.8, 1, 8, "idle:2 walk:4 punch:3 gear2_walk:4 fall:2 down:1 getup:3 ride:2 hit:1"),
    "marine": (1.75, 1, 8, "walk:4 hit:1 attack:3 down:1"),
    "vice_admiral": (2.3, 1, 8, "walk:4 hit:1 attack:3 down:1"),
    "ace": (1.85, 1, 8, "idle:2 walk:4 attack:3 hit:1 down:1"),
    "jinbe": (3., 1, 8, "idle:2 walk:4 attack:3 hit:1"),
    "ivankov": (3.1, 1, 8, "idle:2 walk:4 attack:3 hit:1"),
    "marine_rifle": (1.75, 1, 8, "walk:4 attack:3 hit:1 down:1"),
    # Five stored rows must fit even at 345px body height: five frames in one shelf.
    "pacifista": (6.9, 1, 8, "walk:2 attack:2 hit:1"),
    "wb_pirate_a": (1.9, 1, 8, "idle:2 attack:3 hit:1"),
    "wb_pirate_b": (2.1, 1, 8, "idle:2 attack:3 hit:1"),
    "smoker": (2.1, 2, 8, "idle:2 walk:4 attack:3 smoke:2 hit:1"),
    "garp": (2.9, 2, 8, "idle:2 walk:4 block:2 hit:1 knocked:2"),
    "akainu": (3.05, 2, 8, "idle:2 walk:4 attack:3"),
    "crocodile": (2.5, 2, 8, "idle:2 walk:4 attack:3"),
    "whitebeard": (6.7, 3, 1, "idle:2 quake:3 slash:3"),
    "aokiji": (3., 3, 1, "idle:2 attack:3"),
    "kizaru": (3., 3, 1, "idle:2 attack:3"),
    "hancock": (1.9, 3, 1, "idle:2 kick:3"),
    "marco": (2., 3, 1, "idle:2 phoenix:3"),
    "coby": (1.7, 3, 1, "idle:2 hit:1 knocked:2"),
    "sengoku_buddha": (9., 3, 1, "idle:2 strike:3"),
    "executioner": (2., 3, 1, "idle:2 raise:3 down:1"),
    "ace_chained": (1.85, 3, 1, "kneel:2 struggle:2"),
    "giant": (18., 3, 1, "walk:2"),
}
HEIGHTS = {k: v[0] for k, v in CAST.items()}
LOOPS = {"idle", "walk", "gear2_walk", "ride", "smoke", "kneel", "struggle", "phoenix"}
NO_MIRROR = {"ace_chained", "sengoku_buddha", "giant"}
PORTRAITS = "luffy_shout luffy_resolve luffy_hurt ace garp whitebeard smoker hancock jinbe ivankov crocodile marco kizaru aokiji akainu sengoku coby".split()
# shirt, trousers, hair, skin; signature geometry is drawn separately below.
STYLES = {
    "ace": (SKIN, "#34394b", OUTLINE, SKIN),
    "ace_chained": (SKIN, "#34394b", OUTLINE, SKIN),
    "jinbe": ("#d99a43", "#323d7e", "#283b67", "#65abc1"),
    "ivankov": ("#993c9d", "#e3c8e8", "#563280", "#e8ad8b"),
    "marine_rifle": (WHITE, BLUE, BLUE, SKIN),
    "pacifista": ("#34394b", "#34394b", "#a8a9ac", SKIN),
    "wb_pirate_a": ("#459a8d", "#654b3c", "#ba713d", SKIN),
    "wb_pirate_b": ("#ae5083", "#44587d", "#e6b56d", SKIN),
    "smoker": (WHITE, "#55687c", WHITE, SKIN),
    "garp": (WHITE, COOL, "#b4bec7", SKIN),
    "akainu": ("#a2393b", "#6f353b", WHITE, SKIN),
    "crocodile": ("#5c7958", "#484347", OUTLINE, SKIN),
    "whitebeard": (SKIN, COOL, WHITE, SKIN),
    "aokiji": (WHITE, "#354d92", OUTLINE, "#bf8b6c"),
    "kizaru": ("#e1c453", "#b09443", "#443e3c", SKIN),
    "hancock": ("#b83b59", "#b83b59", OUTLINE, SKIN),
    "marco": ("#6466a9", "#293d6b", "#efcf69", SKIN),
    "coby": (WHITE, "#305980", "#e7a5c4", SKIN),
    "sengoku_buddha": (GOLD, STRAW, "#bd8438", STRAW),
    "giant": ("#45526e", "#303c55", "#303c55", "#68768d"),
    "executioner": ("#522f47", "#373844", OUTLINE, SKIN),
}


def actions(who):
    return {k: int(n) for k, n in (v.split(":") for v in CAST[who][3].split())}


def outline(im):
    """One four-neighbour texel, applied AFTER native-grid pose geometry."""
    alpha = im.getchannel("A")
    expanded = alpha.copy()
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        shifted = Image.new("L", im.size)
        shifted.paste(alpha, (dx, dy))
        expanded = ImageChops.lighter(expanded, shifted)
    result = Image.new("RGBA", im.size)
    result.paste(OUTLINE, (0, 0, *im.size), expanded)
    result.alpha_composite(im)
    return result


def draw_cast(who, height, cell, direction, action, frame):
    im = Image.new("RGBA", (cell, cell))
    d = ImageDraw.Draw(im)
    top, ground = cell-4-height+1, cell-6
    span = ground-top
    side = (0, .5, 1, .5, 0)[direction]
    back = direction >= 3
    shirt, pants, hair, skin = STYLES[who]
    phase = (.35, 1, -.35, -1)[frame] if action == "walk" else 0
    bulk = 1.7 if who in ("jinbe", "pacifista", "wb_pirate_b") else 1
    if who == "hancock":
        bulk = .8
    def p(x, y):
        return (round(cell/2+(x-(.04*(1-y) if action == "hit" else 0))*span), round(top+y*span))
    def poly(points, color):
        d.polygon([p(*v) for v in points], fill=color)
    def ell(box, color):
        d.ellipse((*p(*box[:2]), *p(*box[2:])), fill=color)
    def line(points, color, width=1):
        d.line([p(*v) for v in points], fill=color, width=width)
    # Walk, stance and silhouette are independently rasterized at each density.
    for sign in (-1, 1):
        x = sign*(.085-.035*side)
        step = sign*phase*.07
        poly([(x-.045,.62),(x+.045,.62),(x+.045+step,.95),(x-.045+step,.95)], pants)
        poly([(x-.05+step,.93),(x+.08+step,.93),(x+.085+step,1),(x-.05+step,1)], OUTLINE)
    coat = who in {"garp", "akainu", "aokiji", "kizaru", "smoker", "whitebeard"}
    if coat:
        poly([(-.2,.3),(.2,.3),(.27,.9),(.09,.88),(0,.7),(-.22,.9)], WHITE)
        line([(-.2,.32),(-.24,.85)], COOL, max(1, round(span*.025)))
        for sign in (-1, 1):
            ell((sign*.18-.06,.3,sign*.18+.06,.36), GOLD)
    half = .15*bulk*(1-.25*side)
    poly([(-half,.3),(half,.3),(half*.85,.72),(-half*.85,.72)], shirt)
    line([(half*.65,.35),(half*.65,.67)], COOL if shirt == WHITE else pants)
    if who == "hancock":
        poly([(-half,.6),(half,.6),(.23,.95),(-.23,.95)], shirt)
        for y in (.66,.78,.89):
            ell((-.09,y,-.04,y+.035),GOLD)
    if who == "crocodile":
        poly([(-.23,.29),(-.12,.28),(-.13,.78),(-.27,.83)], "#735744")
        poly([(.12,.28),(.23,.29),(.27,.83),(.13,.78)], "#735744")
        ell((-.29,.55,-.17,.72),GOLD)
    if who == "jinbe":
        for x in (-.14,.08):
            poly([(x,.42),(x+.06,.49),(x,.56),(x-.06,.49)],pants)
    if who == "pacifista":
        poly([(-.24,.31),(.24,.31),(.24,.68),(-.24,.68)],shirt)
        ell((-.07,.43,.07,.58),WHITE)
        line([(-.06,.5),(.06,.5)],OUTLINE)
        line([(0,.44),(0,.57)],OUTLINE)
    if who == "kizaru":
        for x in (-.1,-.04,.04,.1):
            line([(x,.34),(x,.69)],GOLD)
    # Change arm angles per pose. Right-facing attacks remain inside the square.
    for sign in (-1, 1):
        x = sign*(half+.025)
        swing = phase*sign*.04 + (frame*sign*.018 if action in {"idle","kneel"} else 0)
        endx, endy = x+swing,.62
        if action == "block":
            endx, endy = sign*(.39+frame*.025),.37+frame*.035
        elif action in {"attack","quake","slash","strike","raise","phoenix"} and sign == 1:
            endx, endy = ((.29,.43),(.39,.32),(.25,.55))[frame % 3]
            if action in {"strike","raise"}:
                endx, endy = .27+frame*.04,.26-frame*.07
        line([(x,.36),(endx,endy)],skin if who in {"ace","whitebeard","sengoku_buddha"} else shirt, max(2,round(span*.065)))
        ell((endx-.045,endy-.035,endx+.045,endy+.05),skin)
    # Heads: Ivankov's wide purple crown and Pacifista's small head are deliberate.
    hr = .18 if who == "ivankov" else (.085 if who == "pacifista" else .12)
    ell((-hr,.065,hr,.32),hair)
    ell((-hr*.78+side*.025,.13,hr*.84+side*.025,.32),skin)
    if back:
        ell((-hr,.08,hr*.95,.29),hair)
        if direction == 3:
            poly([(.075,.2),(.145,.24),(.09,.28)],skin)
    else:
        if side:
            poly([(.075,.2),(.15,.245),(.08,.27)],skin)
        for x in (-.045+side*.045,.05+side*.045):
            line([(x,.215),(x,.24)],OUTLINE)
        line([(-.025,.28),(.055,.28)],OUTLINE)
    # Every standing reference spans y=0..1; top details vary per character.
    if who in {"marine_rifle","akainu","pacifista"}:
        ell((-.14,0,.14,.13),hair if who == "pacifista" else WHITE)
        poly([(-.15,.1),(.19,.1),(.18,.145),(-.15,.145)],hair if who == "pacifista" else COOL)
    elif who == "ivankov":
        poly([(-.21,.13),(-.2,.025),(-.12,.05),(-.07,0),(0,.04),(.1,0),(.17,.03),(.22,.13)],hair)
        if not back:
            line([(-.1,.18),(-.035,.2)],"#5675c2",max(1,round(span*.025)))
            line([(.03,.18),(.1,.2)],"#5675c2",max(1,round(span*.025)))
            ell((-.05,.255,.08,.3),"#b83b59")
            if action == "attack":
                line([(.025,.21),(.1,.23),(.025,.245)],OUTLINE)
    elif who == "whitebeard":
        ell((-.14,0,.14,.1),OUTLINE)
    elif who == "sengoku_buddha":
        for x in (-.12,-.06,0,.06,.12):
            ell((x-.035,0,x+.035,.09),hair)
        ell((-.145,.23,-.1,.31),GOLD)
        ell((.1,.23,.145,.31),GOLD)
    elif who == "executioner":
        poly([(-.13,.27),(-.12,.04),(0,0),(.12,.04),(.14,.28)],hair)
        if not back:
            line([(-.07,.2),(.08,.2)],WHITE)
    else:
        poly([(-hr,.17),(-hr,.055),(-.06,.025),(-.02,0),(.035,.035),(.1,.015),(hr,.12)],hair)
    if who == "whitebeard" and not back:
        poly([(-.17,.23),(-.14,.29),(0,.32),(.15,.27),(.19,.2),(.12,.25),(0,.27),(-.11,.26)],WHITE)
    if who == "garp" and not back:
        poly([(-.08,.27),(0,.3),(.09,.26),(.06,.33),(-.05,.33)],hair)
    if who == "jinbe" and not back:
        for x in (-.07,.07):
            poly([(x-.025,.31),(x,.255),(x+.025,.31)],WHITE)
    if who == "marco":
        poly([(-.06,.07),(-.08,0),(.035,.02),(.1,.11)],hair)
    if who in {"smoker","crocodile"} and not back:
        line([(.06,.275),(.18,.29)],GOLD, max(1,round(span*.018)))
        ell((.16,.26,.2,.3),COOL)
    if who in {"aokiji","kizaru","coby"} and not back:
        line([(-.075,.205),(.1,.205)],BLUE if who != "kizaru" else GOLD,max(1,round(span*.025)))
    # Readable native-grid signature props and attack silhouettes.
    if who == "marine_rifle":
        y = .41 if action == "attack" else .58
        line([(-.09,y+.08),(.39,y)],"#735744",max(2,round(span*.045)))
        line([(.24,y+.025),(.45,y-.012)],OUTLINE,max(1,round(span*.025)))
        if action == "attack" and frame == 1:
            poly([(.45,y),(.48,y-.06),(.5,y),(.48,y+.045)],GOLD)
    if action in {"attack","slash","raise"}:
        if who in {"smoker","whitebeard","executioner"}:
            xx = .29 + .025*frame
            line([(xx,.83),(xx,.12 if frame == 0 else .025)],GOLD,max(1,round(span*.018)))
            poly([(xx,.18),(xx+.075,.07),(xx+.05,.33),(xx,.4)],WHITE)
            if who == "smoker":
                line([(xx-.06,.3),(xx-.06,.43),(xx,.43)],COOL)
        if who in {"ace","akainu","crocodile","aokiji","kizaru"}:
            color = {"ace":"#f3a340","akainu":"#e85735","crocodile":"#cfb77b","aokiji":"#8ed7e5","kizaru":STRAW}[who]
            reach = (.29,.47,.35)[frame]
            poly([(.22,.45),(.28,.33),(reach,.3),(.4,.4),(reach,.5),(.29,.53)],color)
            if frame == 1:
                line([(.29,.41),(.44,.39)],WHITE)
        if who in {"wb_pirate_a","wb_pirate_b"}:
            line([(.2,.58),(.4,.18+frame*.07)],COOL,max(1,round(span*.035)))
    if who == "pacifista" and action == "attack":
        ell((.025,.25,.105,.31),OUTLINE)
        if frame == 1:
            line([(.08,.28),(.48,.27)],STRAW,max(2,round(span*.024)))
            line([(.1,.28),(.48,.28)],WHITE)
    if action == "quake":
        for x,y in ((.31,.3),(.38,.23),(.42,.35)):
            line([(x-.03,y-.06),(x+.015,y),(x-.025,y+.05)],WHITE)
    if action == "phoenix":
        for sign in (-1,1):
            poly([(sign*.12,.4),(sign*.4,.18+frame*.035),(sign*.45,.38),(sign*.31,.46),(sign*.42,.56),(sign*.14,.62)],"#45bad3")
            line([(sign*.18,.45),(sign*.38,.34+frame*.03)],WHITE)
    if action == "smoke":
        # Replace the legs with curling smoke, without shifting the foot anchor.
        d.rectangle((0,p(0,.64)[1],cell,cell),fill=(0,0,0,0))
        for i in range(5):
            y=.64+i*.065
            x=math.sin(i+frame*1.7)*.09
            ell((x-.11,y,x+.11,min(1.,y+.1)),WHITE if i%2 else COOL)
    if action == "kick" and frame != 0:
        # Remove resting legs; one planted leg and one extended high leg.
        d.rectangle((0,p(0,.72)[1],cell,cell),fill=(0,0,0,0))
        line([(-.07,.7),(-.08,.98)],skin,max(2,round(span*.06)))
        line([(-.1,.98),(.02,.98)],OUTLINE,max(1,round(span*.025)))
        line([(.06,.66),(.43,.45+frame*.06)],skin,max(2,round(span*.07)))
        line([(.41,.45+frame*.06),(.48,.43+frame*.06)],OUTLINE,max(1,round(span*.035)))
    return im


def pose(im, height, cell, action, frame):
    """Pose transforms act on unoutlined native rasters, with a stable canvas foot."""
    ground=cell-6
    if action == "down" or (action == "getup" and frame == 0):
        box=im.getbbox()
        body=im.crop(box).transpose(Image.Transpose.ROTATE_90)
        # Full body keeps its native dimensions; only its orientation changes.
        result=Image.new("RGBA", im.size)
        result.paste(body,((cell-body.width)//2,ground-body.height+1))
        return result
    if action in {"ride","kneel","struggle"} or (action == "getup" and frame == 1):
        # A kneel folds the legs; upper body stays at original pixel scale.
        box=im.getbbox(); top=box[1]; span=height-3
        cut=round(top+.67*span)
        upper=im.crop((0,top,cell,cut))
        target_h=round(height*.5)-2 if action in {"kneel","struggle"} else round(height*.65)-2
        upper=upper.crop((0,0,cell,min(upper.height,target_h-3)))
        result=Image.new("RGBA",im.size)
        dy=ground-target_h+1+(1 if frame else 0)
        result.paste(upper,(0,dy))
        d=ImageDraw.Draw(result)
        w=max(4,round(height*.23))
        pants=BLUE if action == "ride" else "#34394b"
        d.rectangle((cell//2-w,ground-4,cell//2+w,ground),fill=pants)
        # Closed chain and anchored cuffs are visible in both chained poses.
        if action in {"kneel","struggle"}:
            yy=ground-round(target_h*.36)
            dx=round(height*(.17 if frame else .13))
            d.line([(cell//2-dx,yy),(cell//2,yy+3),(cell//2+dx,yy)],fill=COOL,width=1)
            for x in (cell//2-dx,cell//2+dx):
                d.rectangle((x-1,yy-1,x+1,yy+1),fill=COOL)
        return result
    if action == "knocked":
        body=im.crop(im.getbbox()).rotate(25+frame*25,resample=Image.Resampling.NEAREST,expand=True)
        if body.width > cell-4:
            # Never rescale a pose; rotate less if the canvas cannot contain it.
            body=im.crop(im.getbbox()).transpose(Image.Transpose.ROTATE_90)
        result=Image.new("RGBA",im.size)
        result.paste(body,((cell-body.width)//2,max(2,ground-body.height-3-frame*2)))
        return result
    if action == "fall":
        # Raised arms and bent, separated knees; descent changes canvas offset.
        box=im.getbbox();d=ImageDraw.Draw(im)
        y=box[1]+round(height*.25)
        d.line([(cell//2-round(height*.18),y+8),(cell//2-round(height*.28),y)],fill=SKIN,width=max(2,round(height*.07)))
        d.line([(cell//2+round(height*.18),y+8),(cell//2+round(height*.28),y)],fill=SKIN,width=max(2,round(height*.07)))
        result=Image.new("RGBA",im.size)
        result.paste(im,(0,-(4-frame*3)))
        return result
    return im


def draw_frame(who, height, cell, direction, action, frame):
    if who in {"luffy","marine","vice_admiral"}:
        base_action="walk" if action == "gear2_walk" else action
        im=draw_legacy(who,height,cell,direction,base_action,frame)
        d=ImageDraw.Draw(im)
        if action == "gear2_walk":
            # Palette replacement on the new native raster, no scaling or blur.
            skin=Image.new("RGBA",(1,1),SKIN).getpixel((0,0))
            im.putdata([(237,130,123,255) if c == skin else c for c in im.getdata()])
            d=ImageDraw.Draw(im)
            for i in range(3):
                x=cell//2+round(height*((-.28,.26,-.24)[i]))
                y=cell-7-round(height*(.25+i*.22))-(frame%2)*2
                d.line([(x,y),(x+(2 if frame%2 else -2),y-3),(x,y-5)],fill=WHITE,width=1)
        if action == "attack":
            x=cell//2+round(height*(.22+.035*frame))
            d.line([(x,cell-7-round(height*.35)),(x+round(height*.13),cell-7-round(height*(.85-.12*frame)))],fill=COOL,width=max(1,round(height*.035)))
            d.line([(x-2,cell-7-round(height*.35)),(x+3,cell-7-round(height*.35))],fill=GOLD,width=2)
    else:
        im=draw_cast(who,height,cell,direction,action,frame)
    return outline(pose(im,height,cell,action,frame))


def layout(names, cell):
    """Simulate kit shelf packing; choose smallest <=2048 atlas, no hidden shrink."""
    best=None
    for columns in range(max(max(actions(n).values()) for n in names),2048//cell+1):
        x=y=shelf=0
        for name in names:
            rows=5 if CAST[name][2] == 8 else 1
            for n in actions(name).values():
                if x+n > columns:
                    x,y,shelf=0,y+shelf,0
                x+=n;shelf=max(shelf,rows)
        rows=y+shelf
        if rows*cell <=2048:
            candidate=(columns*rows,columns,rows)
            if best is None or candidate < best:
                best=candidate
    return None if best is None else best[1:]


def groups(density, legacy_cell):
    result=[("sheets",["luffy","marine","vice_admiral"],legacy_cell)]
    special={"pacifista","whitebeard","sengoku_buddha","giant"}
    for kind in (8,1):
        group=[];number=1
        for who in CAST:
            if who in result[0][1] or who in special or CAST[who][2] != kind:
                continue
            trial=group+[who]
            cell=math.ceil((max(round(HEIGHTS[n]/density) for n in trial)+16)/16)*16
            if layout(trial,cell) is None:
                oldcell=math.ceil((max(round(HEIGHTS[n]/density) for n in group)+16)/16)*16
                result.append((f"cast_{kind}dir_{number}",group,oldcell))
                group=[who];number+=1
            else:
                group=trial
        if group:
            cell=math.ceil((max(round(HEIGHTS[n]/density) for n in group)+16)/16)*16
            result.append((f"cast_{kind}dir_{number}",group,cell))
    for who in CAST:
        if who in special:
            cell=math.ceil((round(HEIGHTS[who]/density)+16)/16)*16
            result.append((who,[who],cell))
    return result


def validate(data, manifest, atlas):
    cell, columns, foot = data["cell_px"], data["columns"], data["foot_px"]
    assert max(atlas.size) <= 2048
    assert data["meters_per_px"] == manifest["meters_per_px"]
    count=0
    for who,ch in data["characters"].items():
        colors=set()
        for action,anim in ch["anims"].items():
            rows=[]
            for row in range(5 if ch["directions"] == 8 else 1):
                frames=[]
                for frame in range(anim["n"]):
                    index=anim["cell"]+row*columns+frame
                    x,y=index%columns*cell,index//columns*cell
                    image=atlas.crop((x,y,x+cell,y+cell));box=image.getbbox()
                    assert box and box[0]>=1 and box[1]>=1 and box[2]<=cell-1 and box[3]<=cell-foot,(who,action,box,cell)
                    assert set(image.getchannel("A").getdata()) <= {0,255}
                    colors.update(c for c in image.getdata() if c[3])
                    if action == next(iter(ch["anims"])) and row == frame == 0:
                        assert box[3]-box[1] == manifest["characters"][who]["height_px"],(who,box,manifest["characters"][who]["height_px"])
                    frames.append(image.tobytes());count+=1
                if anim["n"]>1:
                    assert len(set(frames)) == anim["n"],(who,action,"duplicate frames")
                rows.append(frames[0])
            # A horizontal fallen silhouette may be symmetric; upright views must differ.
            if ch["directions"]==8 and action not in {"down","getup","ride"}:
                assert len(set(rows))==5,(who,action,"duplicate directions")
        assert len(colors)<=16,(who,len(colors))
    return count


def portrait(identifier):
    """Native 96px busts, distinct silhouettes and expressions, binary alpha."""
    who="luffy" if identifier.startswith("luffy_") else identifier
    if who == "sengoku": who="sengoku_buddha"
    # Draw an unoutlined native head/upper body at 220px body height. Crop to bust
    # without resampling: each portrait pixel was drawn directly at its final size.
    raw=draw_legacy(who,220,256,0,"idle",0) if who=="luffy" else draw_cast(who,220,256,0,"idle",0)
    box=raw.getbbox(); top=box[1]
    im=Image.new("RGBA",(96,96))
    # Head center at x=48; chest continues beyond the bottom edge like a bust.
    crop=raw.crop((80,top,176,top+96))
    im.paste(crop,(0,2))
    d=ImageDraw.Draw(im)
    if identifier.startswith("luffy_"):
        if identifier=="luffy_shout":
            d.ellipse((40,60,57,76),fill=OUTLINE);d.rectangle((43,61,54,65),fill=WHITE)
            d.line([(34,46),(41,49)],fill=OUTLINE,width=2)
        elif identifier=="luffy_resolve":
            d.line([(34,46),(42,49)],fill=OUTLINE,width=2)
            d.line([(53,49),(62,45)],fill=OUTLINE,width=2)
            d.line([(43,65),(57,65)],fill=OUTLINE,width=1)
        else:
            d.line([(33,48),(41,53),(33,56)],fill=OUTLINE,width=2)
            d.line([(54,48),(62,53),(54,56)],fill=OUTLINE,width=2)
            d.line([(29,62),(35,68),(29,71)],fill=RED,width=2)
            d.line([(43,69),(52,65),(59,70)],fill=OUTLINE,width=1)
    # Leave one clear texel on the sides and bottom for the external contour.
    d.rectangle((0,0,0,95),fill=(0,0,0,0));d.rectangle((95,0,95,95),fill=(0,0,0,0))
    d.rectangle((0,94,95,95),fill=(0,0,0,0))
    result=outline(im)
    # Same deterministic <=16-color policy as sprite packing.
    alpha=result.getchannel("A")
    result=result.convert("RGB").quantize(colors=16,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).convert("RGBA")
    result.putalpha(alpha)
    assert result.size==(96,96) and result.getbbox() and 0 in alpha.getdata()
    return result


def main():
    sys.dont_write_bytecode=True
    spec=importlib.util.spec_from_file_location("sprite_atlas",ROOT/"prototypes/godot-kit/tools/sprite_atlas.py")
    kit=importlib.util.module_from_spec(spec);spec.loader.exec_module(kit)
    source_root=GAME/"art_src/placeholder"
    source_root.mkdir(parents=True,exist_ok=True)
    (source_root/".gdignore").write_text("# Native source strips; runtime uses assets/sprites.\n")
    preview=Image.new("RGB",(3*720,6*210+70),"#d4dce3");pd=ImageDraw.Draw(preview)
    for di,(tag,density,legacy_cell) in enumerate(DENSITIES):
        index={"characters":{}};total=0
        pd.text((di*720+12,12),f"density_{tag} | {density} m/px | native pixels; thumbnails fit 160px",fill=OUTLINE)
        for group,names,cell in groups(density,legacy_cell):
            planned=layout(names,cell)
            assert planned is not None,(tag,group,cell)
            columns,rows=planned
            source=source_root/f"density_{tag}"/group;source.mkdir(parents=True,exist_ok=True)
            manifest={"cell_px":cell,"columns":columns,"foot_px":4,"meters_per_px":density,"pixel":{"colors":16},"characters":{}}
            for who in names:
                height=round(HEIGHTS[who]/density)
                # Packer scales from reference: use the explicit half-height kneel,
                # while index.height_m remains the actor's standing world height.
                reference=round(height*.5) if who=="ace_chained" else height
                ch={"height_px":reference,"directions":CAST[who][2],"mirror":who not in NO_MIRROR,"align":"canvas","foot_y":cell-4,"anims":{}}
                for action,n in actions(who).items():
                    strip=Image.new("RGBA",(cell*n,cell*(5 if ch["directions"]==8 else 1)))
                    for row in range(strip.height//cell):
                        direction=row if ch["directions"]==8 else 2
                        for frame in range(n):
                            strip.paste(draw_frame(who,height,cell,direction,action,frame),(frame*cell,row*cell))
                    filename=f"{who}_{action}.png";strip.save(source/filename)
                    ticks=([30]*n if action in {"idle","kneel"} else [8]*n)
                    ch["anims"][action]={"d":ticks,"loop":action in LOOPS,"sheet":{"file":filename,"fw":cell,"fh":cell}}
                manifest["characters"][who]=ch
            path=source/"manifest.json";path.write_text(json.dumps(manifest,indent=2)+"\n")
            out=GAME/"assets/sprites"/f"density_{tag}";out.mkdir(parents=True,exist_ok=True)
            with tempfile.TemporaryDirectory(prefix="luffy-placeholder-") as tmp:
                data=kit.build(path,Path(tmp))
                atlas=Image.open(Path(tmp)/"atlas.png").convert("RGBA")
                total+=validate(data,manifest,atlas)
                data["atlas"]="atlas.png" if group=="sheets" else group+".png"
                atlas.save(out/data["atlas"])
            (out/(group+".json")).write_text(json.dumps(data,indent=2)+"\n")
            for who in names:
                entry={"sheet":group+".json","height_m":HEIGHTS[who],"tier":CAST[who][1]}
                if who=="ace_chained": entry["pose_height_m"]=.925
                index["characters"][who]=entry
                a=next(iter(data["characters"][who]["anims"].values()));i=a["cell"]
                tile=atlas.crop((i%columns*cell,i//columns*cell,(i%columns+1)*cell,(i//columns+1)*cell))
                tile=tile.crop(tile.getbbox())
                factor=min(2.,160/tile.width,160/tile.height)
                thumb=tile.resize((round(tile.width*factor),round(tile.height*factor)),Image.Resampling.NEAREST)
                ci=list(CAST).index(who);xx=di*720+(ci%4)*180;yy=50+(ci//4)*210
                preview.paste(thumb,(xx+(180-thumb.width)//2,yy+160-thumb.height),thumb)
                pd.text((xx+6,yy+164),who,fill=OUTLINE)
                pd.text((xx+6,yy+180),f"{manifest['characters'][who]['height_px']}px / {HEIGHTS[who]}m",fill=OUTLINE)
            print(f"density_{tag}/{group}.json: {atlas.width}x{atlas.height}, cell={cell}, {', '.join(names)}",flush=True)
        assert set(index["characters"])==set(CAST)
        (out/"index.json").write_text(json.dumps(index,indent=2)+"\n")
        print(f"density_{tag}: PASS {total} occupied cells",flush=True)
    portraits=GAME/"assets/portraits";portraits.mkdir(parents=True,exist_ok=True)
    for identifier in PORTRAITS:
        portrait(identifier).save(portraits/(identifier+".png"))
    preview_path=ROOT/".claude/tasks/luffy-acts/placeholders-preview.png"
    preview.save(preview_path)
    # Review aids live with source art and are excluded from game imports.
    busts=Image.new("RGB",(6*160,3*140),"#b4c2cf")
    bd=ImageDraw.Draw(busts)
    for i,identifier in enumerate(PORTRAITS):
        tile=Image.open(portraits/(identifier+".png")).convert("RGBA")
        xx,yy=(i%6)*160,(i//6)*140
        busts.paste(tile,(xx+32,yy+4),tile)
        bd.text((xx+6,yy+110),identifier,fill=OUTLINE)
    busts.save(source_root/"portraits-preview.png")
    selected=[("luffy","gear2_walk"),("luffy","fall"),("luffy","down"),("luffy","getup"),("luffy","ride"),("ace","attack"),
              ("jinbe","attack"),("ivankov","attack"),("marine","attack"),("marine_rifle","attack"),("pacifista","attack"),("smoker","smoke"),
              ("garp","block"),("garp","knocked"),("akainu","attack"),("crocodile","attack"),("whitebeard","quake"),("whitebeard","slash"),
              ("aokiji","attack"),("hancock","kick"),("marco","phoenix"),("executioner","raise"),("sengoku_buddha","strike"),("ace_chained","struggle")]
    poses=Image.new("RGB",(6*200,4*210),"#b4c2cf");qd=ImageDraw.Draw(poses)
    base=GAME/"assets/sprites/density_020"
    idx=json.loads((base/"index.json").read_text())["characters"]
    for i,(who,action) in enumerate(selected):
        data=json.loads((base/idx[who]["sheet"]).read_text())
        anim=data["characters"][who]["anims"][action]
        cell=data["cell_px"];cols=data["columns"]
        row=2 if data["characters"][who]["directions"]==8 else 0
        n=anim["cell"]+row*cols+min(1,anim["n"]-1)
        atlas=Image.open(base/data["atlas"]).convert("RGBA")
        tile=atlas.crop((n%cols*cell,n//cols*cell,(n%cols+1)*cell,(n//cols+1)*cell))
        tile=tile.crop(tile.getbbox());factor=min(2.,180/tile.width,160/tile.height)
        tile=tile.resize((round(tile.width*factor),round(tile.height*factor)),Image.Resampling.NEAREST)
        xx,yy=(i%6)*200,(i//6)*210
        poses.paste(tile,(xx+(200-tile.width)//2,yy+160-tile.height),tile)
        qd.text((xx+8,yy+165),who+" / "+action,fill=OUTLINE)
    poses.save(source_root/"actions-preview.png")
    print(f"PASS: 24 actors x 3 densities, 17 portraits; binary alpha, borders, reference heights, distinct poses, <=16 colors.\nPreview: {preview_path}")


if __name__ == "__main__":
    main()
