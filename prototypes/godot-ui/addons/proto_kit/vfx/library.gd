extends RefCounted
## Native scene catalog; original notices retained in licenses/.
const EFFECTS := {
	"aether-beam": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/aether-beam.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/aether-beam.tscn")},
	"aqua-ambient": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/aqua-ambient.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/aqua-ambient.tscn")},
	"aqua-splash": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/aqua-splash.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/aqua-splash.tscn")},
	"arcane-fireworks": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/arcane-fireworks.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/arcane-fireworks.tscn")},
	"ashen-poof": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/ashen-poof.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/ashen-poof.tscn")},
	"astral-portal": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/astral-portal.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/astral-portal.tscn")},
	"blaze-ambient": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/blaze-ambient.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/blaze-ambient.tscn")},
	"blaze-tornado": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/blaze-tornado.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/blaze-tornado.tscn")},
	"blight-cloud": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/blight-cloud.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/blight-cloud.tscn")},
	"bloom-ambient": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/bloom-ambient.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/bloom-ambient.tscn")},
	"bloom-heal": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/bloom-heal.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/bloom-heal.tscn")},
	"cinder-breath": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/cinder-breath.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/cinder-breath.tscn")},
	"cinder-explosion": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/cinder-explosion.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/cinder-explosion.tscn")},
	"cyclone-dash": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/cyclone-dash.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/cyclone-dash.tscn")},
	"cyclone-slash": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/cyclone-slash.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/cyclone-slash.tscn")},
	"divine-pillar": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/divine-pillar.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/divine-pillar.tscn")},
	"eldritch-magic-circle": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/eldritch-magic-circle.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/eldritch-magic-circle.tscn")},
	"ember-damage-number": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/ember-damage-number.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/ember-damage-number.tscn")},
	"ember-flame": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/ember-flame.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/ember-flame.tscn")},
	"ember-meteor": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/ember-meteor.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/ember-meteor.tscn")},
	"ember-projectile": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/ember-projectile.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/ember-projectile.tscn")},
	"flux-shield": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/flux-shield.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/flux-shield.tscn")},
	"flux-slash": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/flux-slash.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/flux-slash.tscn")},
	"frost-nova": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/frost-nova.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/frost-nova.tscn")},
	"frozen-spikes": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/frozen-spikes.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/frozen-spikes.tscn")},
	"gilded-level-up": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/gilded-level-up.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/gilded-level-up.tscn")},
	"glacial-ambient": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/glacial-ambient.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/glacial-ambient.tscn")},
	"ion-orb": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/ion-orb.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/ion-orb.tscn")},
	"lucky-loot": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/lucky-loot.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/lucky-loot.tscn")},
	"mystic-ambient": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/mystic-ambient.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/mystic-ambient.tscn")},
	"mystic-teleport": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/mystic-teleport.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/mystic-teleport.tscn")},
	"night-aura": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/night-aura.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/night-aura.tscn")},
	"pulse-charge": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/pulse-charge.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/pulse-charge.tscn")},
	"razor-slash": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/razor-slash.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/razor-slash.tscn")},
	"sacred-sparkle": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/sacred-sparkle.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/sacred-sparkle.tscn")},
	"sanguine-claw": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/sanguine-claw.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/sanguine-claw.tscn")},
	"shadow-vortex": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/shadow-vortex.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/shadow-vortex.tscn")},
	"stone-ground-slam": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/stone-ground-slam.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/stone-ground-slam.tscn")},
	"storm-strike": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/storm-strike.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/storm-strike.tscn")},
	"thorn-ambient": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/thorn-ambient.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/thorn-ambient.tscn")},
	"volcanic-pillar": {"2d": preload("res://addons/proto_kit/vfx/2d/scenario/volcanic-pillar.tscn"), "3d": preload("res://addons/proto_kit/vfx/3d/scenario/volcanic-pillar.tscn")},
	"arc-ray": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/arc-ray.tscn")},
	"arcane-matrix": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/arcane-matrix.tscn")},
	"arcane-missile": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/arcane-missile.tscn")},
	"astral-convergence": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/astral-convergence.tscn")},
	"astral-gate": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/astral-gate.tscn")},
	"azure-sweep": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/azure-sweep.tscn")},
	"billowing-airburst": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/billowing-airburst.tscn")},
	"black-hole": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/black-hole.tscn")},
	"burning-ground": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/burning-ground.tscn")},
	"charged-beam": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/charged-beam.tscn")},
	"continuous-beam": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/continuous-beam.tscn")},
	"darkchain-detonation": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/darkchain-detonation.tscn")},
	"dimensional-rend": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/dimensional-rend.tscn")},
	"dust-devil": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/dust-devil.tscn")},
	"energy-burst": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/energy-burst.tscn")},
	"energy-vortex": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/energy-vortex.tscn")},
	"fire-explosion": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/fire-explosion.tscn")},
	"fire-vortex": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/fire-vortex.tscn")},
	"fireball": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/fireball.tscn")},
	"flame-surge": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/flame-surge.tscn")},
	"frost-field": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/frost-field.tscn")},
	"golden-chain-rain": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/golden-chain-rain.tscn")},
	"ground-fog": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/ground-fog.tscn")},
	"healing-field": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/healing-field.tscn")},
	"ice-shard": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/ice-shard.tscn")},
	"ice-shatter": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/ice-shatter.tscn")},
	"impact-frame": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/impact-frame.tscn")},
	"magic-barrier": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/magic-barrier.tscn")},
	"painterly-grass": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/painterly-grass.tscn")},
	"plasma-bolt": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/plasma-bolt.tscn")},
	"prism-guard": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/prism-guard.tscn")},
	"prism-parry": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/prism-parry.tscn")},
	"pulse-beam": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/pulse-beam.tscn")},
	"radiant-beam": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/radiant-beam.tscn")},
	"shockwave": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/shockwave.tscn")},
	"smoke-column": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/smoke-column.tscn")},
	"smoke-puff": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/smoke-puff.tscn")},
	"soul-siphon": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/soul-siphon.tscn")},
	"spell-indicator-circle": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/spell-indicator-circle.tscn")},
	"spell-indicator-sector": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/spell-indicator-sector.tscn")},
	"spiral-gale": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/spiral-gale.tscn")},
	"steam-jet": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/steam-jet.tscn")},
	"thunder-strike": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/thunder-strike.tscn")},
	"venom-stream": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/venom-stream.tscn")},
	"weapon-smear": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/weapon-smear.tscn")},
	"wind-vortex": {"3d": preload("res://addons/proto_kit/vfx/3d/00gamedevs/wind-vortex.tscn")},
}
const DETAILS := {
	"aether-beam": {
		"name": "Aether Beam",
		"source": "Scenario",
		"loop": true,
		"duration": 1.0666666666666667
	},
	"aqua-ambient": {
		"name": "Aqua Ambient",
		"source": "Scenario",
		"loop": true,
		"duration": 2.0
	},
	"aqua-splash": {
		"name": "Aqua Splash",
		"source": "Scenario",
		"loop": false,
		"duration": 1.0666666666666667
	},
	"arcane-fireworks": {
		"name": "Arcane Fireworks",
		"source": "Scenario",
		"loop": false,
		"duration": 2.1333333333333333
	},
	"ashen-poof": {
		"name": "Ashen Poof",
		"source": "Scenario",
		"loop": false,
		"duration": 0.9333333333333333
	},
	"astral-portal": {
		"name": "Astral Portal",
		"source": "Scenario",
		"loop": true,
		"duration": 1.3333333333333333
	},
	"blaze-ambient": {
		"name": "Blaze Ambient",
		"source": "Scenario",
		"loop": true,
		"duration": 2.0
	},
	"blaze-tornado": {
		"name": "Blaze Tornado",
		"source": "Scenario",
		"loop": true,
		"duration": 1.3333333333333333
	},
	"blight-cloud": {
		"name": "Blight Cloud",
		"source": "Scenario",
		"loop": true,
		"duration": 1.3333333333333333
	},
	"bloom-ambient": {
		"name": "Bloom Ambient",
		"source": "Scenario",
		"loop": true,
		"duration": 2.0
	},
	"bloom-heal": {
		"name": "Bloom Heal",
		"source": "Scenario",
		"loop": false,
		"duration": 1.3333333333333333
	},
	"cinder-breath": {
		"name": "Cinder Breath",
		"source": "Scenario",
		"loop": true,
		"duration": 1.0666666666666667
	},
	"cinder-explosion": {
		"name": "Cinder Explosion",
		"source": "Scenario",
		"loop": false,
		"duration": 1.2
	},
	"cyclone-dash": {
		"name": "Cyclone Dash",
		"source": "Scenario",
		"loop": false,
		"duration": 0.5555555555555556
	},
	"cyclone-slash": {
		"name": "Cyclone Slash",
		"source": "Scenario",
		"loop": false,
		"duration": 0.6666666666666666
	},
	"divine-pillar": {
		"name": "Divine Pillar",
		"source": "Scenario",
		"loop": false,
		"duration": 1.3333333333333333
	},
	"eldritch-magic-circle": {
		"name": "Eldritch Magic Circle",
		"source": "Scenario",
		"loop": true,
		"duration": 2.0
	},
	"ember-damage-number": {
		"name": "Ember Damage Number",
		"source": "Scenario",
		"loop": false,
		"duration": 1.0666666666666667
	},
	"ember-flame": {
		"name": "Ember Flame",
		"source": "Scenario",
		"loop": true,
		"duration": 1.0
	},
	"ember-meteor": {
		"name": "Ember Meteor",
		"source": "Scenario",
		"loop": false,
		"duration": 1.7333333333333334
	},
	"ember-projectile": {
		"name": "Ember Projectile",
		"source": "Scenario",
		"loop": true,
		"duration": 0.6666666666666666
	},
	"flux-shield": {
		"name": "Flux Shield",
		"source": "Scenario",
		"loop": true,
		"duration": 1.3333333333333333
	},
	"flux-slash": {
		"name": "Flux Slash",
		"source": "Scenario",
		"loop": false,
		"duration": 1.1666666666666667
	},
	"frost-nova": {
		"name": "Frost Nova",
		"source": "Scenario",
		"loop": false,
		"duration": 1.0666666666666667
	},
	"frozen-spikes": {
		"name": "Frozen Spikes",
		"source": "Scenario",
		"loop": false,
		"duration": 1.2
	},
	"gilded-level-up": {
		"name": "Gilded Level Up",
		"source": "Scenario",
		"loop": false,
		"duration": 1.6
	},
	"glacial-ambient": {
		"name": "Glacial Ambient",
		"source": "Scenario",
		"loop": true,
		"duration": 2.0
	},
	"ion-orb": {
		"name": "Ion Orb",
		"source": "Scenario",
		"loop": true,
		"duration": 1.0
	},
	"lucky-loot": {
		"name": "Lucky Loot",
		"source": "Scenario",
		"loop": false,
		"duration": 1.6
	},
	"mystic-ambient": {
		"name": "Mystic Ambient",
		"source": "Scenario",
		"loop": true,
		"duration": 2.0
	},
	"mystic-teleport": {
		"name": "Mystic Teleport",
		"source": "Scenario",
		"loop": false,
		"duration": 1.3333333333333333
	},
	"night-aura": {
		"name": "Night Aura",
		"source": "Scenario",
		"loop": true,
		"duration": 1.3333333333333333
	},
	"pulse-charge": {
		"name": "Pulse Charge",
		"source": "Scenario",
		"loop": true,
		"duration": 1.0666666666666667
	},
	"razor-slash": {
		"name": "Razor Slash",
		"source": "Scenario",
		"loop": false,
		"duration": 0.6666666666666666
	},
	"sacred-sparkle": {
		"name": "Sacred Sparkle",
		"source": "Scenario",
		"loop": true,
		"duration": 1.0
	},
	"sanguine-claw": {
		"name": "Sanguine Claw",
		"source": "Scenario",
		"loop": false,
		"duration": 0.6666666666666666
	},
	"shadow-vortex": {
		"name": "Shadow Vortex",
		"source": "Scenario",
		"loop": true,
		"duration": 1.3333333333333333
	},
	"stone-ground-slam": {
		"name": "Stone Ground Slam",
		"source": "Scenario",
		"loop": false,
		"duration": 1.2
	},
	"storm-strike": {
		"name": "Storm Strike",
		"source": "Scenario",
		"loop": false,
		"duration": 0.8888888888888888
	},
	"thorn-ambient": {
		"name": "Thorn Ambient",
		"source": "Scenario",
		"loop": true,
		"duration": 2.0
	},
	"volcanic-pillar": {
		"name": "Volcanic Pillar",
		"source": "Scenario",
		"loop": false,
		"duration": 1.3333333333333333
	},
	"arc-ray": {
		"name": "Forked Lightning Stream",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"arcane-matrix": {
		"name": "Floating Rune Matrix",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"arcane-missile": {
		"name": "Runic Crystal Missiles",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"astral-convergence": {
		"name": "Astral Ring Detonation",
		"source": "00GameDevs",
		"loop": false,
		"duration": 3.4,
		"preview_height": 1.4
	},
	"astral-gate": {
		"name": "Gate of Astral Tracery",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"azure-sweep": {
		"name": "Azure Blade Sweep",
		"source": "00GameDevs",
		"loop": false,
		"duration": 0.85,
		"preview_height": 1.4
	},
	"billowing-airburst": {
		"name": "Billowing Airburst",
		"source": "00GameDevs",
		"loop": false,
		"duration": 2.4,
		"preview_height": 1.4
	},
	"black-hole": {
		"name": "Luminous Vortex Black Hole",
		"source": "00GameDevs",
		"loop": true,
		"duration": 6,
		"preview_height": 1.4
	},
	"burning-ground": {
		"name": "Flame-Etched Ground",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"charged-beam": {
		"name": "Charged Light Cannon",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"continuous-beam": {
		"name": "Threadwoven Beam",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"darkchain-detonation": {
		"name": "Darkchain Sigil Rupture",
		"source": "00GameDevs",
		"loop": false,
		"duration": 5.15,
		"preview_height": 1.4
	},
	"dimensional-rend": {
		"name": "Rift-Shattering Slashes",
		"source": "00GameDevs",
		"loop": false,
		"duration": 3.4,
		"preview_height": 1.4
	},
	"dust-devil": {
		"name": "Sand-Swept Vortex",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"energy-burst": {
		"name": "Lightning Arc Burst",
		"source": "00GameDevs",
		"loop": false,
		"duration": 2.8,
		"preview_height": 1.4
	},
	"energy-vortex": {
		"name": "Runic Ring Vortex",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"fire-explosion": {
		"name": "White-Hot Fireburst",
		"source": "00GameDevs",
		"loop": false,
		"duration": 2.8,
		"preview_height": 1.4
	},
	"fire-vortex": {
		"name": "Flame-Swept Vortex",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"fireball": {
		"name": "Blazing Fireball",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"flame-surge": {
		"name": "Surging Flame Tide",
		"source": "00GameDevs",
		"loop": false,
		"duration": 3,
		"preview_height": 1.4
	},
	"frost-field": {
		"name": "Sixfold Frost Sigil",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"golden-chain-rain": {
		"name": "Golden Chain Rain",
		"source": "00GameDevs",
		"loop": false,
		"duration": 4.8,
		"preview_height": 1.4
	},
	"ground-fog": {
		"name": "Ground-Hugging Mist",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"healing-field": {
		"name": "Healing Sigil",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"ice-shard": {
		"name": "Frostcrystal Dart",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"ice-shatter": {
		"name": "Shattering Frostburst",
		"source": "00GameDevs",
		"loop": false,
		"duration": 2.8,
		"preview_height": 1.4
	},
	"impact-frame": {
		"name": "Impact Frame",
		"source": "00GameDevs",
		"loop": false,
		"duration": 0.4,
		"preview_height": 0
	},
	"magic-barrier": {
		"name": "Runic Mesh Barrier",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"painterly-grass": {
		"name": "Windswept Meadow",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"plasma-bolt": {
		"name": "Plasma Dart",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"prism-guard": {
		"name": "Prismatic Crystal Bulwark",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"prism-parry": {
		"name": "Prismatic Crystal Block",
		"source": "00GameDevs",
		"loop": false,
		"duration": 0.55,
		"preview_height": 1.4
	},
	"pulse-beam": {
		"name": "Ringpulse Ray",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"radiant-beam": {
		"name": "Solar Halo Beam",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"shockwave": {
		"name": "Dust-Raising Shockwave",
		"source": "00GameDevs",
		"loop": false,
		"duration": 2.8,
		"preview_height": 1.4
	},
	"smoke-column": {
		"name": "Billowing Smoke Column",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"smoke-puff": {
		"name": "Dispersing Smoke Puff",
		"source": "00GameDevs",
		"loop": false,
		"duration": 3.5,
		"preview_height": 1.4
	},
	"soul-siphon": {
		"name": "Dark Energy Siphon",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"spell-indicator-circle": {
		"name": "Red Circle Spell Indicator",
		"source": "00GameDevs",
		"loop": false,
		"duration": 2.15,
		"preview_height": 0
	},
	"spell-indicator-sector": {
		"name": "Red Sector Spell Indicator",
		"source": "00GameDevs",
		"loop": false,
		"duration": 2.15,
		"preview_height": 0
	},
	"spiral-gale": {
		"name": "Spiraling Wind Spear",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"steam-jet": {
		"name": "Rising Steam Jet",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"thunder-strike": {
		"name": "Vortex Lightning Strike",
		"source": "00GameDevs",
		"loop": false,
		"duration": 2.6,
		"preview_height": 1.4
	},
	"venom-stream": {
		"name": "Corrosive Venom Jet",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	},
	"weapon-smear": {
		"name": "Gleaming Blade Trail",
		"source": "00GameDevs",
		"loop": true,
		"duration": 4,
		"preview_height": 1.4
	},
	"wind-vortex": {
		"name": "Leaf-Swept Vortex",
		"source": "00GameDevs",
		"loop": true,
		"duration": 5,
		"preview_height": 1.4
	}
}

static func get_scene(id: String, dimension: String = "2d") -> PackedScene:
	return EFFECTS.get(id, {}).get(dimension) as PackedScene

static func ids(dimension: String = "2d") -> PackedStringArray:
	var result := PackedStringArray()
	for id: String in EFFECTS:
		if EFFECTS[id].has(dimension):
			result.append(id)
	return result
