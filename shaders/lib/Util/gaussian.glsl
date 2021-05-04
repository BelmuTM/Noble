/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

const vec2 off1 = vec2(1.411764705882353f);
const vec2 off2 = vec2(3.2941176470588234f);
const vec2 off3 = vec2(5.176470588235294f);
const vec2 ph = vec2(0.0f, 1.0f);

vec4 gaussian(vec2 resolution) {
    vec4 color = vec4(0.0f);

    color += texture2D(colortex0, TexCoords) * 0.1964825501511404f;
    color += texture2D(colortex0, TexCoords + (off1 * ph / resolution)) * 0.2969069646728344f;
    color += texture2D(colortex0, TexCoords - (off1 * ph / resolution)) * 0.2969069646728344f;
    color += texture2D(colortex0, TexCoords + (off2 * ph / resolution)) * 0.09447039785044732f;
    color += texture2D(colortex0, TexCoords - (off2 * ph / resolution)) * 0.09447039785044732f;
    color += texture2D(colortex0, TexCoords + (off3 * ph / resolution)) * 0.010381362401148057f;
    color += texture2D(colortex0, TexCoords - (off3 * ph / resolution)) * 0.010381362401148057f;
    return color;
}
