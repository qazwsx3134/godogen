#!/usr/bin/env bash
# Cleans the voice clips recorded from the show (assets/sfx/*.MOV, local only) into assets/voice/<id>.wav:
# audio only, mono 44.1 kHz, 90 Hz high-pass (handling rumble), light FFT denoise, EBU R128 loudness aimed at
# -12 LUFS (peaks -1 dBTP; these short clips land near -15, all within 1 LU) so every line plays at the same level
# and cuts through the songs (about -7 LUFS; RhythmLevel.say also ducks the song 6 dB), 10 ms fades against clicks (the length stays), 16-bit WAV (no MP3
# encoder delay, so a chomp lands on its beat; Godot imports it QOA-compressed).
# The game loads assets/voice/<id>.wav only if it exists (RhythmLevel.say), so a clone without them still runs.
# Run from the project root: bash tools/convert_voice.sh
set -eu
src=assets/sfx
out=assets/voice
mkdir -p "$out"

# id | source file | start s | length s (empty = to the end). The author trims the recordings, so every clip
# plays whole.
clips=(
	"gintoki_eat|阿銀吃東西.mov|0|"
	"shinpachi_eat|新八吃東西.MOV|0|"
	"shinpachi_bento|新巴在裝外帶便當.MOV|0|"
	"kagura_rice|神樂說再一碗白飯.MOV|0|"
	"kagura_now|神樂說現在才開始.MOV|0|"
	"kagura_eye|神樂被砸到眼睛痛苦倒地.MOV|0|"
	"referee_start|裁判說能吃就盡量吃.mov|0|"
	"gintoki_kick|阿銀家餐桌不許有外人.MOV|0|"
	"gintoki_pep|阿銀精神喊話.MOV|0|"
)

for row in "${clips[@]}"; do
	IFS='|' read -r id file start len <<<"$row"
	if [ ! -f "$src/$file" ]; then
		echo "skip $id: $src/$file missing"
		continue
	fi
	total=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$src/$file")
	[ -n "$len" ] || len=$(python3 -c "print(round($total - $start, 3))")
	fade_at=$(python3 -c "print(max(0.0, round($len - 0.01, 3)))")
	ffmpeg -v error -y -ss "$start" -t "$len" -i "$src/$file" -vn -ac 1 -ar 44100 \
		-af "highpass=f=90,afftdn=nr=10:nf=-40,loudnorm=I=-12:TP=-1:LRA=11,afade=t=in:d=0.01,afade=t=out:st=$fade_at:d=0.01" \
		-c:a pcm_s16le "$out/$id.wav"
	echo "$id: $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out/$id.wav") s"
done
