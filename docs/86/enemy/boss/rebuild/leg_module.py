"""Radial leg/spine assemblies and a restrained underbody support frame."""
import math


def build_legs(b):
    g = b.group('Leg_And_Spine_Module')
    rx, ry = 5.05, 6.35
    # Thin attachment rails and radial braces are mostly tucked under the hull.
    count = 48
    for i in range(count):
        a = 2*math.pi*i/count
        c = 2*math.pi*(i+1)/count
        p = (rx*math.cos(a), ry*math.sin(a), 3.05)
        q = (rx*math.cos(c), ry*math.sin(c), 3.05)
        b.rod(f'Spine_Inner_Rail_{i:02d}',p,q,.075,b.frame,g,sides=6)
        if i % 2 == 0:
            b.rod(f'Spine_Radial_Brace_{i:02d}',
                  (p[0]*.64,p[1]*.64,3.50), p, .095,b.blue,g,sides=6)
    # Distributed radially rather than as a straight vertical fringe.
    for side in (-1,1):
        for i in range(31):
            angle = -math.pi/2 + math.pi*(i+.5)/31
            dx,dy=side*math.cos(angle),math.sin(angle)
            root=(side*rx*math.cos(angle),ry*math.sin(angle),3.05)
            reach=1.90+.22*math.sin(i*.91)
            tip=(root[0]+dx*reach,root[1]+dy*reach*1.05,
                 .06+.16*(i%4))
            b.rod(f'Leg_Primary_{side}_{i:02d}',root,tip,.095,b.steel,g,
                  sides=5,radius_end=.009)
            if i%2 == 0:
                # The second layer points outward behind the long leg.
                short=(root[0]+dx*(reach*.76),root[1]+dy*(reach*.84)+.18,
                       .85+.12*(i%3))
                b.rod(f'Leg_Secondary_{side}_{i:02d}',
                      (root[0]*.985,root[1]*.985,3.08),short,.055,b.pale,g,
                      sides=4,radius_end=.008)
            if i%3 == 0:
                b.rod(f'Leg_Socket_{side}_{i:02d}',
                      (root[0]*.96,root[1]*.96,3.14),
                      (root[0]+dx*.30,root[1]+dy*.30,2.77),
                      .135,b.blue,g,sides=8,radius_end=.09)
    return g
