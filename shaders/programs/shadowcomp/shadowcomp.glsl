/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#if defined STAGE_VERTEX

    out vec2 textureCoords;

    void main() {
        gl_Position   = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
        textureCoords = gl_Vertex.xy;
    }
    
#elif defined STAGE_FRAGMENT

    layout (location = 0) out vec4 shadowmap;

    in vec2 textureCoords;

    #if WATER_CAUSTICS == 1
        #include "/include/fragment/gerstner.glsl"

        // https://medium.com/@evanwallace/rendering-realtime-caustics-in-webgl-2a99a29a0b2c
        float waterCaustics(vec3 oldPos, vec3 normal) {
	        vec3 newPos = oldPos + refract(shadowLightVector, normal, rcp(1.333)) * 10.0;

            float oldArea = length(dFdx(oldPos)) * length(dFdy(oldPos));
            float newArea = length(dFdx(newPos)) * length(dFdy(newPos));
	        return oldArea / newArea * 0.2;
        }
    #endif

    vec3 screenToShadow(vec3 position) {
        position     = position * 2.0 - 1.0;
        position.xy *= getDistortionFactor(position.xy);
        position.z  /= SHADOW_DEPTH_STRETCH;
        position     = projectOrthogonal(shadowProjectionInverse, position);

        return transform(shadowModelViewInverse, position);
    }

    void main() {
        vec4 albedoTex = texture(shadowcolor0, textureCoords);

        shadowmap = albedoTex;

        /*
        #if WATER_CAUSTICS == 1

            if(albedoTex.a - 1e-2 < 0.333 && albedoTex.a + 1e-2 > 0.333) {
                shadowmap.a = 0.0;

                vec3 scenePosition = screenToShadow(vec3(textureCoords, texture(shadowtex0, textureCoords).r));
                vec3 worldPosition = scenePosition + cameraPosition;

                vec3  waterNormals = getWaterNormals(worldPosition, 8);
                float caustics     = waterCaustics(scenePosition, waterNormals) * WATER_CAUSTICS_STRENGTH;

                shadowmap.rgb += caustics;
            }

        #endif
        */
    }
    
#endif
