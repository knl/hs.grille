package = "mjolnir.grille"
version = "0.1-0"

-- General metadata:

local url = "github.com/knl/mjolnir.grille"
local desc = "Mjolnir module for moving/resizing your windows along both virtual and horizontal grids."

source = {
  url = "git://" .. url,
  tag = version,
}
description = {
  summary = desc,
  detailed = desc,
  homepage = "https://" .. url,
  license = "BSD",
}

-- Dependencies:

supported_platforms = {"macosx"}
dependencies = {
  "lua >= 5.2",
  "mjolnir.fnutils",
  "mjolnir.application",
  "mjolnir.alert",
}

-- Build rules:

build = {
  type = "builtin",
  modules = {
    ["mjolnir.grille"] = "grille.lua",
  },
}
