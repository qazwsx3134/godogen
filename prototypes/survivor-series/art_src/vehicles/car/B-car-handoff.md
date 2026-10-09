# B-car handoff: COMPLETED

- Scope: B car only; raw files/specs untouched; C not started.
- Route/model: `local:codex-cli` / `codex-image_gen`; identity FIRST, hero style SECOND only.
- Pad geometry: all 8 candidates RGBA 1024; mob top `406`, height `471`, groundline `y=877`, inbounds, warnings `0`.
- s: both visually pass DOWN; n: fixed candidate-01 and original candidate-02 both pass TOP with rear and driver back visible.
- e: root `dir-e/fix-e-02` succeeded in two takes and both candidates are adopted as exact EAST/RIGHT: horizontal wheel axles/ground contacts, narrow nose RIGHT, elevated roof visible. e-02 retains a slight lower-right projection, recorded as a report note.
- ne: both root fix candidates pass UPPER-RIGHT, rear LOWER-LEFT, rear three-quarter with driver on the right/rear side; old candidates remain only as beforefix diagnostics.
- n fix: root `dir-n/fix-north-01` was padded to `candidate-01`; old diagonal candidate is retained as `candidate-01-beforefix.png` and was not selected. Fix changed heading only; raw inputs remain untouched.
- Stale warning: fix run records “the style reference master_rgba.png is missing; its recorded sha256 is kept”; actual run references include approved car FIRST and hero SECOND with expected hashes, so this is a stale relative-path warning, not an absent style attachment.
- NE/N source QC: fixed raw paths and hashes match their run/pad provenance; both runs are `local:codex-cli` / `codex-image_gen`, with approved car FIRST and hero SECOND refs present. NE has no run warning; N has only the known stale relative style-path warning, not a missing attachment. All initial/raw files remain untouched.
- E pad/QC: e-01 bbox `[83,406,941,877]`, width `858`, scale `0.8234265734`, offset `[3.5340909091,25.5769230769]`; e-02 bbox `[138,406,886,877]`, width `748`, scale `0.8336283186`, offset `[59.7566371681,-29.9876106195]`. Both `width_limited=false`, groundline `877`, warnings `0`, RGBA/inbounds.
- Geometry: all eight final candidates are inbounds with top=`406`, height=`471`, groundline=`877`; widths s=`386,380`, e=`858,748`, ne=`632,680`, n=`428,428`; approved se baseline width=`636`.
- Projection note: width spread `380–858 px` is large (59.7–134.9% of se; max/min about 2.26×); physical car length is not claimed equal across views. e-02's slight lower-right projection is explicitly retained.
- Raw mappings, alpha counts, bbox, transform scales, refs and route provenance are in `B-car-handoff.json`.
- Rebuilt contacts: `dir-e/candidates-contact.png` and final `directions-contact.png`; approved se remains centered and all eight adopted candidates are labeled with no failed candidate.
- Retry incident / final-report note: car-e fix `PID 43523` / `Codex 43531` stalled about 3h; root verified and SIGINT-stopped all 3 layers, then `ps` was empty. Old run `ed8a04a874bf4026a8188c934856ab84` resume returned no image: `ARTIFACT_MISSING`. User authorized exactly one retry: `dir-e/fix-e-02` completed within root outer timeout `360s`, warnings `0`; both raw outputs were padded/adopted, with no further retry.
- Only candidate outputs/contact/pad metadata changed; all root raw generated files and specs remain untouched. No approve, animation, C work, SS/report or API write.
- Fix warning: only `dir-n/fix-north-01/run.json` has the stale relative style-path warning; its actual car FIRST/hero SECOND refs and hashes are present and correct.
- Handoff complete and closed: B is now published and the B report is updated by commander. No further B file changes are required; C is a separate assignment.
