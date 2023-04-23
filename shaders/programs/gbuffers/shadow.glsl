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
    out vec2 texCoords;
    out vec3 worldPosition;
    out vec4 vertexColor;
    out mat3 TBN;

    #include "/include/vertex/animation.glsl"

    void main() {
        texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        vertexColor = gl_Color;
        blockId     = int((mc_Entity.x - 1000.0) + 0.25);

        vec3 viewShadowPos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
             worldPosition = (shadowModelViewInverse * vec4(viewShadowPos, 1.0)).xyz;

        #if WATER_CAUSTICS == 1
            vec3 geoNormal = normalize(gl_NormalMatrix * gl_Normal);
    	    vec3 tangent = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
		    TBN			 = mat3(tangent, cross(tangent, geoNormal) * sign(at_tangent.w), geoNormal);
        #endif

	    #if RENDER_MODE == 0
            animate(worldPosition, texCoords.y < mc_midTexCoord.y);
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
    in vec2 texCoords;
    in vec3 worldPosition;
    in vec4 vertexColor;
    in mat3 TBN;

    #if WATER_CAUSTICS == 1
        // https://medium.com/@evanwallace/rendering-realtime-caustics-in-webgl-2a99a29a0b2c
        // Thanks jakemichie97#7237 for the help!
        float waterCaustics(vec3 oldPos, vec3 normal) {
	        vec3 newPos = oldPos + refract(shadowLightVector, normal, 0.75) * 3.00;

            float oldArea = fastInvSqrtN1(lengthSqr(dFdx(oldPos)) * lengthSqr(dFdy(oldPos)));
            float newArea =    fastSqrtN1(lengthSqr(dFdx(newPos)) * lengthSqr(dFdy(newPos)));
	        return oldArea * newArea;
        }
    #endif

    void main() {
        vec4 albedoTex = texture(tex, texCoords) * vertexColor;
        if(albedoTex.a < 0.102) discard;

        #if WHITE_WORLD == 1
	    	albedoTex.rgb = vec3(1.0);
        #endif

        #if WATER_CAUSTICS == 1
            float caustics = waterCaustics(worldPosition, TBN * getWaterNormals(worldPosition, 2));
            color0         = mix(albedoTex, vec4(vec3(caustics), -1.0), float(blockId == 1));
        #else
            color0 = mix(albedoTex, vec4(1.0, 1.0, 1.0, 0.0), float(blockId == 1));
        #endif
    }
#endif
