--Database module for Medical App #JericoFX

local _DATABASE_MODULE = lib.load("server.modules.db")
local medicalDB = lib.class("medicalDB")

function medicalDB:constructor(...)
    self:super(_DATABASE_MODULE)

end