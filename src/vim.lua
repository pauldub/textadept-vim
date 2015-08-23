local math = require('math')

MODE_COMMAND = {
  keys_mode = 'command_mode',
  status = 'COMMAND MODE',
  on_enter = function()
    -- Change the caret style only in GUI mode, because with curses it just fucks up its display...
    if not CURSES then
      buffer.caret_style = buffer.CARETSTYLE_BLOCK
    end
  end
}

MODE_INSERT = {
  status = 'INSERT MODE',
  on_enter = function()
    if not CURSES then
      buffer.caret_style = buffer.CARETSTYLE_LINE
    end
  end
}

MODE_EX = {
  keys_mode = 'ex_mode',
  status = 'EX MODE',
  on_enter = function()
    ui.command_entry.enter_mode('ex_mode')
  end
}

function enter_mode(mode)
  keys.MODE = mode.keys_mode
  ui.statusbar_text = mode.status
  local on_enter = mode.on_enter
  if type(on_enter) == 'function' then
    on_enter(mode)
  end
end

function cmd(command)
  return {
    then_insert = function()
      command()
      enter_mode(MODE_INSERT)
    end,
    then_command = function()
      command()
      enter_mode(MODE_COMMAND)
    end
  }
end

-- Quickmarks

--[[
  TODO:
    - handle multiple buffers...
]]
local Quickmarks = {}
Quickmarks.mt = {
  __index = function(quickmarks, key)
    return function()
      local pos = quickmarks.assigned[key]
      if pos ~= nil then
        buffer.goto_pos(pos)
      else
        ui.statusbar_text = 'quickmark ' .. tostring(key) .. ' does not exist'
      end
    end
  end
}

function Quickmarks.new()
  local marks = {}
  local q = { 
    assigned = marks,
    
    assign_keymap = function(self)
      local t = {}
      setmetatable(t, {
        __index = function(table, key)
          return function(self)
            marks[key] = buffer.current_pos
          end
        end
      })
      return t
    end
  }
  setmetatable(q, Quickmarks.mt)
  return q
end

-- MODE_COMMAND mode keybindings
local quickmarks = Quickmarks.new()

keys.command_mode = {
  -- Movement keys
  ['h'] = buffer.char_left,
  ['j'] = buffer.line_down,
  ['k'] = buffer.line_up,
  ['l'] = buffer.char_right,
  ['w'] = buffer.word_part_right, -- move word forward
  ['b'] = buffer.word_part_left, -- move word backward
  ['e'] = buffer.word_right_end, -- move to the end of the word
  ['cf'] = buffer.page_down, -- scroll 1 page down
  ['cb'] = buffer.page_up, -- scroll 1 page up
  ['ce'] = buffer.line_scroll_down,
  ['cy'] = buffer.line_scroll_up,
  ['G'] = buffer.document_end,
  ['I'] = cmd(buffer.vc_home).then_insert, -- scroll to the end
  ['$'] = buffer.line_end,
  ['^'] = buffer.home,
  ['0'] = buffer.home,
  ['A'] = cmd(buffer.line_end).then_insert,
  ['a'] = cmd(buffer.char_right).then_insert,
  ['M'] = buffer.vertical_center_caret,
  -- Quickmarks
  ['\''] = quickmarks,
  ['m'] = quickmarks:assign_keymap(),
  ['H'] = function()
    buffer.goto_pos(buffer.position_from_line(buffer.first_visible_line))
  end,
  ['M'] = function()
    local middle_line = math.floor(buffer.first_visible_line + (buffer.lines_on_screen / 2))
    buffer.goto_pos(buffer.position_from_line(middle_line))
  end,
  ['L'] = function()
    buffer.goto_line(buffer.first_visible_line + buffer.lines_on_screen - 1)
  end,
  -- Editing keys
  ['o'] = cmd(function()
                buffer.line_end()
                buffer.new_line()
              end).then_insert,
  ['O'] = cmd(function()
                buffer.home()
                buffer.new_line()
                buffer.line_up()
              end).then_insert,
  ['x'] = function()     
    buffer.delete_range(buffer.current_pos, 1)
  end, -- delete char under caret
  ['d'] = {
    ['d'] = buffer.line_delete, -- delete line under caret
    ['w'] = buffer.del_word_right, -- delete word after caret
    ['b'] = buffer.del_word_left, -- delete word before caret
    ['$'] = buffer.del_line_right, -- delete whole line after caret
    ['^'] = buffer.del_line_left, -- delete whole line before caret
    -- ['j'] = -- delete the current line and the next one
    -- ['k'] = -- delete the current line and the previous one
  },
  ['D'] = buffer.del_line_right, -- delete rest of line
  ['C'] = cmd(buffer.del_line_right).then_insert, -- delete rest of line and go to insert mode.
  ['c'] = {
    ['w'] = cmd(buffer.del_word_right).then_insert,
    ['b'] = cmd(buffer.del_word_left).then_insert,
  },
  -- Buffers navigation
  ['g'] = {
    ['g'] =  buffer.document_start, -- scroll to the beginning, this and the following bindings have to be grouped
    ['t'] = function() view:goto_buffer(1, true) end,
    ['T'] = function() view:goto_buffer(-1, true) end,
  },
  -- Clipboard
  ['u'] = buffer.undo,
  ['cr'] = buffer.redo,
  -- Folds
  ['z'] = {
    -- TODO: Iterate all lines and close chidlren if fold is toplevel.
    ['M'] = {buffer.fold_all, buffer.FOLDACTION_CONTRACT}, -- close all folds
    ['m'] = function()
      local current_line = buffer.line_from_position(buffer.current_pos)
      buffer.fold_children(current_line, buffer.FOLDACTION_CONTRACT)
    end, -- fold all children
    ['o'] = function()
      local current_line = buffer.line_from_position(buffer.current_pos)
      -- ui.print('current_pos: ', buffer.current_pos, ' current_line: ', current_line)
      buffer.fold_line(current_line, buffer.FOLDACTION_MODE_EXPAND)
    end, -- unfold current line
    ['c'] = function()
      local current_line = buffer.line_from_position(buffer.current_pos)
      buffer.fold_line(current_line, buffer.FOLDACTION_CONTRACT)
    end, -- fold current line
    -- ['A'] = -- Open all folds
  },
  -- View navigation
  ['cw'] = {
    ['w'] = {ui.goto_view, 1, true}, -- next view
    ['cw'] = {ui.goto_view, -1, true},
    ['s'] = {view.split, view}, -- horizontal split
    ['v'] = {view.split, view, true}, -- vertical split
    ['c'] = {view.unsplit, view}, -- close / unsplit
  },
  [':'] = {enter_mode, MODE_EX},
  ['i'] = {enter_mode, MODE_INSERT}
}

-- MODE_EX mode keybindings

function handle_ex_command(cmd)
  if cmd == 'q' then
    quit()
  elseif cmd == 'w' then
    io.save_file()
  else
    ui.statusbar_text = 'unknown ex command \'' .. cmd .. '\''
  end
end

keys.ex_mode = {
  ['cc'] = cmd(ui.command_entry.finish_mode).then_command,
  ['\n'] = function()
    ui.command_entry.finish_mode(handle_ex_command)
    enter_mode(MODE_COMMAND)
  end
}

keys['cc'] = {enter_mode, MODE_COMMAND}
keys['esc'] = {enter_mode, MODE_COMMAND}

events.connect(events.BUFFER_NEW, function()
  enter_mode(MODE_COMMAND)
end)
