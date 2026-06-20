#!/bin/bash

nvim --headless -c "lua local i = require('block_end_comment'); local p = require('block_end_comment.parser'); print('OK\n')" -c "q"
