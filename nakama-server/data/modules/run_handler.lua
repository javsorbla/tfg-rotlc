local nk = require("nakama")

local M = {}

function M.submit_run(context, payload)
  local run = payload.run

  local run_json = nk.json_encode(run)
  local run_table = nk.json_decode(run_json)

  -- STORAGE
  nk.storage_write({
    {
      collection = "runs",
      key = nk.uuid_v4(),
      user_id = context.user_id,
      value = run_json,
      permission_read = 1,
      permission_write = 0
    }
  })

  -- LEADERBOARD
  local score = run_table.score or 0
  local metadata = run_table.metadata or {}

  nk.leaderboard_record_write(
    "global_score",
    context.user_id,
    context.username,
    score,
    metadata
  )

  return nk.json_encode({
    ok = true,
    score = score
  })
end

return M