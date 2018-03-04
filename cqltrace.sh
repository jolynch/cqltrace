# For tracing slow queries in real time
wget https://raw.githubusercontent.com/starius/lua-lru/master/src/lru/lru.lua
tshark -q -X lua_script:query_latency.lua -i lo -w out -b filesize:10000 -b files:2 -f "tcp port 9042"
# OR
PRINT_SUBS= tshark -q -X lua_script:query_latency.lua -i lo -w out -b filesize:10000 -b files:2 -f "tcp port 9042"

# For parsing only (faster, but doesn't have responses)
tshark -q -X lua_script:query_parser.lua -i lo -w out -b filesize:10000 -b files:2 -f "tcp port 9042 and ((tcp[((tcp[12:1] & 0xF0) >> 2):1] = 0x04) or (tcp[((tcp[12:1] & 0xF0) >> 2):1] = 0x84 and tcp[((tcp[12:1] & 0xF0) >> 2) + 12:1] = 0x04))"
