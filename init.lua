ufos = {}

local UFO_SPEED = 1
local UFO_TURN_SPEED = 2
local UFO_MAX_SPEED = 10
local UFO_FUEL_USE = 0.01

-- Convierte desgaste a combustible
ufos.fuel_from_wear = function(wear)
    if wear == 0 then
        return 0
    end
    return (65535 - (wear - 1)) * 100 / 65535
end

-- Convierte combustible a desgaste
ufos.wear_from_fuel = function(fuel)
    local wear = (100 - fuel) * 65535 / 100 + 1
    if wear > 65535 then wear = 0 end
    return wear
end

-- Obtiene el nivel de combustible
ufos.get_fuel = function(self)
    return self.fuel
end

-- Establece el nivel de combustible
ufos.set_fuel = function(self, fuel, object)
    self.fuel = fuel
end

-- Convierte un OVNI a un ítem con desgaste según el combustible
ufos.ufo_to_item = function(self)
    local wear = ufos.wear_from_fuel(ufos.get_fuel(self))
    return {name = "ufos:ufo", wear = wear}
end

-- Convierte un ítem a un OVNI
ufos.ufo_from_item = function(itemstack, placer, pointed_thing)
    -- Establece el propietario
    ufos.next_owner = placer:get_player_name()
    -- Restaura el combustible dentro del ítem
    local wear = itemstack:get_wear()
    ufos.set_fuel(ufos.ufo, ufos.fuel_from_wear(wear))
    -- Añade la entidad
    minetest.add_entity(pointed_thing.above, "ufos:ufo")
    -- Elimina el ítem
    itemstack:take_item()
    -- Resetea el propietario para el próximo OVNI
    ufos.next_owner = ""
end

-- Verifica si el jugador es el propietario del OVNI
ufos.check_owner = function(self, clicker)
    if self.owner_name ~= "" and clicker:get_player_name() ~= self.owner_name then
        minetest.chat_send_player(clicker:get_player_name(), "This UFO is owned by " .. self.owner_name .. "!")
        return false
    elseif self.owner_name == "" then
        minetest.chat_send_player(clicker:get_player_name(), "This UFO was not protected, you are now its owner!")
        self.owner_name = clicker:get_player_name()
    end
    return true
end

-- Inicializa propiedades del OVNI
ufos.next_owner = ""
ufos.ufo = {
    physical = true,
    collisionbox = {-1.5, -0.5, -1.5, 1.5, 2, 1.5},
    visual = "mesh",
    mesh = "ufo.x",
    textures = {"ufo_0.png"},
    driver = nil,
    owner_name = "",
    v = 0,
    fuel = 0,
    fueli = 0
}

-- Gestión de clic derecho en el OVNI
function ufos.ufo:on_rightclick(clicker)
    if not clicker or not clicker:is_player() then
        return
    end
    if self.driver and clicker == self.driver then
        self.driver = nil
        clicker:set_detach()
    elseif not self.driver then
        if ufos.check_owner(self, clicker) then
            self.driver = clicker
            clicker:set_attach(self.object, "", {x = 0, y = 7.5, z = 0}, {x = 0, y = 0, z = 0})
        end
    end
end

-- Activación del OVNI
function ufos.ufo:on_activate(staticdata, dtime_s)
    if ufos.next_owner ~= "" then
        self.owner_name = ufos.next_owner
        ufos.next_owner = ""
    else
        local data = staticdata:split(';')
        if data and data[1] and data[2] then
            self.owner_name = data[1]
            self.fuel = tonumber(data[2])
        end
    end
    self.object:set_armor_groups({immortal = 1})
end

-- Gestión de golpes al OVNI
function ufos.ufo:on_punch(puncher, time_from_last_punch, tool_capabilities, direction)
    if puncher and puncher:is_player() then
        if ufos.check_owner(self, puncher) then
            puncher:get_inventory():add_item("main", ufos.ufo_to_item(self))
            self.object:remove()
        end
    end
end

