local M = {}

-- 获取当前脚本所在目录作为基准路径
local function get_base_dir()
  local source = debug.getinfo(1, 'S').source:sub(2)
  return source:match("(.*/)")
end

local base_dir = get_base_dir()
local config = {
  templates = {
    ['*.py'] = 'python.txt',
    ['*.sh'] = 'bash.txt',
    ['*.c'] = 'c.txt',
    ['*.cpp'] = 'cpp.txt',
  },
  author_file = vim.fn.stdpath('data') .. '/header_author.txt',
  cursor_marker = '<!-- CURSOR -->',
  enable_persistent_author = true,
  default_author = os.getenv('USER') or 'Your Name',
  remove_trailing_newlines = true,
}

-- 创建一个自动命令组来管理所有模板相关的自动命令
local template_augroup = vim.api.nvim_create_augroup('TemplateAutoCommands', { clear = true })

-- 已注册的模板模式缓存
local registered_templates = {}

-- 读取保存的作者信息
local function read_saved_author()
  if not config.enable_persistent_author then
    return config.default_author
  end
  
  local file = io.open(config.author_file, 'r')
  if file then
    local author = file:read('*l')
    file:close()
    return author or config.default_author
  end
  return config.default_author
end

-- 保存作者信息
local function save_author(author)
  if not config.enable_persistent_author or not author then
    return
  end
  
  local file = io.open(config.author_file, 'w')
  if file then
    file:write(author)
    file:close()
  end
end

-- 检查缓冲区是否已经包含模板内容
local function buffer_has_template(bufnr, template_path)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 10, false) -- 检查前10行
  local template_content = vim.fn.readfile(template_path)
  
  if #template_content == 0 then return false end
  
  -- 检查前几行是否匹配模板内容
  for i, line in ipairs(template_content) do
    if i > #lines then break end
    if lines[i]:gsub('%s+', '') ~= line:gsub('%s+', '') then
      return false
    end
  end
  
  return true
end

-- 模板插入函数
local function insert_template(pattern, template_path)
  -- 防止重复注册
  if registered_templates[pattern] then return end
  registered_templates[pattern] = true
  
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
      local bufnr = vim.api.nvim_get_current_buf()
      
      -- 检查是否已经插入过模板
      if buffer_has_template(bufnr, full_path) then
        return
      end
      
      -- 插入模板文件内容
      vim.cmd('0r ' .. full_path)
      
      -- 删除尾部空行
      if config.remove_trailing_newlines and pattern ~= '*.sh' then
        vim.cmd([[%s/\n\+\%$//e]])
      end

      -- 获取保存的作者或使用默认值
      local saved_author = read_saved_author()
      
      vim.ui.input({
        prompt = "Author: ",
        default = saved_author,
      }, function(author_name)
        if not author_name then return end -- 用户取消输入
        
        -- 保存新的作者信息
        if author_name ~= saved_author then
          save_author(author_name)
        end
        
        local date = os.date("%Y-%m-%d")
        local filename = vim.fn.expand('%:t') -- 只取文件名，不含路径
        
        -- 读取缓冲区内容
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        
        -- 替换变量
        for i, line in ipairs(lines) do
          lines[i] = line
            :gsub("{{DATE}}", date)
            :gsub("{{AUTHOR}}", author_name)
            :gsub("{{FILENAME}}", filename)
            :gsub("{{YEAR}}", os.date("%Y"))
            :gsub("{{TIME}}", os.date("%H:%M:%S"))
        end
        
        -- 更新缓冲区
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        
        -- 查找光标标记并移动光标
        local cursor_pos = vim.fn.search(config.cursor_marker, 'n')
        if cursor_pos > 0 then
          vim.api.nvim_win_set_cursor(0, {cursor_pos, 0})
          vim.cmd(cursor_pos .. 'delete _') -- 删除标记行
        else
          -- 没有标记，移动到文件末尾或第一个非空行
          local line_count = vim.api.nvim_buf_line_count(bufnr)
          if line_count > 0 then
            vim.api.nvim_win_set_cursor(0, {line_count, 0})
          end
        end
        
        -- 触发用户事件，便于其他插件扩展
        vim.api.nvim_exec_autocmds('User', { pattern = 'TemplateInserted' })
      end)
    end,
    group = template_augroup
  })
end

-- 注册所有模板
function M.setup(opts)
  -- 重置已注册模板缓存
  registered_templates = {}
  
  -- 合并用户配置
  config = vim.tbl_deep_extend('force', config, opts or {})
  
  -- 创建保存作者的目录（如果不存在）
  if config.enable_persistent_author then
    local data_dir = vim.fn.stdpath('data')
    if vim.fn.isdirectory(data_dir) == 0 then
      vim.fn.mkdir(data_dir, 'p')
    end
  end
  
  -- 注册所有模板
  for pattern, template_path in pairs(config.templates) do
    insert_template(pattern, template_path)
  end
end

-- 手动插入模板命令
function M.insert_template_for_current_file()
  local filename = vim.fn.expand('%:t')
  
  -- 查找匹配的模板
  for pattern, template_path in pairs(config.templates) do
    -- 将模式转换为正则表达式
    local regex = '^' .. pattern:gsub('%.', '%%.'):gsub('%*', '.*') .. '$'
    if filename:match(regex) then
      local full_path = base_dir .. 'templates/' .. template_path
      
      -- 检查模板文件是否存在
      if vim.fn.filereadable(full_path) == 0 then
        vim.notify(string.format("Template file not found: %s", full_path), vim.log.levels.WARN)
        return false
      end
      
      -- 检查是否已经插入过模板
      if buffer_has_template(0, full_path) then
        vim.notify("Template already exists in buffer", vim.log.levels.INFO)
        return false
      end
      
      -- 插入模板
      vim.cmd('0r ' .. full_path)
      vim.notify("Inserted template for " .. pattern)
      
      -- 触发模板处理逻辑（不包含文件读取部分）
      local bufnr = vim.api.nvim_get_current_buf()
      local saved_author = read_saved_author()
      
      vim.ui.input({
        prompt = "Author: ",
        default = saved_author,
      }, function(author_name)
        if not author_name then return end
        
        if author_name ~= saved_author then
          save_author(author_name)
        end
        
        local date = os.date("%Y-%m-%d")
        local filename = vim.fn.expand('%:t')
        
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        
        for i, line in ipairs(lines) do
          lines[i] = line
            :gsub("{{DATE}}", date)
            :gsub("{{AUTHOR}}", author_name)
            :gsub("{{FILENAME}}", filename)
            :gsub("{{YEAR}}", os.date("%Y"))
            :gsub("{{TIME}}", os.date("%H:%M:%S"))
        end
        
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        
        local cursor_pos = vim.fn.search(config.cursor_marker, 'n')
        if cursor_pos > 0 then
          vim.api.nvim_win_set_cursor(0, {cursor_pos, 0})
          vim.cmd(cursor_pos .. 'delete _')
        end
      end)
      
      return true
    end
  end
  
  vim.notify("No template found for current file type", vim.log.levels.INFO)
  return false
end

-- 默认初始化
M.setup()

return M
