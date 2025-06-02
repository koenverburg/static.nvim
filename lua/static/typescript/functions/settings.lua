return {
  config = {
    enabled = true,
    min_lines = 5,
    debounce_ms = 100,
    virtual_text_color = "Comment",
    show_param_hints = true,
    show_early_exits = true,
    show_function_ends = true,
  },
  ns_id = vim.api.nvim_create_namespace("ts_function_hints"),
}
