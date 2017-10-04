-- query_latency.lua
-- TODO
-- - Actually show latency outliars ...
-- - Persist the Prepared Statement IDs to disk, or ask Cassandra > 3.11
--   from the system table
-- - Figure out lowest memory way to do this, separate capture + minimal
--   script which calls this one, or ... something else ...
-- - Support various protocol versions
--
-- Execute with:
--[[

tshark -q -X lua_script:query_latency.lua -i lo -w out -b filesize:10000 -b files:2 -f "tcp port 9042"

or to get all variables in the query:

PRINT_SUBS= tshark -q -X lua_script:query_latency.lua -i lo -w out -b filesize:10000 -b files:2 -f "tcp port 9042"
]]--

print("Loading Real time CQL Latency Tracer")
lru = require('lru')
-- frame id -> query
query_cache = lru.new(100)

cql_query = Field.new("cql.string")
cql_opcode = Field.new("cql.opcode")
cql_query_id = Field.new("cql.query_id")
cql_query_cl = Field.new("cql.consistency")
cql_result_kind = Field.new("cql.result.kind")
tcp_data = Field.new("tcp.payload")
cql_response_to = Field.new("cql.response_to")
cql_response_time = Field.new("cql.response_time")
cql_bytes = Field.new("cql.bytes")

-- query_id -> CQL statement
local prepared_statements = {}
-- packet id -> CQL statement
local pending_prepared_statements = {}

function decode_prepared_statement(pinfo)
    local query
    local query_bytes = {}
    if cql_query_id().value then
        if prepared_statements[tostring(cql_query_id().value)] then
            query = prepared_statements[tostring(cql_query_id().value)]
        else
            query = tostring(cql_query_id().value)
        end
        for i,b in ipairs({ cql_bytes() }) do
            query_bytes[i] = tostring(b.value)
        end
        query_cache:set(pinfo.number, {query=query, values=query_bytes})
    end
end

function decode_normal_statement(pinfo)
    if cql_query().value then
        local query = cql_query().value
        query_cache:set(pinfo.number, {query=query, values={}})
    end
end

function record_prepared_statement(pinfo)
    print("PENDING PREPARE", pinfo.number, cql_query())
    pending_prepared_statements[pinfo.number] = cql_query().value
end

function finalize_prepared_statement(pinfo)
    -- 9 bytes in the header, and then 4 more for the result type
    local length = tcp_data().range(13, 2):int()
    -- We then read the query_id directly out of the data
    local query_id = tcp_data().range(15, length):bytes()
    local query = pending_prepared_statements[cql_response_to().value]
    prepared_statements[tostring(query_id)] = query
    pending_prepared_statements[cql_response_to().value] = nil
    print("PREPARED", tostring(query_id), query)
end

function decode_response()
    if cql_response_to() and query_cache:get(cql_response_to().value) then
        query = query_cache:get(cql_response_to().value)
        local key = query.values[1]
        if key then
            local _, question_count = string.gsub(query.query, "%?", "")
            if os.getenv('PRINT_SUBS') then
                key = table.concat(query.values, ':')
            end
        end

        print(string.format(
            "Query [%s][subs=%s] took: [%s]s",
            query.query, key,
            cql_response_time().value)
        )
    end
end

-- Setup the capture
-- On each packet, decode the query and log it
local tap = Listener.new();
function tap.packet(pinfo, tvb)
    if cql_opcode() == nil then
        return
    end

    -- EXECUTE
    if cql_opcode().value == 10 then
        decode_prepared_statement(pinfo)
    -- PREPARE
    elseif cql_opcode().value == 9 then
        record_prepared_statement(pinfo)
    -- RESULT (we should only get results to PREPARE statements
    elseif cql_opcode().value == 8 then
        if cql_result_kind().value == 4 then
            finalize_prepared_statement(pinfo)
        else
            decode_response()
        end
    -- QUERY
    elseif cql_opcode().value == 7 then
        decode_normal_statement(pinfo)
    end
end

function tap.reset()
    print "GOT ROLLOVER"
    -- todo sync prepared statement state or somethin
end