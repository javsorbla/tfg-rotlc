local nk = require("nakama")

local bootstrap = require("bootstrap")
local run_handler = require("run_handler")

nk.register_rpc(run_handler.submit_run, "submit_run")
bootstrap.init()