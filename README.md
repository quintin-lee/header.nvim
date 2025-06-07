A Neovim plugin that automatically inserts templates when creating new files. It supports variable substitution, cursor positioning, and author information memorization.

## Features

+ ✨ Multi-language Support: Predefined templates for Python, Shell, C/C++, and more.
+ 🧠 Intelligent Variable Substitution: Supports variables like {{DATE}}, {{AUTHOR}}, {{FILENAME}}, etc.
+ 📌 Cursor Positioning: Automatically positions the cursor at the location marked by <!-- CURSOR -->.
+ 🔄 Author Memorization: Automatically saves the last-entered author information.
+ 🚀 Flexible Configuration: Allows customizing template paths, variable markers, and default author.

## Installation

### Using Plugin Managers

#### Lazy.nvim

```lua
{
  "quintin-lee/header",
  config = function()
    require("header").setup()
  end
}
```

#### packer.nvim

```lua
use {
  "quintin-lee/header",
  config = function()
    require("header").setup()
  end
}
```

## Configuration Example

```lua
require("header").setup({
  -- Custom templates (supports more file types)
  templates = {
    ["*.sh"] = "bash.txt",
    ["*.c"] = "c.txt",
  },
  -- Author configuration
  default_author = "John Doe",          -- Default author
  enable_persistent_author = true,      -- Enable author memorization
  author_file = vim.fn.stdpath("data").. "/header_author.txt", -- Author information save path
  -- Other configurations
  cursor_marker = "<!-- CURSOR -->",    -- Cursor positioning marker
  remove_trailing_newlines = true,      -- Automatically remove trailing empty lines
})
```

## Template Syntax

Template files support the following variables, which will be automatically substituted during insertion:

+ {{DATE}}: Current date (YYYY-MM-DD)
+ {{AUTHOR}}: Entered author name
+ {{FILENAME}}: File name (without path)
+ {{YEAR}}: Current year
+ {{TIME}}: Current time (HH:MM:SS)

## Example Template (bash.txt)

```
#!/usr/bin/env bash
#
# {{FILENAME}}
# @author {{AUTHOR}}
# @date {{DATE}}
#
# Description: This is a Shell script.
#
# <!-- CURSOR -->
```

## Usage

### Automatic Insertion (Recommended)

Templates are automatically inserted when creating new files:

```bash
nvim new_script.sh
```

### Manual Insertion

Manually insert a template for the current file using the command:

```lua
:lua require("header").insert_template_for_current_file()
```
