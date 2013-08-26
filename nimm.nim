# 
# Parse theindex.html to extract document snippet.
#
# Usage:
#   export NIMDOC=/path/to/nimrod/doc
#   nimm
#
#   nimm> m             # shows list of supported modules
#   nimm> m <module>    # shows all the symboles of the module
#   nimm> <symbol>      # show the descript of the symbol
#
# TODO:
#   store the parsed contents in a in-memory data structure
#   read from structured data
#

import os, streams, parsexml, strutils, strtabs, tables, sets
import rdstdin, algorithm

const textNode = { xmlCharData, xmlWhitespace }
const nimrodDoc = "NIMDOC"

type
  IndexEntries = TTable[string, seq[string]]

# case-insenstive compare
proc `~==` (a, b: string): bool = cmpIgnoreCase(a, b) == 0

proc isEndElement(x: TXmlparser, el: string): bool =
  result = x.kind == xmlElementEnd and x.elementName ~== el

proc isStartElement(x: TXmlparser, el: string): bool =
  result = x.kind == xmlElementStart and x.elementName ~== el

proc isOpenElement(x: TXmlparser, el: string): bool =
  result = x.kind == xmlElementOpen and x.elementName ~== el

proc innerText(x: var TXmlParser): string =
  result = ""
  while x.kind in textNode:
    result.add(x.charData)
    next(x)

proc getKeyword(x: var TXmlParser): string =
  while not x.isEndElement("dt"):
    if x.isStartElement("span"): 
      next(x)
      return innerText(x)
    next(x)

proc getRefEntry(x: var TXmlParser): string =
  # skip tag <a> attr's
  while x.kind != xmlCharData:
    next(x)
  result = ""
  while x.kind == xmlCharData: 
    result.add(x.charData)
    next(x)

proc getReferences(x: var TXmlParser): seq[string] =
  result = @[]
  while not x.isEndElement("dd"):
    if x.isOpenElement("a"):
      next(x)
      result.add(getRefEntry(x))
    next(x)

proc tagNeedsLinefeed(x: TXmlParser): bool =
  return x.isStartElement("p") or
         x.isStartElement("br") or
         x.isStartElement("tr") or
         x.isStartElement("li")
 
proc extractNode(x: var TXmlParser): string =
  # extract current dt, dd text
  result = ""
  while not x.isEndElement("dt"):
    if x.kind in textNode:
      result.add(x.charData)
    elif x.tagNeedsLinefeed():
      result.add("\n")
    next(x)
  while not x.isEndElement("dd"):
    if x.kind in textNode:
      result.add(x.charData)
    elif x.tagNeedsLinefeed():
      result.add("\n")
    next(x)

proc getItemId(x: var TXmlParser): string =
  next(x)
  while x.kind == xmlAttribute:
    if x.attrKey() == "id":
      return x.attrValue()
    next(x)

proc openFileAsStream(filename: string): PStream =
  let docPath = getEnv(nimrodDoc)
  if docPath == "":
    return nil
  return newFileStream(docPath / filename, fmRead)

proc moduleName(filename: string): string = filename.splitFile().name

proc getItem(e: string): string =
  # e is of the form "system.html#206". Read system.html
  # and extract the element with an id #206.
  result = ""
  var tokens = e.split('#')
  var filename = tokens[0]
  var id = tokens[1]
  var s = openFileAsStream(filename)
  if s == nil:
    return

  var x: TXmlParser
  open(x, s, filename, { reportWhitespace })
  next(x)
  while true:
    if x.isOpenElement("dt"):
      if x.getItemId() == id:
        result.add("==== " & filename.moduleName() & " ====================\n")
        result.add(extractNode(x))
        break
    elif x.kind == xmlEof:
      break
    next(x)
  close(x)  

proc getSuggestion(q: string, index:IndexEntries): string =
  result = ""
  for diff in 2..5:
    for key in index.keys():
      var d = editDistance(key, q)
      #echo("key: " & key & " dist:" & $(d))
      if d <= diff:
        result.add(key)
        result.add(' ')
    if len(result) > 0:
      break


