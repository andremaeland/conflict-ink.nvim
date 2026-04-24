-- Module: request_handler.lua
-- Handles incoming HTTP requests, validation, and response formatting.

local M = {}

local DEFAULT_TIMEOUT = 30
local MAX_RETRIES = 3

-- ---------------------------------------------------------------------------
-- Logging
-- ---------------------------------------------------------------------------

<<<<<<< feature/structured-logging
local log = require("logger").new({
  level = "debug",
  format = "json",
  destination = "stdout",
})

local function log_request(req)
  log.info("incoming request", {
    method = req.method,
    path = req.path,
    remote = req.remote_addr,
    request_id = req.id,
  })
end

local function log_error(msg, ctx)
  log.error(msg, ctx or {})
end
||||||| base
local function log_request(req)
  print(string.format("[INFO] %s %s from %s", req.method, req.path, req.remote_addr))
end

local function log_error(msg)
  print(string.format("[ERROR] %s", msg))
end
=======
local function log_request(req)
  io.write(string.format("[%s] %s %s\n", os.date("%H:%M:%S"), req.method, req.path))
end

local function log_error(msg)
  io.stderr:write(string.format("[ERROR] %s\n", msg))
end
>>>>>>> main

-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------

<<<<<<< feature/structured-logging
local validators = {}

function validators.require_fields(body, fields)
  local missing = {}
  for _, f in ipairs(fields) do
    if body[f] == nil or body[f] == "" then
      table.insert(missing, f)
    end
  end
  if #missing > 0 then
    return false, "missing required fields: " .. table.concat(missing, ", ")
  end
  return true
end

function validators.max_length(value, max, field)
  if type(value) == "string" and #value > max then
    return false, string.format("field '%s' exceeds max length of %d", field, max)
  end
  return true
end

function M.validate(body, schema)
  for _, rule in ipairs(schema) do
    local ok, err = rule(body)
    if not ok then
      return false, err
    end
  end
  return true
end
=======
function M.validate(body, required_fields)
  for _, field in ipairs(required_fields) do
    if body[field] == nil then
      return false, "missing field: " .. field
    end
  end
  return true
end
>>>>>>> main

-- ---------------------------------------------------------------------------
-- Rate limiting
-- ---------------------------------------------------------------------------

local rate_limits = {}

<<<<<<< feature/structured-logging
local RATE_WINDOW = 60
local RATE_MAX = 100

function M.check_rate_limit(client_id)
  local now = os.time()
  local bucket = rate_limits[client_id]

  if not bucket or (now - bucket.window_start) >= RATE_WINDOW then
    rate_limits[client_id] = { window_start = now, count = 1 }
    return true
  end

  bucket.count = bucket.count + 1
  if bucket.count > RATE_MAX then
    log.warn("rate limit exceeded", { client_id = client_id, count = bucket.count })
    return false, "rate limit exceeded"
  end

  return true
end
||||||| base
local RATE_WINDOW = 60
local RATE_MAX = 60

function M.check_rate_limit(client_id)
  local now = os.time()
  local bucket = rate_limits[client_id]

  if not bucket or (now - bucket.window_start) >= RATE_WINDOW then
    rate_limits[client_id] = { window_start = now, count = 1 }
    return true
  end

  bucket.count = bucket.count + 1
  if bucket.count > RATE_MAX then
    return false, "rate limit exceeded"
  end

  return true
end
=======
local RATE_WINDOW = 30
local RATE_MAX = 50

function M.check_rate_limit(client_id)
  local now = os.time()
  local entry = rate_limits[client_id]

  if not entry or (now - entry.ts) >= RATE_WINDOW then
    rate_limits[client_id] = { ts = now, hits = 1 }
    return true
  end

  entry.hits = entry.hits + 1
  if entry.hits > RATE_MAX then
    return false, "too many requests"
  end

  return true
end
>>>>>>> main

-- ---------------------------------------------------------------------------
-- Response helpers
-- ---------------------------------------------------------------------------

<<<<<<< feature/structured-logging
function M.respond(res, status, body)
  res.status = status
  res.headers["Content-Type"] = "application/json"
  res.headers["X-Request-ID"] = res.request_id
  res.body = vim.json.encode(body)
end

function M.respond_error(res, status, message, details)
  log_error(message, { status = status, details = details })
  M.respond(res, status, {
    error = message,
    details = details,
    request_id = res.request_id,
  })
end
=======
function M.respond(res, status, body)
  res.status = status
  res.headers["Content-Type"] = "application/json"
  res.body = body
end

function M.respond_error(res, status, message)
  log_error(message)
  M.respond(res, status, { error = message })
end
>>>>>>> main

-- ---------------------------------------------------------------------------
-- Middleware chain
-- ---------------------------------------------------------------------------

<<<<<<< feature/structured-logging
local function with_timeout(handler, timeout_ms)
  return function(req, res)
    local done = false
    local timer = vim.loop.new_timer()
    timer:start(timeout_ms, 0, function()
      if not done then
        log_error("request timed out", { path = req.path, timeout_ms = timeout_ms })
        M.respond_error(res, 504, "request timed out", nil)
      end
      timer:close()
    end)
    handler(req, res)
    done = true
  end
end

function M.chain(...)
  local handlers = { ... }
  return function(req, res)
    local i = 0
    local function next()
      i = i + 1
      if handlers[i] then
        handlers[i](req, res, next)
      end
    end
    next()
  end
end
=======
function M.chain(...)
  local handlers = { ... }
  return function(req, res)
    for _, h in ipairs(handlers) do
      h(req, res)
    end
  end
end
>>>>>>> main

-- ---------------------------------------------------------------------------
-- Main handler
-- ---------------------------------------------------------------------------

function M.handle(req, res)
  log_request(req)

<<<<<<< feature/structured-logging
  local ok, err = M.check_rate_limit(req.remote_addr)
  if not ok then
    return M.respond_error(res, 429, err, { retry_after = RATE_WINDOW })
  end

  local valid, verr = M.validate(req.body, {
    function(b) return validators.require_fields(b, { "action", "payload" }) end,
    function(b) return validators.max_length(b.action, 64, "action") end,
  })
  if not valid then
    return M.respond_error(res, 400, verr, nil)
  end

  log.debug("handling action", { action = req.body.action })
  M.respond(res, 200, { status = "ok", action = req.body.action })
=======
  local ok, err = M.check_rate_limit(req.remote_addr)
  if not ok then
    return M.respond_error(res, 429, err)
  end

  local valid, verr = M.validate(req.body, { "action", "payload" })
  if not valid then
    return M.respond_error(res, 400, verr)
  end

  M.respond(res, 200, { status = "ok" })
>>>>>>> main
end

return M
