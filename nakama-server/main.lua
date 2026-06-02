local nk = require("nakama")

-- módulos
local bootstrap = require("data.modules.bootstrap")
local run_handler = require("data.modules.run_handler")

-- =========================
-- RPCs
-- =========================
nk.register_rpc(run_handler.submit_run, "submit_run")

-- =========================
-- INIT (leaderboards, setup)
-- =========================
bootstrap.init()