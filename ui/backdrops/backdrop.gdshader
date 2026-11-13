shader_type canvas_item;
// The placeholder Backdrops (game glossary, ADR 0035): a landscape hint for each color,
// drawn on the 320 x 180 grid a Backdrop's picture has, with hard edges, until each has a
// picture of its own. kind: 0 white, 1 blue, 2 black, 3 red, 4 green.

uniform int kind = 0;

const vec2 GRID = vec2(320.0, 180.0);
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float weight = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		total += weight * noise(p);
		p *= 2.03;
		weight *= 0.5;
	}
	return total;
}

// Sharp peaks, 0..1.
float peaks(float x, float seed) {
	float total = 0.0;
	float weight = 0.5;
	float at = x;
	for (int octave = 0; octave < 4; octave++) {
		total += weight * (1.0 - abs(2.0 * noise(vec2(at, seed)) - 1.0));
		at *= 2.1;
		weight *= 0.5;
	}
	return total;
}

float dither(vec2 cell) {
	int x = int(mod(cell.x, 4.0));
	int y = int(mod(cell.y, 4.0));
	return (BAYER[y * 4 + x] + 0.5) / 16.0;
}

// One of four tones for t in 0..1, dithered between neighbors.
vec3 ramp(vec3 a, vec3 b, vec3 c, vec3 d, float t, vec2 cell) {
	float step_at = floor(clamp(t, 0.0, 0.999) * 3.0 + dither(cell));
	if (step_at < 0.5) {
		return a;
	} else if (step_at < 1.5) {
		return b;
	} else if (step_at < 2.5) {
		return c;
	}
	return d;
}

// Whether the cell is on a trunk of a row of trunks about `spacing` apart.
float trunk(vec2 cell, float spacing, float width, float seed) {
	float column = floor(cell.x / spacing);
	float center = (column + 0.2 + 0.6 * hash(vec2(column, seed))) * spacing;
	float half_width = width * (0.6 + 0.8 * hash(vec2(column, seed + 7.0)));
	float lean = (hash(vec2(column, seed + 3.0)) - 0.5) * 0.08 * (GRID.y - cell.y);
	return step(abs(cell.x - center - lean), half_width) * step(0.25, hash(vec2(column, seed + 11.0)));
}

vec3 white_scene(vec2 cell) {
	float horizon = 96.0;
	if (cell.y < horizon) {
		float t = cell.y / horizon;
		float glow = 1.0 - clamp(distance(cell, vec2(160.0, horizon)) / 170.0, 0.0, 1.0);
		vec3 sky = ramp(vec3(0.62, 0.68, 0.78), vec3(0.76, 0.79, 0.84), vec3(0.90, 0.87, 0.80), vec3(0.99, 0.95, 0.82), t * 0.6 + glow * 0.5, cell);
		float cloud = fbm(vec2(cell.x / 46.0, cell.y / 9.0));
		if (cloud > 0.60 && cell.y < 70.0) {
			sky = vec3(0.97, 0.96, 0.93);
		}
		float hill = horizon - 5.0 - 12.0 * fbm(vec2(cell.x / 55.0, 3.0));
		if (cell.y > hill) {
			sky = vec3(0.70, 0.72, 0.70);
		}
		return sky;
	}
	float depth = (cell.y - horizon) / (GRID.y - horizon);
	float across = (cell.x - 160.0) / (depth + 0.12);
	float row = step(0.5, fract(across / 90.0));
	vec3 field = mix(vec3(0.86, 0.78, 0.50), vec3(0.93, 0.86, 0.60), row);
	if (dither(cell) < 0.25 + 0.2 * noise(cell / 5.0) && depth > 0.15) {
		field *= 0.93;
	}
	return field;
}

vec3 blue_scene(vec2 cell) {
	float horizon = 78.0;
	if (cell.y < horizon) {
		float t = cell.y / horizon;
		vec3 sky = ramp(vec3(0.10, 0.20, 0.45), vec3(0.16, 0.33, 0.62), vec3(0.28, 0.52, 0.78), vec3(0.55, 0.78, 0.90), t, cell);
		float cloud = fbm(vec2(cell.x / 50.0, cell.y / 11.0 + 4.0));
		if (cloud > 0.58) {
			sky = mix(vec3(0.80, 0.90, 0.96), vec3(0.62, 0.78, 0.90), step(cloud, 0.61));
		}
		return sky;
	}
	float depth = (cell.y - horizon) / (GRID.y - horizon);
	float wave = noise(vec2(cell.x / (5.0 + 40.0 * depth), cell.y * (0.9 - 0.6 * depth)));
	vec3 sea = ramp(vec3(0.05, 0.12, 0.32), vec3(0.08, 0.20, 0.46), vec3(0.12, 0.30, 0.58), vec3(0.20, 0.44, 0.70), wave * 0.8 + (1.0 - depth) * 0.25, cell);
	if (wave > 0.80) {
		sea = vec3(0.62, 0.82, 0.92);
	}
	return sea;
}

