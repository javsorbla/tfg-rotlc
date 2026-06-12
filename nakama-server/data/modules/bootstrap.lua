local nk = require("nakama")

local M = {}

local LEVEL_IDS = {"level_0", "level_1", "level_2", "level_3", "level_4"}
local METRICS = {"time", "kills", "deaths", "damage_dealt", "damage_received", "prism_cores"}
local CAMPAIGN_METRICS = {"score", "time", "kills", "deaths", "damage_dealt", "damage_received", "prism_cores"}

function M.init()
  for _, level in ipairs(LEVEL_IDS) do
    -- Composite score per level
    local score_id = level .. "_score"
    local ok, err = pcall(nk.leaderboard_create, score_id, false, "desc", "best", nil, {})
    if not ok then
      nk.logger_warn("Leaderboard " .. score_id .. " ya existía o error: " .. tostring(err))
    else
      nk.logger_info("Leaderboard " .. score_id .. " creado")
    end

    -- Metrics per level
    for _, metric in ipairs(METRICS) do
      local id = level .. "_" .. metric
      local ok2, err2 = pcall(nk.leaderboard_create, id, false, "desc", "best", nil, {})
      if not ok2 then
        nk.logger_warn("Leaderboard " .. id .. " ya existía o error: " .. tostring(err2))
      else
        nk.logger_info("Leaderboard " .. id .. " creado")
      end
    end
  end

  -- Campaign (accumulated) leaderboards
  for _, metric in ipairs(CAMPAIGN_METRICS) do
    local id = "campaign_" .. metric
    local ok, err = pcall(nk.leaderboard_create, id, false, "desc", "best", nil, {})
    if not ok then
      nk.logger_warn("Leaderboard " .. id .. " ya existía o error: " .. tostring(err))
    else
      nk.logger_info("Leaderboard " .. id .. " creado")
    end
  end
end

return M
