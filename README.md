# Teal Pages #

This is the Teal Pages Template Preprocessor, a modification of the Lua Pages Template Preprocessor to enable the [Teal](https://github.com/teal-language/tl) language, a typed dialect of Lua, instead of Lua directly from within `<?teal` and `<?` tags in script files ending with .tlp extension.

Currently it can be used from within Lua scripts or Apache mod_lua if you enable tlp_handler.lua through the LuaMapHandler directive (as explained below).

## Development Status #

Teal Pages is a beta, experimental merge of slightly modified parts of [tl's compiler](https://github.com/teal-language/tl/blob/master/tl) and a modified lp.lua. All input, feedback and contributions are highly appreciated.

## Installation

### Installation for Apache with mod_lua

1. Edit the Apache httpd.conf file and uncomment: `LoadModule lua_module modules/mod_lua.so`
2. Add:

```
LuaMapHandler "\.tlp$" "path/to/lua/teal-pages/tlp_handler.lua" handle_tlp
```

Done! You can start using `<?teal` or simply `<?` in .tlp files.

#### Where do Teal Pages errors go?

Currently script transpilation errors are not yet printed through the handler, so you must check the Apache's errors.log. Error handling can still evolve a lot.

#### Note about FallbackResource

With Apache HTTPd <2.4.9, the FallbackResource directive should preferably not be used in the active virtual host, as it invalidates the LuaMapHandler directive.

## Usage Examples #

See test.tlp. Make sure testlib.tl is within the Lua libraries search path.

## License #

Teal Pages is licensed under the [MIT license](http://opensource.org/licenses/MIT)

(c) Felipe Daragon, exluna.org, 2020