################################################################################
#                                                                              #
#    Noble Shaders                                                             #
#    Copyright (C) 2026  Belmu                                                 #
#                                                                              #
#    This program is free software: you can redistribute it and/or modify      #
#    it under the terms of the GNU General Public License as published by      #
#    the Free Software Foundation, either version 3 of the License, or         #
#    (at your option) any later version.                                       #
#                                                                              #
#    This program is distributed in the hope that it will be useful,           #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of            #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             #
#    GNU General Public License for more details.                              #
#                                                                              #
#    You should have received a copy of the GNU General Public License         #
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.    #
#                                                                              #
################################################################################

from numpy import double, log, power


NEWTON_ITERATIONS = 4096

def Klein_Nishina_g_to_e(g: double) -> double:
    e = 1.0

    for i in range(NEWTON_ITERATIONS):
        gFromE = 1.0 / e - 2.0 / log(2.0 * e + 1.0) + 1.0
        deriv  = 4.0 / ((2.0 * e + 1.0) * power(log(2.0 * e + 1.0), 2.0)) - 1.0 / (e * e)

        if abs(deriv) < 1e-8:
            break

        e = e - (gFromE - g) / deriv

    return e


if __name__ == "__main__":

    try:
        g_input = input("Enter anisotropy factor g: ")

        e_output = Klein_Nishina_g_to_e(double(g_input))

        print("Corresponding energy factor e: " + str(e_output))

    except ValueError:
        print("Enter a valid value.")
