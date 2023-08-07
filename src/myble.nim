import std/asyncdispatch
import std/logging
from std/options import get, some
from std/strutils import strip, join, toLowerAscii, contains, split, replace
from std/strformat import fmt
from std/sugar import collect

import pkg/db_connector/db_sqlite

import pkg/telebot

from pkg/bibleTools import parseBibleVerses, `$`, inOzzuuBible, BibleVerse, UnknownBook

const apiSecretFile {.strdefine.} = "secret.key"
let apiSecret = strip readFile apiSecretFile

var db: DbConn

const
  tgMsgMaxLen = 4096
  limitReachedText = "...\n\nText too long, open it online below."

func cleanVerse(verse: string): string =
  debugecho verse
  var words: seq[string]
  for word in verse.replace("<", " <").split " ":
    debugecho word
    if word.len > 0 and word[0] != '<':
      words.add word
  result = words.join " "

proc getFromDb(verse: BibleVerse): string =
  if verse.book.book != UnknownBook:
    let bookId = 10 * verse.book.book.ord
    if verse.verses.len == 1:
      let
        verseNum = verse.verses[0]
        text = db.getValue(
          sql"SELECT text FROM verses WHERE book_number = ? AND chapter = ? AND verse = ?",
          bookId,
          verse.chapter,
          verseNum
        )
      result = fmt"{verseNum} {cleanVerse text}"
    elif verse.verses.len > 0:
      let versesQuery = collect(for verse in verse.verses: fmt"verse = {verse}").join " OR "
      for row in db.rows(
        sql fmt"SELECT verse, text FROM verses WHERE book_number = ? AND chapter = ? AND ({versesQuery})",
        bookId,
        verse.chapter
      ):
        result.add fmt"{row[0]} {cleanVerse row[1]}" & "\l"
    if result.len > tgMsgMaxLen:
      result = result[0..tgMsgMaxLen - limitReachedText.len]
      result.add limitReachedText

proc inlineHandler(b: Telebot, u: InlineQuery): Future[bool] {.async, gcsafe.} =
  if u.fromUser.isBot: return

  {.gcsafe.}:
    let verses = parseBibleVerses u.query
  var results: seq[InlineQueryResultArticle]
  for i, (verse, raw) in verses:
    if verse.verses.len == 0:
      continue
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
    res.inputMessageContent = some InputTextMessageContent(
      res.title &
      "\l\l" &
      getFromDb verse
    )

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
