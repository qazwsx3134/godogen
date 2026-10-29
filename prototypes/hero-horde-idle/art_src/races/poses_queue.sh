#!/bin/bash
# Runs each character's five poses once it is picked in selected.json, in batch order (after beast_sword).
cd "$(dirname "$0")"
PY=~/repo/agent-sprite-forge/.venv/bin/python
until [ -f inputs/beast_sword-delivery-qc.json ]; do sleep 10; done
for rc in elf_shield elf_spear elf_bow elf_mage elf_healer beast_shield beast_spear beast_bow beast_mage beast_healer; do
  until grep -q "\"$rc\"" selected.json; do sleep 15; done
  $PY run_generation.py poses ${rc%%_*} ${rc#*_} >> inputs/stream-poses.log 2>&1
  grep -qiE "quota|usage limit|rate limit" inputs/stream-poses.log && { echo "STOPPED quota at $rc"; exit 1; }
done
echo "QUEUE DONE"
