local M = {}

-- 获取当前脚本所在目录作为基准路径
local function get_base_dir()
  local source = debug.getinfo(1, 'S').source:sub(2)
  return source:match("(.*/)")
end

local base_dir = get_base_dir()

-- 创建一个自动命令组来管理所有模板相关的自动命令
local template_augroup = vim.api.nvim_create_augroup('TemplateAutoCommands', { clear = true })

-- 模板插入函数
local function insert_template(pattern, template_path)
  -- 构建完整路径
  local full_path = base_dir .. 'templates/' .. template_path
  
  -- 检查模板文件是否存在
  if vim.fn.filereadable(full_path) == 0 then
    vim.notify(string.format("Template file not found: %s", full_path), vim.log.levels.WARN)
    return
  end

  vim.api.nvim_create_autocmd('BufNewFile', {
    pattern = pattern,
    callback = function()
      -- 插入模板文件内容
      vim.cmd('0r ' .. full_path)
      -- 删除尾部空行
      if pattern ~= '*.sh' then
          vim.cmd([[%s/\n\+\%$//e]])
      end

      vim.ui.input({
        prompt = "Enter your name: ",
        default = "",
      }, function(author_name)
        local bufnr = vim.api.nvim_get_current_buf()
        local date = os.date("%Y-%m-%d")
        local filename = vim.fn.expand('%')
        -- 读取缓冲区内容
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

        -- 替换 {{DATE}} 和 {{AUTHOR}}
        for i, line in ipairs(lines) do
          lines[i] = line:gsub("{{DATE}}", date):gsub("{{AUTHOR}}", author_name):gsub("{{FILENAME}}", filename)
        end
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

        -- 查找 <!-- CURSOR --> 标记并移动光标到该位置
        local cursor_pos = vim.fn.search('<\\!-- CURSOR -->', 'n')
        if cursor_pos > 0 then
          vim.api.nvim_win_set_cursor(0, {cursor_pos, 0})
          -- 删除 <!-- CURSOR --> 标记
          vim.cmd(cursor_pos .. 'delete _')
        else
          -- 如果没有找到 <!-- CURSOR --> 标记，跳转到文件末尾
          local line_count = vim.api.nvim_buf_line_count(vim.api.nvim_get_current_buf())
          if line_count > 0 then
            vim.api.nvim_win_set_cursor(0, {line_count, 0})
          end
        end
      end)
    end,
    group = template_augroup
  })
end

-- 注册模板（现在只需要文件名，不需要完整路径）
M.templates = {
  ['*.py'] = 'python.txt',
  ['*.sh'] = 'bash.txt',
  ['*.c'] = 'c.txt',
  ['*.cpp'] = 'cpp.txt',
  ['*.lua'] = 'lua.txt', -- 示例新增Lua模板
}

-- 注册所有模板
function M.setup(opts)
  -- 合并用户配置
  if opts and opts.templates then
    M.templates = vim.tbl_deep_extend('force', M.templates, opts.templates)
  end
  
  -- 注册所有模板
  for pattern, template_path in pairs(M.templates) do
    insert_template(pattern, template_path)
  end
end

-- 默认初始化
M.setup()

return M
