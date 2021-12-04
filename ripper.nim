import osproc, strutils, json, os, httpclient, sequtils, strformat
import detectLine, tuilib

proc checkRequirements() =
  let requirements = [
    "youtube-dl",
    "ffmpeg",
  ]
  var missingRequirement = false
  for requirement in requirements:
    if findExe(requirement) == "":
      echo "[ripper] cannot find '$#' install it please" % [requirement]
      missingRequirement = true
  if missingRequirement:
    quit()

proc downloadMetadata(url: string): string =
  stdout.write "[ripper] downloading metadata: "
  stdout.flushFile
  var (output, returnCode) = execCmdEx("""youtube-dl "$#" -j""" % [url]  )
  if returnCode != 0:
    stdout.write "false\p"
    stdout.flushFile
    echo output
    quit()
  else:
    stdout.write "true\p"
    stdout.flushFile
    return output

proc createAlbumFolder(metadata: JsonNode): string =
  # creates album folder, returns absolute path to album folder
  let folderName = metadata["title"].getStr().replace(" ", "_")
  echo "[ripper] create folder: ", folderName
  createDir(folderName)
  return folderName.absolutePath()

proc downloadThumbnail(metadata: JsonNode, albumFolder: string) =
  let thumbnail = metadata["thumbnail"].getStr()
  if thumbnail == "": return
  stdout.write "[ripper] downloading thumbnail: "
  try:
    var client = newHttpClient()
    let thumbnailRaw = client.getContent(thumbnail)
    let thumbnailExt = (thumbnail.splitFile()).ext
    writeFile(albumFolder / "cover" & thumbnailExt, thumbnailRaw)
    stdout.write "true\p"
  except:
    stdout.write "false\p"
    echo getCurrentExceptionMsg()

proc downloadAudio(metadata: JsonNode, albumFolder: string): string =
  # downloads the audio file returns absolute path to audio file
  let url = metadata["webpage_url"].getStr()
  stdout.write "[ripper] downloading audio: "
  stdout.flushFile()
  var returnCode = execCmd(
    """youtube-dl "$#" -x --audio-quality 0 --audio-format opus -o "$#/output.%(ext)s" """ % [
      url, albumFolder
  ])
  if returnCode != 0:
    quit()
  return albumFolder / "output.opus"


proc allTitlesNumbered(titles: seq[string]): bool =
  result = true
  for title in titles:
    if title.strip() == "":
      result = false
      break
    if not (title[0] in "0123456789"):
      result = false
      break

proc allChapteresNumbered(metadata: JsonNode): bool =
  let list = metadata.mapIt(it["title"].getStr())
  return allTitlesNumbered(list)

func buildCmd(combinedFile, startTime, endTime, songName: string): string =
  return fmt"""ffmpeg -i "{combinedFile}"  -ss {startTime} -to {endTime} -c copy "{songName}.opus" """

func convertDuration(duration: int): string =
  ## converts duratin in seconds to "mm:ss"
  let min = duration div 60
  let sec = duration mod 60
  return fmt"{min}:{sec}"

func cleanTitle(title: string): string =
  ## cleanup the title
  result = title
  while result.contains("  "): result = result.replace("  ", " ")
  result = result.replace(" ", "_")

func buildTitle(idx: int, title: string): string =
  return ($idx).align(2, '0') & "_-_" & title

proc inputManually(): seq[LineRes]  =
  while true:
    echo "paste here, empty newline when done:"
    var lines = ""
    while true:
      var cur = stdin.readLine()
      if cur.strip().len == 0:
        break
      lines.add cur & "\n"
    echo result
    if "happy?".askYN():
      result = detect(lines)
      break

proc ensureNumbered(lineRess: seq[LineRes]): seq[LineRes] =
  ## Ensure that all tracks are numbered, if not, then number them all
  if allTitlesNumbered(lineRess): return lineRess
  for idx, lineRes in lineRess:
    var cur = lineRes
    cur.name = fmt"{idx} {cur.name}"
    result.add cur

proc extractTracks(metadata: JsonNode, albumFolder: string) =
  echo "[ripper] extracting songs: "
  var idx = 1

  if metadata.hasKey("chapter"):
    echo "[ripper] metadata has 'chapter' use this"
    let allNumbered = metadata.allChapteresNumbered()
    for chapter in metadata["chapters"]:
      var title = chapter["title"].getStr().cleanTitle()
      if not allNumbered:
        title = buildTitle(idx, title)
      let cmd = buildCmd(albumFolder / "output.opus", $chapter["start_time"].getFloat, $chapter["end_time"].getFloat, albumFolder / title)
        # let cmd = """ffmpeg -i "$#"  -ss $# -to $# -c copy "$#.opus" """ % [
        #   albumFolder / "output.opus",
        #   $chapter["start_time"].getFloat,
        #   $chapter["end_time"].getFloat,
        #   albumFolder / title
        # ]
      echo cmd
      echo execCmdEx(cmd).output
      idx.inc
  else:
    var lineRes: seq[LineRes]
    echo "[ripper] Metadata does not contain 'chapter' try description..."
    if not metadata.hasKey("description"):
      echo "[ripper] Metadata does not contain 'description', we are lost, sorry..."
      if not askYN("input manually?"):
        quit()
      else:
        lineRes = inputManually()
    else:
      lineRes = detect(metadata["description"].getStr())

    echo lineRes
    if not "happy?".askYN():
      lineRes = inputManually()

    var songInfos = build(lineRes, metadata["duration"].getInt().convertDuration())
    for songInfo in songInfos:
      let title = buildTitle(idx, songInfo.name)
      let cmd = buildCmd(albumFolder / "output.opus", songInfo.startTime, songInfo.endTime, albumFolder / title)
      echo cmd
      echo execCmdEx(cmd).output
      idx.inc


proc deleteOriginal(albumFolder: string) =
  removeFile(albumFolder / "output.opus")

when isMainModule:
  # let url = """https://www.youtube.com/watch?v=wnGSh8qP6eM"""
  # let url = """https://www.youtube.com/watch?v=2K6inwe1TwY"""
  # let url = """https://www.youtube.com/watch?v=eHZgChQpi8w"""
  checkRequirements()
  if paramCount() == 0: quit()
  let url = paramStr(1)
  if url.strip == "": quit()
  let metadataRaw = downloadMetadata(url)
  var metadata = parseJson(metadataRaw)
  let albumFolder = metadata.createAlbumFolder
  metadata.downloadThumbnail(albumFolder)
  echo metadata.downloadAudio(albumFolder)
  metadata.extractTracks(albumFolder)
  deleteOriginal(albumFolder)