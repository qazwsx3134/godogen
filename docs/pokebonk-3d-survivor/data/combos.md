# 圖鑑 Combo

口徑：這是 bundle 預設圖鑑條件；已存的 api-config.json 快照沒有 Combo 專屬鍵，通用武器與敵人係數仍可能改變實戰傷害。這 16 組只記錄組件條件並在 run 中顯示完成橫幅，不額外改數值（main:17232-17345、18497、31006-31024）。它們與「Tempestade Divina」三招同持有時的防疊加傷害折扣完全不同，後者見 [武器資料](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/weapons.md)。

條件縮寫：進化招＝指定招式已進化；一般招＝持有該招；能力／道具／維他命＝持有指定項；同屬招＝至少三招與角色同屬。Bundle 以 `Sr` 檢查條件與以 `checkCombos` 顯示組合（main:17347-17381、31006-31024）。

| 行 | 名稱（pt-BR） | 條件 | 說明（轉述 bundle） |
|---:|---|---|---|
| main:17234 | Buraco Negro | 進化 Surf；Earthquake；Sheer Force | Hydro Vortex 聚怪後接地震；Sheer Force 讓擊退不把敵群推散。 |
| main:17241 | Era do Gelo | 進化 Ice Beam；Icicle Crash；Pressure | 冰雪控場、冰柱暈眩，再以 Pressure 減速存活敵人。 |
| main:17248 | Tempestade Elétrica | Thunderbolt；Static；Serene Grace | 閃電連鎖與麻痺機率相疊，Serene Grace 加強觸發機率。 |
| main:17255 | Executor | 進化 Kowtow；King's Rock；Super Luck | 低 HP 處決、即死機率與暴擊組合。 |
| main:17262 | Saco de Pancada | Rage Fist；Flame Body；Leftovers | 受擊增強 Rage Fist，接觸反傷並靠 Leftovers 回復。 |
| main:17269 | Magnata | 進化 Make It Rain；Amulet Coin；Clover | 增加金錢收益與幸運，並擴大淘金效果。 |
| main:17276 | Técnico de Rajada | Technician；Skill Link；Water Shuriken | 低基礎傷害觸發 Technician，Skill Link 再加投射物與穿透。 |
| main:17283 | Inferno | 進化 Flamethrower；Torch Song；Flame Body | 地面燃燒、火焰追擊與接觸燃燒形成火區。 |
| main:17290 | Sombra Infinita | 進化 Shadow Ball；Skill Link；Master Ball | Shadow Ball 擊中分裂，額外投射物與穿透擴大覆蓋。 |
| main:17297 | Muralha | Multiscale；Regenerator；Leftovers | 滿 HP 減傷，離開受傷狀態後以兩種回復來源補血。 |
| main:17304 | Placas Tectônicas | 進化 Earth Power；進化 Earthquake | 持續地裂與石刃把場地變成危險區。 |
| main:17311 | Bola de Neve | Moxie；進化 Psychic；Flamethrower | 範圍精神攻擊與火焰清場，擊殺再累積 Moxie 傷害。 |
| main:17318 | Crítico Absurdo | Super Luck；Scope Lens；Razor Claw | 提高暴擊率與暴擊傷害。 |
| main:17325 | Vampiro | Life Orb；Shell Bell；Huge Power | 高傷害換取吸血回復。 |
| main:17332 | Furacão Verde | 進化 Razor Leaf；Speed Boost；Quick Claw | 環繞葉片與逐漸提高的攻擊速度。 |
| main:17339 | Puro-Sangue | 至少三招同屬；Adaptability | 同屬 STAB 與 Adaptability 的傷害加成相配。 |

