-- This demo script just executes a Teal string without support for <?teal tags
local input = [[
require("testlib")   
function xadd(a: number, b: number): number
   return a + b
end

printnumber(xadd(1,2))
   ]]



local tlp = require "tlp"
tlp.runstring(input)