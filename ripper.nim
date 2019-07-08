import osproc, strutils, json, os, httpclient, sequtils
# proc checkRequirements() = 
  

# download metadata
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
  
# download audio
proc downloadAudio(metadata: JsonNode, albumFolder: string): string =
  # downloads the audio file returns absolute path to audio file
  let url = metadata["webpage_url"].getStr()
  stdout.write "[ripper] downloading audio: "
  stdout.flushFile()
  var returnCode = execCmd("""youtube-dl "$#" -x --audio-quality 0 --audio-format opus -o "$#/output.%(ext)s" """ % [url, albumFolder])
  if returnCode != 0:
    # stdout.write "false\p"
    # stdout.flushFile()
    # echo output
    quit()
  # else:
    # stdout.write "true\p"
    # stdout.flushFile()
  return albumFolder / "output.opus"  # toSeq(walkFiles( albumFolder / "output.*"))[0]

# extract tracks
proc extractTracks(metadata: JsonNode, albumFolder: string) = 
  echo "[ripper] extracting songs: "
  var idx = 1
  for chapter in metadata["chapters"]:
    let title = chapter["title"].getStr()
    # echo title
    let cmd = """ffmpeg -i "$#"  -ss $# -to $# -c copy "$#.opus" """ % [
      albumFolder / "output.opus", 
      $chapter["start_time"].getFloat,
      $chapter["end_time"].getFloat,
      albumFolder / $idx & "_-_" & title.replace(" ", "_")
    ]
    echo cmd
    echo execCmdEx(cmd).output
    idx.inc


proc deleteOriginal(albumFolder: string) = 
  removeFile(albumFolder / "output.opus")


when isMainModule:
  # let url = """https://www.youtube.com/watch?v=wnGSh8qP6eM"""
  # let url = """https://www.youtube.com/watch?v=2K6inwe1TwY"""
  # let url = """https://www.youtube.com/watch?v=eHZgChQpi8w"""
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


  