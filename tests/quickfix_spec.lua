local quickfix = require("conflict-ink.quickfix")

local function write_temp(lines)
  local path = vim.fn.tempname()
  vim.fn.writefile(lines, path)
  return path
end

describe("quickfix.build_items", function()
  it("returns one item for a file with one conflict", function()
    local path = write_temp({
      "before",
      "<<<<<<< HEAD",
      "ours",
      "=======",
      "theirs",
      ">>>>>>> feature",
      "after",
    })

    local items = quickfix.build_items({ path })
    assert.equals(1, #items)
    assert.equals(path, items[1].filename)
    assert.equals(2, items[1].lnum)
    assert.equals(1, items[1].col)
    assert.equals("[1/1] <<<<<<< HEAD", items[1].text)
  end)

  it("returns items for each conflict with correct count label", function()
    local path = write_temp({
      "<<<<<<< HEAD",
      "ours 1",
      "=======",
      "theirs 1",
      ">>>>>>> feature",
      "<<<<<<< HEAD",
      "ours 2",
      "=======",
      "theirs 2",
      ">>>>>>> feature",
    })

    local items = quickfix.build_items({ path })
    assert.equals(2, #items)
    assert.equals(1, items[1].lnum)
    assert.equals("[1/2] <<<<<<< HEAD", items[1].text)
    assert.equals(6, items[2].lnum)
    assert.equals("[2/2] <<<<<<< HEAD", items[2].text)
  end)

  it("returns empty list for file with no conflicts", function()
    local path = write_temp({ "just normal code" })
    local items = quickfix.build_items({ path })
    assert.equals(0, #items)
  end)

  it("aggregates items across multiple files", function()
    local path1 = write_temp({
      "<<<<<<< HEAD",
      "ours",
      "=======",
      "theirs",
      ">>>>>>> branch-a",
    })
    local path2 = write_temp({
      "<<<<<<< HEAD",
      "ours",
      "=======",
      "theirs",
      ">>>>>>> branch-b",
    })

    local items = quickfix.build_items({ path1, path2 })
    assert.equals(2, #items)
    assert.equals(path1, items[1].filename)
    assert.equals(path2, items[2].filename)
  end)

  it("returns empty list for empty paths table", function()
    local items = quickfix.build_items({})
    assert.equals(0, #items)
  end)
end)
