-- trace.lua                                                                                                                   
                                                                                   
print("Loading Real time CQL Tracer")                                              
cql_query = Field.new("cql.string")                                                
cql_opcode = Field.new("cql.opcode")                                               
cql_query_id = Field.new("cql.query_id")                                           
cql_query_cl = Field.new("cql.consistency")                                        
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
                                                                                   
local tap = Listener.new();                                                        
                                                                                   
                                                                                   
function decode_prepared_statement()                                               
    if cql_query_id().value then                                                   
        if prepared_statements[tostring(cql_query_id().value)] then                
            print(                                                                 
                prepared_statements[tostring(cql_query_id().value)],               
                cls[cql_query_cl().value],                                         
                cql_response_time()                                                
            )                                                                      
        else                                                                       
            print("UNKNOWN", cql_query_id().value)                                 
            print("Known statements:")                                             
            for k,v in pairs(prepared_statements) do                               
                print(k, "->", v)                                                  
            end                                                                    
        end                                                                        
    end                                                                            
end                                                                                
                                                                                   
function decode_normal_statement()                                                 
    if cql_query().value then                                                      
        print(cql_query().value, cls[cql_query_cl().value], cql_response_time())
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
    print("PREPARED", tostring(query_id), query)                                   
end

-- On each packet, decode the query and log it                                     
function tap.packet(pinfo, tvb)                                                    
    -- EXECUTE                                                                     
    if cql_opcode().value == 10 then                                            
        decode_prepared_statement()                                             
    -- PREPARE                                                                  
    elseif cql_opcode().value == 9 then                                         
        record_prepared_statement(pinfo)                                        
    -- RESULT (we should only get results to PREPARE statements                 
    elseif cql_opcode().value == 8 then                                         
        finalize_prepared_statement(pinfo)                                      
    -- QUERY                                                                    
    elseif cql_opcode().value == 7 then                                         
        decode_normal_statement()                                               
    end                                                                         
    --print(cql_query(), cql_opcode())                                          
end                                                  
