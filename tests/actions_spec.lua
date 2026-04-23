local parser = require("conflict-ink.parser")
local render = require("conflict-ink.render")
local actions = require("conflict-ink.actions")

local function create_buf(lines)
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(bufnr)
  -- Initialize render state so actions can find conflicts
  render.refresh(bufnr, true)
  return bufnr
end

local function get_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

describe("actions", function()
  describe("choose_ours", function()
    it("keeps ours and removes markers", function()
      local bufnr = create_buf({
        "before",
        "<<<<<<< HEAD",
        "our code",
        "=======",
        "their code",
        ">>>>>>> feature",
        "after",
      })
      vim.api.nvim_win_set_cursor(0, { 3, 0 })

      actions.choose_ours(bufnr)

      assert.are.same({ "before", "our code", "after" }, get_lines(bufnr))
    end)

    it("handles diff3 by excluding base", function()
      local bufnr = create_buf({
        "<<<<<<< HEAD",
        "our code",
        "||||||| base",
        "original",
        "=======",
        "their code",
        ">>>>>>> feature",
      })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      actions.choose_ours(bufnr)

      assert.are.same({ "our code" }, get_lines(bufnr))
    end)
  end)

  describe("choose_theirs", function()
    it("keeps theirs and removes markers", function()
      local bufnr = create_buf({
        "before",
        "<<<<<<< HEAD",
        "our code",
        "=======",
        "their code",
        ">>>>>>> feature",
        "after",
      })
      vim.api.nvim_win_set_cursor(0, { 3, 0 })

      actions.choose_theirs(bufnr)

      assert.are.same({ "before", "their code", "after" }, get_lines(bufnr))
    end)
  end)

  describe("choose_both", function()
    it("keeps both sides without markers", function()
      local bufnr = create_buf({
        "<<<<<<< HEAD",
        "our code",
        "=======",
        "their code",
        ">>>>>>> feature",
      })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      actions.choose_both(bufnr)

      assert.are.same({ "our code", "their code" }, get_lines(bufnr))
    end)
  end)

  describe("choose_none", function()
    it("removes the entire conflict block", function()
      local bufnr = create_buf({
        "before",
        "<<<<<<< HEAD",
        "our code",
        "=======",
        "their code",
        ">>>>>>> feature",
        "after",
      })
      vim.api.nvim_win_set_cursor(0, { 3, 0 })

      actions.choose_none(bufnr)

      assert.are.same({ "before", "after" }, get_lines(bufnr))
    end)
  end)

  describe("choose_all_ours", function()
    it("resolves all conflicts with ours", function()
      local bufnr = create_buf({
        "<<<<<<< HEAD",
        "ours 1",
        "=======",
        "theirs 1",
        ">>>>>>> feature",
        "middle",
        "<<<<<<< HEAD",
        "ours 2",
        "=======",
        "theirs 2",
        ">>>>>>> feature",
      })

      actions.choose_all_ours(bufnr)

      assert.are.same({ "ours 1", "middle", "ours 2" }, get_lines(bufnr))
    end)
  end)

  describe("choose_all_theirs", function()
    it("resolves all conflicts with theirs", function()
      local bufnr = create_buf({
        "<<<<<<< HEAD",
        "ours 1",
        "=======",
        "theirs 1",
        ">>>>>>> feature",
        "middle",
        "<<<<<<< HEAD",
        "ours 2",
        "=======",
        "theirs 2",
        ">>>>>>> feature",
      })

      actions.choose_all_theirs(bufnr)

      assert.are.same({ "theirs 1", "middle", "theirs 2" }, get_lines(bufnr))
    end)
  end)
end)
