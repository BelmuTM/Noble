/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2025  Belmu                                                 */
/*                                                                              */
/*    This program is free software: you can redistribute it and/or modify      */
/*    it under the terms of the GNU General Public License as published by      */
/*    the Free Software Foundation, either version 3 of the License, or         */
/*    (at your option) any later version.                                       */
/*                                                                              */
/*    This program is distributed in the hope that it will be useful,           */
/*    but WITHOUT ANY WARRANTY; without even the implied warranty of            */
/*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             */
/*    GNU General Public License for more details.                              */
/*                                                                              */
/*    You should have received a copy of the GNU General Public License         */
/*    along with this program.  If not, see <https://www.gnu.org/licenses/>.    */
/*                                                                              */
/********************************************************************************/

/*
    [Credits]
        Null (https://github.com/null511)
        ninjamike1211
            
        Thanks to them for their help!
*/

const float layerHeight = 1.0 / float(POM_LAYERS);

#if POM_DEPTH_WRITE == 1

    float projectDepth(float depth) {
        return (-gbufferProjection[2].z * depth + gbufferProjection[3].z) / depth * 0.5 + 0.5;
    }

    float unprojectDepth(float depth) {
        return gbufferProjection[3].z / (gbufferProjection[2].z + depth * 2.0 - 1.0);
    }

#endif

void wrapCoordinates(inout vec2 coords) {
    coords -= floor((coords - botLeft) / texSize) * texSize;
}

vec2 localToAtlas(vec2 localCoords) {
    return fract(localCoords) * texSize + botLeft;
}

vec2 atlasToLocal(vec2 atlasCoords) {
    return (atlasCoords - botLeft) / texSize;
}

#if POM == 1

    #include "/include/utility/sampling.glsl"

    float sampleHeightMap(inout vec2 coords, mat2 texDeriv) {
        wrapCoordinates(coords);

        vec2 uv[4];
        vec2 f = getLinearCoords(atlasToLocal(coords), texSize * atlasSize, uv);

        uv[0] = localToAtlas(uv[0]);
        uv[1] = localToAtlas(uv[1]);
        uv[2] = localToAtlas(uv[2]);
        uv[3] = localToAtlas(uv[3]);

        return 1.0 - textureGradLinear(normals, uv, texDeriv, f, 3);
    }

#elif POM == 2

    float sampleHeightMap(inout vec2 coords, mat2 texDeriv) {
        wrapCoordinates(coords);
        return 1.0 - textureGrad(normals, coords, texDeriv[0], texDeriv[1]).a;
    }

#endif

vec2 parallaxMapping(vec3 viewPosition, mat2 texDeriv, inout float height, out vec2 shadowCoords, out float traceDistance) {
    vec3 tangentDirection = normalize(viewToScene(viewPosition)) * tbn;
    traceDistance = 0.0;

    vec2 increment = (tangentDirection.xy / tangentDirection.z) * POM_DEPTH * texSize * layerHeight;

    vec2  currCoords     = textureCoords;
    float currFragHeight = sampleHeightMap(currCoords, texDeriv);

    for (int i = 0; i < POM_LAYERS && traceDistance < currFragHeight; i++) {
        currCoords    -= increment;
        currFragHeight = sampleHeightMap(currCoords, texDeriv);
        traceDistance += layerHeight;
    }

    vec2 prevCoords = currCoords + increment;

    #if POM == 1

        float afterHeight  = currFragHeight - traceDistance;
        float beforeHeight = sampleHeightMap(prevCoords, texDeriv) - traceDistance + layerHeight;
        float heightDelta  = afterHeight - beforeHeight;
        float weight       = heightDelta <= 0.0 ? 0.0 : afterHeight / (afterHeight - beforeHeight);

        vec2 smoothenedCoords = mix(currCoords, prevCoords, weight);

        height       = sampleHeightMap(smoothenedCoords, texDeriv);
        shadowCoords = smoothenedCoords;
        return smoothenedCoords;

    #elif POM == 2

        height       = traceDistance;
        shadowCoords = prevCoords;
        return currCoords;

    #endif
}

#if POM_SHADOWING == 1

    float parallaxShadowing(vec2 parallaxCoords, float height, mat2 texDeriv) {
        vec3  tangentDirection = shadowLightVectorWorld * tbn;
        float currLayerHeight  = height;

        vec2 increment = (tangentDirection.xy / tangentDirection.z) * POM_DEPTH * texSize * layerHeight;

        vec2  currCoords     = parallaxCoords;
        float currFragHeight = 1.0;

        for (int i = 0; i < POM_LAYERS; i++) {
            if (currLayerHeight >= currFragHeight) return 0.0;

            currCoords      += increment;
            currFragHeight   = sampleHeightMap(currCoords, texDeriv);
            currLayerHeight -= layerHeight;
        }
         return 1.0;
    }
    
#endif
