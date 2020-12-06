----------------------------------------------------------------------------
-- Teal Pages Template Preprocessor
-- A modification of Lua Pages Template Preprocessor to enable the Teal language
-- instead of Lua from within <?teal and ?> tags.
-- Copyright (c) 2020 Felipe Daragon, exluna.org
-- Portions copyright (c) 2019 Hisham Muhammad
-- Portions copyright (c) 2007 CGILua
-- License: MIT
-- 
-- This is an experimental merge of slightly modified parts of tl's compiler 
-- (https://github.com/teal-language/tl/blob/master/tl) and a modified
-- lp.lua (v1.12). Currently it can be used from within Lua scripts or Apache
-- if you enable tlp_handler.lua through the LuaMapHandler directive
----------------------------------------------------------------------------

local assert, error, getfenv, loadstring, setfenv = assert, error, getfenv, loadstring, setfenv
local find, format, gsub, strsub = string.find, string.format, string.gsub, string.sub
local concat, tinsert = table.concat, table.insert
local open = io.open
local ipairs, unpack = ipairs, unpack
local stderr = io.stderr
local exit = os.exit
local tl = require("tl")
local tunpack = table.unpack

module (...)

local function htmlescape(text)
 local special = { ['<']='&lt;', ['>']='&gt;', ['&']='&amp;', ['"']='&quot;' }
 return text:gsub('[<>&"]', special)
end

----------------------------------------------------------------------------
-- function to do output
local outfunc = "io.write"
-- accepts the old expression field: `$| <Lua expression> |$'
local compatmode = true

--
-- Builds a piece of Lua code which outputs the (part of the) given string.
-- @param s String.
-- @param i Number with the initial position in the string.
-- @param f Number with the final position in the string (default == -1).
-- @return String with the correspondent Lua code which outputs the part of the string.
--
local function out (s, i, f)
	s = strsub(s, i, f or -1)
	if s == "" then return s end
	-- we could use `%q' here, but this way we have better control
	s = gsub(s, "([\\\n\'])", "\\%1")
	-- substitute '\r' by '\'+'r' and let `loadstring' reconstruct it
	s = gsub(s, "\r", "\\r")
	return format(" %s('%s'); ", outfunc, s)
end

----------------------------------------------------------------------------
-- Translate the template to Teal code.
-- @param s String to translate.
-- @return String with translated code.
----------------------------------------------------------------------------
function translate (s)
	if compatmode then
		s = gsub(s, "$|(.-)|%$", "<?teal = %1 ?>")
		s = gsub(s, "<!%-%-$$(.-)$$%-%->", "<?teal %1 ?>")
	end
	s = gsub(s, "<%%(.-)%%>", "<?teal %1 ?>")
	local res = {}
	local start = 1   -- start of untranslated part in `s'
	while true do
		local ip, fp, target, exp, code = find(s, "<%?(%w*)[ \t]*(=?)(.-)%?>", start)
		if not ip then break end
		tinsert(res, out(s, start, ip-1))
		if target ~= "" and target ~= "teal" then
			-- not for Teal; pass whole instruction to the output
			tinsert(res, out(s, ip, fp))
		else
			if exp == "=" then   -- expression?
				tinsert(res, format(" %s(%s);", outfunc, code))
			else  -- command
				tinsert(res, format(" %s ", code))
			end
		end
		start = fp + 1
	end
	tinsert(res, out(s, start))
	return concat(res)
end


----------------------------------------------------------------------------
-- Defines the name of the output function.
-- @param f String with the name of the function which produces output.

function setoutfunc (f)
	outfunc = f
end

----------------------------------------------------------------------------
-- Turns on or off the compatibility with old CGILua 3.X behavior.
-- @param c Boolean indicating if the compatibility mode should be used.

function setcompatmode (c)
	compatmode = c
end

----------------------------------------------------------------------------
-- Internal compilation cache.

local cache = {}

----------------------------------------------------------------------------
-- Translates a template into a Lua function.
-- Does NOT execute the resulting function.
-- Uses a cache of templates.
-- @param string String with the template to be translated.
-- @param chunkname String with the name of the chunk, for debugging purposes.
-- @return Function with the resulting translation.

function compile (string, chunkname)
	local f, err = cache[string]
	if f then return f end
	f, err = loadstring (translate (string), chunkname)
	if not f then error (err, 3) end
	cache[string] = f
	return f
end

----------------------------------------------------------------------------
--                        TEAL COMPILER                                   --
----------------------------------------------------------------------------

  local function get_config()
   local config = {
      preload_modules = {},
      include_dir = {},
      quiet = false
   }
   return config
end   
  local tlconfig = get_config()
  
local function printerr(s)
   stderr:write(s .. "\n")
end

local function trim(str)
   return str:gsub("^%s*(.-)%s*$", "%1")
end

local function die(msg)
   printerr(msg)
   exit(1)
end 
  
 local function report_errors(category, errors)
   if not errors then
      return false
   end
   if #errors > 0 then
      local n = #errors
      printerr("========================================")
      printerr(n .. " " .. category .. (n ~= 1 and "s" or "") .. ":")
      for _, err in ipairs(errors) do
         printerr(htmlescape(err.filename) .. ":" .. err.y .. ":" .. err.x .. ": " .. (err.msg or ""))
      end
      return true
   end
   return false
end   

local function report_type_errors(result)
   local has_type_errors = report_errors("error", result.type_errors)
   report_errors("unknown variable", result.unknowns)

   return not has_type_errors
end

local env = nil  
  

  
 local function type_check_and_loadstring(filename, input, islua, modules)
   local filename = "@"..filename
   local result, err = tl.process_string(input, islua, env, nil, modules, filename)
   if err then
      die(err)
   end
   env = result.env

   local has_syntax_errors = report_errors("syntax error", result.syntax_errors)
   if has_syntax_errors then
      exit(1)
   end
   if islua == false then
      local ok = report_type_errors(result)
      if not ok then
         exit(1)
      end
   end

   local chunk; chunk, err = (loadstring or load)(tl.pretty_print_ast(result.ast), filename)
   if err then
      die("Internal Compiler Error: Teal generator produced invalid Lua. Please report a bug at https://github.com/teal-language/tl")
   end
   return chunk
end 
  
  local function setup_env(filename)
   if not env then
      local basename, extension = filename:match("(.*)%.([a-z]+)$")
      extension = extension and extension:lower()

      local lax_mode
      if extension == "tl" then
         lax_mode = false
      elseif extension == "lua" then
         lax_mode = true
      else
         -- if we can't decide based on the file extension, default to strict mode
         lax_mode = false
      end

      local skip_compat53 = tlconfig["skip_compat53"]

      env = tl.init_env(lax_mode, skip_compat53)
   end
end 

local function compilestring(input, filename)
   setup_env(filename)
   local chunk = type_check_and_loadstring(filename, input, false, modules)
   return chunk
end

function runstring(input, filename)
   local arg = {}	
   filename = filename or "@teal"
   chunk = compilestring(input, filename)
   tl.loader()
   return chunk((unpack or table.unpack)(arg))
end


----------------------------------------------------------------------------
-- Translates and executes a template in a given file.
-- The translation creates a Lua function which will be executed in an
-- optionally given environment.
-- @param filename String with the name of the file containing the template.
-- @param env Table with the environment to run the resulting function.

function include (filename, env)
	-- read the whole contents of the file
	local fh = assert (open (filename))
	local src = fh:read("*a")
	src = translate (src)
	fh:close()
	-- translates the file into a function
	local prog = compilestring(src, filename)
	local arg = {}	
	local _env
	if env then
		_env = getfenv (prog)
		setfenv (prog, env)
	end
   tl.loader()
   prog((unpack or tunpack)(arg))	
end


