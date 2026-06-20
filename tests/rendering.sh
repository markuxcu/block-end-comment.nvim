#!/bin/bash

for f in tmp.*; do
  [ -f "$f" ] || continue
  echo "=== $f ==="
  nvim --headless "$f" \
    -c "lua require('block_end_comment').setup()" \
    -c "BlockCommentAll" \
    -c "%print" \
    -c "q!" 2>&1
  echo "\n"
done
