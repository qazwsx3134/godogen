"""Two armoured tails with broad overlapping scales and forked arrow tips."""
from boss_geometry import curved


def build_tails(b):
    groups = []
    for side in (-1,1):
        g=b.group('Tail_Left_Module' if side < 0 else 'Tail_Right_Module',
                  (side*1.30,4.9,6.45))
        groups.append(g)

        def center(t):
            return (side*(1.30+.58*t), 4.9+14.25*t, 6.45+2.15*t)

        def section(t, w, h, zoffset=0):
            x,y,z=center(t)
            return (x,y,z+zoffset,w,h)

        b.section_loft(f'Tail_Structural_Core_{side}',
            [section(0,.86,.49),section(.24,.81,.46),section(.52,.72,.42),
             section(.78,.62,.37),section(1,.50,.31)], b.frame,g,sides=10,smooth=True)
        b.section_loft(f'Tail_Base_Collar_{side}', [
            (side*.90,3.4,6.22,.65,.50),section(.09,.90,.48)],b.blue,g,sides=10,smooth=True)

        # Overlap plate ends slightly to avoid accidental gaps during inspection.
        for i in range(17):
            t0=max(0,(i-.06)/17)
            tm=(i+.48)/17
            t1=min(1,(i+1.08)/17)
            width=.90-.34*tm
            b.beveled_band(f'Tail_Armor_Scale_{side}_{i:02d}', curved([
                section(t0,width*.91,.075,.34),
                section(tm,width,.14,.38),
                section(t1,width*.90,.075,.34)],2),b.pale,g)
            # Fine seam on the top of each plate, ending before the next seam.
            x,y,z=center(tm)
            b.rod(f'Tail_Scale_Splice_{side}_{i:02d}',
                  (x-side*width*.54,y,z+.51),
                  (x+side*width*.54,y,z+.51),.035,b.white,g,sides=5)
            # Thin fins on the outside edge are the tail's distinctive fringe.
            origin=(x+side*width*.74,y,z-.12)
            end=(x+side*(width+.62),y+.30,z-.66)
            b.rod(f'Tail_Outer_Fin_{side}_{i:02d}',origin,end,.052,b.steel,g,
                  sides=5,radius_end=.007)

        ex,ey,ez=center(1)
        b.beveled_band(f'Tail_Arrow_Center_{side}', curved([
            (ex,ey-.55,ez,.48,.26),(ex,ey-.02,ez+.04,.70,.22),
            (ex,19.60,ez+.12,.53,.16),(ex,20.00,ez+.18,.035,.035)],2),b.blue,g)
        for wing in (-1,1):
            b.panel(f'Tail_Arrow_Wing_{side}_{wing}', [
                (ex+wing*.12,ey-.35,ez+.12),
                (ex+wing*.92,ey+.08,ez+.12),
                (ex+wing*1.14,19.76,ez+.20),
                (ex+wing*.38,19.48,ez+.21),
                (ex+wing*.14,19.72,ez+.18)], .11, b.white,g)
    return groups
