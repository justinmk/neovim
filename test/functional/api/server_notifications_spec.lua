local helpers = require('test.functional.helpers')(after_each)
local eq, clear, eval, command, nvim, next_msg =
  helpers.eq, helpers.clear, helpers.eval, helpers.command, helpers.nvim,
  helpers.next_msg
local feed = helpers.feed
local funcs = helpers.funcs
local meths = helpers.meths
local notify = helpers.notify
local retry = helpers.retry

describe('notify', function()
  local channel

  before_each(function()
    clear()
    channel = nvim('get_api_info')[1]
  end)

  describe('passing a valid channel id', function()
    it('sends the notification/args to the corresponding channel', function()
      eval('rpcnotify('..channel..', "test-event", 1, 2, 3)')
      eq({'notification', 'test-event', {1, 2, 3}}, next_msg())
      command('au FileType lua call rpcnotify('..channel..', "lua!")')
      command('set filetype=lua')
      eq({'notification', 'lua!', {}}, next_msg())
    end)
  end)

  describe('receive', function()
    before_each(function()
      helpers.clear()
      command("let g:_gained=0")
      command("let g:_lost=0")
      command("autocmd FocusGained * let g:_gained+=1")
      command("autocmd FocusLost * let g:_lost+=1")
    end)
    it('in normal-mode', function()
      eq(0, eval('g:_gained'))
      eq(0, eval('g:_lost'))
      -- notify('focusgained')
      funcs.rpcnotify(0, 'focusgained')
      retry(nil, 1000, function()
        eq(1, eval('g:_gained'))
      end)
    end)
    it('in insert-mode', function()
      feed('ifoo')
      eq(0, eval('g:_gained'))
      eq(0, eval('g:_lost'))
      -- notify('focusgained')
      funcs.rpcnotify(0, 'focusgained')
      retry(nil, 1000, function()
        eq(1, eval('g:_gained'))
      end)
    end)
    it('in cmdline-mode', function()
      feed(':foo')
      eq(0, eval('g:_gained'))
      eq(0, eval('g:_lost'))
      -- notify('focusgained')
      funcs.rpcnotify(0, 'focusgained')
      retry(nil, 1000, function()
        eq(1, eval('g:_gained'))
      end)
    end)
    it('in terminal-mode', function()
      feed(':terminal<CR>')
      feed('ifoo')
      eq(0, eval('g:_gained'))
      eq(0, eval('g:_lost'))
      -- notify('focusgained')
      funcs.rpcnotify(0, 'focusgained')
      retry(nil, 1000, function()
        eq(1, eval('g:_gained'))
      end)
    end)
  end)

  describe('passing 0 as the channel id', function()
    it('sends the notification/args to all subscribed channels', function()
      nvim('subscribe', 'event2')
      eval('rpcnotify(0, "event1", 1, 2, 3)')
      eval('rpcnotify(0, "event2", 4, 5, 6)')
      eval('rpcnotify(0, "event2", 7, 8, 9)')
      eq({'notification', 'event2', {4, 5, 6}}, next_msg())
      eq({'notification', 'event2', {7, 8, 9}}, next_msg())
      nvim('unsubscribe', 'event2')
      nvim('subscribe', 'event1')
      eval('rpcnotify(0, "event2", 10, 11, 12)')
      eval('rpcnotify(0, "event1", 13, 14, 15)')
      eq({'notification', 'event1', {13, 14, 15}}, next_msg())
    end)

    it('does not crash for deeply nested variable', function()
      meths.set_var('l', {})
      local nest_level = 1000
      meths.command(('call map(range(%u), "extend(g:, {\'l\': [g:l]})")'):format(nest_level - 1))
      eval('rpcnotify('..channel..', "event", g:l)')
      local msg = next_msg()
      eq('notification', msg[1])
      eq('event', msg[2])
      local act_ret = msg[3]
      local act_nest_level = 0
      while act_ret do
        if type(act_ret) == 'table' then
          local cur_act_ret = nil
          for k, v in pairs(act_ret) do
            eq(1, k)
            cur_act_ret = v
          end
          if cur_act_ret then
            act_nest_level = act_nest_level + 1
          end
          act_ret = cur_act_ret
        else
          eq(nil, act_ret)
        end
      end
      eq(nest_level, act_nest_level)
    end)
  end)
end)
