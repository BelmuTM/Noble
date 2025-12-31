/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2026  Belmu                                                 */
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

#include "/settings.glsl"

#if defined STAGE_VERTEX

    void main() {
        gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 5 */

    layout (location = 0) out vec3 bloom;

    void main() {
        bloom = vec3(0.0);
    }
    
#endif
