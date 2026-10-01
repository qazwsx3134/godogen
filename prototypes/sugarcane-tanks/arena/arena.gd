extends Node2D
## One stage: a full-screen painted Background (1080x1920, the whole world), invisible Walls that follow
## what is drawn (railings, gardens, buildings, trees), and the exit %Door. It sits at z_index -2 so the
## red circles (-1) and everything that stands on the floor draw above it.

## The open floor's bounding box. Enemies and the hero start inside it, and boss summons are kept in it.
@export var walk_area: Rect2 = Rect2(60, 260, 960, 1500)
