local nk = require("nakama")

local M = {}

function M.init()
  nk.run_once(function()
    nk.logger_info("Inicializando leaderboards...")

    nk.leaderboard_create(
      "global_score",
      true,
      "desc",
      "best score",
      "{}",
      nil,
      false
    )

    nk.logger_info("Leaderboards listos")
  end)
end

return M