vec3 black_scene(vec2 cell) {
	float ground = 124.0;
	float t = cell.y / ground;
	float fog = fbm(vec2(cell.x / 60.0, cell.y / 14.0));
	vec3 scene = ramp(vec3(0.10, 0.08, 0.14), vec3(0.17, 0.14, 0.22), vec3(0.26, 0.24, 0.30), vec3(0.38, 0.40, 0.38), t * 0.75 + fog * 0.3, cell);
	if (distance(cell, vec2(236.0, 34.0)) < 13.0) {
		scene = vec3(0.78, 0.80, 0.70);
	}
	if (cell.y > ground) {
		float depth = (cell.y - ground) / (GRID.y - ground);
		float streak = noise(vec2(cell.x / 26.0, cell.y / 2.0));
		scene = ramp(vec3(0.05, 0.05, 0.08), vec3(0.09, 0.09, 0.13), vec3(0.14, 0.16, 0.17), vec3(0.24, 0.27, 0.25), streak * 0.9 - depth * 0.2, cell);
		// Trunks mirrored in the water.
		vec2 mirrored = vec2(cell.x, ground - (cell.y - ground) * 1.6);
		if (trunk(mirrored, 34.0, 2.0, 1.0) > 0.5 && mod(cell.y, 2.0) < 1.0) {
			scene = vec3(0.04, 0.04, 0.06);
		}
		return scene;
	}
	float far_top = 30.0 + 40.0 * hash(vec2(floor(cell.x / 19.0), 5.0));
	if (trunk(cell, 19.0, 1.0, 5.0) > 0.5 && cell.y > far_top) {
		scene = vec3(0.14, 0.12, 0.18);
	}
	float near_top = 6.0 + 30.0 * hash(vec2(floor(cell.x / 34.0), 1.0));
	if (trunk(cell, 34.0, 2.0, 1.0) > 0.5 && cell.y > near_top) {
		scene = vec3(0.04, 0.04, 0.06);
	}
	return scene;
}

vec3 red_scene(vec2 cell) {
	float t = cell.y / 130.0;
	float haze = fbm(vec2(cell.x / 70.0, cell.y / 12.0));
	vec3 scene = ramp(vec3(0.30, 0.07, 0.08), vec3(0.52, 0.13, 0.09), vec3(0.78, 0.30, 0.12), vec3(0.96, 0.60, 0.22), t * 0.8 + haze * 0.25, cell);
	float far = 120.0 - 70.0 * peaks(cell.x / 80.0, 2.0);
	if (cell.y > far) {
		scene = mix(vec3(0.60, 0.26, 0.22), vec3(0.50, 0.20, 0.18), step(0.5, dither(cell) + (cell.y - far) / 60.0 - 0.3));
	}
	float mid = 150.0 - 75.0 * peaks(cell.x / 60.0 + 9.0, 5.0);
	if (cell.y > mid) {
		// Lit on the left face of each peak.
		float lit = step(mid - (150.0 - 75.0 * peaks((cell.x + 1.0) / 60.0 + 9.0, 5.0)), 0.0);
		scene = mix(vec3(0.30, 0.09, 0.09), vec3(0.42, 0.13, 0.11), lit);
	}
	float near = 186.0 - 60.0 * peaks(cell.x / 45.0 + 30.0, 8.0);
	if (cell.y > near) {
		scene = vec3(0.14, 0.04, 0.05);
	}
	return scene;
}

vec3 green_scene(vec2 cell) {
	float shaft = fbm(vec2((cell.x + cell.y * 0.5) / 34.0, 1.0));
	float t = 1.0 - abs(cell.y - 70.0) / 110.0;
	vec3 scene = ramp(vec3(0.05, 0.16, 0.09), vec3(0.09, 0.27, 0.13), vec3(0.18, 0.42, 0.18), vec3(0.42, 0.62, 0.28), t * 0.55 + shaft * 0.5, cell);
	if (trunk(cell, 15.0, 1.0, 21.0) > 0.5) {
		scene = vec3(0.10, 0.22, 0.12);
	}
	if (trunk(cell, 44.0, 4.0, 13.0) > 0.5) {
		float bark = step(0.5, noise(vec2(cell.x / 2.0, cell.y / 9.0)));
		scene = mix(vec3(0.13, 0.09, 0.06), vec3(0.20, 0.14, 0.08), bark);
	}
	float canopy = 26.0 + 30.0 * fbm(vec2(cell.x / 24.0, 7.0));
	if (cell.y < canopy) {
		float leaf = noise(cell / 3.0);
		scene = mix(vec3(0.04, 0.14, 0.07), vec3(0.10, 0.30, 0.12), step(0.62, leaf));
	}
	float floor_top = 150.0 - 14.0 * fbm(vec2(cell.x / 30.0, 12.0));
	if (cell.y > floor_top) {
		float fern = noise(vec2(cell.x / 3.0, cell.y / 2.0));
		scene = mix(vec3(0.05, 0.15, 0.07), vec3(0.16, 0.36, 0.14), step(0.60, fern));
	}
	return scene;
}

void fragment() {
	vec2 cell = floor(UV * GRID);
	vec3 scene;
	if (kind == 0) {
		scene = white_scene(cell);
	} else if (kind == 1) {
		scene = blue_scene(cell);
	} else if (kind == 2) {
		scene = black_scene(cell);
	} else if (kind == 3) {
		scene = red_scene(cell);
	} else {
		scene = green_scene(cell);
	}
	COLOR = vec4(scene, 1.0);
}
