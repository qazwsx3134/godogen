1. movement weight 不能一開始就是full speed 然後要有加速跟摩擦力 用 move_toward(velocity.x, direction * SPEED, ACCEL * delta)
2. squash amd strectch onland的時候 squich tehn spring back sprite_scale = Vector2(1.3, 0.7) var t = create_tween() t.tween_property(sprite, "scale", Bector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC) 只縮放sprite 但是hitbox不縮放
3. impact add tiny effect 比如落地加上 dust 或是煞車的時候 衝擊的時候抖動螢幕
4. freeze frame (not overdoing it! important!) 要有打擊感很常用到
func hit_stop(duration):
    engine.time_scale = 0.05
    await get_tree().create_timer(duration, true, false, true).timeout
    Engine.time_scale = 1.0

5. coyote time and time buffering
func _physics_process(delta):
    if is_on_floor():
        coyote = COYOTE_TIME
    else:
        coyote -= delta
    if jump and coyote > 0.0:
        velocity.y = JUNP_FORCE

6. 聲音 sound
func play(stream):
    sfx.stream = stream
    # never the same twice
    sfx.pitch_scale = randf_range(0.9, 1.1)
    sfx.play()

func collect():
    Juice.spawn_burst(position, color.GOLD, 8)
    var t = create_tween()
    t.tween_property(score, "scale", Vector2(1.3, 1.3), 0.1)
    t.tween_property(score, "scale", Vector2.ONE, 0.12)