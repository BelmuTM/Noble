/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 4,3 */

layout (location = 0) out vec4 color;
layout (location = 1) out vec3 bloomBuffer;

#if BLOOM == 1
    #include "/include/post/bloom.glsl"
#endif

#if DOF == 1
    // https://en.wikipedia.org/wiki/Circle_of_confusion#Determining_a_circle_of_confusion_diameter_from_the_object_field
    float getCoC(float fragDepth, float cursorDepth) {
        return fragDepth < MC_HAND_DEPTH ? 0.0 : abs((FOCAL / APERTURE) * ((FOCAL * (cursorDepth - fragDepth)) / (fragDepth * (cursorDepth - FOCAL)))) * 0.5;
    }

    void depthOfField(inout vec3 color, sampler2D tex, vec2 coords, int quality, float radius, float coc) {
        vec3 dof   = vec3(0.0);
        vec2 noise = vec2(randF(), randF());

        float distFromCenter = pow2(distance(coords, vec2(0.5)));
        vec2  caOffset       = vec2(distFromCenter) * coc / pow2(quality);

        for(int x = 0; x < quality; x++) {
            for(int y = 0; y < quality; y++) {
                vec2 offset = ((vec2(x, y) + noise) - quality * 0.5) * rcp(quality);
            
                if(length(offset) < 0.5) {
                    vec2 sampleCoords = coords + (offset * radius * coc * pixelSize);

                    dof += vec3(
                        texture(tex, sampleCoords + caOffset).r,
                        texture(tex, sampleCoords).g,
                        texture(tex, sampleCoords - caOffset).b
                    );
                }
            }
        }
        color = dof * rcp(pow2(quality));
    }
#endif

void main() {
    color   = texture(colortex4, texCoords);
    color.a = sqrt(luminance(color.rgb));
    
    #if DOF == 1
        float depth0 = texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r;
        float coc    = getCoC(linearizeDepthFast(depth0), linearizeDepthFast(centerDepthSmooth));

        depthOfField(color.rgb, colortex4, texCoords, 8, DOF_RADIUS, coc);
    #endif

    #if BLOOM == 1
        writeBloom(bloomBuffer);
    #endif
}
