/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

const vec2 off1 = vec2(1.411764705882353);
const vec2 off2 = vec2(3.2941176470588234);
const vec2 off3 = vec2(5.176470588235294);
const vec2 ph = vec2(0.0, 1.0);

vec4 gaussianOnePass(sampler2D tex, vec2 resolution, inout vec4 color) {

    color += texture2D(tex, texCoords) * 0.1964825501511404;
    color += texture2D(tex, texCoords + (off1 * ph / resolution)) * 0.2969069646728344;
    color += texture2D(tex, texCoords - (off1 * ph / resolution)) * 0.2969069646728344;
    color += texture2D(tex, texCoords + (off2 * ph / resolution)) * 0.09447039785044732;
    color += texture2D(tex, texCoords - (off2 * ph / resolution)) * 0.09447039785044732;
    color += texture2D(tex, texCoords + (off3 * ph / resolution)) * 0.010381362401148057;
    color += texture2D(tex, texCoords - (off3 * ph / resolution)) * 0.010381362401148057;
    return color;
}

vec4 fastGaussian(sampler2D tex, vec2 resolution, float size, float quality, float directions) {
    vec4 color = vec4(0.0);
    vec2 radius = size / resolution;
    int SAMPLES;
    for(float d = 0.0; d < PI2; d += PI2 / directions) {
		    for(float i = 1.0 / quality; i <= 1.0; i += 1.0 / quality) {
			    color += texture2D(tex, texCoords + vec2(cos(d), sin(d)) * radius * i);
            SAMPLES++;
        }
    }
    color /= SAMPLES;
    return color / quality * directions;
}
