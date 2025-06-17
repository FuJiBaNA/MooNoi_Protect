-- ตรวจสอบว่า require ทำงานได้หรือไม่
local function safe_require(module_name)
    local success, result = pcall(require, module_name)
    if not success then
        print("^1[ERROR] Failed to load module: " .. module_name .. " - " .. tostring(result) .. "^7")
        return nil
    end
    return result
end

---@class ClientInit
local ClientInit = {}

---@description Initialize all client components
function ClientInit.initialize()
    print("^5[INFO] Starting SecureServe Client initialization...^7")
    
    -- โหลด logger ก่อน
    local logger = safe_require("client/core/client_logger")
    if not logger then
        print("^1[FATAL ERROR] Cannot load client logger!^7")
        return
    end
    
    logger.initialize({
        Debug = false
    })
    
    logger.info("==============================================")
    logger.info("SecureServe Client v1.2.1 initializing...")
    
    -- โหลด ConfigLoader
    local ConfigLoader = safe_require("client/core/config_loader")
    if not ConfigLoader then
        logger.error("Cannot load ConfigLoader!")
        return
    end
    
    ConfigLoader.initialize()
    logger.info("Config Loader initialized")
    
    local secureServe = ConfigLoader.get_secureserve()
    
    -- โหลด Cache
    local Cache = safe_require("client/core/cache")
    if not Cache then
        logger.error("Cannot load Cache!")
        return
    end
    
    Cache.initialize()
    logger.info("Cache initialized")
    
    -- ส่งสัญญาณว่า client พร้อม
    Citizen.CreateThread(function()
        Wait(2000) 
        TriggerServerEvent("SecureServe:CheckWhitelist")
    end)
    
    -- โหลด Protection Manager
    logger.info("Loading Protection Manager...")
    local ProtectionManager = safe_require("client/protections/protection_manager")
    if not ProtectionManager then
        logger.error("Cannot load Protection Manager!")
        return
    end
    
    ProtectionManager.initialize()
    logger.info("Protection Manager initialized")
    
    -- โหลด Entity Monitor
    logger.info("Loading Entity Monitor...")
    local EntityMonitor = safe_require("client/core/entity_monitor")
    if not EntityMonitor then
        logger.error("Cannot load Entity Monitor!")
        return
    end
    
    EntityMonitor.initialize()
    logger.info("Entity Monitor initialized")
    
    -- โหลด Blue Screen
    logger.info("Loading Blue Screen...")
    local blue_screen = safe_require("client/core/blue_screen")
    if not blue_screen then
        logger.error("Cannot load Blue Screen!")
        return
    end
    
    blue_screen.initialize()
    logger.info("Blue Screen initialized")

    -- ตั้งค่า event handlers
    RegisterNetEvent("SecureServe:UpdateDebugMode", function(enabled)
        if logger and logger.set_debug_mode then
            logger.set_debug_mode(enabled)
        end
    end)
    
    if SecureServeErrorHandler then
        logger.info("Global Error Handler initialized")
    end
    
    logger.info("Client-side components initialized")
    logger.info("==============================================")
end

-- รอให้ player spawn แล้วค่อยเริ่ม
CreateThread(function()
    -- รอให้ resource เริ่มต้นอย่างสมบูรณ์
    Wait(1000) 
    
    -- เริ่ม initialization
    local success, err = pcall(ClientInit.initialize)
    if not success then
        print("^1[FATAL ERROR] Client initialization failed: " .. tostring(err) .. "^7")
    end
end)

return ClientInit