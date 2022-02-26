/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 reprojection(vec3 pos) {
    pos = pos * 2.0 - 1.0;

    vec4 currPos = gbufferProjectionInverse * vec4(pos, 1.0);
    currPos     /= currPos.w;
    currPos      = gbufferModelViewInverse * currPos;

    vec3 cameraOffset = (cameraPosition - previousCameraPosition) * float(pos.z > 0.56);
    
    vec4 prevPos = currPos + vec4(cameraOffset, 0.0);
         prevPos = gbufferPreviousModelView  * prevPos;
         prevPos = gbufferPreviousProjection * prevPos;
    return (prevPos.xyz / prevPos.w) * 0.5 + 0.5;
}

/*
    AABB Clipping from "Temporal Reprojection Anti-Aliasing in INSIDE"
    http://s3.amazonaws.com/arena-attachments/655504/c5c71c5507f0f8bf344252958254fb7d.pdf?1468341463
*/

vec3 clipAABB(vec3 prevColor, vec3 minColor, vec3 maxColor) {
    vec3 pClip = 0.5 * (maxColor + minColor); // Center
    vec3 eClip = 0.5 * (maxColor - minColor); // Size

    vec3 vClip  = prevColor - pClip;
    vec3 aUnit  = abs(vClip / eClip);
    float denom = max(aUnit.x, max(aUnit.y, aUnit.z));

    return denom > 1.0 ? pClip + vClip / denom : prevColor;
}

vec3 neighbourhoodClipping(sampler2D currTex, vec3 prevColor) {
    vec3 minColor = vec3(1e5), maxColor = vec3(-1e5);

    for(int x = -NEIGHBORHOOD_SIZE; x <= NEIGHBORHOOD_SIZE; x++) {
        for(int y = -NEIGHBORHOOD_SIZE; y <= NEIGHBORHOOD_SIZE; y++) {
            vec3 color = linearToYCoCg(texture(currTex, texCoords + vec2(x, y) * pixelSize).rgb);
            minColor = min(minColor, color); maxColor = max(maxColor, color); 
        }
    }
    return clipAABB(prevColor, minColor, maxColor);
}

float getLumaWeight(vec3 currColor, vec3 prevColor) {
    float currLuma   = luminance(currColor), prevLuma = luminance(prevColor);
    float lumaWeight = exp(-abs(currLuma - prevLuma) / max(currLuma, max(prevLuma, TAA_LUMA_MIN)));
	return mix(TAA_FEEDBACK_MIN, TAA_FEEDBACK_MAX, pow2(lumaWeight));
}

// Thanks LVutner for the help with TAA (buffer management, luminance weight)
// https://github.com/LVutner
vec3 temporalAntiAliasing(sampler2D currTex, sampler2D prevTex) {
    vec3 prevPos = reprojection(vec3(texCoords, texture(depthtex1, texCoords).r));

    vec3 currColor = linearToYCoCg(texture(currTex, texCoords).rgb);
    vec3 prevColor = linearToYCoCg(texture(prevTex, prevPos.xy).rgb);
         prevColor = neighbourhoodClipping(currTex, prevColor);

    float blendWeight = float(clamp01(prevPos.xy) == prevPos.xy);

    #if ACCUMULATION_VELOCITY_WEIGHT == 0
        vec4 weightTex   = texture(colortex10, texCoords);
        float lumaWeight = getLumaWeight(currColor, prevColor);

        float normalWeight = pow(clamp01(dot(getMaterial(texCoords).normal, weightTex.rgb)), 8.0);
        float depthWeight  = pow(exp(-abs(linearizeDepth(prevPos.z) - linearizeDepth(texture(colortex10, prevPos.xy).a))), 1e-3);
        
        blendWeight *= (normalWeight * depthWeight * TAA_STRENGTH);
    #else
        float historyFrames = texture(colortex5, texCoords).a;
        blendWeight        *= 1.0 - (1.0 / max(historyFrames, 1.0));
    #endif

    return YCoCgToLinear(mix(currColor, prevColor, blendWeight)); 
}
