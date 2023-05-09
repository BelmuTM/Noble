/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/common.glsl"

#if defined STAGE_VERTEX
    #define attribute in
    attribute vec4 at_tangent;
    attribute vec3 mc_Entity;
    attribute vec2 mc_midTexCoord;

    flat out int blockId;
    out vec2 textureCoords;
    out vec3 worldPosition;
    out vec4 vertexColor;
    out mat3 tbn;

    #include "/include/vertex/animation.glsl"

    void main() {
        textureCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        vertexColor   = gl_Color;
        blockId       = int((mc_Entity.x - 1000.0) + 0.25);

        vec3 viewShadowPos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
             worldPosition = transform(shadowModelViewInverse, viewShadowPos);

        #if WATER_CAUSTICS == 1
    	    tbn[2] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
    	    tbn[0] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
		    tbn[1] = cross(tbn[0], tbn[2]) * sign(at_tangent.w);
        #endif

	    #if RENDER_MODE == 0 && WAVING_PLANTS == 1
            animate(worldPosition, textureCoords.y < mc_midTexCoord.y, getSkylightFalloff(gl_MultiTexCoord1.y * rcp(240.0)));
            gl_Position = transform(shadowModelView, worldPosition).xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];
	    #else
            gl_Position = ftransform();
        #endif

        worldPosition  += cameraPosition;
        gl_Position.xyz = distortShadowSpace(gl_Position.xyz);
    }
    
#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 0 */

    layout (location = 0) out vec4 color0;

    flat in int blockId;
    in vec2 textureCoords;
    in vec3 worldPosition;
    in vec4 vertexColor;
    in mat3 tbn;

    #if WATER_CAUSTICS == 1
        // https://medium.com/@evanwallace/rendering-realtime-caustics-in-webgl-2a99a29a0b2c
        // Thanks jakemichie97#7237 for the help!
        float waterCaustics(vec3 oldPos, vec3 normal) {
	        vec3 newPos = oldPos + refract(shadowLightVector, normal, 0.75) * 3.0;

            float oldArea = fastInvSqrtN1(lengthSqr(dFdx(oldPos)) * lengthSqr(dFdy(oldPos)));
            float newArea =    fastSqrtN1(lengthSqr(dFdx(newPos)) * lengthSqr(dFdy(newPos)));
	        return oldArea * newArea;
        }
    #endif

    void main() {
        vec4 albedoTex = texture(tex, textureCoords) * vertexColor;
        if(albedoTex.a < 0.102) discard;

        #if WHITE_WORLD == 1
	    	albedoTex.rgb = vec3(1.0);
        #endif

        #if WATER_CAUSTICS == 1
            float caustics = 1.0 + saturate(1.0 - waterCaustics(worldPosition, tbn * getWaterNormals(worldPosition, int(WATER_OCTAVES * 0.5))));
            color0         = mix(albedoTex, vec4(caustics, caustics, caustics, 0.0), float(blockId == WATER_ID));
        #else
            color0 = mix(albedoTex, vec4(1.0, 1.0, 1.0, 0.0), float(blockId == WATER_ID));
        #endif
    }
#endif
