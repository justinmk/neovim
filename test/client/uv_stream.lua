---
--- Basic stream types.
--- See `rpc_stream.lua` for the msgpack layer.
---

local uv = vim.uv

--- @class test.Stream
--- @field write fun(self, data: string|string[])
--- @field read_start fun(self, cb: fun(chunk: string))
--- @field read_stop fun(self)
--- @field close fun(self, signal?: string)

--- Stream over given pipes.
---
--- @class vim.StdioStream : test.Stream
--- @field private _in uv.uv_pipe_t
--- @field private _out uv.uv_pipe_t
local StdioStream = {}
StdioStream.__index = StdioStream

function StdioStream.open()
  local self = setmetatable({
    _in = assert(uv.new_pipe(false)),
    _out = assert(uv.new_pipe(false)),
  }, StdioStream)
  self._in:open(0)
  self._out:open(1)
  return self
end

--- @param data string|string[]
function StdioStream:write(data)
  self._out:write(data)
end

function StdioStream:read_start(cb)
  self._in:read_start(function(err, chunk)
    if err then
      error(err)
    end
    cb(chunk)
  end)
end

function StdioStream:read_stop()
  self._in:read_stop()
end

function StdioStream:close()
  self._in:close()
  self._out:close()
end

--- Stream over a named pipe or TCP socket.
---
--- @class test.SocketStream : test.Stream
--- @field package _stream_error? string
--- @field package _socket uv.uv_pipe_t
local SocketStream = {}
SocketStream.__index = SocketStream

function SocketStream.open(file)
  local socket = assert(uv.new_pipe(false))
  local self = setmetatable({
    _socket = socket,
    _stream_error = nil,
  }, SocketStream)
  uv.pipe_connect(socket, file, function(err)
    self._stream_error = self._stream_error or err
  end)
  return self
end

function SocketStream.connect(host, port)
  local socket = assert(uv.new_tcp())
  local self = setmetatable({
    _socket = socket,
    _stream_error = nil,
  }, SocketStream)
  uv.tcp_connect(socket, host, port, function(err)
    self._stream_error = self._stream_error or err
  end)
  return self
end

function SocketStream:write(data)
  if self._stream_error then
    error(self._stream_error)
  end
  uv.write(self._socket, data, function(err)
    if err then
      error(self._stream_error or err)
    end
  end)
end

function SocketStream:read_start(cb)
  if self._stream_error then
    error(self._stream_error)
  end
  uv.read_start(self._socket, function(err, chunk)
    if err then
      error(err)
    end
    cb(chunk)
  end)
end

function SocketStream:read_stop()
  if self._stream_error then
    error(self._stream_error)
  end
  uv.read_stop(self._socket)
end

function SocketStream:close()
  uv.close(self._socket)
end

--- Stream over child process stdio.
---
--- @class test.ProcStream : test.Stream
--- @field private _proc uv.uv_process_t
--- @field private _pid integer
--- @field private _child_stdin uv.uv_pipe_t
--- @field private _child_stdout uv.uv_pipe_t
--- @field private _child_stderr uv.uv_pipe_t
--- @field stdout_eof boolean
--- @field stderr_eof boolean
--- @field collect_output boolean
--- @field status integer
--- @field signal integer
local ProcStream = {}
ProcStream.__index = ProcStream

--- Starts child process specified by `argv`.
---
--- @param argv string[]
--- @param env string[]?
--- @param io_extra uv.uv_pipe_t?
--- @return test.ProcStream
function ProcStream.spawn(argv, env, io_extra)
  local self = setmetatable({
    collect_output = true,
    stdout = '',
    stderr = '',
    stdout_error = nil,
    stderr_error = nil,
    stdout_eof = false,
    stderr_eof = false,
    _child_stdin = assert(uv.new_pipe(false)),
    _child_stdout = assert(uv.new_pipe(false)),
    _child_stderr = assert(uv.new_pipe(false)),
    _exiting = false,
  }, ProcStream)
  local prog = argv[1]
  local args = {} --- @type string[]
  for i = 2, #argv do
    args[#args + 1] = argv[i]
  end
  --- @diagnostic disable-next-line:missing-fields
  self._proc, self._pid = uv.spawn(prog, {
    stdio = { self._child_stdin, self._child_stdout, self._child_stderr, io_extra },
    args = args,
    --- @diagnostic disable-next-line:assign-type-mismatch
    env = env,
  }, function(status, signal)
    self.status = status
    self.signal = signal
    -- self:check_done()
  end)

  if not self._proc then
    local err = self._pid
    error(err)
  end

  return self
end

function ProcStream:write(data)
  self._child_stdin:write(data)
end

function ProcStream:on_read(stream, cb, err, chunk)
  if err then
    -- stderr_error/stdout_error
    self[stream .. '_error'] = err ---@type string
    -- error(err)
  elseif chunk then
    -- stderr/stdout
    self[stream] = self[stream] .. chunk ---@type string
    if self.collect_output then
      self.stdout = self.stdout .. chunk ---@type string
    end
  else
    -- stderr_eof/stdout_eof
    self[stream .. '_eof'] = true ---@type boolean
    -- self:check_done()
  end

  -- Handler provided by the caller.
  if cb then
    cb(chunk)
  end
end

-- function ProcStream:check_done()
--   if self.stdout_eof and self.stderr_eof and (self.status or self.signal) then
--     self.wait_cb()
--   end
-- end
--
function ProcStream:wait()
  while not (self.stdout_eof and self.stderr_eof and (self.status or self.signal)) do
    uv.run('once')
  end
end

function ProcStream:read_start(on_stdout, on_stderr)
  self._child_stdout:read_start(function(err, chunk)
    self:on_read('stdout', on_stdout, err, chunk)
  end)
  self._child_stderr:read_start(function(err, chunk)
    self:on_read('stderr', on_stderr, err, chunk)
  end)
end

function ProcStream:read_stop()
  self._child_stdout:read_stop()
  self._child_stderr:read_stop()
end

function ProcStream:close(signal)
  if self._closed then
    return
  end
  self._closed = true
  self:read_stop()
  self._child_stdin:close()
  self._child_stdout:close()
  self._child_stderr:close()
  if type(signal) == 'string' then
    self._proc:kill('sig' .. signal)
  end
  while self.status == nil do
    uv.run 'once'
  end
  return self.status, self.signal
end

return {
  StdioStream = StdioStream,
  ProcStream = ProcStream,
  SocketStream = SocketStream,
}
