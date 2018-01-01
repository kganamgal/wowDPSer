local function argsToString(arg, ...)
    if select("#", ...) > 0 then
        return tostring(arg), argsToString(...)
    else
        return tostring(arg)
    end
end
local function print(...)
    local output = strjoin(", ", argsToString(...))
    ChatFrame1:AddMessage("Print: " .. output)
end

