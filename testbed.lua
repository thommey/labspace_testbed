-- for now, nick == numeric == .. and all users are valid // TODO
chanusers = { "u1", "u2", "u3", "u4", "u5", "u6" }

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

  for m in mode_iter(modes) do
    if m.plsmns then
      modestr = modestr .. "+"
    else
      modestr = modestr .. "-"
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
        if (f.args) then
          f.func(unpack(f.args))
        else
          f.func()
        end
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

function sleep(n)
  os.execute("sleep " .. n)
end

function Scheduler.mainloop()
  while 1 do
    Scheduler.allcheck()
    ontick()
    sleep(1)
  end
end

-- various debugging utilities
function debug(text)
  print(os.date() .. " " .. text)
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
  debug(format_from(from) .. " -> " .. text)
end

function pub(from, chan, text)
  debug("<" .. from .. "@" .. chan .. "> " .. text)
  gamehandler(nil, "irc_onchanmsg", from, chan, text)
end

function notc(from, text)
  debug("-" .. from .. "- " .. text)
  gamehandler(nil, "irc_onnotice", from, text)
end

function moveon()
  pub("u6", "#labspace", "!status")
  notc("u1", "kill u2")
  notc("u6", "kill u1")
  sleep(4)
  notc("u2", "investigate u6")
  pub("u6", "#labspace", "!status")
  sleep(4)
  pub("u2", "#labspace", "u6 is mad says the investigator who is me")
  pub("u6", "#labspace", "!status")
  sleep(2)
  notc("u2", "vote u6")
  sleep(5)
  pub("u6", "#labspace", "!status")
  sleep(5)
  notc("u3", "vote u6")
  notc("u4", "vote u6")
  pub("u6", "#labspace", "!status")
  notc("u5", "vote u2")
  sleep(1)
  pub("u6", "#labspace", "!status")
  notc("u6", "vote u2")
  pub("u6", "#labspace", "!status")
  sleep(3)
  pub("u6", "#labspace", "!status")
  notc("u6", "kill u2")
  pub("u6", "#labspace", "!status")
  sleep(4)
  pub("u6", "#labspace", "!status")
  notc("u2", "investigate u6")
  sleep(4)
  pub("u6", "#labspace", "!status")
  notc("u2", "vote u6")
  notc("u3", "vote u6")
  pub("u6", "#labspace", "!status")
  sleep(1)
  pub("u6", "#labspace", "!status")
  notc("u4", "vote u6")
  pub("u6", "#labspace", "!status")
  sleep(4)
  pub("u6", "#labspace", "!status")
  notc("u5", "vote u2")
  pub("u6", "#labspace", "!status")
  notc("u6", "vote u2")
  pub("u6", "#labspace", "!status")
  sleep(1)
  pub("u6", "#labspace", "!status")
end

debug("Loading script")
local f = loadfile("labspace.lua")
f()
debug("Loaded")
onload()
math.randomseed(1)

pub("u1", "#labspace", "!add")
pub("u2", "#labspace", "!add")
pub("u3", "#labspace", "!add")
pub("u4", "#labspace", "!add")
pub("u5", "#labspace", "!add")
pub("u6", "#labspace", "!add")
pub("u6", "#labspace", "!status")

Schedulers[1]:add(35, moveon)
local nick = irc_getnickbynumeric("derp")
Scheduler.mainloop()

