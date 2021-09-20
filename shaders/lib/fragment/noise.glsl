/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

// Certain functions below aren't my property. They either are public domain
// or require to credit the author.

vec2 vogelDisk(int index, int samplesCount) {
    float r = sqrt(index + 0.5) / sqrt(samplesCount);
    float theta = index * GOLDEN_ANGLE;
    return r * vec2(cos(theta), sin(theta));
}

float rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 4.1414))) * 43758.5453);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 hash32(vec2 p) {
    vec3 q = vec3(dot(p, vec2(127.1, 311.7)), 
			      dot(p, vec2(269.5, 183.3)), 
			      dot(p, vec2(419.2, 371.9)));
	return fract(sin(q) * 43758.5453);
}

vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
		     dot(p, vec3(269.5, 183.3, 246.1)),
		     dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}

vec4 hash43(vec3 p) {
	vec4 p4 = fract(vec4(p.xyzx) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

float noise(vec2 p) {
	vec2 ip = floor(p);
	vec2 u = fract(p);
	u = u * u * (3.0 - 2.0 * u);

	float res = mix(
		mix(rand(ip), rand(ip + vec2(1.0, 0.0)), u.x),
		mix(rand(ip + vec2(0.0, 1.0)), rand(ip + vec2(1.0, 1.0)), u.x), u.y);
	return res * res;
}

const vec3 interleavedConstants = vec3(0.06711056, 0.00583715, 52.9829189);

float interleavedGradientNoise(vec2 p) {
    float f = interleavedConstants.x * p.x + interleavedConstants.y * p.y;
    return fract(interleavedConstants.z * fract(f));
}

vec2 interleavedGradientNoise2D(vec2 p) {
    vec2 x = vec2(dot(p, interleavedConstants.xy), dot(p, interleavedConstants.yx));
    return fract(interleavedConstants.z * fract(x));
}

float FBM(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;

    for(int i = 0; i < octaves; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

vec3 blueNoise() {
    return texelFetch(noisetex, ivec2(mod(gl_FragCoord, noiseRes)), 0).rgb;
}

vec2 uniformAnimatedNoise() {
    vec2 noise = hash22(gl_FragCoord.xy);
    return fract(noise + vec2(GOLDEN_RATIO * frameTimeCounter, (GOLDEN_RATIO + GOLDEN_RATIO) * mod(frameTimeCounter, 100.0)));
}

vec2 uniformNoise(int i) {
    vec2 noise = texture2D(noisetex, texCoords).rg;
    noise.x = fract(noise.x + GOLDEN_RATIO * i);
    noise.y = fract(noise.y + (GOLDEN_RATIO + GOLDEN_RATIO) * i);
    return noise;
}

// Gold Noise ©2015 dcerisano@standard3d.com
float gold_noise(vec2 xy, float seed){
    return fract(tan(distance(xy * GOLDEN_RATIO, xy) * seed) * xy.x);
}

//	<https://www.shadertoy.com/view/Xd23Dh>
//	by inigo quilez <http://iquilezles.org/www/articles/voronoise/voronoise.htm>
float voronoise(in vec2 p, float u, float v) {
	float k = 1.0 + 63.0 * pow(1.0 - v, 6.0);
    vec2 i = floor(p);
    vec2 f = fract(p);
	vec2 a = vec2(0.0, 0.0);

    for(int y = -2; y <= 2; y++) {
        for(int x = -2; x <= 2; x++) {

            vec2 g = vec2(x, y);
		    vec3 o = hash32(i + g) * vec3(u, u, 1.0);
		    vec2 d = g - f + o.xy;
		    float w = pow(1.0 - smoothstep(0.0, 1.414, length(d)), k);
		    a += vec2(o.z * w, w);
        }
    }
    return a.x / a.y;
}
