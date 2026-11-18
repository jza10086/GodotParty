extends StaticBody3D

## 相对普通地面的抓地力，影响地面加速、转向和制动。0 完全打滑，1 等同普通地面。
@export_range(0.0, 1.0, 0.01) var friction := 0.12
