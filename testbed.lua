require "socket"

local debugtestbed = 0

-- for now, nick == numeric == .. and all users are valid // TODO
chanusers = { "u1", "u2", "u3", "u4", "u5", "u6", "u7", "u8", "u9", "u10" }

local HOMECHANNEL = "#labspace"

-- TODO: database management
function basepath()
  return ""
end

function loadtable(path)
  return nil
end

function savetable(path)
  return nil
end

-- stub implementations

function irctolower(channel)
  if string.len(channel) == 0 or channel == "#" then
    return channel;
  end
  channel = string.gsub(channel, "%[", "{")
  channel = string.gsub(channel, "%]", "}")
  channel = string.gsub(channel, "\\", "|")
  return string.lower(channel)
end

function irc_localregisteruser(nick, ident, host, ...)
  local bot = {}
  bot.nick = nick
  bot.ident = ident
  bot.host = host
  return bot
end

irc_localregisteruserid = irc_localregisteruser

function irc_localchanmsg(bot, chan, text)
  out(bot, "PRIVMSG " .. chan .. " :" .. text)
end

function irc_getnickbynumeric(x)
  return { nick = x, numeric = x, accountid = -1 }
end

function irc_getnickbynick(x)
  return { nick = x, numeric = x, accountid = -1 }
end

function mode_iter(t)
  local n = 1
  local max = table.getn(t)
  return function()
    local o
    if n <= max then
      o = {plsmns = t[n], mode = t[n+1], target = t[n+2]}
    end
    n = n + 3
    return o
  end
end

function irc_localovmode(bot, chan, modes)
  local modestr, targets = "", ""
  local lastplsmns = nil

  for m in mode_iter(modes) do
    if lastplsmns == nil or m.plsmns ~= lastplsmns then
      if m.plsmns then
        modestr = modestr .. "+"
      else
        modestr = modestr .. "-"
      end
      lastplsmns = m.plsmns
    end
    modestr = modestr .. m.mode
    targets = targets .. " " .. m.target
  end
  out(bot, "MODE " .. chan .. " " .. modestr .. targets)
end

function irc_localjoin(bot, chan)
  out(bot, "JOIN " .. chan)
end

function irc_localsimplechanmode(bot, chan, mode)
  out(bot, "MODE " .. chan .. " " .. mode)
end

function irc_localnotice(bot, target, text)
  out(bot, "NOTICE " .. target .. " :" .. text)
end

function irc_getuserchanmodes(channel, numeric)
  local usermode = {}
  usermode.opped = false
  usermode.voiced = false
  return usermode
end

nickpusher = {}

function nickpusher.numeric(user)
  return user
end

function channelusers_iter(chan, dataselectors)
  local i, n = 1, table.getn(chanusers)
  return function()
    local o = {}
    i = i + 1
    if i <= n then
      for j, dataselector in ipairs(dataselectors) do
        o[j] = dataselector(chanusers[i])
      end
      return o
    end
  end
end

-- Scheduler
Scheduler = {}
Scheduler.__index = Scheduler
Schedulers = {}

function Scheduler.new()
  local sched = setmetatable({tasks = {}}, Scheduler)
  table.insert(Schedulers, sched)
  return sched
end

setmetatable(Scheduler, { __call = function(_, ...) return Scheduler.new(...) end })

function Scheduler:add(secs, func, ...)
  local future = os.time() + secs
  local f = { func = func, args = { ... } }

  if not self.tasks[future] then
    self.tasks[future] = {}
  end

  debug("Added scheduler entry (" .. secs .. "): " .. tostring(func) .. " as " .. tostring(f))
  table.insert(self.tasks[future], f)

  return f
end

function Scheduler:remove(call)
  local found = 0
  for time, funcs in pairs(self.tasks) do
    for _, f in ipairs(funcs) do
      if f == call then
        found = 1
        table.remove(self.tasks[time], i)
      end
    end
  end
  debug("Attempted to remove scheduler entry (" .. tostring(call) .. "): " .. found)
