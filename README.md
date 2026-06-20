# block_comment.nvim

Fügt am Ende von Codeblöcken automatisch Kommentare ein, die erklären, was geschlossen wird.  
Basiert auf **Treesitter** – präzise und sprachübergreifend.

## Unterstützte Sprachen

| Sprache    | Schließendes Token | Kommentar-Stil |
|------------|--------------------|----------------|
| C / C++    | `}`                | `// end …`     |
| Rust       | `}`                | `// end …`     |
| Zig        | `}`                | `// end …`     |
| Lua        | `end` / `}`        | `-- end …`     |
| Python     | (Einrückung)       | `# end …`      |
| Java / Go / JS / TS | `}`     | `// end …`     |

## Beispiele

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

## Installation

### lazy.nvim

```lua
{
  "yourname/block_comment.nvim",  -- oder dir = "~/.config/nvim/plugins/block_comment"
  config = function()
    require("block_comment").setup()
  end,
}
```

### Manuell (kein Plugin-Manager)

```
~/.config/nvim/
└── lua/
    └── block_comment/
        ├── init.lua
        └── parser.lua
```

In deiner `init.lua`:
```lua
require("block_comment").setup()
```

---

## Konfiguration

```lua
require("block_comment").setup({

  -- Kommentar-Template pro Filetype (%s = erkanntes Label)
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

  -- Automatisch beim Verlassen von Insert-Mode einfügen (default: false)
  auto_insert = true,

  -- Standard-Keymaps registrieren (default: true)
  -- <leader>}  = add comment
  -- <leader>{  = remove comment
  keymaps = true,
})
```

---

## Befehle

| Befehl                  | Beschreibung                                             |
|-------------------------|----------------------------------------------------------|
| `:BlockComment`         | Kommentar auf der aktuellen schließenden Zeile einfügen  |
| `:BlockCommentRemove`   | Kommentar von der aktuellen Zeile entfernen              |
| `:BlockCommentAll`      | Alle schließenden Zeilen im Buffer kommentieren          |
| `:BlockCommentRemoveAll`| Alle eingefügten Kommentare im Buffer entfernen          |

## Standard-Keymaps

| Keymap       | Aktion           |
|--------------|------------------|
| `<leader>}`  | Kommentar hinzufügen |
| `<leader>{`  | Kommentar entfernen  |

---

## Voraussetzungen

- Neovim ≥ 0.9
- `nvim-treesitter` mit den gewünschten Parsern installiert:

```vim
:TSInstall cpp rust zig lua python
```
