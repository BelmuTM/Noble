/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#if defined STAGE_VERTEX

    out vec3 scenePosition;
    out vec4 vertexColor;

    void main() {
        vertexColor = gl_Color;

        scenePosition = transform(shadowModelViewInverse, transform(gl_ModelViewMatrix, gl_Vertex.xyz));

        gl_Position     = ftransform();
        gl_Position.xyz = distortShadowSpace(gl_Position.xyz);
    }
    
#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 0 */

    layout (location = 0) out vec4 shadowmap;

    in vec3 scenePosition;
    in vec4 vertexColor;

    void main() {
        float viewDistance = length(scenePosition);
        if(viewDistance < 0.5 * far) { discard; return; }

        shadowmap = vertexColor;
    }
    
#endif
