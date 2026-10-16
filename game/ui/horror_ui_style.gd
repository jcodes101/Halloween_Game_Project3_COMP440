extends RefCounted
## Shared functional-control styling for the main and pause menus.

const PAPER := Color("e8e0d1")
const MUTED := Color("8c8579")
const AMBER := Color("bd9860")
const TRACK := Color("514d45")

static func style_slider(slider: HSlider) -> void:
	var base_track := StyleBoxLine.new()
	base_track.color = TRACK
	base_track.thickness = 3
	slider.add_theme_stylebox_override("slider", base_track)
	var filled_track := StyleBoxLine.new()
	filled_track.color = Color("62533c")
	filled_track.thickness = 3
	slider.add_theme_stylebox_override("grabber_area", filled_track)
	var hover_track := StyleBoxLine.new()
	hover_track.color = AMBER
	hover_track.thickness = 3
	slider.add_theme_stylebox_override("grabber_area_highlight", hover_track)
	slider.add_theme_icon_override("grabber", _knob(AMBER))
	slider.add_theme_icon_override("grabber_highlight", _knob(PAPER))
	slider.add_theme_icon_override("grabber_disabled", _knob(MUTED))
	slider.add_theme_color_override("font_color", PAPER)
	slider.add_theme_color_override("font_focus_color", AMBER)

static func style_scroll_container(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 8
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.035, 0.032, 0.034, 0.82)
	track.corner_radius_top_left = 3
	track.corner_radius_top_right = 3
	track.corner_radius_bottom_left = 3
	track.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("scroll", track)
	var thumb := StyleBoxFlat.new()
	thumb.bg_color = Color("65543f")
	thumb.corner_radius_top_left = 3
	thumb.corner_radius_top_right = 3
	thumb.corner_radius_bottom_left = 3
	thumb.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("grabber", thumb)
	var hover_thumb := StyleBoxFlat.new()
	hover_thumb.bg_color = AMBER
	hover_thumb.corner_radius_top_left = 3
	hover_thumb.corner_radius_top_right = 3
	hover_thumb.corner_radius_bottom_left = 3
	hover_thumb.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("grabber_highlight", hover_thumb)

static func _knob(color: Color) -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in 16:
		for x in 16:
			if Vector2(x - 7.5, y - 7.5).length() <= 6.5:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
