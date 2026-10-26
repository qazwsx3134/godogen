from pathlib import Path
import math

base = Path(__file__).resolve().parents[1]
p = base / 'scripts/harbor.gd'
s = p.read_text(encoding='utf-8-sig')
s = s.replace('\t%FishButton.button_down.connect(func():reel_held=true)\n\t%FishButton.button_up.connect(func():reel_held=false)', '\t%Fishing.landed.connect(land_fish)\n\t%Fishing.closed.connect(func():enter_phase(Phase.IDLE))')
start = s.index('\tmatch phase:\n', s.index('func _process'))
end = s.index('\nfunc land_fish()', start)
s = s[:start] + '''

func enter_phase(next: Phase) -> void:
	phase=next;phase_time=0
	%FishingPanel.hide();%Rod.hide();%Bobber.hide();%FishingLine.hide()
	%CatchCard.visible=phase==Phase.CAUGHT and not %Fishing.active
	%FishButton.text="釣魚  [ 空白鍵 ]"

func fish_action() -> void:
	if %Journal.visible or %Dialog.visible or %Fishing.active:return
	enter_phase(Phase.WAIT)
	%Fishing.begin(auto_fish)
	sound([293.66,196.0])
''' + s[end:]
# Fishing screen displays its own result; harbor collection still receives one signal.
s = s.replace('toast("放置模式會自動拋竿和收線。" if auto_fish else "放置已停止，這尾魚仍可慢慢釣完。")', 'toast("輔助模式會示範拋竿、誘魚、控線與角力。" if auto_fish else "回到手動操作。")\n\tif %Fishing.active:%Fishing.assist=auto_fish')
s = s.replace('"放置中 · 再按可停" if auto_fish else "放置釣魚  [ Tab ]"', '"輔助示範中 · Tab 停止" if auto_fish else "輔助釣魚  [ Tab ]"')
s = s.replace('func toggle_book() -> void:\n', 'func toggle_book() -> void:\n\tif %Fishing.active:return\n')
p.write_text(s, encoding='utf-8')

# Original code-authored vector scenery, no extracted game assets.
art = ['<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="470" viewBox="0 0 1280 470">',
       '<defs><linearGradient id="depth" x2="0" y2="1"><stop stop-color="#21566b"/><stop offset="1" stop-color="#0c233c"/></linearGradient></defs>',
       '<path fill="url(#depth)" d="M0 0h1280v470H0z"/>']
for x in range(80, 1280, 190):
    art.append(f'<path fill="#89d4cc" opacity=".035" d="M{x} 0h45l160 470H{x+60}z"/>')
for x, y, w in [(40,240,290),(340,365,300),(800,280,380),(1040,420,300)]:
    art.append(f'<path fill="#173b4d" d="M{x} 470V{y+30}h-40v-18h{w}v18h-55v{470-y}z"/>')
    art.append(f'<path fill="#37695d" d="M{x-40} {y+12}v-12h{w}v12z"/>')
for i in range(27):
    x = (i*167+17)%1280
    y = (i*61+23)%445
    art.append(f'<rect x="{x}" y="{y}" width="3" height="3" fill="#8ee6d8" opacity=".35"/>')
for i in range(20):
    x=i*71
    h=22+(i*19)%80
    art.append(f'<path fill="none" stroke="#338c80" stroke-width="4" d="M{x} 470v-{h}l-12 -14m12 30 13 -17"/>')
art.append('</svg>')
(base/'assets/underwater.svg').write_text('\n'.join(art),encoding='utf-8')
