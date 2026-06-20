# block-end-comment.nvim 🧩

Automatically inserts comments at the end of code blocks to show what is being closed.  
Built on **Treesitter** – precise and cross-language.

## 📑 Table of Contents

- [✨ Examples](#-examples)
- [📋 Requirements](#-requirements)
- [📦 Installation](#-installation)
- [⚙️ Configuration](#️-configuration)
- [🎮 Commands](#-commands)
- [⌨️ Default Keymaps](#️-default-keymaps)
- [🌍 Supported Languages](#-supported-languages)

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
  "markuxcu/block_comment.nvim",
  config = function()
    require("block_comment").setup()
  end,
}
```

### Manually (no plugin manager)

```
~/.config/nvim/
└── lua/
    └── block_comment/
        ├── init.lua
        └── parser.lua
```

In your `init.lua`:

```lua
require("block_comment").setup()
```

---

## ⚙️ Configuration

```lua
require("block_comment").setup({

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
