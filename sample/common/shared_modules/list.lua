local List = {}
List.__index = List

function List:new()
    local t = {first = 0, last = -1}
    return setmetatable(t, List)
end

function List:__pairs()
    return function (a_self, k)
        return k <= a_self.last - a_self.first and k+1 or nil, a_self[a_self.first+k]
    end, self, 0
end

function List:pushleft (value)
    local first = self.first - 1
    self.first = first
    self[first] = value
end

function List:pushright (value)
    local last = self.last + 1
    self.last = last
    self[last] = value
end

function List:popleft ()
    local first = self.first
    if first > self.last then error("list is empty") end
    local value = self[first]
    self[first] = nil        -- to allow garbage collection
    if first == self.last then
        self.first = 0
        self.last = -1
    else
        self.first = first + 1
    end
    return value
end

function List:popright ()
    local last = self.last
    if self.first > last then error("list is empty") end
    local value = self[last]
    self[last] = nil         -- to allow garbage collection
    if last == self.first then
        self.first = 0
        self.last = -1
    else
        self.last = last - 1
    end
    return value
end

function List:empty()
    return (self.first > self.last)
end

function List:length()
    return (self.first > self.last) and 0 or (self.last-self.first+1)
end

-- should not change the self in func
-- func return break or not
function List:foreach(func, right_first)
    if right_first then
        for i = self.last, self.first, -1 do
            if func(self[i]) then break end
        end
    else
        for i = self.first, self.last do
            if func(self[i]) then break end
        end
    end
end

function List:clear()
    if not self:empty() then
        for i = self.first, self.last do
            self[i] = nil
        end
    end
    self.first = 0
    self.last = -1
end

function List:left()
    local first = self.first
    if first > self.last then error("list is empty") end
    return self[first]
end

function List:right()
    local last = self.last
    if self.first > last then error("list is empty") end
    return self[last]
end

List.__ipairs = List.__pairs
List.len = List.length
List.push = List.pushright
List.pop = List.popleft
return List
