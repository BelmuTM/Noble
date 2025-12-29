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

const int noiseTextureResolution = 256;

// Maximum values for x amount of bits and their inverses (2^x - 1)
const float maxFloat8     = 255.0;
const float maxFloat16    = 65535.0;
const float rcpMaxFloat8  = 1.0 / maxFloat8;
const float rcpMaxFloat12 = 1.0 / (pow(2.0, 12.0) - 1.0);
const float rcpMaxFloat13 = 1.0 / (pow(2.0, 13.0) - 1.0);
const float rcpMaxFloat16 = 1.0 / maxFloat16;

const float handDepth = MC_HAND_DEPTH * 0.5 + 0.5;
