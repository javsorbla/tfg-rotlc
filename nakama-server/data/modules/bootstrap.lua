local nk = require("nakama")

local M = {}

local LEADERBOARDS = {
  {"global_score", "Puntuación compuesta"},
  {"global_time", "Tiempo"},
  {"global_kills", "Enemigos eliminados"},
  {"global_deaths", "Muertes"},
  {"global_damage_dealt", "Daño infligido"},
  {"global_damage_taken", "Daño recibido"},
  {"global_prism_cores", "Núcleos de prisma"},
}

function M.init()
  for _, lb in ipairs(LEADERBOARDS) do
    local ok, err = pcall(nk.leaderboard_create, lb[1], false, "desc", "best", nil, {})
    if not ok then
      nk.logger_warn("Leaderboard " .. lb[1] .. " ya existía o error: " .. tostring(err))
    else
      nk.logger_info("Leaderboard " .. lb[1] .. " creado")
    end
  end
end

return M
