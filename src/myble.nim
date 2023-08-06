import std/asyncdispatch
import std/logging
import std/options
from std/strutils import strip
from std/strformat import fmt

import pkg/db_connector/db_sqlite

import pkg/telebot

from pkg/bibleTools/verses import parseBibleVerses, `$`, inOzzuuBible, BibleVerse

const apiSecretFile {.strdefine.} = "secret.key"
let apiSecret = strip readFile apiSecretFile

var db: DbConn

proc getFromDb(verse: BibleVerse): string =
  if verse.verses.len > 0:
    if verse.verses.len == 1:
      result = db.getValue(
        sql"SELECT text FROM verses WHERE book_number = ? AND chapter = ? AND verse = ?",
        10 * verse.book.book.ord,
        verse.chapter,
        verse.verses[0]
      )

proc inlineHandler(b: Telebot, u: InlineQuery): Future[bool] {.async, gcsafe.} =
  {.gcsafe.}:
    let verses = parseBibleVerses u.query

  var results: seq[InlineQueryResultArticle]
  for i, (verse, raw) in verses:
    var res: InlineQueryResultArticle
    res.kind = "article"
    res.title = `$`(
      verse,
      hebrewTransliteration = true,
      maxVerses = 5,
      shortBook = false
    )
    res.id = $i
    res.replyMarkup = some newInlineKeyboardMarkup(@[
      initInlineKeyboardButton(fmt"Open in Ozzuu Bible", verse.inOzzuuBible)
    ])
    res.inputMessageContent = fmt"""{res.title}
{getFromDb verse}

""".InputTextMessageContent.some

    results.add res

  echo u

  discard waitFor b.answerInlineQuery(u.id, results)

proc main(mybibleModule: string; dbUser = "", dbPass = "") {.async.} =
  var L = newConsoleLogger(fmtStr="$levelname, [$time] ")
  addHandler(L)

  db = open(mybibleModule, dbUser, dbPass, "")

  let bot = newTeleBot apiSecret
  bot.onInlineQuery inlineHandler
  bot.poll(timeout = 300)

when isMainModule:
  import pkg/cligen

  proc cli(mybibleModule: string; dbUser = "", dbPass = "") =
    waitFor main(mybibleModule, dbUser, dbPass)
  dispatch cli 
