/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 reprojection(vec3 screenPos) {
    screenPos = screenPos * 2.0 - 1.0;

    vec4 position = gbufferProjectionInverse * vec4(screenPos, 1.0);
         position = gbufferModelViewInverse * (position / position.w);

    vec3 cameraOffset = (cameraPosition - previousCameraPosition) * float(screenPos.z > 0.56);
    
    position += vec4(cameraOffset, 0.0);
    position  = gbufferPreviousModelView  * position;
    position  = gbufferPreviousProjection * position;

    return (position.xyz / position.w) * 0.5 + 0.5;
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
            vec3 color = linearToYCoCg(texelFetch(currTex, ivec2(gl_FragCoord.xy) + ivec2(x, y), 0).rgb);
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
vec3 temporalAntiAliasing(Material currMat, sampler2D currTex, sampler2D prevTex) {
    vec3 prevPos = reprojection(vec3(texCoords, currMat.depth0));

    vec3 currColor = texelFetch(currTex, ivec2(gl_FragCoord.xy), 0).rgb;
    vec3 prevColor = linearToYCoCg(texture(prevTex, prevPos.xy).rgb);
         prevColor = neighbourhoodClipping(currTex, prevColor);
         prevColor = YCoCgToLinear(prevColor);

    float blendWeight  = float(clamp01(prevPos.xy) == prevPos.xy);

    float lumaWeight   = getLumaWeight(currColor, prevColor);
    float depthWeight  = pow(exp(-abs(linearizeDepth(currMat.depth0) - linearizeDepth(texture(colortex9, prevPos.xy).a))), TAA_DEPTH_WEIGHT);
    //float normalWeight = pow(clamp01(dot(currMat.normal, texture(colortex9, prevPos.xy).rgb * 2.0 - 1.0)), TAA_NORMAL_WEIGHT);
        
    blendWeight *= (depthWeight * lumaWeight);

    return mix(currColor, prevColor, blendWeight); 
}
