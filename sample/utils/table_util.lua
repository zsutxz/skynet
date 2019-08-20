--[[--

深度克隆一个值

~~~ lua

-- 下面的代码，t2 是 t1 的引用，修改 t2 的属性时，t1 的内容也会发生变化
local t1 = {a = 1, b = 2}
local t2 = t1
t2.b = 3    -- t1 = {a = 1, b = 3} <-- t1.b 发生变化

-- clone() 返回 t1 的副本，修改 t2 不会影响 t1
local t1 = {a = 1, b = 2}
local t2 = clone(t1)
t2.b = 3    -- t1 = {a = 1, b = 2} <-- t1.b 不受影响

~~~

@param mixed object 要克隆的值

@return mixed


]]

function table.printtable(t, prefix)
    if (#t == 0) then
        print('table is empty')
    end
    prefix = prefix or "";
    if #prefix<5 then
        print(prefix.."{")
        for k,v in pairs(t) do
            if type(v)=="table" then
                print(prefix.." "..tostring(k).." = ")
                if v~=t then
                    table.printtable(v, prefix.."   ")
                end
            elseif type(v)=="string" then
                print(prefix.." "..tostring(k).." = \""..v.."\"")
            elseif type(v)=="number" then
                print(prefix.." "..tostring(k).." = "..v)
            elseif type(v)=="userdata" then
                print(prefix.." "..tostring(k).." =  "..tostring(v))
            else
                print(prefix.." "..tostring(k).." = "..tostring(v))
            end
        end
        print(prefix.."}")
    end
end

function table.clone(object)
    local lookup_table = {}
    local function _copy(an_object)
        if type(an_object) ~= "table" then
            return an_object
        elseif lookup_table[an_object] then
            return lookup_table[an_object]
        end
        local new_table = {}
        lookup_table[an_object] = new_table
        for key, value in pairs(an_object) do
            new_table[_copy(key)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(an_object))
    end
    return _copy(object)
end

function table.get_readonly_table(t)
    local tt = {}
    local mt = {
        __index = t,
        __newindex = function (t1, k, v)
            error("attempt to update a read-only table")
        end
    }
    setmetatable(tt, mt)
    return tt
end

function table.print_readonly_table(t)    
    table.printT(getmetatable(t).__index)
end

function table.pairs_readonly_table(t)
    local key = nil
    local function next_readonly(tt)   
        local real_table = getmetatable(tt).__index     
        local k, v = next(real_table, key)
        key = k
        if type(k) == "table" then 
            k = table.get_readonly_table(k)
        end
        if type(v) == "table" then 
            v = table.get_readonly_table(v)
        end
        return k, v
    end
    return next_readonly, t, nil;    
end

-- 只支持一层拷贝
function table.copy(t)
    local tt = {}
    for k, v in pairs(t) do
        tt[k] = v
    end
    return tt
end

--initialize table value all to zero
function table.zero(t)
    for k,v in pairs(t) do
        if type(v)~= "table" then 
            t[k] =0
        else
            table.zero(v)
        end
    end
    return t
end

function table.printR(root)
    print("\27[37m")
    local cache = { [root] = '.' }
    local function _dump(t, space, name)
        local temp = {}
        for k,v in pairs(t) do
            local key = tostring(k)
            if cache[v] then
                table.insert(temp, "+" .. key .. " {" .. cache[v] .. "}")
            elseif type(v) == "table" then
                local new_key = name .. "." ..key
                cache[v] = new_key
                table.insert(temp, "+" .. key .. _dump(v, space .. (next(t,k) and "|" or " ").. string.rep(" ",#key), new_key))
            else
                table.insert(temp, "+" .. key .. " [".. tostring(v) .. "]")
            end
        end
        return table.concat(temp, "\n"..space)
    end
    print(_dump(root, "",""))
    print("\27[0m")
end

-- cycle print all field in table
function table.printT(ta)
    -- print("\27[37m")
    local table_type = type( ta );
    if table_type == "boolean" then
        if ta then
            print( "table.printT table is boolean value = true" );
        else
            print( "table.printT table is boolean value = false" );
        end
        return;
    elseif table_type == "string" then
        print( "table.printT table is string value = "..ta );
        return;
    elseif table_type == "number" then
        print( "table.printT table is number value = "..ta );
        return;
    end
    local s =""
    local c = ""
    local looped_table = {}
    
    local function pt(key,t,ms,mc)
        local nc = mc.."  "
        print(mc.."{")
        looped_table[t] = key
        for k,v in pairs(t) do
            if k then
                local ns=ms.."    "
                if type(v)~= "table" then                     
                    if type(v) ~= "function" then
                        if type(v) == "boolean" then   
                            print(ms..k.." ", v)
                        else                                             
                            print(ms..k.."  "..v)
                        end
                    else
                        print(ms..k.."  function()")
                    end
                elseif not looped_table[v] then--avoid dead loop
                        print(ms..k.." ")                        
                        pt(k, v, ns, nc)
                        looped_table[v] = k
                else
                    print(ms..k.." looped_table:"..tostring(looped_table[v]))
                end

            end
        end
        print(mc.."}")
    end
    if ta then 
        pt("self", ta, s,c)
    else
        print("nil")
    end
    print("\27[0m")
end
--[[--

计算表格包含的字段数量

Lua table 的 "#" 操作只对依次排序的数值下标数组有效，table.nums() 则计算 table 中所有不为 nil 的值的个数。

@param table t 要检查的表格

@return integer

]]
function table.nums(t)
    local count = 0
    if t and type(t) == 'table' then
        for k, v in pairs(t) do
            count = count + 1
        end
    end
    return count
end

--[[--

返回指定表格中的所有键

~~~ lua

local hashtable = {a = 1, b = 2, c = 3}
local keys = table.keys(hashtable)
-- keys = {"a", "b", "c"}

~~~

@param table hashtable 要检查的表格

@return table

]]
function table.keys(hashtable)
    local keys = {}
    for k, v in pairs(hashtable) do
        keys[#keys + 1] = k
    end
    return keys
end

--[[--

返回指定表格中的所有值

~~~ lua

local hashtable = {a = 1, b = 2, c = 3}
local values = table.values(hashtable)
-- values = {1, 2, 3}

~~~

@param table hashtable 要检查的表格

@return table

]]
function table.values(hashtable)
    local values = {}
    for k, v in pairs(hashtable) do
        values[#values + 1] = v
    end
    return values
end

--[[--

将来源表格中所有键及其值复制到目标表格对象中，如果存在同名键，则覆盖其值

~~~ lua

local dest = {a = 1, b = 2}
local src  = {c = 3, d = 4}
table.merge(dest, src)
-- dest = {a = 1, b = 2, c = 3, d = 4}

~~~

@param table dest 目标表格
@param table src 来源表格

]]
function table.merge(dest, src)
    for k, v in pairs(src) do
        dest[k] = v
    end
end

--[[--

在目标表格的指定位置插入来源表格，如果没有指定位置则连接两个表格

~~~ lua

local dest = {1, 2, 3}
local src  = {4, 5, 6}
table.insertto(dest, src)
-- dest = {1, 2, 3, 4, 5, 6}

dest = {1, 2, 3}
table.insertto(dest, src, 5)
-- dest = {1, 2, 3, nil, 4, 5, 6}

~~~

@param table dest 目标表格
@param table src 来源表格
@param [integer begin] 插入位置

]]
function table.insertto(dest, src, begin)
    begin = checkint(begin)
    if begin <= 0 then
        begin = #dest + 1
    end

    local len = #src
    for i = 0, len - 1 do
        dest[i + begin] = src[i + 1]
    end
end

--[[

从表格中查找指定值，返回其索引，如果没找到返回 false

~~~ lua

local array = {"a", "b", "c"}
print(table.indexof(array, "b")) -- 输出 2

~~~

@param table array 表格
@param mixed value 要查找的值
@param [integer begin] 起始索引值

@return integer

]]
function table.indexof(array, value, begin)
    for i = begin or 1, #array do
        if array[i] == value then return i end
    end
    return false
end

--[[--

从表格中查找指定值，返回其 key，如果没找到返回 nil

~~~ lua

local hashtable = {name = "dualface", comp = "chukong"}
print(table.keyof(hashtable, "chukong")) -- 输出 comp

~~~

@param table hashtable 表格
@param mixed value 要查找的值

@return string 该值对应的 key

]]
function table.keyof(hashtable, value)
    for k, v in pairs(hashtable) do
        if v == value then return k end
    end
    return nil
end

--[[--

从表格中删除指定值，返回删除的值的个数

~~~ lua

local array = {"a", "b", "c", "c"}
print(table.removebyvalue(array, "c", true)) -- 输出 2

~~~

@param table array 表格
@param mixed value 要删除的值
@param [boolean removeall] 是否删除所有相同的值

@return integer

]]
function table.removebyvalue(array, value, removeall)
    local c, i, max = 0, 1, #array
    while i <= max do
        if array[i] == value then
            table.remove(array, i)
            c = c + 1
            i = i - 1
            max = max - 1
            if not removeall then break end
        end
        i = i + 1
    end
    return c
end

--[[--

对表格中每一个值执行一次指定的函数，并用函数返回值更新表格内容

~~~ lua

local t = {name = "dualface", comp = "chukong"}
table.map(t, function(v, k)
    -- 在每一个值前后添加括号
    return "[" .. v .. "]"
end)

-- 输出修改后的表格内容
for k, v in pairs(t) do
    print(k, v)
end

-- 输出
-- name [dualface]
-- comp [chukong]

~~~

fn 参数指定的函数具有两个参数，并且返回一个值。原型如下：

~~~ lua

function map_function(value, key)
    return value
end

~~~

@param table t 表格
@param function fn 函数

]]
function table.map(t, fn)
    for k, v in pairs(t) do
        t[k] = fn(v, k)
    end
end

--[[--

对表格中每一个值执行一次指定的函数，但不改变表格内容

~~~ lua

local t = {name = "dualface", comp = "chukong"}
table.walk(t, function(v, k)
    -- 输出每一个值
    print(v)
end)

~~~

fn 参数指定的函数具有两个参数，没有返回值。原型如下：

~~~ lua

function map_function(value, key)

end

~~~

@param table t 表格
@param function fn 函数

]]
function table.walk(t, fn)
    for k,v in pairs(t) do
        fn(v, k)
    end
end

--[[--

对表格中每一个值执行一次指定的函数，如果该函数返回 false，则对应的值会从表格中删除

~~~ lua

local t = {name = "dualface", comp = "chukong"}
table.filter(t, function(v, k)
    return v ~= "dualface" -- 当值等于 dualface 时过滤掉该值
end)

-- 输出修改后的表格内容
for k, v in pairs(t) do
    print(k, v)
end

-- 输出
-- comp chukong

~~~

fn 参数指定的函数具有两个参数，并且返回一个 boolean 值。原型如下：

~~~ lua

function map_function(value, key)
    return true or false
end

~~~

@param table t 表格
@param function fn 函数

]]
function table.filter(t, fn)
    for k, v in pairs(t) do
        if not fn(v, k) then t[k] = nil end
    end
end

--[[--

遍历表格，确保其中的值唯一

~~~ lua

local t = {"a", "a", "b", "c"} -- 重复的 a 会被过滤掉
local n = table.unique(t)

for k, v in pairs(n) do
    print(v)
end

-- 输出
-- a
-- b
-- c

~~~

@param table t 表格

@return table 包含所有唯一值的新表格

]]
function table.unique(t)
    local check = {}
    local n = {}
    for k, v in pairs(t) do
        if not check[v] then
            n[k] = v
            check[v] = true
        end
    end
    return n
end

function table.clear(t)
    if t then
        for k, _ in pairs(t) do
            t[k] = nil
        end
    end
end

function table.make_key(t, key_name1, key_name2)
    local tt = {}
    if not key_name2 then
        for k, v in pairs(t) do
            tt[v[key_name1]] = v
        end
    else
        for k, v in pairs(t) do
            tt[v[key_name1]] = tt[v[key_name1]] or {}
            tt[v[key_name1]][v[key_name2]] = v
        end
    end
    return tt
end

function table.remake_key_value(t, key, value)
    local tt = {}
    for k, v in pairs(t) do
        local ttt = {}
        ttt[key] = k
        ttt[value] = v
        table.insert(tt, ttt)
    end
    return tt
end

function table.make_key_value(t, key, value)
    local tt = {}
    for k, v in pairs(t) do
        tt[v[key]] = v[value]
    end
    return tt
end


--[[--

序列化table到文件

local info = {
    mail = {
        [1] = {
            guid = "k1i3jfnxd",
            msg = "hello world"
        },
        [2] = {
            guid = "zxcvj332a",
            msg = "match award"
        }
    },
    inventory = {
        [1] = {
            itemid = 40318,
            itemcount = 2
        }
    }
}

-- 输出
do local ret = {mail={[2]={guid="zxcvj332a",msg="match award"},[1]={guid="k1i3jfnxd",msg="hello world"}},inventory={[1]={itemid=40318,itemcount=2}}} return ret end


]]
function table.serialize(t)
    local mark = {}
    local assign = {}

    local function ser_table(tb1, parent)
        mark[tb1] = parent
        local tmp = {}
        for k,v in pairs(tb1) do
            local key = type(k)=="number" and "["..k.."]" or k
            if type(v) == "table" then
                local dotkey = parent .. (type(k)=="number" and key or "."..key)
                if mark[v] then
                    table.insert(assign, dotkey.."="..mark[v])
                else
                    table.insert(tmp, key.."="..ser_table(v, dotkey))
                end
            else
                if type(v) == "string" then
                    print("string")
                    table.insert(tmp, key.."=" .. "\"" .. v .. "\"")
                else
                    print("not string")
                    table.insert(tmp, key.."="..v)
                end
            end
        end
        return "{" .. table.concat(tmp, ",") .. "}"
    end

    return "do local ret = " .. ser_table(t, "ret") .. table.concat(assign, " ") .. " return ret end"
end



--[[
function table.tableToStr( t, prefix )
    if t==nil then
        return "nil"
    end
    if type(t)=="userdata" then
        t = tolua.getpeer(t);
    end
    local result = "";
    prefix = prefix or "";
    if #prefix<5 then
        result = result..(prefix.."{").."\n"
        for k,v in pairs(t) do
            if type(v)=="table" then
                result = result..(prefix.." "..tostring(k).." = ").."\n"
                result = result..Utils:tableToStr(v, prefix.." ").."\n"
            elseif type(v)=="string" then
                result = result..(prefix.." "..tostring(k).." = \""..v.."\"").."\n"
            elseif type(v)=="number" then
                result = result..(prefix.." "..tostring(k).." = "..v).."\n"
            elseif type(v)=="userdata" then
                result = result..(prefix.." "..tostring(k).." = "..tolua.type(v).." "..tostring(v)).."\n"
                local pt = tolua.getpeer(v);
                if pt~=nil then
                    result = result..tableToStr(pt, prefix.." ").."\n"
                end
            else
                result = result..(prefix.." "..tostring(k).." = "..tostring(v)).."\n"
            end
        end
        result = result..(prefix.."}")
    end
    return result;
end
--]]

