--[[ 

1. 支持递归目录。因此该目录下不能有配置表以外的文件。
2. 用到配置时只需:
    require "query_sharedata"
    ...
    local config = query_sharedata("configs")[$config_name] (不带.lua)

]]


return {
    -- "../res/",
    "../services/game_kind/11/room/config/"
}