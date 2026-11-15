"""The small central cannon: separate bore, shroud, sleeves and mounting parts."""


def build_cannon(b):
    g = b.group('Cannon_Module')
    z = 7.05
    # An annular, bevelled profile keeps the muzzle truly hollow and closed.
    profile = [(-.65,.40), (-1.45,.40), (-1.62,.36), (-2.28,.36),
               (-2.35,.44), (-2.58,.44), (-2.67,.39), (-2.67,.285),
               (-2.60,.245), (-2.31,.245), (-1.85,.245), (-.65,.245)]
    bands = [2,2,1,1,3,3,3,3,4,4,4,0]
    b.ring_profile('Cannon_Barrel_Hollow', profile, 0, z,
                   (b.frame,b.blue,b.pale,b.steel,b.black), g,
                   sides=32, band_materials=bands)
    # End the visible bore deep inside the barrel, before the solid shroud.
    b.rod('Cannon_Bore_End', (0,-2.06,z), (0,-1.96,z), .248, b.black, g, sides=32)
    # The protective shoulder is tapered and articulated into the deck.
    b.section_loft('Cannon_Main_Shroud', [
        (0,-1.74,7.05,.39,.39), (0,-1.35,7.12,.50,.48),
        (0,-.70,7.22,.64,.54), (0,.15,7.29,.70,.51),
        (0,1.10,7.31,.60,.42), (0,1.90,7.24,.37,.29),
        (0,2.18,7.18,.14,.14)], b.pale, g, sides=12, smooth=True)
    b.section_loft('Cannon_Underside_Cradle', [
        (0,-1.35,6.68,.42,.30), (0,-.65,6.66,.55,.31),
        (0,.70,6.65,.55,.32), (0,1.55,6.61,.29,.22)],
        b.frame, g, sides=10)
    b.rod('Cannon_Mount_Post', (0,-.05,5.80), (0,-.05,6.65), .32, b.frame, g, sides=12)
    b.section_loft('Cannon_Upper_Ridge', [
        (0,-1.30,7.49,.19,.065), (0,-.55,7.72,.29,.075),
        (0,.45,7.75,.28,.075), (0,1.55,7.57,.14,.06)],
        b.white, g, sides=8, smooth=True)
    for side in (-1, 1):
        b.section_loft(f'Cannon_Armour_Cheek_{side}', [
            (side*.33,-1.49,7.18,.14,.18), (side*.52,-.85,7.25,.16,.21),
            (side*.59,.15,7.29,.17,.20), (side*.48,1.15,7.28,.15,.15),
            (side*.25,1.86,7.20,.06,.07)], b.white, g, sides=8, smooth=True)
        b.section_loft(f'Cannon_Armour_Seam_{side}', [
            (side*.44,-1.10,7.46,.035,.035), (side*.60,-.35,7.54,.04,.035),
            (side*.60,.48,7.55,.04,.035), (side*.47,1.18,7.44,.025,.025)],
            b.blue, g, sides=6)
        for i in range(3):
            y = .25 + i*.38
            b.rod(f'Cannon_Side_Vent_{side}_{i}', (side*.58,y,7.42),
                  (side*.63,y+.07,7.44), .065, b.frame, g, sides=8)
    return g