-- Actualización del OVNI en cada paso del juego
function ufos.ufo:on_step(dtime)
    local fuel = ufos.get_fuel(self)
    if self.driver then
        local ctrl = self.driver:get_player_control()
        local vel = self.object:get_velocity()
        if fuel == nil then fuel = 0 end
        if fuel > 0 and ctrl.up then
            vel.x = vel.x + math.cos(self.object:get_yaw() + math.pi / 2) * UFO_SPEED
            vel.z = vel.z + math.sin(self.object:get_yaw() + math.pi / 2) * UFO_SPEED
            fuel = fuel - UFO_FUEL_USE
        else
            vel.x = vel.x * 0.99
            vel.z = vel.z * 0.99
        end
        if ctrl.down then
            vel.x = vel.x * 0.9
            vel.z = vel.z * 0.9
        end
        if fuel > 0 and ctrl.jump then
            vel.y = vel.y + UFO_SPEED
            fuel = fuel - UFO_FUEL_USE
        elseif fuel > 0 and ctrl.sneak then
            vel.y = vel.y - UFO_SPEED
            fuel = fuel - UFO_FUEL_USE
        else
            vel.y = vel.y * 0.9
        end
        if vel.x > UFO_MAX_SPEED then vel.x = UFO_MAX_SPEED end
        if vel.x < -UFO_MAX_SPEED then vel.x = -UFO_MAX_SPEED end
        if vel.y > UFO_MAX_SPEED then vel.y = UFO_MAX_SPEED end
        if vel.y < -UFO_MAX_SPEED then vel.y = -UFO_MAX_SPEED end
        if vel.z > UFO_MAX_SPEED then vel.z = UFO_MAX_SPEED end
        if vel.z < -UFO_MAX_SPEED then vel.z = -UFO_MAX_SPEED end
        self.object:set_velocity(vel)
        if ctrl.left then
            self.object:set_yaw(self.object:get_yaw() + math.pi / 120 * UFO_TURN_SPEED)
        end
        if ctrl.right then
            self.object:set_yaw(self.object:get_yaw() - math.pi / 120 * UFO_TURN_SPEED)
        end
        if ctrl.aux1 then
            local pos = self.object:get_pos()
            local t = {{x = 2, z = 0}, {x = -2, z = 0}, {x = 0, z = 2}, {x = 0, z = -2}}
            for _, offset in ipairs(t) do
                pos.x = pos.x + offset.x
                pos.z = pos.z + offset.z
                if minetest.get_node(pos).name == "ufos:furnace" then
                    local meta = minetest.get_meta(pos)
                    if fuel < 100 and meta:get_int("charge") > 0 then
                        fuel = fuel + 1
                        meta:set_int("charge", meta:get_int("charge") - 1)
                        meta:set_string("formspec", ufos.furnace_inactive_formspec
                            .. "label[0,0;Charge: " .. meta:get_int("charge"))
                    end
                end
                pos.x = pos.x - offset.x
                pos.z = pos.z - offset.z
            end
        end
    end

    if fuel < 0 then fuel = 0 end
    if fuel > 100 then fuel = 100 end
    if self.fueli ~= math.floor(fuel * 8 / 100) then
        self.fueli = math.floor(fuel * 8 / 100)
        self.textures = {"ufo_" .. self.fueli .. ".png"}
        self.object:set_properties(self)
    end
    ufos.set_fuel(self, fuel)
end

-- Obtiene los datos estáticos del OVNI
function ufos.ufo:get_staticdata()
    return self.owner_name .. ";" .. tostring(self.fuel)
end

minetest.register_entity("ufos:ufo", ufos.ufo)

minetest.register_tool("ufos:ufo", {
    description = "UFO",
    inventory_image = "ufos_inventory.png",
    wield_image = "ufos_inventory.png",
    tool_capabilities = {load = 0, max_drop_level = 0, groupcaps = {fleshy = {times = {}, uses = 100, maxlevel = 0}}},
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type ~= "node" then
            return
        end

        -- Llama a on_rightclick si el nodo apuntado lo define
        if placer and not placer:get_player_control().sneak then
            local n = minetest.get_node(pointed_thing.under)
            local nn = n.name
            if minetest.registered_nodes[nn] and minetest.registered_nodes[nn].on_rightclick then
                return minetest.registered_nodes[nn].on_rightclick(pointed_thing.under, n, placer, itemstack) or itemstack
            end
        end

        ufos.ufo_from_item(itemstack, placer, pointed_thing)
        return itemstack
    end,
})

minetest.register_craft({
    output = 'ufos:ufo',
    recipe = {
        {"", "default:glass", ""},
        {"default:mese_crystal_fragment", "", "default:mese_crystal_fragment"},
        {"default:steelblock", "default:mese", "default:steelblock"},
    },
})

-- Registro del nodebox del OVNI (para compatibilidad)
minetest.register_node("ufos:box", {
    description = "UFO BOX (you hacker you!)",
    tiles = {"ufos_box.png"},
    groups = {not_in_creative_inventory = 1},
    is_ground_content = false,
    on_rightclick = function(pos, node, clicker, itemstack)
        local meta = minetest.get_meta(pos)
        if meta:get_string("owner") == clicker:get_player_name() then
            -- Establece el propietario
            ufos.next_owner = meta:get_string("owner")
            -- Restaura el combustible dentro del nodo
            ufos.set_fuel(ufos.ufo, meta:get_int("fuel"))
            -- Añade la entidad
            minetest.add_entity(pos, "ufos:ufo")
            -- Elimina el nodo
            minetest.remove_node(pos)
            -- Resetea el propietario para el próximo OVNI
            ufos.next_owner = ""
        end
    end,
})

-- Carga el archivo furnace.lua del mod
dofile(minetest.get_modpath("ufos") .. "/furnace.lua")

})

dofile(minetest.get_modpath("ufos").."/furnace.lua")

