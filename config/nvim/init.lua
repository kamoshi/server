local plugins = {
    {
        'rebelot/kanagawa.nvim',
        lazy     = false,
        priority = math.huge,
        config   = function()
            vim.cmd 'colorscheme kanagawa'
        end,
    },
    {
        'nvim-lualine/lualine.nvim',
        dependencies = {
            'nvim-tree/nvim-web-devicons',
        },
        config = true,
    },
}

do
    local data = vim.fn.stdpath 'data'
    local path = data .. '/lazy/lazy.nvim'

    if not vim.loop.fs_stat(path) then
        vim.fn.system {
            'git',
            'clone',
            '--filter=blob:none',
            'https://github.com/folke/lazy.nvim.git',
            '--branch=stable',
            path,
        }
    end

    vim.opt.rtp:prepend(path)
    require 'lazy'.setup(plugins)
end
