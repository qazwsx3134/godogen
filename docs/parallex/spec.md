pixel art game
sky 遠中近 然後 還有最近 跟遮蔽(介於角色跟玩家之間)
用 parallax 2d sku 0.03 far 0.1 mid 0.24 near 0.45 closest 0.7 遮蔽 1.3 (遮蔽要放置在不會影響重要互動的地方)
有森林 有夜晚(星空)
營地 有營火 有看道具的地方 煮飯的地方
角色
跳起來有聲音 落到地上有聲音
增加 raycast2D 陰影
越來越晚 CanvasModulate 越近的parallax會黯淡的比較快 darker per row
增加營火或路燈 要使用tiem cull mask 只點亮目前的layer
