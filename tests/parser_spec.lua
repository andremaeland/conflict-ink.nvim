local parser = require("conflict-ink.parser")

local function create_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

describe("parser", function()
  it("finds a single conflict", function()
    local bufnr = create_buf({
      "before",
      "<<<<<<< HEAD",
      "ours line",
      "=======",
      "theirs line",
      ">>>>>>> feature",
      "after",
    })

    local conflicts = parser.parse(bufnr)
    assert.equals(1, #conflicts)
    assert.equals(1, conflicts[1].start)
    assert.equals(3, conflicts[1].separator)
    assert.equals(5, conflicts[1].finish)
    assert.equals("<<<<<<< HEAD", conflicts[1].ours_label)
    assert.equals(">>>>>>> feature", conflicts[1].theirs_label)
  end)

  it("finds multiple conflicts", function()
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

    local conflicts = parser.parse(bufnr)
    assert.equals(2, #conflicts)
    assert.equals(0, conflicts[1].start)
    assert.equals(4, conflicts[1].finish)
    assert.equals(6, conflicts[2].start)
    assert.equals(10, conflicts[2].finish)
  end)

  it("handles diff3 with base section", function()
    local bufnr = create_buf({
      "<<<<<<< HEAD",
      "ours line",
      "||||||| merged common ancestor",
      "base line",
      "=======",
      "theirs line",
      ">>>>>>> feature",
    })

    local conflicts = parser.parse(bufnr)
    assert.equals(1, #conflicts)
    assert.equals(0, conflicts[1].start)
    assert.equals(2, conflicts[1].base)
    assert.equals(4, conflicts[1].separator)
    assert.equals(6, conflicts[1].finish)
    assert.equals("||||||| merged common ancestor", conflicts[1].base_label)
  end)

  it("returns empty list when no conflicts", function()
    local bufnr = create_buf({
      "just normal code",
      "nothing to see here",
    })

    local conflicts = parser.parse(bufnr)
    assert.equals(0, #conflicts)
  end)

  it("handles empty ours section", function()
    local bufnr = create_buf({
      "<<<<<<< HEAD",
      "=======",
      "theirs line",
      ">>>>>>> feature",
    })

    local conflicts = parser.parse(bufnr)
    assert.equals(1, #conflicts)
    assert.equals(0, conflicts[1].start)
    assert.equals(1, conflicts[1].separator)
  end)

  it("handles empty theirs section", function()
    local bufnr = create_buf({
      "<<<<<<< HEAD",
      "ours line",
      "=======",
      ">>>>>>> feature",
    })

    local conflicts = parser.parse(bufnr)
    assert.equals(1, #conflicts)
    assert.equals(2, conflicts[1].separator)
    assert.equals(3, conflicts[1].finish)
  end)

  it("ignores incomplete conflict markers", function()
    local bufnr = create_buf({
      "<<<<<<< HEAD",
      "ours line",
      "=======",
      "no closing marker",
    })

    local conflicts = parser.parse(bufnr)
    assert.equals(0, #conflicts)
  end)
end)
