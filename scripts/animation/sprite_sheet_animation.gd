class_name SpriteSheetAnimation
extends RefCounted


const CARDINAL_DIRECTIONS: Array[String] = [
	"s",
	"w",
	"n",
	"e"
]


static func add_cardinal_sheet(
	frames: SpriteFrames,
	texture: Texture2D,
	animation_prefix: String,
	animation_speed: float,
	loop_animation: bool
) -> void:

	if frames == null or texture == null:

		return


	var frame_size: Vector2 = texture.get_size() / 4.0


	for row: int in range(CARDINAL_DIRECTIONS.size()):

		var animation_name: StringName = StringName(
			animation_prefix + "_" + CARDINAL_DIRECTIONS[row]
		)


		if frames.has_animation(animation_name):

			frames.remove_animation(animation_name)


		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, loop_animation)
		frames.set_animation_speed(animation_name, animation_speed)


		for column: int in range(4):

			var atlas_frame: AtlasTexture = AtlasTexture.new()
			atlas_frame.atlas = texture
			atlas_frame.region = Rect2(
				Vector2(column, row) * frame_size,
				frame_size
			)
			frames.add_frame(animation_name, atlas_frame)
