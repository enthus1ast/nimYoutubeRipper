import strutils

proc askYN*(prompt: string): bool =
  stdout.write prompt & " [y/n]: "
  let line = stdin.readLine().strip()
  return line == "y"
