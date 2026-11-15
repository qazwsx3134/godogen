"""Central ray-shaped hull and the two continuous white forward yokes."""
import math

from boss_geometry import curved


def build_body(b):
    body = b.group('Body_Module')
    yokes = b.group('Forward_Yokes')
    b.section_loft('Hull_Continuous_Keel', [
        (0,-9.3,4.25,.35,.32), (0,-8.15,4.05,1.55,.85),
        (0,-6.3,4.0,3.15,1.25), (0,-3.8,4.0,4.75,1.50),
        (0,-.8,4.15,5.65,1.62), (0,2.0,4.38,5.45,1.57),
        (0,4.3,4.80,4.25,1.38), (0,6.1,5.15,2.4,1.07),
        (0,7.15,5.32,.70,.50)], b.blue, body, sides=20, smooth=True)
    b.section_loft('Hull_Dark_Underside', [
        (0,-7.8,3.65,.95,.45),(0,-5.4,3.38,3.10,.62),
        (0,-2.0,3.32,4.75,.69),(0,1.5,3.48,4.65,.67),
        (0,4.5,3.86,3.45,.56),(0,6.2,4.42,1.7,.42)],
        b.frame, body, sides=16, smooth=True)
    # Recess under the cannon: an elongated dark, layered central dish.
    b.section_loft('Crown_Recess_Core', [
        (0,-6.4,5.20,.38,.12),(0,-4.5,5.42,1.55,.13),
        (0,-2.0,5.76,2.45,.13),(0,.5,6.08,2.48,.13),
        (0,2.75,6.35,1.75,.13),(0,4.4,6.47,.55,.12)],
        b.black, body, sides=16, smooth=True)
    # Raised rear carapace joins the central gun area to the twin tail roots.
    b.section_loft('Dorsal_Carapace', [
        (0,.15,6.18,.65,.37),(0,1.3,6.40,1.35,.48),
        (0,3.0,6.60,1.55,.50),(0,4.5,6.65,1.22,.46),
        (0,5.9,6.48,.73,.33),(0,6.8,6.27,.24,.18)],
        b.pale, body, sides=12, smooth=True)
    b.beveled_band('Dorsal_Center_Ridge', curved([
        (0,.85,6.73,.13,.065),(0,2.1,6.94,.35,.09),
        (0,3.6,7.02,.33,.09),(0,5.2,6.82,.20,.07),
        (0,6.35,6.47,.05,.04)]), b.white, body)

    # The white U continues forward as TWO blades, following the reference.
    base = [(.30,-20.00,3.90,.040,.045),(.39,-16.5,4.12,.12,.11),
            (.63,-12.7,4.42,.19,.15),(.96,-9.1,4.90,.30,.18),
            (1.55,-6.3,5.56,.44,.23),(2.28,-4.0,6.20,.56,.28),
            (2.86,-1.6,6.90,.61,.34),(2.92,.8,7.30,.59,.36),
            (2.50,2.8,7.35,.52,.31),(1.65,4.20,7.04,.39,.23),
            (.66,4.93,6.73,.28,.17)]
    # The side reference shows a substantial blue-silver blade between the
    # white edges. Its cross section grows gradually into the central hull.
    b.beveled_band('Forward_Lance_Inner_Blade', curved([
        (0,-19.98,3.90,.05,.045),(0,-17.0,4.10,.30,.13),
        (0,-13.0,4.43,.51,.17),(0,-9.2,4.91,.76,.21),
        (0,-6.35,5.52,1.22,.23)]), b.pale,yokes)
    b.beveled_band('Forward_Lance_Dark_Spine', curved([
        (0,-19.80,3.95,.02,.025),(0,-17.0,4.22,.055,.035),
        (0,-13.0,4.58,.085,.045),(0,-9.2,5.10,.10,.045),
        (0,-6.35,5.73,.12,.045)]), b.blue,yokes)
    for side in (-1,1):
        sections=[(side*x,y,z,w,h) for x,y,z,w,h in base]
        b.beveled_band(f'Yoke_Continuous_{side}',curved(sections),b.white,yokes)
        # A recessed blue edge accent makes the layered yoke legible at distance.
        trim=[]
        for x,y,z,w,h in base[1:-1]:
            trim.append((side*(x-w*.55),y,z+h*.72,.040,.040))
        b.beveled_band(f'Yoke_Inner_Trim_{side}',curved(trim,2),b.blue,yokes)

    # Backlit mechanical spokes in the recess, shaped around the centre gun.
    for side in (-1,1):
        for i in range(11):
            y=-4.8+i*.67
            xouter=1.08 + 1.15*max(0,1-abs(y+.3)/4.5)
            zinner=5.56+(y+4.8)*.12
            b.rod(f'Crown_Recess_Rib_{side}_{i:02d}',
                  (side*.64,y+.22,zinner),(side*xouter,y-.25,zinner),
                  .045,b.steel,body,sides=6)

    # Each side contains a fan-shaped dark intake framed by long white armour.
    for side in (-1,1):
        outline=[(side*2.65,-5.55,5.57),(side*3.85,-5.15,5.57),
                 (side*5.15,-3.55,5.57),(side*5.38,-.70,5.57),
                 (side*5.05,1.75,5.57),(side*4.25,3.38,5.57),
                 (side*2.80,2.75,5.57),(side*2.54,-1.15,5.57)]
        b.panel(f'Wing_Dark_Vent_{side}', outline, .28, b.black, body)
        anchor=(side*2.90,-.55,5.72)
        for i in range(17):
            y=-4.45+i*.44
            x=4.4 + .72*(1-abs(y+.5)/4.8)
            b.rod(f'Wing_Vent_Rib_{side}_{i:02d}',anchor,(side*x,y,5.72),
                  .026,b.steel,body,sides=5)
        # Side-facing armour is conformed to the hull section; these layered
        # shells hide the plain bulk while retaining the tapered ray silhouette.
        hull_sections=[(-7.8,1.8,4.0,.95),(-6.3,3.15,4.0,1.25),
                       (-3.8,4.75,4.0,1.50),(-.8,5.65,4.15,1.62),
                       (2.0,5.45,4.38,1.57),(4.3,4.25,4.80,1.38),
                       (6.1,2.4,5.15,1.07)]
        for lane,ratio in enumerate((-.48,-.05,.38)):
            segments=[]
            for index,(y,width,zc,h) in enumerate(hull_sections):
                x=width*math.sqrt(1-ratio*ratio)+.025
                taper=.35 if index in (0,len(hull_sections)-1) else 1.0
                segments.append((side*x,y,zc+ratio*h,.16*taper,.30*taper))
            b.beveled_band(f'Wing_Side_Armor_Layer_{side}_{lane}',
                           curved(segments,2),b.white if lane != 1 else b.pale,body)
        def hull_at(y):
            for j in range(len(hull_sections)-1):
                a, c = hull_sections[j], hull_sections[j+1]
                if a[0] <= y <= c[0]:
                    t=(y-a[0])/(c[0]-a[0])
                    return tuple(a[k]*(1-t)+c[k]*t for k in range(1,4))
            return hull_sections[0][1:] if y < hull_sections[0][0] else hull_sections[-1][1:]

        # Interleaved swept plates, each following the local side curvature.
        # The rising profile makes them read as separate overlapping feathers.
        for i in range(6):
            mid=-5.8+i*1.92
            stations=[]
            for y,ratio,w,h in ((mid-.95,-.56,.035,.045),
                                (mid-.42,-.35,.13,.23),
                                (mid+.25,-.08,.16,.28),
                                (mid+.88,.17,.035,.05)):
                width,zc,height=hull_at(y)
                x=width*math.sqrt(1-ratio*ratio)+.17
                stations.append((side*x,y,zc+ratio*height,w,h))
            b.beveled_band(f'Wing_Overlapping_Feather_{side}_{i:02d}',
                           curved(stations,2),b.white,body)
        # Rear shoulder feathers fan outward from the yoke/tail junction.
        for i in range(5):
            b.beveled_band(f'Rear_Shoulder_Feather_{side}_{i:02d}', curved([
                (side*(4.15+i*.22),.85-i*.46,5.75,.045,.06),
                (side*(3.78+i*.18),2.25-i*.29,6.12,.24,.13),
                (side*(2.90+i*.10),3.54-i*.08,6.56,.32,.16),
                (side*1.72,4.30,6.87,.22,.14)],2), b.white,body)
        # Two long swept shells with tapered ends, plus overlapping feather plates.
        for lane in range(2):
            add=.68*lane
            stations=[(side*(2.68+add*.35),-7.2,5.15,.07,.075),
                      (side*(3.50+add*.65),-5.75,5.30,.24,.12),
                      (side*(4.65+add*.65),-3.50,5.50,.31,.14),
                      (side*(5.10+add*.55),-.55,5.76,.34,.16),
                      (side*(4.80+add*.50),2.10,6.05,.32,.15),
                      (side*(3.95+add*.35),4.25,6.25,.22,.12),
                      (side*(2.70+add*.20),5.35,6.30,.045,.06)]
            b.beveled_band(f'Wing_Swept_Armour_{side}_{lane}',curved(stations),b.white,body)
        for i in range(5):
            y=-4.9+i*1.85
            x=4.9 + .45*(1-abs(y+.2)/5.0)
            b.beveled_band(f'Wing_Feather_{side}_{i:02d}',curved([
                (side*(x-.30),y-1.05,5.36,.08,.09),
                (side*x,y-.25,5.52,.26,.13),
                (side*(x+.16),y+.48,5.65,.32,.14),
                (side*(x-.12),y+1.20,5.80,.10,.08)],2), b.pale,body)
        # Fin-like lower front prongs remain visible in the front projection.
        b.beveled_band(f'Front_Ventral_Blade_{side}', curved([
            (side*.42,-10.15,.14,.045,.055),(side*.52,-10.00,1.50,.12,.11),
            (side*.66,-9.75,3.20,.18,.15),(side*.83,-9.40,4.55,.22,.18),
            (side*1.05,-8.65,5.10,.25,.22),(side*1.12,-7.55,4.95,.30,.22)]), b.white,body)
    return body, yokes
