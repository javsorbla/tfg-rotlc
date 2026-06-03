local nk = require("nakama")

local M = {}

function M.init()
  local ok, err = pcall(nk.leaderboard_create,
    "global_score",
    false,
    "desc",
    "best",
    nil,
    {}
  )
  if not ok then
    nk.logger_warn("Leaderboard global_score ya existía o error: " .. tostring(err))
  else
    nk.logger_info("Leaderboard global_score creado")
  end
end

return M
