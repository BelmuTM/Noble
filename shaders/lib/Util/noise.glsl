float rand(vec2 x) {
	  return fract(sin(dot(x, vec2(12.9898f, 4.1414f))) * 43758.5453f);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031f);
    p3 += dot(p3, p3.yzx + 33.33f);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
		vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031f, 0.1030f, 0.0973f));
    p3 += dot(p3, p3.yzx + 33.33f);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 hash33(vec3 pos) {
	  pos = vec3(dot(pos, vec3(127.1f, 311.7f, 74.7f)),
			    		dot(pos, vec3(269.5f, 183.3f, 246.1f)),
			    		dot(pos, vec3(113.5f, 271.9f, 124.6f)));

	  return fract(sin(pos) * 43758.5453123f);
}

float noise(vec2 p) {
	  vec2 ip = floor(p);
	  vec2 u = fract(p);
	  u = u * u * (3.0f - 2.0f * u);

	  float res = mix(
		   mix(rand(ip), rand(ip + vec2(1.0f, 0.0f)), u.x),
		   mix(rand(ip + vec2(0.0f, 1.0f)), rand(ip + vec2(1.0f, 1.0f)), u.x), u.y);
	  return res * res;
}
