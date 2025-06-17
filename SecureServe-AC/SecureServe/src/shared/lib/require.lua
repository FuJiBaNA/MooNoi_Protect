---@class RequireLibrary
---@field loaded table Table of loaded modules
---@field paths table Paths to search for modules
local Require = {
    loaded = {},
    paths = {
        "src/shared/",
        "src/client/",
        "src/server/",
        "src/",
        ""
    }
}

---@description Set a custom error handler that provides more detailed error information
---@param err string The error message
---@param module_name string The module name that caused the error
---@param trace_level number The level to start tracing from
---@return nil
local function enhanced_error_handler(err, module_name, trace_level)
    local trace_level = trace_level or 2
    local trace = debug.traceback("", trace_level)
    
    local formatted_error = "\n^1============ SECURESERVE ERROR ============^7\n"
    formatted_error = formatted_error .. "^1Error in module: ^3" .. tostring(module_name) .. "^7\n"
    formatted_error = formatted_error .. "^1Message: ^3" .. tostring(err) .. "^7\n"
    formatted_error = formatted_error .. "^1Traceback: ^7\n" .. trace:gsub("stack traceback:", "^3Stack traceback:^7")
    formatted_error = formatted_error .. "\n^1==========================================^7\n"
    
    print(formatted_error)
    
    error(err)
end

---@param module_name string The name of the module to require
---@return any The exported module content
function Require.load(module_name)
    -- ตรวจสอบว่าเคยโหลดแล้วหรือไม่
    if Require.loaded[module_name] then
        return Require.loaded[module_name]
    end
    
    -- เก็บ module_name เดิมไว้
    local original_module_name = module_name
    
    -- แปลง path สำหรับ modules ที่เรียกแบบสั้น
    if not module_name:match("^src/") then
        if module_name:match("^server/") then
            module_name = "src/" .. module_name
        elseif module_name:match("^client/") then
            module_name = "src/" .. module_name
        elseif module_name:match("^shared/") then
            module_name = "src/" .. module_name
        end
    end
    
    local module_path = nil
    local code = nil
    
    -- ลองหาไฟล์ในตำแหน่งต่างๆ
    local search_paths = {
        module_name .. ".lua",
        "src/" .. module_name .. ".lua",
        module_name .. "/init.lua",
        "src/" .. module_name .. "/init.lua"
    }
    
    -- ถ้าไม่มี src/ prefix ให้เพิ่มเข้าไป
    if not module_name:match("^src/") then
        table.insert(search_paths, "src/" .. module_name .. ".lua")
        table.insert(search_paths, "src/" .. module_name .. "/init.lua")
    end
    
    for _, search_path in ipairs(search_paths) do
        local success, result = pcall(function()
            return LoadResourceFile(GetCurrentResourceName(), search_path)
        end)
        
        if success and result and result ~= "" then
            code = result
            module_path = search_path
            break
        end
    end
    
    -- ถ้าหาไม่เจอ ลองใช้ path แบบเดิม
    if not module_path or not code then
        for _, path in ipairs(Require.paths) do
            local full_path = path .. original_module_name .. ".lua"
            local success, result = pcall(function()
                return LoadResourceFile(GetCurrentResourceName(), full_path)
            end)
            
            if success and result and result ~= "" then
                code = result
                module_path = full_path
                break
            end
            
            -- ลอง init.lua
            full_path = path .. original_module_name .. "/init.lua"
            success, result = pcall(function()
                return LoadResourceFile(GetCurrentResourceName(), full_path)
            end)
            
            if success and result and result ~= "" then
                code = result
                module_path = full_path
                break
            end
        end
    end
    
    if not module_path or not code then
        enhanced_error_handler("Module not found: " .. original_module_name .. " (also tried: " .. module_name .. ")", original_module_name)
        return nil
    end
    
    -- สร้าง environment สำหรับ module
    local module_env = setmetatable({
        require = function(name) return Require.load(name) end,
        exports = {},
    }, {__index = _G})
    
    -- โหลดและรัน module
    local module_func, load_err = load(code, module_path, "bt", module_env)
    if not module_func then
        enhanced_error_handler("Error loading module: " .. tostring(load_err), original_module_name)
        return nil
    end
    
    local success, result = pcall(module_func)
    if not success then
        enhanced_error_handler("Error executing module: " .. tostring(result), original_module_name)
        return nil
    end
    
    -- ใช้ result ที่ return มา หรือ exports ที่ตั้งไว้ใน module_env
    local module_exports = result or module_env.exports
    
    -- เก็บผลลัพธ์ไว้ในทั้ง original_module_name และ module_name
    Require.loaded[original_module_name] = module_exports
    if original_module_name ~= module_name then
        Require.loaded[module_name] = module_exports
    end
    
    return module_exports
end

---@param path string Path to add to the require paths
function Require.add_path(path)
    table.insert(Require.paths, 1, path)
end

-- ตั้งค่า global error handler
_G.SecureServeErrorHandler = function(err)
    local trace = debug.traceback("", 2)
    
    local formatted_error = "\n^1============ SECURESERVE RUNTIME ERROR ============^7\n"
    formatted_error = formatted_error .. "^1Error: ^3" .. tostring(err) .. "^7\n"
    formatted_error = formatted_error .. "^1Traceback: ^7\n" .. trace:gsub("stack traceback:", "^3Stack traceback:^7")
    formatted_error = formatted_error .. "\n^1================================================^7\n"
    
    print(formatted_error)
    
    return err
end

-- แทนที่ฟังก์ชัน require ของ FiveM
_G.require = function(module_name)
    return Require.load(module_name)
end

return Require