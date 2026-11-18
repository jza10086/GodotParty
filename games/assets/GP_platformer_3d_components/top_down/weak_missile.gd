extends ParkourProjectile

## Limited turning and a short guidance window let runners dodge sideways.
@export_range(0.0, 120.0, 1.0, "suffix:°/s") var turn_rate := 30.0
@export_range(0.0, 10.0) var guidance_duration := 2.5
var target: ParkourEffectReceiver
var age := 0.0

func _physics_process(delta: float) -> void:
	age += delta
	if target != null and target.is_active() and age <= guidance_duration:
		var offset := target.global_position-global_position
		offset.y = 0.0
		if not offset.is_zero_approx():
			var heading := atan2(velocity.x,velocity.z)
			var desired := atan2(offset.x,offset.z)
			var angle := clampf(wrapf(desired-heading,-PI,PI),-deg_to_rad(turn_rate)*delta,deg_to_rad(turn_rate)*delta)
			velocity = velocity.rotated(Vector3.UP,angle)
	if not velocity.is_zero_approx():
		look_at(global_position+velocity,Vector3.UP)
	super(delta)
