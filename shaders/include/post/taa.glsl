/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/*
    AABB Clipping from "Temporal Reprojection Anti-Aliasing in INSIDE"
    http://s3.amazonaws.com/arena-attachments/655504/c5c71c5507f0f8bf344252958254fb7d.pdf?1468341463
*/

vec3 clipAABB(vec3 prevColor, vec3 minColor, vec3 maxColor) {
    vec3 pClip = 0.5 * (maxColor + minColor); // Center
    vec3 eClip = 0.5 * (maxColor - minColor); // Size

    vec3 vClip  = prevColor - pClip;
    float denom = maxOf(abs(vClip / eClip));

    return denom > 1.0 ? pClip + vClip / denom : prevColor;
}

vec3 neighbourhoodClipping(sampler2D currTex, vec3 prevColor) {
    vec3 minColor = vec3(1e10), maxColor = vec3(-1e10);

    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            vec3 color = SRGB_2_YCoCg_MAT * texelFetch(currTex, ivec2(gl_FragCoord.xy) + ivec2(x, y), 0).rgb;
            minColor = min(minColor, color); 
            maxColor = max(maxColor, color); 
        }
    }
    return clipAABB(prevColor, minColor, maxColor);
}

vec3 getClosestFragment(vec3 position) {
	vec3 closestFragment = position;
    vec3 currentFragment;

    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            currentFragment.xy = position.xy + vec2(x, y) * pixelSize;
            currentFragment.z  = texture(depthtex0, currentFragment.xy).r;
            closestFragment    = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;
        }
    }
    return closestFragment;
}

vec3 temporalAntiAliasing(sampler2D currTex, sampler2D prevTex) {
    vec3 closestFragment = getClosestFragment(vec3(texCoords, texture(depthtex0, texCoords).r));
    vec2 prevCoords      = texCoords - getVelocity(closestFragment).xy;

    vec3 currColor = SRGB_2_YCoCg_MAT * textureCatmullRom(currTex, texCoords).rgb;
    vec3 prevColor = SRGB_2_YCoCg_MAT * textureCatmullRom(prevTex, prevCoords).rgb;
         prevColor = neighbourhoodClipping(currTex, prevColor);

    float weight = float(clamp01(prevCoords) == prevCoords) * TAA_STRENGTH;

    // Offcenter rejection from Zombye#7365 (Spectrum - https://github.com/zombye/spectrum)
    vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(prevCoords * viewSize) - 1.0);
         weight         *= sqrt(pixelCenterDist.x * pixelCenterDist.y) * TAA_OFFCENTER_REJECTION + (1.0 - TAA_OFFCENTER_REJECTION);

    return YCoCg_2_SRGB_MAT * mix(currColor, prevColor, clamp01(weight)); 
}