end

function Scheduler:check()
  local now = os.time()
  local newtasks = {}
  for time, funcs in pairs(self.tasks) do
    if time <= now then
      for _, f in ipairs(funcs) do
        debug("Func call (scheduler): " .. tostring(f.func) .. "/" .. tostring(f.args))
        f.func(unpack(f.args))
      end
    else
      newtasks[time] = funcs
    end
  end
  self.tasks = newtasks
end 

function Scheduler.allcheck()
  for _, sched in ipairs(Schedulers) do
    sched:check()
  end
end

local cmd = {}

function cmd.join(tokens)
  if table.getn(tokens) ~= 2 or not tonumber(tokens[2]) then
    print("Usage: join <playercount> - playercount 1..10 for now")
    return
  end

  for i = 1,tonumber(tokens[2]) do
    pub("u" .. i, "!add")
  end
end

function cmd.pub(tokens)
  if table.getn(tokens) < 3 then
    print("Usage: pub <from nick> <message goes here ...>")
    return
  end

  pub(tokens[2], table.concat(tokens, " ", 3))
end

function cmd.notc (tokens)
  if table.getn(tokens) < 3 then
    print("Usage: notc <from nick> <message goes here ...>")
    return
  end

  notc(tokens[2], table.concat(tokens, " ", 3))
end

function cmd.exit (tokens)
  os.exit(0)
end

cmd.notice = cmd.notc

function docmd(str)
  local tokens = ls_split_message(str)

  if not tokens[1] then
    return
  end

  if not cmd[tokens[1]] then
    print("Invalid command name: " .. tokens[1])
  else
    cmd[tokens[1]](tokens)
  end
end

local stdin = socket.tcp()
stdin:close()
stdin:setfd(0)

function sleep(n)
  local s_in, s_out, s_err
  while not s_err do
    s_in, s_out, s_err = socket.select({ stdin }, nil, n)
    if s_in and table.getn(s_in) > 0 then
      docmd(io.read("*line"))
    end
  end
end

function Scheduler.mainloop()
  while 1 do
    Scheduler.allcheck()
    ontick()
    debug("tick")
    sleep(1)
  end
end

-- various debugging utilities
function debug(text)
  if debugtestbed == 1 then
    log("DEBUG: " .. text)
  end
end

function log(text)
  print(os.date("(%H:%M.%S)") .. " " .. text)
end

function format_from(from)
  return from.nick .. "!" .. from.ident .. "@" .. from.host
end

function terminate(code)
  io.flush()
  os.exit(code)
end

function out(from, text)
  text = string.gsub(text, "\002", "")
  if string.match(text, "Science wins again:") or string.match(text, "The citizens win this round:") then
    Schedulers[1]:add(10, terminate(0))
  end
  log(format_from(from) .. " -> " .. text)
end

function pub(from, text)
  log("<" .. from .. "@" .. HOMECHANNEL .."> " .. text)
  gamehandler(nil, "irc_onchanmsg", from, HOMECHANNEL, text)
end

function notc(from, text)
  log("-" .. from .. "- " .. text)
  gamehandler(nil, "irc_onnotice", from, text)
end

-- 5.1 compat code for 5.2
if not unpack then
  unpack = table.unpack
end
if not table.getn then
  table.getn = function (t) return #t end
end

log("Loading script")
local f = loadfile("labspace.lua")
f()
log("Loaded")
onload()
math.randomseed(1)

print("")
print("You can now type commands. Dummy channel users: u1..u10.")
print("Command: pub <nick> <message here> - channel message (e.g. pub u1 !add)")
print("Command: notc <nick> <message here> - notice to labspace (e.g. notc u1 kill u2)")
print("Command: join <playercount> - join fake players (to not have to !add everyone)")
print("Command: exit - terminates simulation")
print("")

Scheduler.mainloop()

