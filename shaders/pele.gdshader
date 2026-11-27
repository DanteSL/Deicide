shader_type spatial;
// Pele humana dos braços em primeira pessoa: duas texturas de pele (poros, rugas) misturadas
// em manchas, cor de base vinda das cores de vértice (nós avermelhados, palma mais clara, veias)
// e espalhamento sob a pele (as bordas finas dos dedos ficam rosadas contra a luz).
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D cor1 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cor2 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nrm1 : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nrm2 : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D liso1 : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D liso2 : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D manchas : filter_linear_mipmap, repeat_enable;
uniform float repete = 6.5;
uniform vec3 tom : source_color = vec3(1.04, 0.96, 0.93);
uniform float sangue = 0.0;
uniform float sss = 0.45;

void fragment() {
	vec2 uv = UV * repete;
	float m = smoothstep(0.38, 0.66, texture(manchas, UV * 1.7).r);
	vec3 a = mix(texture(cor2, uv).rgb, texture(cor1, uv).rgb, m);
	// menos saturado que as fotos de pele (a luz do viewmodel já é quente)
	a = mix(a, vec3(dot(a, vec3(0.3, 0.55, 0.15))), 0.3);
	vec3 base = a * COLOR.rgb * tom;
	ALBEDO = base;
	NORMAL_MAP = normalize(mix(texture(nrm2, uv).rgb, texture(nrm1, uv).rgb, m));
	NORMAL_MAP_DEPTH = 0.55;
	float lis = mix(texture(liso2, uv).r, texture(liso1, uv).r, m);
	ROUGHNESS = clamp(0.82 - lis * 0.45, 0.32, 0.86);
	SPECULAR = 0.36;
	SSS_STRENGTH = sss;
	BACKLIGHT = vec3(0.32, 0.07, 0.04);
}
