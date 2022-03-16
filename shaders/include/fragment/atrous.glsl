/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

const float aTrous[3] = float[3](1.0, 2.0 / 3.0, 1.0 / 6.0);
const float steps[5]  = float[5](
    ATROUS_STEP_SIZE,
    ATROUS_STEP_SIZE * 0.5,
    ATROUS_STEP_SIZE * 0.25,
    ATROUS_STEP_SIZE * 0.125,
    ATROUS_STEP_SIZE * 0.0625
);

// Thanks swr#1793 and L4mbads#6227 for helping me understand SVGF!
void aTrousFilter(inout vec3 color, sampler2D tex, vec2 coords, int passIndex) {
    Material mat      = getMaterial(coords);
    float totalWeight = EPS;
    vec2 stepSize     = steps[passIndex] * pixelSize;

    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            vec2 sampleCoords  = coords + (vec2(x, y) * stepSize);
            Material sampleMat = getMaterial(sampleCoords);

            float weight  = aTrous[abs(x)] * aTrous[abs(y)];
                  weight *= pow(exp(-abs(linearizeDepth(mat.depth0) - linearizeDepth(sampleMat.depth0))), 1e-3);
                  weight *= pow(clamp01(dot(mat.normal, sampleMat.normal)), 12.0);
           
            color       += texelFetch(tex, ivec2(sampleCoords * viewResolution), 0).rgb * weight;
            totalWeight += weight;
        }
    }
    color /= totalWeight;
}