proc buildIndex(filename: string): IndexEntries =
  var s = openFileAsStream(filename)
  if s == nil:
    quit("cannot open the file " & filename & ". Did you set the env NIMDOC?")

  var 
    x: TXmlParser
    keyword: string
    entries: seq[string]
    indexTable: IndexEntries = initTable[string, seq[string]]()

  open(x, s, filename, { reportWhitespace })
  next(x) # get first event

  while true:
    if x.isStartElement("dt"):
      keyword = getKeyword(x).toLower
      next(x)
    elif x.isStartElement("dd"):
      entries = getReferences(x)
      if keyword != nil:
        indexTable[keyword] = entries
        keyword = nil
      next(x)
    else:
      case x.kind
      of xmlEof: break # end of file reached
      of xmlError: 
        echo(errorMsg(x))
        next(x)
      else:
        next(x) # skip other events
  x.close()
  result = indexTable

proc buildModuleRoster(index: IndexEntries): seq[string] =
  result = @[]
  var modules: TSet[string] = initSet[string]()
  for e in index.values():
    for s in e:
      modules.incl(moduleName(s))
  for e in modules:
    result.add(e)
  sort(result, cmp)

proc sectionName(x: var TXmlParser): string
proc sectionItems(x: var TXmlParser): string
proc className(x: var TXmlParser): string
proc extractModuleBrief(x: var TXmlParser): string

proc modulePublicSymbol(query: string): seq[string] =
  # query is of the form "m <module>"
  var filename = query.split(' ')[1] & ".html"
  var s = openFileAsStream(filename)
  if s == nil:
    return

  var x: TXmlParser
  open(x, s, filename, { reportWhitespace })
  next(x)
  result = @[]
  while true:
    if x.isOpenElement("div") and x.className == "section":
      next(x)
      result.add(sectionName(x))
    elif x.isOpenElement("dl") and x.className == "item":
      next(x)
      result.add(sectionItems(x))
    elif x.kind == xmlEof:
      break
    next(x)
  close(x)  

proc className(x: var TXmlParser): string =
  next(x) # move to attribute
  while x.kind == xmlAttribute:
    if x.attrKey ~== "class":
      return x.attrValue
    next(x)
  return ""

proc sectionName(x: var TXmlParser): string =
  while true:
    if x.isOpenElement("a") and x.className == "toc-backref":
      # skip to inner text node containing the section name
      while x.kind notin textNode:
        next(x)
      return "==== " & innerText(x) & "===="
    elif x.kind == xmlEof:
      break
    next(x)

proc sectionItems(x: var TXmlParser): string =
  result = ""
  # collect all the text under <dt> tags
  while not x.isEndElement("dl"):
    if x.isOpenElement("dt"):
      result.add(extractModuleBrief(x))
    next(x)

proc extractModuleBrief(x: var TXmlParser): string =
  # extract current dt, dd text
  result = ""
  while not x.isEndElement("dt"):
    if x.kind in textNode:
      result.add(x.charData)
    elif x.tagNeedsLinefeed():
      result.add("\n")
    next(x)
  result.add("\n")

proc run(): int {.discardable.} =
  const filename = "theindex.html"

  var
    indexTable: IndexEntries = buildIndex(filename)
    modules: seq[string]

  modules = buildModuleRoster(indexTable)

  while true:
    var query = ReadLineFromStdin("nimm> ").strip.toLower
    if len(query) == 0:
      continue
    if query == "bye" or query == "exit":
      break
    elif query == "m":
      echo("Available modules:\n" & join(modules, ", "))
    elif query.startsWith("m "):
      echo(join(modulePublicSymbol(query), "\n"))
    else:
      var resp = indexTable[query]
      if resp != nil:
        for e in resp:
          echo(getItem(e))
      else:
        echo("No match found. Suggestion: " & getSuggestion(query, indexTable))

when isMainModule:
  run()
