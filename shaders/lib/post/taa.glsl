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

    vec3 cameraOffset = (cameraPosition - previousCameraPosition) * float(pos.z > MC_HAND_DEPTH);

    vec4 prevPos = viewPosPrev + vec4(cameraOffset, 0.0);
    prevPos = gbufferPreviousModelView * prevPos;
    prevPos = gbufferPreviousProjection * prevPos;
    return (prevPos.xy / prevPos.w) * 0.5 + 0.5;
}

vec3 screenToWorld(float depth, vec2 coords, mat4 projection, mat4 modelView) {
    vec4 clipPos = vec4(coords * 2.0 - 1.0, depth, 1.0);
    vec4 viewPos = inverse(projection) * clipPos;
    viewPos /= viewPos.w;
    return (inverse(modelView) * viewPos).xyz;
}

/*
    AABB Clipping from "Temporal Reprojection Anti-Aliasing in INSIDE"
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

vec3 neighbourhoodClamping(sampler2D currColorTex, vec3 prevColor) {
    vec3 minColor = vec3(0.0), maxColor = vec3(0.0); 
    const int size = 4;

    for(int x = -size; x <= size; x++) {
        for(int y = -size; y <= size; y++) {
            vec3 color = texture2D(currColorTex, texCoords + vec2(x, y) * pixelSize).rgb; 
            minColor = min(minColor, color); maxColor = max(maxColor, color); 
        }
    }
    return clipAABB(prevColor, minColor, maxColor);
}

// Thanks LVutner for the help with previous / current textures management!
vec3 computeTAA(sampler2D currTex, sampler2D prevTex) {
    vec2 prevTexCoords = reprojection(vec3(texCoords, texture2D(depthtex1, texCoords).r));
    vec3 currColor = texture2D(currTex, texCoords).rgb;

    vec3 prevColor = texture2D(prevTex, prevTexCoords).rgb;
    prevColor = neighbourhoodClamping(currTex, prevColor);

    vec2 velocity = (texCoords - prevTexCoords) * viewSize;
    float blendFactor = exp(-length(velocity)) * 0.6 + 0.3;
          blendFactor *= float(clamp(prevTexCoords, 0.0, 1.0) == prevTexCoords);

    return mix(currColor, prevColor, blendFactor); 
}
