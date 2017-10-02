-- query_parser.lua
-- TODO
-- - Persist the Prepared Statement IDs to disk, or ask Cassandra > 3.11
--   from the system table
-- - Figure out lowest memory way to do this, separate capture + minimal
--   script which calls this one, or ... something else ...
-- - Support various protocol versions
--
-- Execute with:
--[[
tshark -q -X lua_script:query_parser.lua -i lo -w out -b filesize:10000 -b files:2 -f "tcp port 9042 and ((tcp[((tcp[12:1] & 0xF0) >> 2):1] = 0x04) or (tcp[((tcp[12:1] & 0xF0) >> 2):1] = 0x84 and tcp[((tcp[12:1] & 0xF0) >> 2) + 12:1] = 0x04))"
]]--

print("Loading Real time CQL Tracer")
cql_query = Field.new("cql.string")
cql_opcode = Field.new("cql.opcode")
cql_query_id = Field.new("cql.query_id")
cql_query_cl = Field.new("cql.consistency")
cql_result_kind = Field.new("cql.result.kind")
tcp_data = Field.new("tcp.payload")
cql_response_to = Field.new("cql.response_to")
cql_response_time = Field.new("cql.response_time")

-- query_id -> CQL statement
local prepared_statements = {}
-- packet id -> CQL statement
local pending_prepared_statements = {}
local cls = {
    [0x0000]    = "ANY",
    [0x0001]    = "ONE",
    [0x0002]    = "TWO",
    [0x0003]    = "THREE",
    [0x0004]    = "QUORUM",
    [0x0005]    = "ALL",
    [0x0006]    = "LOCAL_QUORUM",
    [0x0007]    = "EACH_QUORUM",
    [0x0008]    = "SERIAL",
    [0x0009]    = "LOCAL_SERIAL",
    [0x000A]    = "LOCAL_ONE",
}

function decode_prepared_statement()
    local query

    if cql_query_id().value then
        if prepared_statements[tostring(cql_query_id().value)] then
            query = prepared_statements[tostring(cql_query_id().value)]
        else
            query = tostring(cql_query_id().value)
        end
        print(
            string.format("[%s]@[%s]", query, cls[cql_query_cl().value])
        )
    end
end

function decode_normal_statement()
    if cql_query().value then
        print(
            string.format(
                "[%s]@[%s]",
                cql_query().value, cls[cql_query_cl().value]
            )
        )
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
    print("Query took", cql_response_time().value)
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
        decode_prepared_statement()
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
        decode_normal_statement()
    end
end

function tap.reset()
    print "GOT ROLLOVER"
    -- todo sync prepared statement state or somethin
end