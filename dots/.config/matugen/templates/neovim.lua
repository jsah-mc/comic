local palette = {
  base00 = "{{colors.background.default.hex}}",
  base01 = "{{colors.surface_container_lowest.default.hex}}",
  base02 = "{{colors.surface_container_low.default.hex}}",
  base03 = "{{colors.outline_variant.default.hex}}",
  base04 = "{{colors.on_surface_variant.default.hex}}",
  base05 = "{{colors.on_surface.default.hex}}",
  base06 = "{{colors.inverse_on_surface.default.hex}}",
  base07 = "{{colors.surface_bright.default.hex}}",
  base08 = "{{colors.tertiary.default.hex | lighten: -5}}",
  base09 = "{{colors.tertiary.default.hex}}",
  ["base0A"] = "{{colors.secondary.default.hex}}",
  ["base0B"] = "{{colors.primary.default.hex}}",
  ["base0C"] = "{{colors.tertiary.default.hex}}",
  ["base0D"] = "{{colors.primary.default.hex}}",
  ["base0E"] = "{{colors.secondary.default.hex}}",
  ["base0F"] = "{{colors.secondary.default.hex | lighten: -10}}",
}

local function apply()
  require("base16-colorscheme").setup(palette)
  vim.g.colors_name = "matugen"
  vim.api.nvim_set_hl(0, "Visual", { bg = palette["base0D"], fg = palette.base00 })
  vim.api.nvim_set_hl(0, "Comment", { fg = palette.base03, italic = true })

  local lualine_ok, lualine = pcall(require, "lualine")
  if lualine_ok then
    lualine.refresh()
  end
end

if package.loaded["base16-colorscheme"] then
  apply()
end

return {
  "RRethy/base16-nvim",
  lazy = false,
  priority = 1000,
  config = apply,
}
