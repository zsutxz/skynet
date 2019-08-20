local eris = require "eris"
local skynet = require "skynet"
local logger = require "logger"
require "dump_table"

local err_msg = ""
local eris_util = {}

local __dump_index = 1 
local __max_dump = skynet.getenv('max_dump') or 50 
local __dump_path = skynet.getenv('dump_path') or "../log"
local __process = skynet.getenv('dump_name') or "eris_dump"
local __assert = skynet.getenv('assert_dump') or "eris_assert"

local function get_cur_time_str()
    local t = os.date("%Y%m%d%H%M%S", os.time())
    return string.format("%s_%d", t,__dump_index) 
end

local function handle_exception(bassert, show_dump)
    if __dump_index > __max_dump then
        logger.err('OUT OF MAX DUMP')
        return false
    end
    local __dump_info = {}
    --从第2层栈开始，前层忽略
    local __level = 2 
    while true do
        local __info = debug.getinfo(__level, "Slfnu")
        if not __info then 
            break 
        end
        --当前栈变量索引
        local __idx = 1
        local __stack_info = {}
        local stack_header = string.format("file:%s line:%d\n", __info.short_src, __info.currentline)
        __stack_info[__idx] = stack_header
        while true do
            local __name, __value = debug.getlocal(__level, __idx)
            if not __name then 
                --__dump_info[__level] = "level:"..__level.." is nil" 
                break 
            end
            local __s = nil 
            if type(__value) == "table" then
                __s = string.format("[table]%s", __name)
                __s = __s..var_dump(__value).."\n"

            elseif type(__value) == "string" or type(__value)=='number' or type(__value)=='boolean' then
                __s = string.format("[value]%s:%s\n", __name, __value)
            end
            __stack_info[__idx+1] = __s
            __idx = __idx + 1
        end
        __dump_info[__level] = __stack_info
        __level = __level + 1
    end
    __dump_info[1] = debug.traceback()
    if show_dump then 
        table.printT(__dump_info)
    end
    local __buf = eris.persist(__dump_info)
    local __filename = string.format("%s_%s.dump",__process,get_cur_time_str())
    if bassert then

        __filename = string.format("%s_%s.dump",__assert,get_cur_time_str())
    end
    local __outfile = io.open(__dump_path..'/'..__filename, "wb")
    __outfile:write(__buf)
    __outfile:close()

    __dump_index = __dump_index + 1
    logger.err('WRITE DUMP SUCCESS!')
    return true
end
-------------------------------------------------------------------------------------
--@class function
--@description trace a function you want
--@param f a function you want to trace
--@param show_dump show dump info or not
--@return none
-------------------------------------------------------------------------------------
function eris_util.trace(f, show_dump)
    xpcall(f, function ()
        local bassert = false
        handle_exception(bassert, show_dump)
    end)
end

-------------------------------------------------------------------------------------
--@class function 
--@description like what you see, assert
--@param is_true a boolean expression
--@param show_dump show dump info or not
--@return none
-------------------------------------------------------------------------------------
function eris_util.assert(is_true, show_dump)
    if not is_true then
        xpcall(function() error(is_true) end, function () 
            handle_exception(true, show_dump)    
        end)
    end
end

-------------------------------------------------------------------------------------
--@class function 
--@description xpcall and write dump while error occur
--@param func function name
--@param params function params
--@usage eris_util.xpcall(func, ...)
--@return none
-------------------------------------------------------------------------------------
function eris_util.xpcall(func, ...)
    local function error_handle() 
        handle_exception(true)    
    end
    return xpcall(func, error_handle, ...)
end

-------------------------------------------------------------------------------------
--@class function 
--@description dump something you want, table or function or values
--@param obj the object to be dump
--@param name the dump file name
--@param show_dump show dump info or not
--@return the object that just dump if success, otherwise nil
function eris_util.dump(obj, name, show_dump)
    local perms = {
        [_ENV] = "_ENV",
        [coroutine.yield] = 1,
        [pcall] = 2,
        [xpcall] = 3,
        --[obj] = 4,
    }
    assert(name, 'please specify dump file name')
    local function do_persist()
        eris.settings("maxrec", 100)
        local outobj = eris.persist(perms, obj)
        local filename = string.format("%s_%s.dump",name,get_cur_time_str())
        local outfile = io.open(__dump_path..'/'..filename, "wb")
        if not outfile then
            logger.err('open output file error:%s', filename)
            return nil
        end
        if show_dump then
            table.printT(obj)
        end
        outfile:write(outobj)
        outfile:close()
        return eris.unpersist(perms, outobj)
    end
    local ok, outobj = xpcall(do_persist, function()
        logger.err('exception occurs while writting dump')
        return nil
    end)
    return outobj
end


return eris_util
