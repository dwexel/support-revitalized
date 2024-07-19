shader_type spatial;
//render_mode depth_test_disabled;
render_mode unshaded;

uniform sampler2D tex;

void fragment() {
	//no alpha
	vec2 coords = UV;
	coords *= 20.0;
	
	vec4 texcol = texture(tex, coords);
	ALBEDO = texcol.rgb;
	ALPHA = texcol.a;
}