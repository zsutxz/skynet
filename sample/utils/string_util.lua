local core = require "csplit"

--分割字符串，逐个返回
--cststr 被分割的字符串
--分隔符标识
function string.csplit(cststr, pattern)
    assert(type(pattern) == "string","csplit error pattern not string")
    if type(pattern) ~= "string" then
        return nil
    end
    return core.csplit(cststr, pattern)
end

--分割字符串，并返回table
--cststr 被分割的字符串
--分隔符标识
function string.csplit_to_table(cststr, pattern)
    assert(type(pattern) == "string","csplit_to_table error pattern not string")
    if type(pattern) ~= "string" then
        return nil
    end
    return core.csplit_to_table(cststr, pattern)
end

