local _h = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local clear, feed, execute = _h.clear, _h.feed, _h.execute
local insert = _h.insert

describe('echomsg', function()
  local screen

  -- Gets the Vim :messages history.
  local function get_messages()
    -- Gather the :messages lines.
    -- Cannot use vim_command_output('messages') because of
    --    https://github.com/neovim/neovim/pull/1959
    execute('redir => g:foo | silent messages | redir END')
    return _h.eval('g:foo')
  end

  -- Asserts that:
  --    - :messages contains `msg` exactly once
  --    - no truncated ("...") text was written to :messages
  local function assert_msg(msg)
    assert(msg ~= nil and msg ~= "", "'msg' should not be empty")
    local messages = get_messages()
    --Should not have truncated "..." messages.
    local istart, iend = messages:find('...', 1, true)
    assert(istart == nil, ':messages contains a truncated message')

    --Should have the exact `msg`.
    istart, iend = messages:find(msg, 1, true)
    assert(istart ~= nil and istart > 0, ':messages does not have: '..msg)

    --Should not have duplicates.
    istart, iend = messages:find(msg, iend, true)
    assert(istart == nil, ':messages contains a duplicate: '..msg)
  end

  -- Asserts that :messages is empty.
  local function assert_messages_empty()
    local messages = get_messages()
    assert(messages == '', ':messages should be empty, but it contains: '..messages)
  end

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
    --Some tests will exercise other 'cmdheight' values.
    _h.nvim('set_option', 'cmdheight', 1)
    --Hide the "+N :messages" notification.
    _h.nvim('set_option', 'showcmd', false)
  end)

  after_each(function()
    screen:detach()
  end)

  describe(':echomsg', function()
    before_each(function()
      execute('set shortmess-=T')
    end)

    it('one line does not cause scroll', function()
      execute('echom "line1, normal message"')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1, normal message                                |
      ]])
    end)

    it('2x causes 1-line scroll', function()
      execute('echom "line1 line1 line1 line1" | echom "line2 line2 line2 line2"')
      screen:expect([[
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1 line1 line1 line1                              |
      line2 line2 line2 line2                              |
      Press ENTER or type command to continue^             |
      ]])
    end)

    it('one very long line causes a scroll', function()
      local fullmsg = "line1.a line1.b line1.c line1.d line1.e line1.f line1.g line1.h line1.i line1.j line1.k line1.l line1.m line1.o line1.p line1.q line1.r line1.s"
      execute('echom "'..fullmsg..'"')
      screen:expect([[
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1.a line1.b line1.c line1.d line1.e line1.f line1|
      .g line1.h line1.i line1.j line1.k line1.l line1.m li|
      ne1.o line1.p line1.q line1.r line1.s                |
      Press ENTER or type command to continue^             |
      ]])
      assert_msg(fullmsg)
    end)

    it(':silent, :silent!', function()
      local fullmsg = 'line1.a line1.b line1.c line1.d line1.e line1.f line1.g line1.h line1.i line1.j line1.k line1.l line1.m line1.o line1.p line1.q line1.r line1.s'
      _h.nvim('set_option', 'cmdheight', 2)
      execute('silent  echom "'..fullmsg..'"')
      execute('silent! echom "'..fullmsg..'"')
      _h.eval('1') --wait()
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
                                                           |
                                                           |
      ]])
      assert_messages_empty()
    end)
  end)

  describe(':echoerr (highlight)', function()
    before_each(function()
      execute('set shortmess-=T')
      --ignore highligting of ~-lines
      screen:set_default_attr_ids({
        [2] = {foreground = Screen.colors.White, background = Screen.colors.Red},
        [3] = {bold=true, foreground = Screen.colors.SeaGreen}
      })
      screen:set_default_attr_ignore(
        {{bold=true, foreground=Screen.colors.Blue}})
    end)

    it('one line does not cause scroll', function()
      execute('echoerr "line1, normal message"')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      {2:line1, normal message}                                |
      ]])
    end)

    it('2x causes 1-line scroll', function()
      execute('echoerr "line1 line1 line1 line1" | echoerr "line2 line2 line2 line2"')
      screen:expect([[
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      {2:line1 line1 line1 line1}                              |
      {2:line2 line2 line2 line2}                              |
      {3:Press ENTER or type command to continue}^             |
      ]])
    end)

    it('one very long line causes a scroll', function()
      local fullmsg = 'line1.a line1.b line1.c line1.d line1.e line1.f line1.g line1.h line1.i line1.j line1.k line1.l line1.m line1.o line1.p line1.q line1.r line1.s'
      execute('echom "'..fullmsg..'"')
      screen:expect([[
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1.a line1.b line1.c line1.d line1.e line1.f line1|
      .g line1.h line1.i line1.j line1.k line1.l line1.m li|
      ne1.o line1.p line1.q line1.r line1.s                |
      {3:Press ENTER or type command to continue}^             |
      ]])
      assert_msg(fullmsg)
    end)
  end)


  local function echomsg_bang_tests(cmd_under_test)
    it('one line does NOT cause scroll', function()
      local fullmsg = 'line1, normal message'
      execute(cmd_under_test..' "'..fullmsg..'"')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1, normal message                                |
      ]])
      assert_msg(fullmsg)
    end)

    it('overwrites previous :echom (does NOT cause a scroll)', function()
      execute('echom  "line1" | '..cmd_under_test..' "line2"')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line2                                                |
      ]])
    end)

    it('followed by :echom causes a scroll', function()
      execute(cmd_under_test..' "line1" | echom  "line2"')
      screen:expect([[
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1                                                |
      line2                                                |
      Press ENTER or type command to continue^             |
      ]])
      assert_msg('line1')
      assert_msg('line2')
    end)

    it('2x does NOT cause a scroll', function()
      execute(cmd_under_test..' "line1 line1 line1 line1" | '..cmd_under_test..' "line2 line2 line2 line2"')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line2 line2 line2 line2                              |
      ]])
    end)

    it('very long line does NOT cause a scroll', function()
      local fullmsg = 'line1.a line1.b line1.c line1.d line1.e line1.f line1.g line1.h line1.i line1.j line1.k line1.l line1.m line1.o line1.p line1.q line1.r line1.s'
      execute(cmd_under_test..' "'..fullmsg..'"')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1.a line1.b line1.c....p line1.q line1.r line1.s |
      ]])
      assert_msg(fullmsg)
    end)

    it('very long line fills available cmdline space', function()
      local fullmsg = 'line1.a line1.b line1.c line1.d line1.e line1.f line1.g line1.h line1.i line1.j line1.k line1.l line1.m line1.o line1.p line1.q line1.r line1.s'
      _h.nvim('set_option', 'cmdheight', 2)
      execute(cmd_under_test..' "'..fullmsg..'"')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1.a line1.b line1.c line1.d line1.e line1.f li...|
      e1.l line1.m line1.o line1.p line1.q line1.r line1.s |
      ]])
      assert_msg(fullmsg)
    end)

    it('called from a function', function()
      local fullmsg = 'line1.a line1.b line1.c line1.d line1.e line1.f line1.g line1.h line1.i line1.j line1.k line1.l line1.m line1.o line1.p line1.q line1.r line1.s'
      _h.nvim('set_option', 'cmdheight', 2)
      execute([[
      func! Foo()
        ]]..cmd_under_test..[[ "]]..fullmsg..[["
      endfunc]])
      execute('call Foo()')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1.a line1.b line1.c line1.d line1.e line1.f li...|
      e1.l line1.m line1.o line1.p line1.q line1.r line1.s |
      ]])
      assert_msg(fullmsg)
    end)

    it('in a mapping', function()
      local fullmsg = 'line1.a line1.b line1.c line1.d line1.e line1.f line1.g line1.h line1.i line1.j line1.k line1.l line1.m line1.o line1.p line1.q line1.r line1.s'
      _h.nvim('set_option', 'cmdheight', 2)
      execute('nnoremap foo :'..cmd_under_test..' "'..fullmsg..'"<cr>')
      _h.feed('foo')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1.a line1.b line1.c line1.d line1.e line1.f li...|
      e1.l line1.m line1.o line1.p line1.q line1.r line1.s |
      ]])
      assert_msg(fullmsg)
    end)

    it(':silent, :silent!', function()
      local fullmsg = 'line1.a line1.b line1.c line1.d line1.e line1.f line1.g line1.h line1.i line1.j line1.k line1.l line1.m line1.o line1.p line1.q line1.r line1.s'
      _h.nvim('set_option', 'cmdheight', 2)
      execute('silent  '..cmd_under_test..' "'..fullmsg..'"')
      execute('silent! '..cmd_under_test..' "line2 for silent!"')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      :silent! echom! "line2 for silent!"                  |
                                                           |
      ]])
      assert_msg(fullmsg)
      assert_msg("line2 for silent!")
    end)

    it('in a <silent> (not :silent) mapping', function()
      local fullmsg = 'line1.a line1.b line1.c line1.d line1.e line1.f line1.g line1.h line1.i line1.j line1.k line1.l line1.m line1.o line1.p line1.q line1.r line1.s'
      _h.nvim('set_option', 'cmdheight', 2)
      execute('nnoremap <silent> foo :'..cmd_under_test..' "'..fullmsg..'"<cr>')
      _h.feed('foo')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1.a line1.b line1.c line1.d line1.e line1.f li...|
      e1.l line1.m line1.o line1.p line1.q line1.r line1.s |
      ]])
      assert_msg(fullmsg)
    end)

    it('in a <silent> :silent mapping', function()
      local fullmsg = 'line1.a line1.b line1.c line1.d line1.e line1.f line1.g line1.h line1.i line1.j line1.k line1.l line1.m line1.o line1.p line1.q line1.r line1.s'
      _h.nvim('set_option', 'cmdheight', 2)
      execute('nnoremap <silent> foo :silent '..cmd_under_test..' "'..fullmsg..'"<cr>')
      _h.feed('foo')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
                                                           |
                                                           |
      ]])
      assert_msg(fullmsg)
    end)
  end

  describe(':echomsg! (shortmess+=T)', function()
    before_each(function()
      execute('silent set shortmess+=T')
    end)
    echomsg_bang_tests('echom!')
  end)

  describe(':echomsg! (shortmess-=T)', function()
    before_each(function()
      execute('set shortmess-=T')
    end)
    echomsg_bang_tests('echom!')
  end)
end)
