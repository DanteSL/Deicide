shader_type spatial;
// Mármore branco com veios de ouro (textura enviada pelo jogador), projetado no mundo (triplanar)
// e com "ladrilho hexagonal aleatório": cada célula pega um pedaço sorteado da foto, então a repetição some.
// corrupt (0..1): o mármore vira a pintura fluida vermelha, preta e dourada, espalhando a partir de corrupt_center.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_gray, filter_linear_mipmap, repeat_enable;
uniform bool use_rough_tex = false;
uniform vec3 tint = vec3(1.0);
uniform float scale = 0.08;
uniform float rough = 0.22;
uniform float normal_k = 0.6;
uniform float gold_shine = 1.0;   // veios de ouro brilham e ficam metálicos
uniform float corrupt = 0.0;
uniform vec3 corrupt_center = vec3(0.0);
uniform float corrupt_reach = 90.0;
uniform float time_s = 0.0;

varying vec3 wp;
varying vec3 wn;

vec2 h22(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float h21(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float a = .5, s = 0.0; for (int i = 0; i < 5; i++) { s += vn(p) * a; p = p * 2.03 + 1.7; a *= .5; } return s; }

// três amostras em grade triangular com deslocamento aleatório por vértice, pesos afiados
void hexs(sampler2D t, vec2 uv, out vec4 col, out vec3 w3, out vec2 o1, out vec2 o2, out vec2 o3) {
	vec2 s = vec2(uv.x - uv.y * .57735027, uv.y * 1.15470054) * 2.2;
	vec2 b = floor(s);
	vec3 f = vec3(fract(s), 0.0);
	f.z = 1.0 - f.x - f.y;
	vec2 v1, v2, v3;
	vec3 w;
	if (f.z > 0.0) { w = vec3(f.z, f.y, f.x); v1 = b; v2 = b + vec2(0, 1); v3 = b + vec2(1, 0); }
	else { w = vec3(-f.z, 1.0 - f.y, 1.0 - f.x); v1 = b + vec2(1, 1); v2 = b + vec2(1, 0); v3 = b + vec2(0, 1); }
	o1 = h22(v1); o2 = h22(v2); o3 = h22(v3);
	w = pow(w, vec3(5.0)); w /= (w.x + w.y + w.z);
	vec2 dx = dFdx(uv), dy = dFdy(uv);
	col = textureGrad(t, uv + o1, dx, dy) * w.x + textureGrad(t, uv + o2, dx, dy) * w.y + textureGrad(t, uv + o3, dx, dy) * w.z;
	w3 = w;
}
vec4 hexn(sampler2D t, vec2 uv, vec3 w, vec2 o1, vec2 o2, vec2 o3) {
	vec2 dx = dFdx(uv), dy = dFdy(uv);
	return textureGrad(t, uv + o1, dx, dy) * w.x + textureGrad(t, uv + o2, dx, dy) * w.y + textureGrad(t, uv + o3, dx, dy) * w.z;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 bw = pow(abs(wn), vec3(6.0)); bw /= (bw.x + bw.y + bw.z);
	vec4 cx, cy, cz; vec3 w; vec2 a, b, c;
	vec3 nrm = vec3(.5, .5, 1.0);
	vec3 col = vec3(0.0);
	float rtex = 0.0;
	if (bw.y > .01) { hexs(albedo_tex, wp.xz * scale, cy, w, a, b, c); col += cy.rgb * bw.y; nrm = mix(nrm, hexn(normal_tex, wp.xz * scale, w, a, b, c).rgb, bw.y); rtex += hexn(rough_tex, wp.xz * scale, w, a, b, c).r * bw.y; }
	if (bw.x > .01) { hexs(albedo_tex, wp.zy * scale, cx, w, a, b, c); col += cx.rgb * bw.x; nrm = mix(nrm, hexn(normal_tex, wp.zy * scale, w, a, b, c).rgb, bw.x); rtex += hexn(rough_tex, wp.zy * scale, w, a, b, c).r * bw.x; }
	if (bw.z > .01) { hexs(albedo_tex, wp.xy * scale, cz, w, a, b, c); col += cz.rgb * bw.z; nrm = mix(nrm, hexn(normal_tex, wp.xy * scale, w, a, b, c).rgb, bw.z); rtex += hexn(rough_tex, wp.xy * scale, w, a, b, c).r * bw.z; }
	// quanto do pixel é veio de ouro (amarelo saturado)
	float gold = clamp((col.r - col.b) * 3.0 - .15, 0.0, 1.0) * gold_shine;
	col *= tint;
	float met = gold * .85;
	float rgh = mix(use_rough_tex ? rtex : rough, .18, gold);

	// --- corrupção: pintura fluida vermelha, preta e dourada ---
	if (corrupt > 0.0) {
		vec2 p = (wp.xz + wp.y * vec2(.6, -.4)) * .045;
		vec2 q = vec2(fbm(p + time_s * .01), fbm(p + 5.2));
		vec2 r2 = vec2(fbm(p + 4.0 * q + vec2(1.7, 9.2) + time_s * .015), fbm(p + 4.0 * q + vec2(8.3, 2.8)));
		float v = fbm(p + 4.0 * r2);
		vec3 blk = vec3(.025, .012, .014);
		vec3 red = vec3(.62, .03, .04);
		vec3 hot = vec3(.95, .12, .08);
		vec3 gld = vec3(.85, .6, .22);
		vec3 cc = mix(blk, red, smoothstep(.35, .62, v));
		cc = mix(cc, hot, smoothstep(.62, .75, v) * .7);
		float gl = smoothstep(.02, .0, abs(v - .44)) * .9 + step(.985, h21(floor(wp.xz * 9.0) + floor(v * 7.0))) * .7;
		cc = mix(cc, gld, clamp(gl, 0.0, 1.0));
		// avanço a partir do centro, com borda irregular em brasa
		float d = length(wp.xz - corrupt_center.xz);
		float front = corrupt * (corrupt_reach + 30.0) - d + (fbm(wp.xz * .08) - .5) * 26.0;
		float m = smoothstep(0.0, 6.0, front);
		float edge = smoothstep(0.0, 2.5, front) * (1.0 - smoothstep(2.5, 7.0, front));
		col = mix(col, cc, m);
		met = mix(met, gl * .9, m);
		rgh = mix(rgh, mix(.12, .35, v), m);
		EMISSION = (vec3(1.0, .15, .04) * edge * 2.0 + hot * smoothstep(.68, .8, v) * .25 * m) * corrupt;
	}
	ALBEDO = col;
	METALLIC = met;
	ROUGHNESS = rgh;
	SPECULAR = .6;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = normal_k;
}
