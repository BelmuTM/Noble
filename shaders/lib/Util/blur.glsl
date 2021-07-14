/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

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

vec4 bilateralBlur(sampler2D tex) {
    vec4 color = vec4(0.0);

    int SAMPLES;
    for(int x = -4 ; x <= 4; x++) {
        for(int y = -4; y <= 4; y++) {
            vec2 offset = vec2(y, x) * pixelSize;
            color += texture2D(tex, texCoords + offset);
            SAMPLES++;
        }
    }
    return color / SAMPLES;
}

// Got help from: https://catlikecoding.com/unity/tutorials/advanced-rendering/depth-of-field/
vec4 bokeh(sampler2D tex) {
    vec4 color = vec4(0.0);
    vec2 noise = vec2(bayer64(gl_FragCoord.xy), bayer64(gl_FragCoord.yx));
    noise = fract(frameTimeCounter + noise);

    int SAMPLES;
    for(int i = 0; i < BOKEH_SAMPLES; i++) {
        for(int j = 0; j < BOKEH_SAMPLES; j++) {

            vec2 offset = ((vec2(i, j) + noise) - BOKEH_SAMPLES / 2.0) / BOKEH_SAMPLES;
            if(length(offset) < 0.5) {
                color += texture2D(tex, texCoords + offset * BOKEH_RADIUS / vec2(aspectRatio, 1.0));
                SAMPLES++;
            }
        }
    }
    return color / SAMPLES;
}
