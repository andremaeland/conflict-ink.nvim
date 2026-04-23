test:
    nvim --headless --noplugin -u tests/minimal_init.vim \
        -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.vim', sequential = true}"

test-file file:
    nvim --headless --noplugin -u tests/minimal_init.vim \
        -c "PlenaryBustedFile {{file}}"
