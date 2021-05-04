/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

float edgeDetection() {
    float w = 1.0f / viewWidth;
    float h = 1.0f / viewHeight;

    float depth = texture2D(depthtex0, TexCoords).r;
    float depthW0 = texture2D(depthtex0, TexCoords + vec2(w, 0.0f)).r;
    float depthH0 = texture2D(depthtex0, TexCoords + vec2(0.0f, -h)).r;
    float depthW1 = texture2D(depthtex0, TexCoords + vec2(-w, 0.0f)).r;
    float depthH1 = texture2D(depthtex0, TexCoords + vec2(0.0f, h)).r;

    float ddx = abs((depthW0 - depth) - (depth - depthW1));
    float ddy = abs((depthH0 - depth) - (depth - depthH1));
    return clamp(clamp(ddx + ddy, 0.0f, 2.0f) / (depth * 0.0005f), -1.0f, 1.0f);
}
