# block-end-comment.nvim 🧩

Automatically inserts comments at the end of code blocks to show what is being closed.  
Built on **Treesitter** – precise and cross-language.

> [!CAUTION]
> This plugin was partially **vibecoded** using **OpenCode Zen Big Pickle**. Use at your own risk.

## 📑 Table of Contents

- [✨ Examples](#-examples)
- [📋 Requirements](#-requirements)
- [📦 Installation](#-installation)
- [⚙️ Configuration](#️-configuration)
- [🎮 Commands](#-commands)
- [⌨️ Default Keymaps](#️-default-keymaps)
- [🌍 Supported Languages](#-supported-languages)
- [📄 License](#-license)

---

## ✨ Examples

```cpp
for (int i = 0; i < vec.size(); i++) {
    process(vec[i]);
} // end for int i = 0

class MyEngine {
    // …
} // end class MyEngine

namespace utils {
    // …
} // end namespace utils
```

```rust
for item in collection.iter() {
    handle(item);
} // end for item in collection.iter()

impl Display for Point {
    // …
} // end impl Display for Point
```

```lua
for k, v in pairs(tbl) do
    print(k, v)
end -- end for k, v in pairs(tbl)
```

```python
for item in my_list:
    process(item)
# end for item in my_list

class MyClass:
    def method(self):
        pass
    # end fn method
# end class MyClass
```

---

## 📋 Requirements

- Neovim ≥ 0.9
- `nvim-treesitter` with desired parsers installed:

```vim
:TSInstall cpp rust zig lua python
```

---

## 📦 Installation

### lazy.nvim

```lua
{
  "markuxcu/block-end-comment.nvim",
  config = function()
    require("block_end_comment").setup()
  end,
}
```

### Manually (no plugin manager)

```
~/.config/nvim/
└── lua/
    └── block-end-comment/
        ├── init.lua
        └── parser.lua
```

In your `init.lua`:

```lua
require("block_end_comment").setup()
```

---

## ⚙️ Configuration

```lua
require("block_end_comment").setup({

  -- Comment template per filetype (%s = detected label)
  comment_style = {
    cpp        = "// end %s",
    c          = "// end %s",
    rust       = "// end %s",
    zig        = "// end %s",
    lua        = "-- end %s",
    python     = "# end %s",
    java       = "// end %s",
    go         = "// end %s",
    javascript = "// end %s",
    typescript = "// end %s",
  },

  -- Auto-insert on leaving Insert mode (default: false)
  auto_insert = true,

  -- Register default keymaps (default: true)
  -- <leader>}  = add comment
  -- <leader>{  = remove comment
  keymaps = true,

	-- Minimum number of lines a block must span before a comment is added.
	-- Avoids noise on tiny single-line blocks.
	min_block_lines = 3,
})
```

---

## 🎮 Commands

| Command                  | Description                                |
| ------------------------ | ------------------------------------------ |
| `:BlockComment`          | Insert comment on the current closing line |
| `:BlockCommentRemove`    | Remove comment from the current line       |
| `:BlockCommentAll`       | Comment all closing lines in the buffer    |
| `:BlockCommentRemoveAll` | Remove all inserted comments in the buffer |

---

## ⌨️ Default Keymaps

| Keymap      | Action         |
| ----------- | -------------- |
| `<leader>}` | Add comment    |
| `<leader>{` | Remove comment |

---

## 🌍 Supported Languages

| Language          | Closing Token | Comment Style |
| ----------------- | ------------- | ------------- |
| C / C++           | `}`           | `// end …`    |
| Rust              | `}`           | `// end …`    |
| Zig               | `}`           | `// end …`    |
| Lua               | `end` / `}`   | `-- end …`    |
| Python            | (indentation) | `# end …`     |
| Java / Go / JS/TS | `}`           | `// end …`    |

---

## 📄 License

```
Copyright 2026 markuxcu

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
