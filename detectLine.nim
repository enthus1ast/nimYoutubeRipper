import strutils


type
  LineRes* = tuple[name: string, pos: string]
  SongInfo* = tuple[startTime, endTime, name: string]

const allowedCharsInPos = Digits + {':'}

proc onlyContains(str: string, allowedChars: set[char]): bool =
  for ch in str:
    if ch in allowedChars: continue
    else: return false
  return true

proc detect*(lines: string): seq[LineRes] =
  for line in lines.splitLines:
    if not line.contains(":"): continue
    var words = line.splitWhitespace()
    var lineRes: LineRes
    var nameWords: seq[string]
    for word in words:
      let cleanWord = word.strip(true, true, {':', '(', ')'} + Whitespace)
      if cleanWord.onlyContains(allowedCharsInPos):
        lineRes.pos = cleanWord
      else:
        nameWords.add cleanWord
    lineRes.name = nameWords.join(" ")
    if not (lineRes.name.len == 0 or lineRes.pos.len == 0):
      result.add lineRes

proc build*(lineRess: seq[LineRes], playTime: string): seq[SongInfo] =
  var pos = 0
  while true:
    if pos == lineRess.len - 1:
      result.add (lineRess[pos].pos, playTime, lineRess[pos].name)
      break

    var curStart = lineRess[pos].pos
    var curEnd = ""
    var curSong = lineRess[pos].name
    if pos == lineRess.len:
      curEnd = playTime
    else:
      curEnd = lineRess[pos+1].pos
    result.add (curStart, curEnd, curSong)
    if pos == lineRess.len: break
    pos.inc

when isMainModule:
  var t1 = """Don't forget to buy the album to support the band: https://smarturl.it/Jinjer-Macro

All content on this video is property of the copyright owners


On the top 0:00
Pit of consciousness 5:29
Judgement (& Punishment) 9:41
Retrospection 14:01
Pausing Death 18:25
Noah 23:10
Home back 27:24
The Prophecy 31:45
Lainnerep 35:46"""

  echo detect(t1).build("40:00")
  # echo detect("0:00: On the top")
  # echo detect("(0:00) On the top")
  # echo detect("On the top: 0:00")
  # echo detect("0:00 On the top")
  # echo detect(t1)
  # # assert detect("On the top 0:00") == @[("On the top", "0:00")]