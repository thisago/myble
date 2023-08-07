# Package

version       = "0.3.0"
author        = "Thiago Navarro"
description   = "MyBible Telegram bot"
license       = "GPL-3.0-or-later"
srcDir        = "src"
bin           = @["myble"]

binDir = "build"

# Dependencies

requires "nim >= 1.6.0"

requires "bibleTools"

requires "db_connector"
requires "telebot"
requires "cligen"
