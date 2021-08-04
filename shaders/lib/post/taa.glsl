/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

// From Chocapic13, modified by Belmu
vec2 reprojection(vec3 pos) {
    pos = pos * 2.0 - 1.0;

    vec4 viewPosPrev = gbufferProjectionInverse * vec4(pos, 1.0);
    viewPosPrev /= viewPosPrev.w;
    viewPosPrev = gbufferModelViewInverse * viewPosPrev;

    vec3 cameraOffset = cameraPosition - previousCameraPosition;
    cameraOffset *= float(pos.z > MC_HAND_DEPTH);

    vec4 previousPosition = viewPosPrev + vec4(cameraOffset, 0.0);
    previousPosition = gbufferPreviousModelView * previousPosition;
    previousPosition = gbufferPreviousProjection * previousPosition;
    return previousPosition.xy / previousPosition.w * 0.5 + 0.5;
}

/*
    Temporal Anti-Aliasing from "Temporal Reprojection Anti-Aliasing in INSIDE"
    http://s3.amazonaws.com/arena-attachments/655504/c5c71c5507f0f8bf344252958254fb7d.pdf?1468341463
*/

vec3 clipAABB(vec3 prevColor, vec3 minColor, vec3 maxColor) {
    vec3 pClip = 0.5 * (maxColor + minColor); // Center
    vec3 eClip = 0.5 * (maxColor - minColor); // Size

    vec3 vClip = prevColor - pClip;
    vec3 vUnit = vClip / eClip;
    vec3 aUnit = abs(vUnit);
    float denom = max(aUnit.x, max(aUnit.y, aUnit.z));

    return denom > 1.0 ? pClip + vClip / denom : prevColor;
}

vec3 neighborhoodClamping(sampler2D currColorTex, vec3 currColor, vec3 prevColor) {
    vec3 minColor = prevColor, maxColor = prevColor;

    for(int x = -2; x <= 2; x++) {
        for(int y = -2; y <= 2; y++) {
            vec3 color = texture2D(currColorTex, texCoords + vec2(x, y) * pixelSize).rgb; 
            minColor = min(minColor, color); maxColor = max(maxColor, color); 
        }
    }
    return clipAABB(prevColor, minColor, maxColor);
}

vec3 TAA(sampler2D tex, vec3 color) {
    vec2 prevTexCoords = reprojection(vec3(texCoords, texture2D(depthtex1, texCoords).r));
    vec3 prevColor = texture2D(tex, prevTexCoords).rgb;
    prevColor = neighborhoodClamping(tex, color, prevColor);

    vec2 velocity = (texCoords - prevTexCoords) * viewSize;
    float blendFactor = float(clamp(prevTexCoords, vec2(0.0), vec2(1.0)) == prevTexCoords);
    blendFactor *= exp(-length(velocity)) * 0.6 + 0.3;
    blendFactor = clamp(blendFactor + 0.5, EPS, 0.979);

    return mix(color, prevColor, blendFactor); 
}
