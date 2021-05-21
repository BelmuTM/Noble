/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

const vec2 off1 = vec2(1.411764705882353f);
const vec2 off2 = vec2(3.2941176470588234f);
const vec2 off3 = vec2(5.176470588235294f);
const vec2 ph = vec2(0.0f, 1.0f);

vec4 gaussianOnePass(sampler2D tex, vec2 resolution, inout vec4 color) {

    color += texture2D(tex, TexCoords) * 0.1964825501511404f;
    color += texture2D(tex, TexCoords + (off1 * ph / resolution)) * 0.2969069646728344f;
    color += texture2D(tex, TexCoords - (off1 * ph / resolution)) * 0.2969069646728344f;
    color += texture2D(tex, TexCoords + (off2 * ph / resolution)) * 0.09447039785044732f;
    color += texture2D(tex, TexCoords - (off2 * ph / resolution)) * 0.09447039785044732f;
    color += texture2D(tex, TexCoords + (off3 * ph / resolution)) * 0.010381362401148057f;
    color += texture2D(tex, TexCoords - (off3 * ph / resolution)) * 0.010381362401148057f;
    return color;
}

vec4 fastGaussian(sampler2D tex, vec2 resolution, float size, float quality, float directions, inout vec4 color) {
    vec2 radius = size / resolution;
    int SAMPLES;
    for(float d = 0.0f; d < PI2; d += PI2 / directions) {
		    for(float i = 1.0f / quality; i <= 1.0f; i += 1.0f / quality) {
			    color += texture2D(tex, TexCoords + vec2(cos(d), sin(d)) * radius * i);
            SAMPLES++;
        }
    }
    color /= SAMPLES;
    return color / quality * directions;
}
