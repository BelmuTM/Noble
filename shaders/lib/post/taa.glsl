/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 reprojection(vec3 pos) {
    pos = pos * 2.0 - 1.0;

    vec4 currViewPos = gbufferProjectionInverse * vec4(pos, 1.0);
    currViewPos /= currViewPos.w;
    vec3 currWorldPos = (gbufferModelViewInverse * currViewPos).xyz;

    vec3 cameraOffset = (cameraPosition - previousCameraPosition) * float(pos.z > 0.56);

    vec3 prevWorldPos = currWorldPos + cameraOffset;
    vec4 prevClipPos = gbufferPreviousProjection * gbufferPreviousModelView * vec4(prevWorldPos, 1.0);
    return (prevClipPos.xyz / prevClipPos.w) * 0.5 + 0.5;
}

/*
    AABB Clipping from "Temporal Reprojection Anti-Aliasing in INSIDE"
    http://s3.amazonaws.com/arena-attachments/655504/c5c71c5507f0f8bf344252958254fb7d.pdf?1468341463
*/

vec3 clipAABB(vec3 prevColor, vec3 minColor, vec3 maxColor) {
    vec3 pClip = 0.5 * (maxColor + minColor); // Center
    vec3 eClip = 0.5 * (maxColor - minColor); // Size

    vec3 vClip = prevColor - pClip;
    vec3 aUnit = abs(vClip / eClip);
    float denom = max(aUnit.x, max(aUnit.y, aUnit.z));

    return denom > 1.0 ? pClip + vClip / denom : prevColor;
}

vec3 neighbourhoodClipping(sampler2D currColorTex, vec3 prevColor) {
    vec3 minColor = vec3(1.0), maxColor = vec3(0.0);
    prevColor = linearToYCoCg(prevColor);

    for(int x = -NEIGHBORHOOD_SIZE; x <= NEIGHBORHOOD_SIZE; x++) {
        for(int y = -NEIGHBORHOOD_SIZE; y <= NEIGHBORHOOD_SIZE; y++) {
            vec3 color = texture2D(currColorTex, texCoords + vec2(x, y) * pixelSize).rgb;
            color = linearToYCoCg(color);
            minColor = min(minColor, color); maxColor = max(maxColor, color); 
        }
    }
    return YCoCgToLinear(clipAABB(prevColor, minColor, maxColor));
}

// Thanks LVutner for the help with previous / current textures management!
vec3 computeTAA(sampler2D currTex, sampler2D prevTex) {
    vec2 prevTexCoords = reprojection(vec3(texCoords, texture2D(depthtex1, texCoords).r)).xy;
    vec3 currColor = texture2D(currTex, texCoords).rgb;

    vec3 prevColor = texture2D(prevTex, prevTexCoords).rgb;
    prevColor = neighbourhoodClipping(currTex, prevColor);

    vec3 pos = getViewPos(texCoords);
    vec3 posAt = getViewPos(prevTexCoords);
    float posWeight = 1.0 / max(1e-5, pow(distance(pos, posAt), 2.0));

    float screenWeight = float(saturate(prevTexCoords) == prevTexCoords);
    return mix(currColor, prevColor, TAA_STRENGTH * saturate(screenWeight)); 
}
