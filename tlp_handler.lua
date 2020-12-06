-- This file is part of the Teal Pages project
-- Copyright (c) 2020 Felipe Daragon
-- License: MIT

function handle_tlp(r)
	local tlp = require "tlp"
	r.content_type = "text/html"
	puts = function(s) r:write(s) end
	print = function(s) r:write(s) end
	tlp.setoutfunc "puts"
	tlp.include(r.filename)
end

