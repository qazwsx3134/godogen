# 任務、評級與 PB 結算

任務條件與獎勵均為 bundle 預設；api-config.json 快照沒有逐任務或 PB 獎勵鍵。Balance 實驗室測試局不進 run 歷史、排行榜或進度，見 bundle 分析的「平衡實驗室」與「遠端平衡」。（main:4562-4718、26081-26089）

## 22 個任務

| 行 | ID | 完成條件 | 獎勵 |
|---:|---|---|---|
| main:4564 | k500 | 單局擊倒 800 敵人 | Kowtow + 15 PB |
| main:4571 | evolve | 單局進化 2 招 | Dragon Pulse + 15 PB |
| main:4578 | combo | 完成 1 組 Combo | Judgment + 15 PB |
| main:4585 | chests | 單局開啟 10 顆付費 Pokébola | King's Rock + 15 PB |
| main:4592 | dmg | 單局造成 150,000 傷害 | Life Orb + 15 PB |
| main:4599 | gold | 單局同時持有 800 金幣 | Gholdengo + 20 PB |
| main:4606 | win | Boss lineup 至少 6 並獲勝 | Lugia + 30 PB |
| main:4613 | lv30 | 單局達等級 40（ID 仍叫 lv30） | Mewtwo + 25 PB |
| main:4620 | t10 | Boss lineup 至少 12 並獲勝 | Rayquaza + 40 PB |
| main:4627 | portal | Bonk 模式通過 portal | Giratina + 25 PB |
| main:4634 | swarm | 在 Bonk 終局 swarm 存活 60 秒 | Master Ball + 30 PB |
| main:4641 | restricted | Restrito 模式獲勝 | Darkrai + 30 PB |
| main:4648 | night | Noite Sombria 模式擊敗 Darkrai | Celebi + 25 PB |
| main:4655 | cave | Pedreira 模式擊敗 Groudon | Groudon + 25 PB |
| main:4662 | coop | 至少 3 人在線存活 300 秒 | Kingambit + 20 PB |
| main:4669 | duel | 贏得 1v1 Duel | Jirachi + 20 PB |
| main:4676 | runs10 | 累計遊玩 10 局 | Dragonite + 20 PB |
| main:4683 | runs30 | 累計遊玩 30 局 | Mew + 30 PB |
| main:4690 | kills20k | 累計擊倒 20,000 敵人 | Kyogre + 30 PB |
| main:4697 | bosses40 | 累計擊倒 40 隻 Boss | Dialga + 30 PB |
| main:4704 | megas15 | 累計 Mega 進化 15 次 | Palkia + 25 PB |
| main:4711 | wins5 | 累計贏 5 局，且 Bonk 通 portal 至少 1 次 | Arceus + 50 PB |

## 評級與 PB

勝利時取 Boss medal 分數平均值：平均至少 0.85 為 S+，否則為 S。失敗則按存活秒數分級：450 秒以上 A、270 以上 B、120 以上 C，其餘 D（main:22582-22587）。PB 基底結算：金／銀／銅勳章各 3／2／1；每存活分鐘 +3；擊殺每 100 隻 +1、最多 30；每 Boss +6；一般勝利 +40、Duel 勝利 +25；再加 bonus PB。結算乘數為 Bonk 時 1.3、否則 1.0，再加 restricted +0.25、adaptive +0.25、各風險修正總和與每名額外玩家 +0.05；四捨五入後再加任務 BP 獎勵（main:3803、4540、4794-4831）。

